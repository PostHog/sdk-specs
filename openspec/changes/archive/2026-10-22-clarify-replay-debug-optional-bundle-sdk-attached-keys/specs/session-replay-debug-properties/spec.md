## MODIFIED Requirements

### Requirement: Attach the optional replay debug bundle only to eligible SDK events

The *optional replay debug bundle* SHALL be every replay debug key that is not a required key (the
required keys are listed in "Attach debug properties to every captured event except
`$snapshot`"). On mobile it is `$sdk_debug_session_start`, `$sdk_debug_replay_flush_hold_reason`,
`$sdk_debug_replay_pending_trigger_conditions`, and the mobile-only
`$sdk_debug_replay_capture_mode`. On the browser it is `$sdk_debug_session_start`,
`$sdk_debug_replay_flush_hold_reason`, `$sdk_debug_replay_pending_trigger_conditions`,
`$sdk_debug_replay_internal_buffer_size`, `$sdk_debug_rrweb_attached`,
`$sdk_debug_rrweb_start_attempted`, `$sdk_debug_replay_stale_config`,
`$sdk_debug_replay_trigger_groups_count`, `$sdk_debug_replay_matched_recording_trigger_groups`, and
`$sdk_debug_replay_remote_trigger_matching_config`. The queue-depth key is in neither tier; its
own requirement governs it.

The SDK SHALL attach the optional bundle only to *eligible SDK events*: events whose name starts
with `$`, **excluding** `$feature_flag_called`, `$snapshot`, and, on the browser, `$$heatmap`.
The SDK SHALL NOT attach any key of the optional bundle to a custom event (a name not starting
with `$`). This constrains only what the SDK attaches itself: it does not require the SDK to
remove a same-named key that reaches the event by another route, whether supplied by the caller in
the capture properties, registered as a super property, or set deliberately by `beforeSend`. When
the SDK does write a key itself, its value wins over a same-named caller or registered value (see
"SDK-computed `$recording_status` and `$sdk_debug_*` values SHALL take precedence" below).
Eligibility SHALL be decided on the event name as passed to capture, before `beforeSend` runs: an
eligible event that `beforeSend` renames to a custom name still carries the bundle it was built
with, and a custom event that `beforeSend` renames to a `$`-prefixed name does not gain it. The
30-second requirement below further limits how often an eligible event actually carries the
bundle.

Reference: posthog-js `origin/main` `928990ded` (posthog-js#5144, merged as `bd66ceef9`) —
`EVENTS_WITHOUT_REPLAY_DEBUG_PROPERTIES = ['$feature_flag_called', '$$heatmap', '$snapshot']` and
`isReplayDebugEvent` (`packages/browser/src/posthog-core.ts:201-204`); the merge copies a key
from `sessionRecording.sdkDebugProperties` only when `includeDebugProperties` (not paused and
eligible) or the key is required (`posthog-core.ts:2166-2175`); eligibility is tested on
the name `capture()` was called with (`eventName` at build, `event_name` when arming the window,
`:1959`), so a `before_send` rename does not change it. The gate only adds keys: at `origin/main`
`0fd32143b`, `calculateEventProperties` starts from a copy of the caller's properties
(`posthog-core.ts:2172`) and the merge loop writes a debug key only when it is included or
required (`:2218-2222`); nothing deletes a same-named key the caller, `register`, or
`before_send` put there. posthog-js separately hides its own persistence-backed replay state
from event properties (`persistence-key-policy.ts:192-200`, cited under the key catalogue);
that is a storage rule, not part of this gate. posthog-android `2e364df96` (posthog-android#833)
does the same: `sdkDebugProperties` builds only the keys it attaches
(`posthog/src/main/java/com/posthog/PostHog.kt:816-832`) and strips nothing. posthog-js is the
only reference for the gate. Mobile SDKs port it, and the two rename cases above
are the mobile contract: the eligibility decision made when the properties are built SHALL
survive `beforeSend`, so a rename in either direction does not change it. posthog-js gets this by
reading the original name directly; a mobile SDK needs its own way to carry the decision across
the hook.

Covering test: posthog-js `packages/browser/src/__tests__/posthog-core-also.test.ts:102` ("keeps
replay diagnosis on every event while throttling optional debug properties" — `custom_event`,
`$feature_flag_called`, and `$$heatmap` get the required keys only; `$pageview` gets the full
bundle). No posthog-js or mobile test captures a custom event with a caller-supplied optional-bundle
key; that scenario is planned on every SDK. Planned (mobile): one test per scenario in this
requirement, including both `beforeSend` rename scenarios.

#### Scenario: An eligible SDK event carries the optional bundle
- **GIVEN** the SDK is initialized with an active session
- **AND** no accepted event in the last 30 seconds carried the optional bundle
- **WHEN** a `$screen` / `$pageview` event is captured
- **THEN** the captured event's properties include `$sdk_debug_session_start`

#### Scenario: A custom event carries the required keys but none of the optional bundle
- **GIVEN** the SDK is initialized with an active session
- **AND** no accepted event in the last 30 seconds carried the optional bundle
- **WHEN** a custom event (name not starting with `$`) is captured
- **THEN** the captured event's properties include `$recording_status`
- **AND** they include neither `$sdk_debug_session_start`, `$sdk_debug_replay_flush_hold_reason`,
  `$sdk_debug_replay_pending_trigger_conditions`, nor `$sdk_debug_replay_capture_mode`

#### Scenario: A caller-supplied optional-bundle key on a custom event is kept
- **GIVEN** the SDK is initialized with an active session
- **AND** no accepted event in the last 30 seconds carried the optional bundle
- **WHEN** a custom event is captured with `$sdk_debug_session_start` set to `123` in its
  capture properties
- **THEN** the captured event's `$sdk_debug_session_start` is `123`
- **AND** its properties include no other key of the optional bundle

#### Scenario: A full-envelope feature-flag-called event carries the required keys only
- **GIVEN** the SDK is initialized with an active session
- **AND** no accepted event in the last 30 seconds carried the optional bundle
- **WHEN** a full-envelope `$feature_flag_called` event is captured
- **THEN** the captured event's properties include `$recording_status`
- **AND** they do not include `$sdk_debug_session_start`

#### Scenario: Heatmap event carries the required keys only (browser)
- **GIVEN** posthog-js is initialized with the session-recording extension
- **WHEN** a `$$heatmap` event is captured
- **THEN** the captured event's properties include `$recording_status`
- **AND** they do not include `$sdk_debug_session_start`

#### Scenario: Eligibility is decided before beforeSend
- **GIVEN** a `beforeSend` hook that renames `$renamed` to `custom name` and `custom` to `$custom`
- **AND** no accepted event in the last 30 seconds carried the optional bundle
- **WHEN** `$renamed` is captured
- **THEN** the sent `custom name` event carries `$sdk_debug_session_start`
- **WHEN** the window has elapsed and `custom` is captured
- **THEN** the sent `$custom` event does not carry `$sdk_debug_session_start`
- **AND** the next eligible SDK event still carries the optional bundle
