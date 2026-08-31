## Context

Several SDKs use a bounded file-backed queue but also carry a retry counter in the flush controller. When exhausting that counter clears the queue, a scheduling safeguard becomes a durability policy: records can disappear without a server response proving them invalid. This is especially damaging during offline periods because a durable backlog may contain records that were never part of the failing request.

A separate race exists when a flush peeks at the first N records and later removes the first N positions after success. If producers fill the queue while that request is in flight, capacity eviction can replace the sent records. Positional removal then deletes the replacements even though they were never sent.

Browser SDKs commonly use page-lifetime best-effort buffers. The durable retention requirements below apply only when an SDK owns a bounded queue intended to survive process or application restarts; they do not require an ephemeral buffer to gain persistence.

## Goals / Non-Goals

**Goals:**

- Define queue durability independently from retry scheduling.
- Preserve records in bounded durable queues after retryable failures exceed a flush retry budget.
- Avoid transport attempts and retry-budget consumption while network state is positively known to be offline.
- Resume eligibility when connectivity returns without allowing a tight retry loop.
- Remove successful in-flight records by stable queue-entry identity.
- Keep capacity, eviction, and backoff bounded.

**Non-Goals:**

- Make browser or other page-lifetime buffers persistent.
- Add, rename, or deprecate a public retry option.
- Standardize an exact retry count, delay formula, connectivity API, or queue capacity.
- Reclassify terminal HTTP responses, serialization failures, or single-record `413` failures.
- Change explicit queue clearing required by consent, reset, or another documented lifecycle operation.

## Decisions

### Durable records have explicit removal conditions

A record in a bounded durable queue remains until its exact queue entry is acknowledged, it receives a terminal disposition, capacity eviction selects it, or an explicit lifecycle operation clears it. A retryable failure and exhaustion of a retry budget are not terminal dispositions.

This applies to recognized pre-response transport failures and retryable HTTP responses such as `408`, `429`, and `5xx`. Queue capacity bounds retained storage, while backoff and retry budgets bound request activity.

### Retry budgets govern failure-driven flush sequences

An SDK may use a retry budget to stop an active failure-driven sequence. Ending that sequence leaves the records queued. A later independent trigger—such as a periodic flush, new capture crossing a threshold, connectivity recovery, explicit `flush()`, or process relaunch—may start another sequence, subject to the queue's current cooldown.

This preserves the resource-control purpose of existing retry settings without treating them as record-retention limits. The specification does not require every SDK to expose such a setting.

### A positive offline signal pauses transport

When an SDK's connectivity facility positively reports no network, queue processing does not start a request and does not consume a retry attempt. Enqueues continue subject to capacity. Connectivity recovery makes the queue eligible for normal processing again.

Connectivity is a scheduling hint, not a delivery verdict. If state is unknown or monitoring is unavailable, the SDK may attempt delivery and classify the resulting transport error normally. A stale or unavailable monitor must never authorize record deletion.

### Successful acknowledgements use queue-entry identity

A flush snapshots both payloads and stable queue-entry identities. On success it removes only matching entries still present in the live queue. Suitable identities include persisted filenames, stable event identifiers, or an equivalent queue-owned token.

If capacity pressure evicts an in-flight entry, its later acknowledgement is harmless because that identity is no longer present. Records inserted as replacements remain queued. Implementations must not acknowledge a batch by deleting the current first N positions.

### Product queue contracts defer to the durable lifecycle

Logs and traces retain their existing retryable and terminal status classifications. Their retry budgets may end an active sequence, but bounded durable implementations retain the affected records for a later trigger. Best-effort non-durable implementations may retain their documented lifecycle behavior.

## Risks / Trade-offs

- [A persistent outage keeps old records resident] → Existing capacity and eviction policies continue to bound storage.
- [Frequent independent triggers could bypass a stopped retry sequence] → Triggers respect the queue's current cooldown and bounded backoff.
- [Connectivity monitors can be stale or unavailable] → Treat them only as positive pause signals; unknown state falls back to transport classification.
- [Stable identity requires a queue API change] → Reuse existing persisted filenames or record ids rather than introducing a public identifier.
- [Retry settings become narrower than their historical name suggests] → Document them as flush-attempt controls without changing their public shape in this change.
