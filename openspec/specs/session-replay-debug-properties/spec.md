# Session Replay Debug Properties Specification

## Purpose

`session-replay-debug-properties` is the per-event debug snapshot of the session replay
subsystem: the `$recording_status` property and the `$sdk_debug_*` keys an SDK attaches
automatically to every captured event except `$snapshot`. It exists so that an event captured
while replay was disabled, buffering, or active says so on the event itself — an `$exception`
or custom event can then be read against the replay state at capture time without correlating
against a separate signal.

It is distinct from `is-session-replay-active`, which is a getter the caller invokes; these
properties are attached without any caller action. The mobile SDKs (`posthog-ios`,
`posthog-android`) and the hybrid SDKs that inherit their event pipeline are the primary
conformance targets; `posthog-js` is the reference implementation, with the deliberate
divergences called out inline.

## Applicability

`client` — browser and UI/mobile SDKs that own session replay capture. Server SDKs do not
observe a session timeline and attach none of these keys.

## Requirements

### Requirement: Attach debug properties to every captured event except `$snapshot`

The SDK SHALL attach `$recording_status` and the applicable `$sdk_debug_*` properties (this
spec's key list) to every captured event **except** `$snapshot`. `$snapshot` events (the replay
payload itself) SHALL carry none of these keys — they are already replay data, not a report
about replay. When the outgoing event is the minimal `$feature_flag_called` shape (the
allowlisted properties sent when the call is gated and the flag has no experiment), the SDK
SHALL strip `$recording_status` and every `$sdk_debug_*` key along with everything else not on
that allowlist; the full (non-minimal) `$feature_flag_called` shape carries them like any other
event.

Reference: posthog-js merges the debug map inside `calculateEventProperties`
(`packages/browser/src/posthog-core.ts:2024`), after the `$snapshot` early return at
`posthog-core.ts:1989-2000` — so `$snapshot` never reaches the merge. The minimal
`$feature_flag_called` allowlist is built by `minimizeFlagCalledEventProperties`
(`packages/core/src/featureFlagUtils.ts:263`), constructing a new object from an explicit key
list rather than deleting keys, so `$recording_status`/`$sdk_debug_*` are structurally excluded
unless allowlisted.

