## MODIFIED Requirements

### Requirement: Session, queue, hold-reason, trigger, and mode keys

In addition to `$recording_status`, the SDK SHALL attach the following keys where applicable to
the current platform, each in the tier this requirement names: a *required* key goes on every
non-`$snapshot` event when available; an *optional* key goes only on an eligible SDK event that
the 30-second window allows (and, on mobile, on the crash-context snapshot).

`$sdk_debug_session_start` (optional; an epoch-millisecond integer, the session's start time)
SHALL be attached whenever the optional bundle is attached and a session start time is available,
and SHALL describe the session identified by the event's own `$session_id` — the key and
`$session_id` on one event MUST never describe different sessions. When that id is the SDK
session manager's current session, the start time is the manager's. When a caller pre-attached a
different `$session_id` (the React Native and Flutter bridges do this on mobile; posthog-js never
accepts one — `calculateEventProperties` spreads the caller's properties and then overwrites
`$session_id` from its own session manager, `posthog-core.ts:2153-2159` at posthog-js `origin/main`
`928990ded`), the SDK SHALL derive the start time from the UUIDv7 timestamp embedded in that id —
the derivation posthog-js itself applies to an externally supplied session id
(`uuid7ToTimestampMs`, `packages/browser/src/sessionid.ts:25`) — and SHALL omit the key when the
id is not a version-7 UUID.

`$sdk_debug_current_session_duration` MUST NOT be attached by any SDK: it was a wall-clock
difference the replay capture diagnostics never read, and both references removed it.

posthog-js SHALL report `$sdk_debug_retry_queue_size` from its dedicated retry-only queue
(requests that failed and are backing off), separate from its normal outgoing batch. Mobile SDKs
have no separate retry queue — a single disk-backed queue handles both normal pre-flush batching
and post-failure retry backoff — so reporting the same depth under the `retry_queue_size` name
would misrepresent ordinary buffering as a stuck retry loop. Mobile SDKs SHALL instead report
that queue's current depth as `$sdk_debug_pending_queue_size`, and SHALL NOT emit
`$sdk_debug_retry_queue_size`. This is a deliberate key-name divergence from posthog-js, not an
oversight: the two keys measure genuinely different things (a retry-only backlog vs. a combined
pending-send depth), so giving them the same name across SDKs would make the property misleading
on whichever platform lacks a true retry-only queue. The queue-depth key is in neither tier (its
own requirement above).

When the replay integration is installed, `$sdk_debug_replay_internal_buffer_length` (required)
SHALL report the number of unsent replay snapshots: on mobile, the held buffer's depth while
`buffering`, otherwise the replay queue's depth. Mobile SDKs SHALL attach
`$sdk_debug_replay_flush_hold_reason` (optional) exactly when `$recording_status` is `buffering`
and the optional bundle is attached, taking one value per hold cause (`awaiting_remote_config`,
`below_minimum_duration`), and SHALL omit the key (not present-and-empty) outside a `buffering`
state. This presence rule is mobile-only and a deliberate divergence from posthog-js: the browser
recorder emits its interaction-hold reason while `$recording_status` still reads `active`
(`lazy-loaded-session-recorder.ts:2770-2772`), because a held browser epoch is otherwise
indistinguishable from an uploading one. That active-with-hold reporting and its values are
governed by `session-replay-ingestion-controls` and the out-of-scope requirement below, not by
this rule.

`$sdk_debug_replay_linked_flag_trigger_status` and `$sdk_debug_replay_event_trigger_status`
(both required) SHALL each report one of `trigger_activated` / `trigger_pending` /
`trigger_disabled` — the same three-value set posthog-js uses for every trigger kind (URL, linked
flag, event). Mobile SDKs emit the identical value set; the only divergence from posthog-js is
*how* the value is produced, not *what* values exist: posthog-js records trigger status for the
session via `register_for_session` with `hidden` persistence exposure, so the keys are not super
properties, and `SessionRecording.sdkDebugProperties` reads them back so the required-key merge
puts them on every event. Mobile SDKs SHALL compute trigger status fresh on every property build
from current integration state. Either way the trigger keys reach events only through the debug
merge and MUST NOT be attached as registered super properties.
`$sdk_debug_replay_pending_trigger_conditions` (optional) SHALL list whichever configured trigger
kinds are not yet satisfied; on mobile the possible kinds are `event_trigger` and `linked_flag`,
and the key is omitted when none is pending.

`$sdk_debug_replay_capture_mode` is **mobile-only** and **optional**. posthog-js has no analog —
its required and optional lists contain no capture-mode key — so a mobile SDK SHALL classify it
in the optional bundle, never in the required keys. Its value SHALL be `screenshot` when the
platform's screenshot-recording mode is on, or when the host SDK name is `posthog-flutter` (the
Flutter plugin always records screenshots through the native SDK); otherwise `wireframe`. No other
value is defined. It derives from configuration, not from integration state, so it stays present
on bundle-carrying events after replay is stopped or the integration is uninstalled, and a mobile
SDK whose platform ships the replay module SHALL include it in the no-integration fallback (see
"Attach the disabled shape when replay is not configured"). It is not a point-in-time key and
stays in the crash-context snapshot. `$sdk_debug_replay_throttle_delay_ms` (the configured
mutation-throttle delay) MUST NOT be attached by any SDK.

