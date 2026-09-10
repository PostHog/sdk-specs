## Why

The `traces` spec preceded its first implementation. That implementation has now shipped —
[PostHog/posthog-js#4579](https://github.com/PostHog/posthog-js/pull/4579), `posthog-node` — after
review against W3C Trace Context, OTLP and OpenTelemetry JS, and it had to decide things the spec
leaves open. Other ports will meet the same questions, so the answers belong in the contract. Each
item below is either behavior that shipped and was verified by running it, or an error in the spec
that production contradicts. They fall into two groups: the OTLP retry policy that `logs` and
`traces` share, and the rest of the `traces` contract.

### The retry policy

Two gaps found while reviewing the `Retry-After` work in
[PostHog/posthog-js#4726](https://github.com/PostHog/posthog-js/pull/4726), both raised by
@jonmcwest against the OTLP specification.

**The retry policy is silent on repeated refusals.** It states the wait for *a* refusal —
`max(ownBackoff, min(parsedRetryAfter, documentedMaximum))` — and says nothing about a second
refusal arriving while the window from the first is still open. Read literally, each refusal
installs a fresh wait, so a host refused faster than the window is long refreshes the deadline
indefinitely and the window never elapses. That matters because `logs` gates its size trigger and
its reconnect trigger on the window being closed, and `metrics` re-arms its timer from it: an
unbounded slide suppresses all three for as long as the host keeps flushing. A React Native app
taking `flush()` on every app-state transition reaches this in normal operation.

**The `5xx` retry set is a deviation from OTLP that is not recorded as one.** The policy requires
`408`/`429`/`5xx` to be retriable. OTLP permits retries only for `429`, `502`, `503` and `504`,
and forbids retrying other `4xx`/`5xx`. The PostHog rule is deliberate — ingestion returns
transient `500`s that are worth retrying, and the predicate is shared with the analytics-events
transport, where narrowing it would drop events — but nothing in the spec says so, so each
reviewer rediscovers it as a possible defect.

Neither is urgent: `capture-logs` sends no `Retry-After` and no `429` today, so every header an
SDK sees comes from a customer's proxy, CDN or load balancer.

Three more came out of the review rounds on
[PostHog/posthog-js#4579](https://github.com/PostHog/posthog-js/pull/4579), the first traces
implementation. Each was a bug found there by running it, and each follows from the traces
requirement leaving something unsaid. These apply to any `5xx` outage, not only to `Retry-After`.

**Automatic sends are not paused during backoff.** `logs` says "pause sends"; `traces` only says
"retry with exponential backoff". A queue above `maxExportBatchSize` for a whole outage re-sends on
every span end: the depth trigger cancelled the backoff, and an outage cost ~1,500 requests
instead of one per backoff window.

**The retry budget is ambiguous about what it counts.** "A bounded number of retries on the same
batch" reads as attempts. A serverless host calls `flush()` per request, so counting attempts
drops a batch after a handful of requests during a blip. And nothing ties the budget to the spans
that spent it, so a retried batch that grows to take in fresh spans drops them on failures they
never had.

**Dropping a batch at the budget can end the wait early.** With the batch gone, the drain carries
straight on to the next batch inside the endpoint's `Retry-After` window.

### The traces contract

**The spec states the wrong body limit.** `traces` and `logs` both say the ingestion body cap is
2 MB. That is only the service default (`MAX_REQUEST_BODY_SIZE_BYTES`, 2 MiB); PostHog's hosted
ingestion runs 10 MiB. Verified on 2026-09-10 against `/i/v1/traces` and `/i/v1/logs`, in both US
and EU: 9.9 MiB accepted, 10.1 MiB refused with `413`. An SDK that measures bodies before sending
(which the spec permits) and takes the spec's 2 MB at its word refuses bodies production accepts,
and drops them with no `413` to show for it.

**Several validity rules are unstated, and one gap costs a whole batch.**

- An unpaired UTF-16 surrogate in any string makes the service reject the entire request —
  verified: `Failed to decode JSON: unexpected end of hex escape`. The client-side validity
  requirement covers ids, names and timestamps, not string well-formedness.
- The spec says an invalid `traceparent` is ignored, but not what invalid means. Uppercase hex,
  version `ff`, and version `00` with trailing fields are all invalid under W3C; accepting them
  continues a trace a conformant peer restarts, splitting it across services.
- `tracestate` has a member limit (32, a grammar rule) and a propagation length (512, a size
  guideline to trim to, not a validity ceiling). Treating the length as validity discards state a
  peer expects forwarded.
- Empty attribute keys are stored verbatim as nameless attributes.
- OpenTelemetry caps attributes per event (default 128); the spec caps only attributes and events
  per span, so one event can carry an unbounded bag.

**`service.name` can be crowded out.** A `resourceAttributes` value large enough to exhaust the
encoder's traversal budget cost the resource its `service.name`, leaving records unattributed.

**Two runtime shapes are missing.** A serverless host holds an invocation open only for work
registered with its keep-alive (`waitUntil`); a handler that records spans but captures no events
registered nothing, and its spans were lost with the invocation. And edge runtimes lack an
async-context primitive, so spans there nest across an `await` only with an explicit `parent` —
the same limitation the spec already allows the browser.

**Child spans can land outside their parent.** Each span anchoring to its own millisecond
wall-clock reading lets a child start before or end after its parent by up to a millisecond, and
by more across a wall-clock step. Observed in production: a child ended 0.6 ms after its parent
root. OpenTelemetry JS (sdk-trace-base 1.30.1, sdk-trace 2.11) behaves the same way, so this is
an improvement on the reference rather than parity.

## What Changes

### Retry policy

- **Repeated refusals bound the window.** A refusal naming a longer wait than the one being served
  SHALL extend the deadline, and SHALL NOT pull it in. The extension is bounded by the documented
  maximum measured from where the window was **first installed**, so a window can never be held
  open indefinitely. When the ceiling is reached the window closes, the next attempt goes out, and
  a further refusal installs a new window.
- **The `5xx` deviation is recorded.** The retry-status set is stated as a deliberate divergence
  from OTLP's retryable-response-codes, with the reason, and with the condition under which it
  would be revisited.
- **The retry budget running out does not end a `Retry-After` window**, and **backoff delays
  SHOULD carry jitter** so clients refused together do not return together.

Stated in the same words in `logs` and `traces`, as the surrounding policy already requires.

`traces` only, in the part of the requirement that already differs from `logs`:

- **Automatic sends pause during backoff.** The flush timer and the depth trigger wait; only a
  caller-driven flush MAY send inside the backoff. This brings `traces` level with `logs`.
- **The budget counts backoff windows, not attempts, and belongs to the batch that failed.** A
  refusal before the previous charge's delay has elapsed is not charged, and a retried batch does
  not grow to take in spans enqueued behind it.
- **Dropping a batch at the budget does not send the next one inside an open `Retry-After`
  window.**

### Traces contract

- **Body limit corrected** in `traces` and `logs`: deployment configuration, 2 MiB by default and
  10 MiB on PostHog's hosted ingestion. An SDK that measures bodies measures against the largest
  known deployment limit, not the default; batch-size defaults stay sized for the default.
- **String well-formedness** added to client-side validity: unpaired surrogates become U+FFFD in
  every wire string.
- **`traceparent` and `tracestate` validity** spelled out per W3C, with `tracestate` trimmed by
  whole members past 512 characters rather than discarded. An SDK MAY accept a single-value
  multi-value header as `parent`.
- **Empty attribute keys** dropped with a debug warning, in `traces` and `logs` — `posthog-js`
  already drops them for both through the shared encoder.
- **Per-event attribute cap** of 128, counted in the event's `droppedAttributesCount`; MAY be
  fixed rather than configurable.
- **`service.name` survives an oversized `resourceAttributes` value**, in `traces` and `logs`: the
  SDK-set identity keys encode on their own budget.
- **Serverless keep-alive** becomes a flush trigger: a span ending registers the drain with
  `waitUntil`.
- **Edge runtimes** join the browser as MAY-be-synchronous-only, with documentation required to
  name the explicit `parent`.
- **Shared clock basis** (SHOULD): a span under a local, non-backdated parent takes its start on
  its root's basis — the root's wall-clock start plus monotonic elapsed — so children stay inside
  their parents.

### Trade-off recorded

Bounding the window means a wait longer than the ceiling is served short: the SDK may retry before
a newer `Retry-After` has expired, which OTLP does not sanction. The alternative — honouring every
fresh header — makes the suppression above unbounded, which costs records once the queue fills.
One risks a request against a rate-limited endpoint every few minutes; the other risks data. The
ceiling is the choice that fails toward keeping records.

If ingestion begins issuing `Retry-After` itself — [posthog/posthog#75090](https://github.com/PostHog/posthog/pull/75090)
was closed unmerged and nothing has replaced it — the deadline stops being a proxy's guess and
this SHOULD be revisited in favour of honouring the header literally.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `traces`: **Active span context and parenting**, **Trace context interop**, **Span data model**,
  **Client-side validity**, **Span limits**, **Attribute value encoding**, **Resource and scope**,
  **Flush triggers**, **Batch assembly and concurrency**, **Error handling and retries**,
  **Server-side contract**.
- `logs`: **Attribute value encoding**, **Resource and scope**, **Batch assembly and concurrency**,
  **Error handling and retries**, **Server-side contract**. Its **Error handling and retries** carries the shared
  retry-policy additions in the same words as `traces`.

## Impact

- `openspec/specs/traces/spec.md` and `openspec/specs/logs/spec.md` — source of truth, updated via
  this change's delta on archive.
- `posthog-js` implements everything here as of #4579 (which carries
  [#4726](https://github.com/PostHog/posthog-js/pull/4726)), except the shared clock basis, which is
  [PostHog/posthog-js#4908](https://github.com/PostHog/posthog-js/pull/4908).
- Other ports inherit these rules when they implement traces or the retry policy.
- No ingestion-service change is required. The status-set deviation is documentation only; any
  future narrowing needs the ingestion team to state which `5xx` responses are transient, and
  would be a separate proposal.
