## Context

Four decisions in this spec are non-obvious enough to record here rather than leave implicit in
the requirements.

## Decisions

### 1. `buffering` spans both mobile holds

Mobile has two distinct reasons a session can be held back from recording — awaiting its first
remote config, and not yet past the configured minimum session duration — but both report the
same `$recording_status: buffering` rather than two distinct status values. The two causes are
disambiguated only by `$sdk_debug_replay_flush_hold_reason` (`awaiting_remote_config` /
`below_minimum_duration`), not by the status enum itself. Rationale: keeping the mobile status
enum at three values (`disabled` / `buffering` / `active`) keeps it a strict subset of the
browser enum; a fourth mobile-only status value would break that subset relationship for no
diagnostic gain the hold-reason key doesn't already provide.

### 2. Trigger status is computed per-capture on mobile, not cached

posthog-js caches trigger status as a session super-property via `register_for_session` and
only updates it when a trigger resolves. Mobile SDKs compute it fresh from current integration
state on every capture instead. Rationale: mobile has no session-scoped super-property store
equivalent to posthog-js's `register_for_session`; computing fresh is the lazy option that needs
no new persistence layer, at the cost of the value being able to change within a session as
triggers resolve (where posthog-js's cached value only changes at the point of resolution).

### 3. posthog-js's trigger value set is adopted rather than inventing a mobile-specific one

An earlier draft of this spec invented separate value sets per trigger kind
(`matched`/`not_matched`/`no_linked_flag` for the linked flag; `no_triggers`/`pending`/
`activated` for the event trigger). This was replaced with posthog-js's actual three-value
`TriggerStatus` type (`trigger_activated` / `trigger_pending` / `trigger_disabled`,
`triggerMatching.ts:54-59`), used identically for every trigger kind (URL, linked flag, event).
Rationale: posthog-js is the reference implementation for this spec; inventing a divergent value
set for mobile with no technical reason to differ just adds a cross-SDK naming mismatch a future
reader has to reconcile by hand.

### 4. Tier-2 counters are deferred to a follow-up change

The buffer/flush/full-snapshot/mutation-drop counter keys are excluded from this change and
tracked as the follow-up `session-replay-debug-counters` change. Rationale: none of the counters
exist on any mobile platform yet, so specifying them now would describe a contract no
implementation could satisfy; deferring keeps this change scoped to keys at least one platform
already ships or is actively implementing.

### 5. Session keys describe the session on the event, derived from the id when a caller supplied it

Mobile bridges (React Native, Flutter) pre-attach `$session_id`, and the SDKs honour it. Reading
the session manager's start time regardless produced an event whose `$session_id` named one
session and whose `$sdk_debug_session_start` named another (reproduced on Android with a
caller id stamped one hour earlier: start 60 min off, duration 14 ms; posthog-ios#825 has the
same shape at `PostHogSDK.swift:591-597`). posthog-js never accepts a caller id, so it has no
rule here; its derivation for an externally supplied id — `uuid7ToTimestampMs` on a bootstrapped
session id — is adopted instead of dropping the keys, so bridge-supplied events keep their session
age. A non-v7 id has no embedded time and omits both keys.

### 6. Debug keys describe the event's time, so a previous-process crash carries none of them

A crash from a previous process reported on the next launch (Android NDK tombstones via
`ApplicationExitInfo`) captured with `timestamp = crash time` was stamped with the *current*
launch's `$recording_status: active`, a session started 24 h after the crash, and a duration of
96 ms — confidently wrong for the OOM triage that motivated this change. The rule is stated on
the event's timestamp rather than on the reporting integration so it needs no marker API and also
covers backdated captures from before the session. iOS's persisted `customData` snapshot is the
"attach what was persisted at the time" arm of the same requirement; a persisted snapshot on
Android is a possible follow-up, not required for conformance.