`$recording_status` and the `$sdk_debug_*` keys are properties the SDK sets itself, so they follow
capture's **Caller-supplied event properties take precedence**: a registered (super) property of
the same name overrides the SDK-computed value, a caller-supplied event property overrides both,
and `before_send` can change any of them. The override applies to that event only; the next event
without that key carries the SDK-computed value again.

Reference: posthog-js `origin/main` `928990ded` — `REQUIRED_REPLAY_PROPERTIES`
(`packages/browser/src/posthog-core.ts:190-200`); the recorder getter
`packages/browser/src/extensions/replay/external/lazy-loaded-session-recorder.ts:2767-2781`
(`$recording_status`, `$sdk_debug_replay_flush_hold_reason`,
`$sdk_debug_replay_internal_buffer_length`, `$sdk_debug_replay_internal_buffer_size`,
`$sdk_debug_session_start`, `$sdk_debug_replay_flushed_size`, `$sdk_debug_replay_rrweb_error`,
`$sdk_debug_rrweb_attached`, `$sdk_debug_rrweb_start_attempted` — no
`$sdk_debug_current_session_duration`); the session-persisted keys read back by
`SessionRecording.sdkDebugProperties`
(`packages/browser/src/extensions/replay/session-recording.ts:51-61`, `:487-499`); their `hidden`
exposure (`packages/browser/src/persistence-key-policy.ts:192-200`); the `register_for_session`
writes (`triggerMatching.ts:303`, `:415`, `:529`); the merge (`posthog-core.ts:2166-2175`);
session-start source `sessionid.ts:25`. posthog-ios `origin/main` `88f4b6b56` — the integration's builder `debugProperties()`
(`PostHog/Replay/PostHogReplayIntegration.swift:1899-1956`: status `:1918-1920`, hold reason
`:1921-1923`, capture mode `:1927`, buffer length `:1930`, trigger statuses `:1945-1946`, pending
conditions `:1948-1953`); `captureMode(config:)` (`:1862-1864`); the session start from the
session manager's start snapshot (`PostHog/PostHogSDK.swift:633-635`). The required/optional tiers,
the two removed keys, and the capture-mode classification are the contract mobile SDKs port; no
mobile code is cited for them.

