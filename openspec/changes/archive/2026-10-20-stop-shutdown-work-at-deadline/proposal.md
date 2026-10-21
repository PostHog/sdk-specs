## Why

The `shutdown` spec names a `timeoutMs` parameter and says what happens *after* it elapses
(resolve, do not reject; log a critical diagnostic). It never says the deadline bounds the work
itself. Read literally, an SDK may keep building, serializing, compressing, and sending the
remaining requests of a final drain after the budget is gone — each one doomed on a zero
timeout — and report a failure per request.

[posthog-rs#298](https://github.com/PostHog/posthog-rs/pull/298) (merged 2026-10-20) fixed exactly
that: shutdown now checks its deadline before each byte-split request and drops the rest with one
warning, matching what the buffer drain in that SDK already did. posthog-js core and
posthog-ruby bound their drains more coarsely: they stop draining at the deadline (Ruby then
spends its documented cleanup grace of up to one second stopping workers) and start no further
drain round, but do not re-check the budget before each batch or retry already under way. The
round-level rule is therefore a SHALL and the per-attempt check a SHOULD.

| SDK | Deadline checked between delivery attempts during the final drain | Where |
|---|---|---|
| posthog-js core (node, browser, react-native) | per round only — `raceWithTimeout` returns at the deadline with one `critical` diagnostic and the drain loop breaks on `hasTimedOut` after the current flush round; batches and retries inside that round are not re-checked | `packages/core/src/posthog-core-stateless.ts` (`_shutdown`) |
| posthog-ruby | per batch — `flush(timeout:)` returns `false` at the deadline and the stopped worker starts no further batch; an in-flight batch's retries are not re-checked | `lib/posthog/client.rb` (`shutdown`) |
| posthog-rs | yes, as of posthog-rs#298 — remaining byte-split chunks are dropped with a single warning and removed from the in-flight count | `src/client/transport.rs` |
| posthog-python | the per-lane flush wait is deadline-bounded; `shutdown()` itself takes no timeout | `posthog/client.py` |

## What Changes

- A new `shutdown` requirement, **Shutdown stops work when its timeout elapses**:
  - the timeout bounds the whole teardown drain, not each attempt within it;
  - once the budget is gone the SDK returns and begins no further drain round; it SHOULD also
    check the budget before each further delivery attempt (next batch, retry, or size-split
    request) and stop instead of preparing one it cannot send;
  - a stopped drain still returns normally and is reported once, not once per abandoned request.
- Three scenarios: a drain stopped at the deadline, a stopped drain leaving the unsent events
  where the SDK persists its queue, and a drain that finishes inside a
  generous timeout (the guard against reading this as licence to stop early).

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `shutdown`: adds the **Shutdown stops work when its timeout elapses** requirement.

## Impact

Mostly descriptive: the three SDKs above already meet the SHALL; only posthog-rs also meets the
per-attempt SHOULD. SDKs whose final drain ignores
the remaining budget between requests would need to add the check.

- **Acceptance adapters**: no scenarios were added to `acceptance/`; the scenarios here are
  spec-level only, because the steps they need (holding an ingestion request past a shutdown
  timeout, asserting a single diagnostic) have no harness binding yet.
