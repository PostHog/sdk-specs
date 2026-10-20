## Why

The `shutdown` spec names a `timeoutMs` parameter and says what happens *after* it elapses
(resolve, do not reject; log a critical diagnostic). It never says the deadline bounds the work
itself. Read literally, an SDK may keep building, serializing, compressing, and sending the
remaining requests of a final drain after the budget is gone — each one doomed on a zero
timeout — and report a failure per request.

[posthog-rs#298](https://github.com/PostHog/posthog-rs/pull/298) (merged 2026-10-20) fixed exactly
that: shutdown now checks its deadline before each byte-split request and drops the rest with one
warning, matching what the buffer drain in that SDK already did. posthog-js core and
posthog-ruby already bound their drains the same way, so this is the undocumented half of a rule
three SDKs follow.

| SDK | Deadline checked between delivery attempts during the final drain | Where |
|---|---|---|
| posthog-js core (node, browser, react-native) | yes — the drain loop breaks on `hasTimedOut` after each flush round, after one `critical` diagnostic from `raceWithTimeout` | `packages/core/src/posthog-core-stateless.ts` (`_shutdown`) |
| posthog-ruby | yes — the shutdown wait is bounded by `deadline`, breaking when the remaining time is gone | `lib/posthog/client.rb` (`shutdown`) |
| posthog-rs | yes, as of posthog-rs#298 — remaining byte-split chunks are dropped with a single warning and removed from the in-flight count | `src/client/transport.rs` |
| posthog-python | the per-lane flush wait is deadline-bounded; `shutdown()` itself takes no timeout | `posthog/client.py` |

## What Changes

- A new `shutdown` requirement, **Shutdown stops work when its timeout elapses**:
  - the timeout bounds the whole teardown drain, not each attempt within it;
  - the SDK checks the remaining budget before starting any further delivery attempt (next batch,
    retry, or size-split request) and stops the drain instead of preparing one it cannot send;
  - a stopped drain still returns normally and is reported once, not once per abandoned request.
- Three scenarios: a drain stopped at the deadline, a stopped drain leaving nothing reported as in
  flight and the unsent events still in persistent storage, and a drain that finishes inside a
  generous timeout (the guard against reading this as licence to stop early).

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `shutdown`: adds the **Shutdown stops work when its timeout elapses** requirement.

## Impact

Mostly descriptive: the three SDKs above already behave this way. SDKs whose final drain ignores
the remaining budget between requests would need to add the check.

- **Acceptance adapters**: no scenarios were added to `acceptance/`; the scenarios here are
  spec-level only, because the steps they need (holding an ingestion request past a shutdown
  timeout, asserting a single diagnostic) have no harness binding yet.