Covering test: `packages/browser/src/__tests__/__snapshots__/featureflags.test.ts.snap` —
the minimal snapshot ("sends exactly the allowlisted properties when gated and the flag has no
experiment") has no `$recording_status` or `$sdk_debug_*` key; the full snapshot ("sends the
full event when gated but the flag has an experiment") has `$recording_status: "disabled"`.
`packages/browser/src/__tests__/posthog-core-also.test.ts:618` and `:767`
(`calculateEventProperties` "returns calculated properties") assert `$recording_status` and
`$sdk_debug_retry_queue_size` on an ordinary custom event.

#### Scenario: Custom event carries debug properties
- **GIVEN** the SDK is initialized
- **WHEN** a custom event is captured
- **THEN** the captured event's properties include `$recording_status`

#### Scenario: Snapshot event carries none of the debug properties
- **GIVEN** the SDK is initialized with session replay active
- **WHEN** a `$snapshot` event is captured
- **THEN** the captured event's properties include neither `$recording_status` nor any
  `$sdk_debug_*` key

#### Scenario: Minimal feature-flag-called event strips debug properties
- **GIVEN** the SDK is initialized
- **AND** minimal `$feature_flag_called` events are configured
- **WHEN** a gated feature flag call with no experiment is captured
- **THEN** the captured event's properties include neither `$recording_status` nor any
  `$sdk_debug_*` key

#### Scenario: Full feature-flag-called event carries debug properties
- **GIVEN** the SDK is initialized
- **AND** minimal `$feature_flag_called` events are not configured
- **WHEN** a feature flag call is captured
- **THEN** the captured event's properties include `$recording_status`

### Requirement: `$recording_status` value set, with a mobile subset

`$recording_status` SHALL take one of the browser value set's members —
`disabled`, `sampled`, `active`, `buffering`, `paused`, `lazy_loading`, `awaiting_config`,
`missing_config`, `rrweb_error` — and every platform's emitted values SHALL be a subset of that
set. Audited mobile SDKs (`posthog-ios`, `posthog-android`) emit only three:

- `disabled` — no replay integration/handler is installed, or replay is not enabled on it.
- `buffering` — the integration is installed and enabled but is holding: awaiting its first
  remote config, or below the configured minimum session duration. Both holds report
  `buffering`; they are disambiguated only by `$sdk_debug_replay_flush_hold_reason` (see the
  keys requirement), not by a distinct status value.
- `active` — otherwise.

`sampled` folds into `disabled` on mobile (mobile has no independent sample-rate gate
distinct from remote-config enablement); `paused`, `lazy_loading`, `awaiting_config`,
`missing_config`, and `rrweb_error` have no mobile analog and MUST NOT be emitted by mobile
SDKs.

Reference: the full value set is `sessionRecordingStatuses`
(`packages/browser/src/extensions/replay/external/triggerMatching.ts:85-96`).

Covering test: no covering test in posthog-js for the mobile subset (mobile has no browser
analog to test) — planned test (repo plan row: each native SDK's own buffering/active test,
`PostHogSessionReplayRemoteConfigBufferTest.swift` on iOS,
`PostHogReplayIntegrationTest.kt` "buffering to active" on Android), not yet in the repo.

#### Scenario: Replay not configured reports disabled
- **GIVEN** the SDK is initialized without session replay configured
- **WHEN** an event is captured
- **THEN** the event's `$recording_status` is `disabled`

#### Scenario: Holding for remote config or minimum duration reports buffering
- **GIVEN** the replay integration is installed and enabled
- **AND** it is awaiting its first remote config, or the session has not yet passed the
  minimum duration
- **WHEN** an event is captured
- **THEN** the event's `$recording_status` is `buffering`

#### Scenario: Neither holding nor disabled reports active
- **GIVEN** the replay integration is installed, enabled, has received remote config, and the
  session has passed the minimum duration
- **WHEN** an event is captured
- **THEN** the event's `$recording_status` is `active`

### Requirement: Session, queue, hold-reason, trigger, and mode keys

In addition to `$recording_status`, the SDK SHALL attach the following keys where applicable to
the current platform. `$sdk_debug_session_start` (an epoch-millisecond integer, the session's
start time) and `$sdk_debug_current_session_duration` (the millisecond difference between now
and that start time) SHALL be attached whenever a session start time is available, and SHALL
describe the session identified by the event's own `$session_id` — the two keys and `$session_id`
on one event MUST never describe different sessions. When that id is the SDK session manager's
current session, the start time is the manager's. When a caller pre-attached a different
`$session_id` (the React Native and Flutter bridges do this on mobile; posthog-js never accepts
one — `calculateEventProperties` spreads the caller's properties at `posthog-core.ts:1515` and
then overwrites `$session_id` from its own session manager at `:1549`), the SDK SHALL derive the
start time from the UUIDv7 timestamp embedded in that id — the derivation posthog-js itself
applies to an externally supplied session id (`uuid7ToTimestampMs`,
`packages/browser/src/sessionid.ts:111` for a bootstrapped id; implementation
`packages/browser/src/uuidv7.ts:254`) — and SHALL omit both keys when the id is not a
version-7 UUID.
posthog-js SHALL report `$sdk_debug_retry_queue_size` from its dedicated retry-only queue
(requests that failed and are backing off), separate from its normal outgoing batch. Mobile SDKs
have no separate retry queue — a single disk-backed queue handles both normal pre-flush batching
and post-failure retry backoff — so reporting the same depth under the `retry_queue_size` name
would misrepresent ordinary buffering as a stuck retry loop. Mobile SDKs SHALL instead report
that queue's current depth as `$sdk_debug_pending_queue_size`, and SHALL NOT emit
`$sdk_debug_retry_queue_size`. This is a deliberate key-name divergence from posthog-js, not an
oversight: the two keys measure genuinely different things (a retry-only backlog vs. a combined
pending-send depth), so giving them the same name across SDKs would make the property misleading
on whichever platform lacks a true retry-only queue.
When the replay integration is installed, `$sdk_debug_replay_internal_buffer_length` SHALL
report the replay queue's current depth. Mobile SDKs SHALL attach
`$sdk_debug_replay_flush_hold_reason` exactly when `$recording_status` is `buffering`, taking
one value per hold cause (`awaiting_remote_config`, `below_minimum_duration`), and SHALL omit
the key (not present-and-empty) outside a `buffering` state. This presence rule is mobile-only
and a deliberate divergence from posthog-js: the browser recorder emits its interaction-hold
reason while `$recording_status` still reads `active`
(`lazy-loaded-session-recorder.ts:2746-2749`, test "names a fresh-start hold on captured events
while the status still reads active"), because a held browser epoch is otherwise
indistinguishable from an uploading one. That active-with-hold reporting and its values are
governed by `session-replay-ingestion-controls` and the out-of-scope requirement below, not by
this rule.

`$sdk_debug_replay_linked_flag_trigger_status` and `$sdk_debug_replay_event_trigger_status`
SHALL each report one of `trigger_activated` / `trigger_pending` / `trigger_disabled` — the same
three-value set posthog-js uses for every trigger kind (URL, linked flag, event). Mobile SDKs
emit the identical value set; the only divergence from posthog-js is *how* the value is produced,
not *what* values exist: unlike posthog-js, which caches trigger status as a session
super-property via `register_for_session` and only updates it when a trigger resolves, mobile
SDKs SHALL compute trigger status fresh on every capture from current integration state. This is
a deliberate divergence: mobile has no session-scoped super-property store, and computing
per-capture means the value can legitimately change within one session as triggers resolve,
where posthog-js's cached value only changes at the point of resolution.
`$sdk_debug_replay_pending_trigger_conditions` SHALL list whichever configured trigger kinds are
not yet satisfied; on mobile the possible kinds are linked flag and event trigger.

Two keys are mobile-only, with no posthog-js analog:
`$sdk_debug_replay_capture_mode` (`screenshot` when the platform's screenshot-recording mode is
on, or the host SDK name is `posthog-flutter`; otherwise `wireframe`) and
`$sdk_debug_replay_throttle_delay_ms` (the configured mutation-throttle delay, in milliseconds).

SDK-computed `$recording_status` and `$sdk_debug_*` values SHALL take precedence over a
caller-supplied event property or a registered super property of the same name; the merge writes
the debug map last, as posthog-js's `extend(properties, sdkDebugProperties)` does.

Reference: getter merge point `packages/browser/src/extensions/replay/external/lazy-loaded-session-recorder.ts:2636`
and pre-load fallback `packages/browser/src/extensions/replay/session-recording.ts:463`;
retry-queue key `packages/browser/src/posthog-core.ts:2026`; session-start epoch-ms source
`packages/browser/src/sessionid.ts:25` (`uuid7ToTimestampMs`), read into the recorder at
`lazy-loaded-session-recorder.ts:656` and `:1232`, and the millisecond-difference duration getter
at `lazy-loaded-session-recorder.ts:2521-2526`; trigger value set `TriggerStatus` /
`triggerStatuses` at `triggerMatching.ts:54-59`; trigger caching via `register_for_session` at
`triggerMatching.ts:304` (URL), `:416` (linked flag), `:530` (event); pending-conditions getter
`_describePendingTriggerConditions` at `lazy-loaded-session-recorder.ts:2213`.

Covering test: no covering test in posthog-js for `$sdk_debug_replay_capture_mode`,
`$sdk_debug_replay_throttle_delay_ms`, or the mobile hold-reason values (new, mobile-only
surface) — planned test (repo plan row: native "flutter host" and "buffering → active" cases),
not yet in the repo. The session/queue/hold-reason/trigger-status keys that do exist on
posthog-js have no dedicated posthog-js test asserting each key individually;
`lazy-sessionrecording.test.ts` exercises the getter that produces them.

#### Scenario: Session and queue keys are present when a session exists (posthog-js)
- **GIVEN** the SDK is initialized with an active session
- **WHEN** an event is captured
- **THEN** the event's properties include `$sdk_debug_session_start`,
  `$sdk_debug_current_session_duration`, and `$sdk_debug_retry_queue_size`

#### Scenario: Session and queue keys are present when a session exists (mobile)
- **GIVEN** the SDK is initialized with an active session
- **WHEN** an event is captured
- **THEN** the event's properties include `$sdk_debug_session_start`,
  `$sdk_debug_current_session_duration`, and `$sdk_debug_pending_queue_size`
- **AND** the event's properties do NOT include `$sdk_debug_retry_queue_size`

#### Scenario: Session keys are present without session replay (mobile)
- **GIVEN** the SDK is initialized without session replay configured
- **AND** a session is active
- **WHEN** an event is captured
- **THEN** the event's properties include `$sdk_debug_session_start` and
  `$sdk_debug_current_session_duration`
- **AND** the event's `$recording_status` is `disabled`

Mobile SDKs source these two keys from the SDK's own session manager, not from the replay
recorder, so they are present whenever a session exists regardless of replay configuration.
This is a deliberate divergence from posthog-js, where both keys live in the recorder's
`sdkDebugProperties` getter and are absent until the recorder has loaded: on mobile the
session is owned by the SDK, and an `$exception` captured without replay still benefits from the
session's age. Consequently their presence is not a proxy for "replay is loaded" on mobile;
`$recording_status` is.

#### Scenario: Session keys follow a caller-supplied session id (mobile)
- **GIVEN** the session manager's session started at T
- **AND** a caller captures an event with a pre-attached `$session_id` that is a UUIDv7 stamped
  at T − 1h
- **WHEN** the event is captured
- **THEN** the event's `$session_id` is the caller's id
- **AND** `$sdk_debug_session_start` is T − 1h, the timestamp embedded in that id, not T
- **AND** `$sdk_debug_current_session_duration` is measured from T − 1h

Covering test: planned — `PostHogTest.kt` "session debug keys follow a caller-provided session
id" on Android; iOS equivalent pending on posthog-ios#825 (`PostHogSDK.swift:591-597` reads the
manager's start unconditionally today).

#### Scenario: Session keys are omitted for a non-UUIDv7 caller session id (mobile)
- **GIVEN** a caller captures an event with a pre-attached `$session_id` that is not a
  version-7 UUID
- **WHEN** the event is captured
- **THEN** the event's properties include neither `$sdk_debug_session_start` nor
  `$sdk_debug_current_session_duration`
- **AND** `$recording_status` is still present

#### Scenario: Mobile hold reason is present only while buffering
- **GIVEN** a mobile SDK whose replay integration is awaiting its first remote config
- **WHEN** an event is captured
- **THEN** the event's `$recording_status` is `buffering`
- **AND** `$sdk_debug_replay_flush_hold_reason` is `awaiting_remote_config`
- **WHEN** remote config arrives and the session passes the minimum duration
- **AND** another event is captured
- **THEN** the event's `$recording_status` is `active`
- **AND** `$sdk_debug_replay_flush_hold_reason` is absent

#### Scenario: Linked-flag trigger status reflects current state on every capture
- **GIVEN** a linked flag trigger that has not matched
- **WHEN** an event is captured
- **THEN** `$sdk_debug_replay_linked_flag_trigger_status` is `trigger_pending`
- **AND** `$sdk_debug_replay_pending_trigger_conditions` includes the linked flag
- **WHEN** the linked flag later matches
- **AND** another event is captured within the same session
- **THEN** `$sdk_debug_replay_linked_flag_trigger_status` is `trigger_activated`

#### Scenario: Event trigger status reflects current state on every capture
- **GIVEN** an event trigger that has not yet been matched
- **WHEN** an event is captured
- **THEN** `$sdk_debug_replay_event_trigger_status` is `trigger_pending`
- **AND** `$sdk_debug_replay_pending_trigger_conditions` includes the event trigger
- **WHEN** the trigger event is captured
- **AND** another event is captured within the same session
- **THEN** `$sdk_debug_replay_event_trigger_status` is `trigger_activated`

#### Scenario: Debug values win over same-named caller or registered properties
- **GIVEN** a super property or a caller-supplied event property named `$recording_status`
- **WHEN** an event is captured
- **THEN** the event's `$recording_status` is the SDK-computed value, not the supplied one

#### Scenario: Capture mode reflects the screenshot flag or the Flutter host name
- **GIVEN** screenshot-recording mode is off
- **AND** the host SDK name is `posthog-flutter`
- **WHEN** an event is captured
- **THEN** `$sdk_debug_replay_capture_mode` is `screenshot`

#### Scenario: Capture mode is screenshot when screenshot recording is on
- **GIVEN** screenshot-recording mode is on
- **AND** the host SDK name is not `posthog-flutter`
- **WHEN** an event is captured
- **THEN** `$sdk_debug_replay_capture_mode` is `screenshot`

#### Scenario: Capture mode is wireframe when both screenshot recording and the Flutter host are off
- **GIVEN** screenshot-recording mode is off
- **AND** the host SDK name is not `posthog-flutter`
- **WHEN** an event is captured
- **THEN** `$sdk_debug_replay_capture_mode` is `wireframe`

### Requirement: All debug keys on one event come from a single consistent snapshot

All `$recording_status` and `$sdk_debug_*` keys attached to a single captured event SHALL come
from one consistent point-in-time snapshot of replay state — no torn reads across locks, where
one key reflects the state before a concurrent replay-lifecycle transition and another key on
the same event reflects the state after it.

#### Scenario: Capture racing stop() yields a consistent status, never a torn read
- **GIVEN** the replay integration is buffering with a hold reason present
- **WHEN** an event capture races a concurrent `stopSessionRecording()`-equivalent call
- **THEN** the event's `$recording_status` is one of the allowed values (`disabled`, `active`,
  or `buffering`)
- **AND** the event never carries `$sdk_debug_replay_flush_hold_reason` unless its
  `$recording_status` on that same event is `buffering`

### Requirement: `$sdk_debug_error_capturing_properties` is attached only on a build failure

`$sdk_debug_error_capturing_properties` SHALL be attached to a captured event, carrying the
stringified error, if and only if building the `$recording_status` / `$sdk_debug_*` debug map
throws. On a successful build, the key SHALL be absent.

Reference: posthog-js wraps the debug-map build in a try/catch and sets this key only in the
catch branch, `packages/browser/src/posthog-core.ts:2027-2028`.

Covering test: no dedicated posthog-js test forces the debug-map build to throw — planned test
(repo plan row: native "error path" case), not yet in the repo, for both SDKs.

#### Scenario: A build failure attaches the stringified error and nothing else from the debug map
- **GIVEN** building the debug properties map throws an error
- **WHEN** an event is captured
- **THEN** the event's properties include `$sdk_debug_error_capturing_properties` with the
  stringified error

#### Scenario: A successful build never attaches the error key
- **GIVEN** building the debug properties map does not throw
- **WHEN** an event is captured
- **THEN** the event's properties do not include `$sdk_debug_error_capturing_properties`

### Requirement: Debug properties attach to exception, identify, and set events

`$exception` events SHALL carry `$recording_status`. `$identify` and `$set` events SHALL carry
`$recording_status`. These are ordinary captured events under the attach rule (the requirement
above); this requirement exists because `$exception` was the original OOM-investigation trigger
for this spec and `$identify`/`$set` are commonly assumed (incorrectly) to be special-cased like
`$snapshot`.

Reference: `calculateEventProperties` (`packages/browser/src/posthog-core.ts:2024`) merges the
debug map for any event that reaches it; `$exception`, `$identify`, and `$set` all reach it —
only `$snapshot` returns early (`:1989-2000`).

Covering test: `packages/browser/src/__tests__/posthog-core-also.test.ts:618` and `:767`
(`calculateEventProperties` "returns calculated properties") assert `$recording_status` on an
ordinary custom event; no dedicated posthog-js test asserts it specifically for `$exception`,
`$identify`, or `$set` — planned test (repo plan row: per-event-type assertions), not yet in the
repo, for both SDKs.

#### Scenario: Exception event carries recording status
- **GIVEN** the SDK is initialized
- **WHEN** an `$exception` event is captured
- **THEN** the captured event's properties include `$recording_status`

#### Scenario: Identify and set events carry recording status
- **GIVEN** the SDK is initialized
- **WHEN** an `$identify` event is captured
- **THEN** the captured event's properties include `$recording_status`
- **WHEN** a `$set` event is captured
- **THEN** the captured event's properties include `$recording_status`

### Requirement: Attach the disabled shape when replay is not configured

The SDK SHALL attach `$recording_status: disabled` to every non-`$snapshot` event even when
session replay is not configured at all (no replay integration installed, or the platform
module that provides it is absent) — an event captured under these conditions is exactly the
case the OOM investigation that motivated this spec needed to distinguish from an active or
buffering replay. Config-derived keys that don't depend on an installed integration
(`$sdk_debug_replay_capture_mode`, `$sdk_debug_replay_throttle_delay_ms`) MAY still be present
if the platform module that owns them is loaded even without an active integration; where that
module itself is entirely absent, those two keys are absent too.

Reference: this generalizes posthog-js's fallback path,
`extensions/replay/session-recording.ts:463`, which returns `{ $recording_status }` before the
full recorder loads.

Covering test: no covering test in posthog-js (mobile-specific "module absent" case) — planned
test (repo plan row: the native "non-iOS" and "no handler" tests, `PostHogSDKTest.swift` under
`make testOnMacSimulator`; `PostHogTest.kt` "with no handler"), not yet in the repo.

#### Scenario: No replay integration installed still reports disabled
- **GIVEN** the SDK is initialized with no session replay integration installed
- **WHEN** a custom event is captured
- **THEN** the event's `$recording_status` is `disabled`

### Requirement: Stop and uninstall reset the reported state and clear any stale hold reason

The SDK SHALL report `$recording_status: disabled` and SHALL NOT attach
`$sdk_debug_replay_flush_hold_reason` on events captured after session replay is stopped (an
explicit `stopSessionRecording()`-equivalent call) or the replay integration is uninstalled, even
if a hold reason was present immediately before the stop/uninstall. A getter or property-attach path that
runs after teardown but still surfaces a pre-teardown hold reason is a bug this requirement
exists to rule out.

Reference: posthog-js's own fix for this exact staleness,
`extensions/replay/external/lazy-loaded-session-recorder.ts:1588` — the getter runs after
`stop()` and clears `flush_hold_reason` accordingly.

Covering test: `lazy-sessionrecording.test.ts` replay-stop tests (posthog-js's fix for the
staleness this requirement generalizes) — no test in posthog-js for the mobile uninstall path
specifically; planned test (repo plan row: the native "stopped integration" tests,
`PostHogSessionReplayRemoteConfigBufferTest.swift` on iOS,
`PostHogReplayIntegrationTest.kt` "stopped integration" on Android, both asserting `disabled`
with no `flush_hold_reason` after `stop()` and after `uninstall()`), not yet in the repo.

#### Scenario: Stopping recording clears the hold reason
- **GIVEN** the replay integration is buffering with a hold reason present
- **WHEN** recording is stopped
- **AND** another event is captured
- **THEN** the event's `$recording_status` is `disabled`
- **AND** `$sdk_debug_replay_flush_hold_reason` is absent

#### Scenario: Uninstalling the integration clears the hold reason
- **GIVEN** the replay integration is buffering with a hold reason present
- **WHEN** the replay integration is uninstalled
- **AND** another event is captured
- **THEN** the event's `$recording_status` is `disabled`
- **AND** `$sdk_debug_replay_flush_hold_reason` is absent

#### Scenario: Config-derived keys remain present after stop/uninstall while status is disabled
- **GIVEN** the replay integration was active with `$sdk_debug_replay_capture_mode` and
  `$sdk_debug_replay_throttle_delay_ms` present
- **WHEN** recording is stopped, or the replay integration is uninstalled
- **AND** another event is captured
- **THEN** the event's `$recording_status` is `disabled`
- **AND** `$sdk_debug_replay_capture_mode` and `$sdk_debug_replay_throttle_delay_ms` remain
  present, because they derive from the platform config module rather than from integration
  install/active state

### Requirement: Debug keys describe the SDK state when the event occurred

`$recording_status` and every `$sdk_debug_*` key SHALL describe the SDK's state at the moment
the event occurred — for an ordinary event, the moment of capture. An event captured with an explicit
timestamp that precedes the current session's start did not occur in this session; the canonical
case is an `$exception` reported on a later launch for a crash in a previous process (Android's
NDK tombstone path in `PostHogNativeCrashIntegration`, iOS's PLCrashReporter reports). For such
an event the SDK SHALL attach the state it persisted at the time the event occurred if the
platform captured one (iOS mirrors the debug map into the crash reporter's `customData` through
`onEventContextChanged`), and otherwise SHALL attach none of these keys. It MUST NOT attach the
current process's live state to an event from a previous process. An explicit timestamp that
falls inside the current session (a backdated capture) keeps the keys: the state at capture is
still the state of the session the event belongs to.

Reference: no posthog-js analog — a browser page does not report previous-process crashes. The
principle is posthog-js's own, though: `calculateEventProperties` resolves the session against
the event's timestamp rather than "now" (`timestamp.getTime()` passed into
`checkAndGetSessionAndWindowId`, `posthog-core.ts:1545-1548`) — the event's time, not capture
time, is authoritative.

Covering test: planned — `PostHogTest.kt` "a previous-run exception carries none of the debug
keys" and "a backdated event within the current session keeps the debug keys" on Android; iOS's
crash-report decode path in `PostHogErrorTrackingAutoCaptureIntegration` (the `customData`
branch) covers the persisted-snapshot arm.

#### Scenario: A previous-process crash carries no live debug state
- **GIVEN** the SDK is initialized with session replay active in the current process
- **AND** the current session started at T
- **WHEN** an `$exception` is captured with an explicit timestamp earlier than T (a crash report
  from a previous process)
- **AND** the platform persisted no debug snapshot for that time
- **THEN** the event's properties include neither `$recording_status` nor any `$sdk_debug_*` key

#### Scenario: A persisted crash snapshot is attached verbatim
- **GIVEN** the platform mirrored the debug map into its crash reporter at the time of the crash
- **WHEN** that crash report is captured on a later launch
- **THEN** the event carries the mirrored map, not the current process's state

#### Scenario: A backdated event within the current session keeps the keys
- **GIVEN** the current session started at T
- **WHEN** an event is captured with an explicit timestamp later than T
- **THEN** the event carries `$recording_status` and the applicable `$sdk_debug_*` keys

### Requirement: Reconciliation with `is-session-replay-active` and `session-replay-ingestion-controls`

The SDK SHALL keep `$recording_status` consistent with the boolean `isSessionReplayActive()`
getter specified by `is-session-replay-active`: a `$recording_status` of `active` SHALL imply that
getter returns `true`, and `disabled` SHALL imply it returns `false`. While
`$recording_status` is `buffering`, this spec makes no claim about the boolean getter's return
value — that getter's own spec governs its `buffering`-equivalent behavior per platform.

The two mobile `buffering` hold causes reported via `$sdk_debug_replay_flush_hold_reason`
(`awaiting_remote_config`, `below_minimum_duration`) correspond to the "Setup" resolution step
and the "Apply the minimum-duration gate" step specified in `session-replay-ingestion-controls`
(`openspec/specs/session-replay-ingestion-controls/spec.md:73` and `:44` respectively); this
spec's hold-reason values are the debug-observable surface of those two gates, not an
independent gating mechanism.

Reference: `is-session-replay-active` spec, `openspec/specs/is-session-replay-active/spec.md`;
`session-replay-ingestion-controls` spec,
`openspec/specs/session-replay-ingestion-controls/spec.md`.

#### Scenario: Active recording status implies the boolean getter is true
- **GIVEN** an SDK conforming to both this spec and `is-session-replay-active`
- **WHEN** an event's `$recording_status` is `active`
- **THEN** `isSessionReplayActive()` (or its platform equivalent) returns `true`

#### Scenario: Disabled recording status implies the boolean getter is false
- **GIVEN** an SDK conforming to both this spec and `is-session-replay-active`
- **WHEN** an event's `$recording_status` is `disabled`
- **THEN** `isSessionReplayActive()` (or its platform equivalent) returns `false`

### Requirement: Out of scope for this capability

This spec SHALL NOT be read as requiring: browser-only keys with no mobile analog (e.g. anything the browser
recorder emits that mobile has no equivalent concept for, including the browser's own
interaction-hold `flush_hold_reason` values, and their presence while `$recording_status` reads
`active`, used for the idle-rotation/fresh-start withholding behavior specified separately in
`session-replay-ingestion-controls`); the browser-only
`$sdk_debug_replay_url_trigger_status` key (`constants.ts:118`,
`SDK_DEBUG_REPLAY_URL_TRIGGER_STATUS`, set via `register_for_session` at
`triggerMatching.ts:304`) — mobile has no URL-trigger concept; the browser-only
`$sdk_debug_extensions_init_method` / `$sdk_debug_extensions_init_time_ms` keys
(`constants.ts:109-110`, set at `posthog-core.ts:1233` and `:1236`) — these describe the
browser's own lazy-extension-loading path, which mobile SDKs do not have; the browser-only
`$sdk_debug_recording_script_not_loaded` key (`constants.ts:111`) — a browser-script-loading
concern with no mobile analog; Tier-2 counter keys
(buffer size/length in bytes, flushed size, full-snapshot counts, slowest full-snapshot
duration, throttled-mutation drop counts, oversized-mutation drop counts and bytes, rrweb error
counts, last-snapshot byte size/dimensions/age) — these need new counters on at least one
platform and are deferred to a follow-up `session-replay-debug-counters` change; Unity, which
has its own recorder and its own event-property edit site and is tracked as a separate
follow-up; and React Native, which builds its own events in JS and does not inherit these
properties the way Flutter does, and is tracked as a separate follow-up. The
`$sdk_diagnostics_config` event (masking flags, capture-log/network-telemetry toggles,
background-capture mode, sample rate) is a distinct, non-per-event surface and is out of scope
here. Cookieless mode is also out of scope: posthog-js drops `$recording_status` and every
`$sdk_debug_*` key entirely in cookieless mode because the replay extension is never
instantiated (`posthog-core.ts:1131`, `if (ext.sessionRecording && !startInCookielessMode)`);
mobile SDKs have no cookieless mode, so this divergence does not apply to them.

#### Scenario: Browser-only and counter keys are not required by this spec
- **GIVEN** an SDK conforming to this spec
- **WHEN** it attaches debug properties to a captured event
- **THEN** the absence of any Tier-2 counter key, of a browser-only interaction-hold value, or of
  `$sdk_debug_replay_url_trigger_status`, `$sdk_debug_extensions_init_method`,
  `$sdk_debug_extensions_init_time_ms`, or `$sdk_debug_recording_script_not_loaded` is not a
  violation of this spec
