## Why

[posthog-js#4347](https://github.com/PostHog/posthog-js/pull/4347) ("preserve events added to
queue flush") fixed an event-loss bug in `@posthog/core`'s shared stateless queue
(`posthog-core-stateless.ts`), shipped to `posthog-node`, `posthog-react-native`, and
`posthog-js-lite` alongside `posthog-js` itself. When a flush completed, the persisted queue was
trimmed with `refreshedQueue.slice(batchItems.length)` — a **positional** removal. If the queue
had hit `maxQueueSize` and been refilled with newly captured events while the original batch was
still in flight (a realistic high-throughput race: capture happens on the live queue while an
async request for a snapshot of it is outstanding), the positional slice removed whichever items
now sat in the first N slots — the new replacement events, not the already-sent ones — silently
dropping them.

The fix removes flushed items by object identity or stable event UUID instead of position, with
a regression test that fills the queue during an in-flight flush and asserts the replacement
events survive and are sent by the next flush.

`openspec/specs/retry-queue/spec.md` already states the intended outcome in the abstract
("Preserve queued events for retry... Successful sends delete/remove the events from the
queue/storage") but never says *how* "the events" that were sent must be identified when the
live queue has changed shape since the batch was snapshotted. The spec's "Concurrency &
ordering guarantees" section only says "Concurrent producers can enqueue while a flush is in
progress; backpressure behavior when full is SDK-specific" — silent on whether those
concurrently-enqueued events must survive a same-tick flush of an unrelated batch. This is a
real spec gap: positional removal is a plausible, spec-compliant-looking implementation that
this bug fell into, and the spec gives no reason to prefer identity-based removal over it.

## What Changes

- **Requirement prose** (`Canonical retry-queue behavior`): adds an explicit removal-by-identity
  clause to the "preserve queued events for retry" behavior — sent events must be identified by
  object identity or a stable event id when trimming the queue after a flush, not by their
  position in the live queue, so events captured concurrently during an in-flight flush are not
  mistaken for the just-sent batch and dropped.
- **New scenario**: events added to a full queue while an earlier batch is mid-flight must
  remain queued and be delivered by the next flush, not silently discarded.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `retry-queue`: the single `Canonical retry-queue behavior` requirement gains one new scenario
  on flush-time removal correctness. The three existing scenarios are unchanged.

## Impact

- `openspec/specs/retry-queue/spec.md` — source of truth, updated via this change's delta plus a
  prose clarification applied at archive.
- Implementations: `@posthog/core`, `posthog-node`, `posthog-react-native`, and
  `posthog-js-lite` already conform after posthog-js#4347 (merged 2026-08-01, patch-released
  across all four packages via changeset). Other SDKs in scope for this spec
  (`posthog-python`, native `posthog-ios`/`posthog-android`, `posthog-flutter`) were not
  independently re-audited for the same positional-removal pattern in this pass — worth a
  follow-up per-SDK check (see `tasks.md` §3).
- No acceptance-harness changes in this proposal; the new scenario is written for a future
  harness port that can simulate an in-flight flush being outlived by new captures (e.g. a mock
  server that delays a response until explicitly released).
