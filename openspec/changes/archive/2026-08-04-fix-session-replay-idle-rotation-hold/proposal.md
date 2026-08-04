## Why

[posthog-js#4407](https://github.com/PostHog/posthog-js/pull/4407) ("hold rotation-born session
recordings until user interaction") fixed a billing/noise bug: a browser tab left open and idle
would rotate to a new session id on its own inactivity timeout, and posthog-js would immediately
start (and ship) a new replay recording for that rotated session even though nothing was
happening — a Meta+FullSnapshot event with zero real content, once per rotation, for as long as
the tab stayed parked. The fix withholds a rotation-born session's buffered replay data until the
first genuine user interaction (or an event/URL trigger independently activates recording);
recording that's never released this way (a further rotation, `stop()`, opt-out, or unload) is
discarded rather than shipped. A *fresh* (non-rotation) session start is never held.

`openspec/specs/session-replay-ingestion-controls/spec.md` already describes what happens on
session rotation only in terms of the *ingestion controls* being re-armed and re-decided
("Session rotation: triggers are re-armed for the new session, sampling is re-decided, and
recording is stopped or started to match" — line 75) and the general "re-evaluate on change"
requirement (line 48). Neither says anything about *when* a rotation caused by inactivity should
start shipping data versus withholding it — this is a real gap, not a contradiction (the spec
never claimed recording starts immediately either), but it's exactly the kind of gap a plausible
implementation falls into by starting to record as soon as the otherwise-configured controls are
satisfied.

## What Changes

- **Lifecycle behavior** ("Session rotation" bullet): notes that a session born from an
  inactivity-timeout rotation withholds its buffered replay data until released by user
  interaction or an independent trigger match, distinct from a fresh session start.
- **New requirement**: `Idle-rotation replay hold until interaction`, scoped to SDKs whose
  sessions rotate on an inactivity timeout while idle (currently posthog-js / web), with two
  scenarios: the hold on an idle rotation, and the non-hold on a fresh session start.

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
- Implementations: posthog-js (web) already conforms after posthog-js#4407. Mobile SDKs
  (`posthog-ios`, `posthog-android`) were not audited for an equivalent idle-rotation-and-record
  pattern in this pass — flagged as a follow-up in `tasks.md` §4; they may not rotate sessions on
  a foreground inactivity timeout the same way, in which case the requirement's scoping clause
  already exempts them.
- No acceptance-harness changes in this proposal; the new scenarios are written for a future
  harness port that can simulate session idle time and a subsequent inactivity-triggered
  rotation.
