## Why

[posthog-js#4407](https://github.com/PostHog/posthog-js/pull/4407) ("hold rotation-born session
recordings until user interaction") fixed a billing/noise bug: a browser tab left open and idle
would rotate to a new session id on its own inactivity timeout, and posthog-js would immediately
start (and ship) a new replay recording for that rotated session even though nothing was
happening — a Meta+FullSnapshot event with zero real content, once per rotation, for as long as
the tab stayed parked. The fix withholds a rotation-born session's buffered replay data until the
first genuine user interaction (or an event/URL trigger independently activates recording);
recording that's never released this way (a further rotation, `stop()`, opt-out, or unload) is
discarded rather than shipped.

**Update (same monitoring pass, before this change merged):** the initial version of this
proposal, following #4407's own framing, stated that "a fresh (non-rotation) session start is
never held." That turned out to be true only transiently. Two more posthog-js PRs merged within
the same window:

- [posthog-js#4412](https://github.com/PostHog/posthog-js/pull/4412) ("hold fresh
  interaction-less recordings until user interaction") — extends the hold to fresh (non-rotation)
  epochs too: any session start without confirmed user activity is now held the same way, because
  production data showed zero-activity recordings still shipping at volume from exactly the
  fresh-start path #4407 didn't cover (in-app browser preloads, background loads, bots). Fresh-start
  holds add one behavioral difference from rotation-born holds: a clean unload ships a held
  fresh-start epoch (preserving passive-visit capture, e.g. reading/watching), but still discards
  a held rotation-born epoch on unload — that discard-on-unload was the original incident fix and
  is deliberately preserved.
- [posthog-js#4410](https://github.com/PostHog/posthog-js/pull/4410) ("release interaction hold on
  V2 event-trigger matches") — internal parity fix so the newer V2 trigger-group strategy releases
  a hold on an event-trigger match the same way the original (V1) code path already did; not new
  contractual ground since the requirement's release conditions already covered "an event/URL
  trigger independently activates recording" generically.

Catching this before merge matters: the requirement below was about to ship into the canonical
spec asserting the opposite of what #4412 shipped days later. The requirement and scenarios are
corrected in this same change rather than left to drift and be fixed retroactively.

`openspec/specs/session-replay-ingestion-controls/spec.md` already describes what happens on
session rotation only in terms of the *ingestion controls* being re-armed and re-decided
("Session rotation: triggers are re-armed for the new session, sampling is re-decided, and
recording is stopped or started to match" — line 75) and the general "re-evaluate on change"
requirement (line 48). Neither said anything about *when* a new epoch — rotated or fresh — should
start shipping data versus withholding it; this was a real gap, not a contradiction, but exactly
the kind of gap a plausible implementation falls into by starting to record as soon as the
otherwise-configured controls are satisfied.

## What Changes

- **Lifecycle behavior** ("Session rotation" bullet): notes that any new epoch — whether from an
  inactivity-timeout rotation or a fresh session start — withholds its buffered replay data until
  released by user interaction, an independent trigger match, or an explicit recording override.
- **New requirement**: `Interaction hold for unconfirmed-activity recording epochs`, scoped to
  SDKs whose sessions can start or rotate without a confirmed-interaction signal (currently
  posthog-js / web), with three scenarios: the hold on an idle rotation, the hold on a fresh
  session start with no confirmed activity, and the unload-behavior split between the two
  (fresh-start ships, rotation-born discards).

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `session-replay-ingestion-controls`: the "Session rotation" lifecycle bullet gains a
  clarifying sentence; the requirements section gains one new requirement with two scenarios.
  All existing requirements and scenarios are unchanged.

## Impact

- `openspec/specs/session-replay-ingestion-controls/spec.md` — source of truth, updated via
  this change's delta.
- Implementations: posthog-js (web) already conforms after posthog-js#4407, #4412, and #4410.
  Mobile SDKs (`posthog-ios`, `posthog-android`) were not audited for an equivalent
  idle-rotation/fresh-start-and-record pattern in this pass — flagged as a follow-up in
  `tasks.md` §4; they may not start or rotate sessions without a confirmed-interaction signal the
  same way, in which case the requirement's scoping clause already exempts them.
- No acceptance-harness changes in this proposal; the new scenarios are written for a future
  harness port that can simulate session idle time and a subsequent inactivity-triggered
  rotation.