Covering test: posthog-js `packages/browser/src/__tests__/posthog-core-also.test.ts:102` (the
required/optional split, including the trigger statuses on every event and
`$sdk_debug_replay_pending_trigger_conditions` / `$sdk_debug_session_start` only on
bundle-carrying events). posthog-ios `PostHogTests/PostHogSDKTest.swift:441` ("reports screenshot capture mode for the
flutter host"), and `PostHogTests/PostHogSessionReplayEventTriggersTest.swift:235` ("trigger status
reflects pending state before either trigger resolves, then activation as each fires") at
`88f4b6b56`; the merge order is covered by posthog-ios 4.0 (PostHog/posthog-ios#938)
`PostHogTests/PostHogSDKTest.swift:1293` ("registered debug properties override the SDK's, and
caller ones override both"). Planned (mobile): the required/optional split on a custom event, and the `wireframe`
default. No test on either mobile SDK derives the session start from a caller-supplied UUIDv7
`$session_id` (iOS reads the manager's snapshot at `PostHog/PostHogSDK.swift:633-635`); that
scenario remains planned.

#### Scenario: Session and queue keys are present when a session exists (posthog-js)
- **GIVEN** posthog-js is initialized with session replay and an active session
- **AND** no accepted event in the last 30 seconds carried the optional bundle
- **WHEN** an eligible SDK event is captured
- **THEN** the event's properties include `$sdk_debug_session_start` and
  `$sdk_debug_retry_queue_size`
- **AND** the event's properties do NOT include `$sdk_debug_current_session_duration`

#### Scenario: Session and queue keys are present when a session exists (mobile)
- **GIVEN** a mobile SDK is initialized with an active session
- **AND** no accepted event in the last 30 seconds carried the optional bundle
- **WHEN** an eligible SDK event is captured
- **THEN** the event's properties include `$sdk_debug_session_start` and
  `$sdk_debug_pending_queue_size`
- **AND** the event's properties do NOT include `$sdk_debug_retry_queue_size`,
  `$sdk_debug_current_session_duration`, or `$sdk_debug_replay_throttle_delay_ms`

#### Scenario: Session keys are present without session replay (mobile)
- **GIVEN** a mobile SDK is initialized without session replay configured
- **AND** a session is active
- **WHEN** an eligible SDK event that the window allows is captured
- **THEN** the event's properties include `$sdk_debug_session_start`
- **AND** the event's `$recording_status` is `disabled`

Mobile SDKs source `$sdk_debug_session_start` from the SDK's own session manager, not from the
replay recorder, so it is present on a bundle-carrying event whenever a session exists regardless
of replay configuration. This is a deliberate divergence from posthog-js, where the key lives in
the recorder's `sdkDebugProperties` getter and is absent until the recorder has loaded: on mobile
the session is owned by the SDK, and a crash-time `$exception` captured without replay still
benefits from the session's start. Consequently its presence is not a proxy for "replay is
loaded" on mobile; `$recording_status` is.

#### Scenario: Session keys follow a caller-supplied session id (mobile)
- **GIVEN** the session manager's session started at T
- **AND** a caller captures an eligible SDK event, with the window allowing the optional bundle,
  whose pre-attached `$session_id` is a UUIDv7 stamped at T − 1h
- **WHEN** the event is captured
- **THEN** the event's `$session_id` is the caller's id
- **AND** `$sdk_debug_session_start` is T − 1h, the timestamp embedded in that id, not T

Covering test: planned — `PostHogTest.kt` "session debug keys follow a caller-provided session
id" on Android; the iOS equivalent is planned too (`PostHog/PostHogSDK.swift:633-635` at
posthog-ios `88f4b6b56` reads the manager's start snapshot unconditionally).

#### Scenario: Session keys are omitted for a non-UUIDv7 caller session id (mobile)
- **GIVEN** a caller captures an eligible SDK event, with the window allowing the optional
  bundle, whose pre-attached `$session_id` is not a version-7 UUID
- **WHEN** the event is captured
- **THEN** the event's properties do not include `$sdk_debug_session_start`
- **AND** `$recording_status` is still present

#### Scenario: Mobile hold reason is present only while buffering
- **GIVEN** a mobile SDK whose replay integration is awaiting its first remote config
- **WHEN** an eligible SDK event that the window allows is captured
- **THEN** the event's `$recording_status` is `buffering`
- **AND** `$sdk_debug_replay_flush_hold_reason` is `awaiting_remote_config`
- **WHEN** remote config arrives and the session passes the minimum duration
- **AND** another eligible SDK event is captured after the window has elapsed
- **THEN** the event's `$recording_status` is `active`
- **AND** `$sdk_debug_replay_flush_hold_reason` is absent

#### Scenario: Linked-flag trigger status reflects current state on every capture
- **GIVEN** a linked flag trigger that has not matched
- **WHEN** a custom event is captured
- **THEN** `$sdk_debug_replay_linked_flag_trigger_status` is `trigger_pending`
- **WHEN** the linked flag later matches
- **AND** another custom event is captured within the same session
- **THEN** `$sdk_debug_replay_linked_flag_trigger_status` is `trigger_activated`

#### Scenario: Event trigger status reflects current state on every capture
- **GIVEN** an event trigger that has not yet been matched
- **WHEN** a custom event is captured
- **THEN** `$sdk_debug_replay_event_trigger_status` is `trigger_pending`
- **WHEN** the trigger event is captured
- **AND** another custom event is captured within the same session
- **THEN** `$sdk_debug_replay_event_trigger_status` is `trigger_activated`

#### Scenario: Pending trigger conditions ride in the optional bundle
- **GIVEN** a linked flag or event trigger is configured and not yet satisfied
- **WHEN** a custom event is captured
- **THEN** the event's properties do not include `$sdk_debug_replay_pending_trigger_conditions`
- **WHEN** an eligible SDK event that the window allows is captured
- **THEN** `$sdk_debug_replay_pending_trigger_conditions` lists the unsatisfied trigger kinds

#### Scenario: A registered property overrides the SDK-computed debug value
- **GIVEN** a super property named `$recording_status` is registered
- **WHEN** an event other than `$snapshot` is captured
- **THEN** the event's `$recording_status` is the registered value

#### Scenario: A caller-supplied property overrides registered and SDK-computed debug values
- **GIVEN** a super property named `$recording_status` is registered
- **WHEN** an event other than `$snapshot` is captured with a caller-supplied `$recording_status`
- **THEN** the event's `$recording_status` is the caller-supplied value

#### Scenario: A caller-supplied debug value applies to that event only
- **GIVEN** no super property named `$recording_status` is registered
- **WHEN** an event other than `$snapshot` is captured with a caller-supplied `$recording_status`
- **AND** a second event is captured without `$recording_status`
- **THEN** the second event's `$recording_status` is the SDK-computed value

#### Scenario: Capture mode reflects the screenshot flag or the Flutter host name
- **GIVEN** screenshot-recording mode is off
- **AND** the host SDK name is `posthog-flutter`
- **WHEN** an eligible SDK event that the window allows is captured
- **THEN** `$sdk_debug_replay_capture_mode` is `screenshot`

#### Scenario: Capture mode is screenshot when screenshot recording is on
- **GIVEN** screenshot-recording mode is on
- **AND** the host SDK name is not `posthog-flutter`
- **WHEN** an eligible SDK event that the window allows is captured
- **THEN** `$sdk_debug_replay_capture_mode` is `screenshot`

#### Scenario: Capture mode is wireframe when both screenshot recording and the Flutter host are off
- **GIVEN** screenshot-recording mode is off
- **AND** the host SDK name is not `posthog-flutter`
- **WHEN** an eligible SDK event that the window allows is captured
- **THEN** `$sdk_debug_replay_capture_mode` is `wireframe`

#### Scenario: Capture mode is never a required key (mobile)
- **GIVEN** a mobile SDK with the replay module available
- **WHEN** a custom event is captured
- **THEN** the event's properties do not include `$sdk_debug_replay_capture_mode`
