## Why

The `event-batcher` spec bounds a batch only by event count, flush interval, and explicit flush.
The one place size appears is reactive: "Some SDKs reduce effective batch size after
oversized-payload errors (`413`)". Ingestion refuses a request body over the deployment's limit —
10 MiB on PostHog's hosted ingestion, as the `logs` spec already records — so an SDK that batches
by count alone can build a request it cannot send, and lose the whole batch when it is refused.

Two SDKs now bound the batch by serialized bytes before sending, with the same ~5 MiB target:

| SDK | Byte bound on analytics requests | Where |
|---|---|---|
| posthog-js (browser-next capture v1) | 5 MiB target per request alongside the event-count limit; `partitionEvents` starts a new request when the next event would cross it | `packages/browser-next/src/capture-v1.ts` (`CAPTURE_V1_BATCH_TARGET_BYTES`) |
| posthog-rs | background analytics sends split into requests of at most 5 MiB of serialized events; a larger event is sent alone, with no per-event cap | [posthog-rs#288](https://github.com/PostHog/posthog-rs/pull/288) (merged 2026-10-18) |
| posthog-python, posthog-node, posthog-go, posthog-ios, posthog-android | count-based batching only, `413` handling after the fact | — |

The `capture-ai` spec already names an "~5 MiB batch target" for the AI lane, but explicitly as a
non-normative transport note. Nothing states the rule for the analytics lane.

## What Changes

- Adds one `event-batcher` requirement, **Analytics requests are bounded by serialized size**: an
  SDK-managed analytics send SHALL be split so each request stays within a byte target below the
  deployment's body limit, in addition to any event-count limit.
- States that splitting is not dropping: order is preserved, no event is discarded, and an event
  larger than the target is sent in a request of its own rather than dropped — the analytics lane
  has no per-event size cap.
- Leaves the existing `413` shrink path in place as the reactive backstop.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `event-batcher`: adds the **Analytics requests are bounded by serialized size** requirement.

## Impact

- posthog-js (capture v1) and posthog-rs already satisfy this. The count-only SDKs would need a
  byte bound added; until then they rely on `413` shrink, which still applies.
- The target is stated as "below the deployment's limit, ~5 MiB where SDKs have picked a number"
  rather than a single mandated constant, because the limit is deployment-dependent (2 MiB default,
  10 MiB hosted) and compression changes the bytes actually sent. See also the open compression
  change (#81), which governs whether a body is gzipped at all.
- No acceptance feature scenarios are added; the scenarios here are spec-level only.
