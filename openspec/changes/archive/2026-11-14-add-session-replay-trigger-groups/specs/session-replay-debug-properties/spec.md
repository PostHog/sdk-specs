## MODIFIED Requirements

### Requirement: Attach the optional replay debug bundle only to eligible SDK events

The *optional replay debug bundle* SHALL be every replay debug key that is not a required key (the
required keys are listed in "Attach debug properties to every captured event except
`$snapshot`"). On mobile it is `$sdk_debug_session_start`, `$sdk_debug_replay_flush_hold_reason`,
`$sdk_debug_replay_pending_trigger_conditions`, the mobile-only
`$sdk_debug_replay_capture_mode`, and, when the SDK implements trigger groups
(`session-replay-trigger-groups`), `$sdk_debug_replay_trigger_groups_count`,
`$sdk_debug_replay_matched_recording_trigger_groups`, and
`$sdk_debug_replay_remote_trigger_matching_config`. On the browser it is `$sdk_debug_session_start`,
`$sdk_debug_replay_flush_hold_reason`, `$sdk_debug_replay_pending_trigger_conditions`,
`$sdk_debug_replay_internal_buffer_size`, `$sdk_debug_rrweb_attached`,
`$sdk_debug_rrweb_start_attempted`, `$sdk_debug_replay_stale_config`,
`$sdk_debug_replay_trigger_groups_count`, `$sdk_debug_replay_matched_recording_trigger_groups`, and
`$sdk_debug_replay_remote_trigger_matching_config`. The three trigger-group keys are not
browser-only: every SDK that implements trigger groups attaches them in the optional tier, with the
values `session-replay-trigger-groups` specifies, and an SDK that does not implement trigger groups
omits them. The queue-depth key is in neither tier; its own requirement governs it.

The SDK SHALL attach the optional bundle only to *eligible SDK events*: events whose name starts
with `$`, **excluding** `$feature_flag_called`, `$snapshot`, and, on the browser, `$$heatmap`.
The SDK SHALL NOT attach any key of the optional bundle to a custom event (a name not starting
with `$`). This constrains only what the SDK attaches itself: it does not require the SDK to
remove a same-named key that reaches the event by another route, whether supplied by the caller in
the capture properties, registered as a super property, or set deliberately by `beforeSend`.
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
When the remote config selects trigger groups (`session-replay-trigger-groups`), mobile SDKs SHALL
report `trigger_disabled` for both keys: the keys describe the V1 linked flag and V1 event
triggers, and neither is in effect while groups are selected. The state of the groups is carried
by `$sdk_debug_replay_pending_trigger_conditions` and
`$sdk_debug_replay_matched_recording_trigger_groups`. This is a deliberate divergence from
posthog-js, which has no rule for these keys under trigger groups: each group's linked-flag and
event matcher writes the key as a side effect of a status read (`LinkedFlagMatching.triggerStatus`
and `EventTriggerMatching.triggerStatus`,
`packages/browser/src/extensions/replay/external/triggerMatching.ts:413-417` and `:527-531` at
posthog-js `origin/main` `f0286fd82`), so the browser value follows the group that was read last.
No posthog-js test covers these two keys under trigger groups.
`$sdk_debug_replay_pending_trigger_conditions` (optional) SHALL list whichever configured trigger
kinds are not yet satisfied; on mobile the V1 kinds are `event_trigger` and `linked_flag`,
and the key is omitted when none is pending. When the remote config selects trigger groups
(`session-replay-trigger-groups`), and only while no group records and some group is pending, each
pending group SHALL contribute one entry of the form
`trigger group "<name>": <condition>` per unsatisfied condition, exactly as posthog-js writes it
(`V2TriggerGroupStrategy.getPendingTriggerConditions`,
`packages/browser/src/extensions/replay/external/recording-strategies.ts:649-658` at posthog-js
`origin/main` `480395c443`), on mobile as well as on the browser; a bare `trigger_groups` entry is
not a conforming value. A group records when it is activated and sampled in. Once any group
records, the property SHALL carry no trigger-group entries, also for a group that is still
pending: a browser SDK MAY write an empty list, and a mobile SDK SHALL omit the key. posthog-js `origin/main` `f05a993f9d` writes the list only while the status is buffering: `packages/browser/src/extensions/replay/external/triggerMatching.ts:850-851` returns sampled as soon as one activated group is sampled in, before `:855-856` returns buffering for a pending group; `lazy-loaded-session-recorder.ts:2295-2320` (`_maybeLogBufferingReason`, called on every flush at `:2423`) registers the pending list at `:2318` and registers `[]` at `:2298` when the status leaves buffering after it reported a reason; `session-recording.ts:554-569` (`sdkDebugProperties`) reads the persisted value back. Covering test for the cleared value: posthog-js `packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:5685` ("reports the same condition again after leaving buffering", V1 URL trigger, asserts `[]` at `:5720`). No posthog-js test covers a pending group next to a group that records; source only. In the same configuration `$sdk_debug_replay_remote_trigger_matching_config`
(optional) SHALL be `v2_trigger_groups` and `$sdk_debug_replay_trigger_groups_count` (optional)
SHALL be the number of configured groups (`recording-strategies.ts:379-382`);
`$sdk_debug_replay_matched_recording_trigger_groups` is specified in
`session-replay-trigger-groups`. Covering test for the pending text: posthog-js
`packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:8763` ("describes
pending conditions within trigger groups"); for the config and count keys `:8829` ("registers
session properties when trigger group matches and is sampled"). No mobile test covers the
trigger-group values yet; they are planned.

`$sdk_debug_replay_capture_mode` is **mobile-only** and **optional**. posthog-js has no analog —
its required and optional lists contain no capture-mode key — so a mobile SDK SHALL classify it
in the optional bundle, never in the required keys. Its value SHALL be `screenshot`, because mobile
session replay always records masked screenshots. posthog-ios and posthog-android before 4.0
reported `wireframe` when their screenshot option was off and the host SDK was not
`posthog-flutter`; 4.0 removed wireframe recording and that option. No other value is defined.
It derives from configuration, not from integration state, so it stays present on
bundle-carrying events after replay is stopped or the integration is uninstalled, and a mobile
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
conditions `:1948-1953`); the session start from the session manager's start snapshot
(`PostHog/PostHogSDK.swift:633-635`). posthog-ios 4.0 (PostHog/posthog-ios#873) `adb99908d`
hardcodes the value as `PostHogReplayIntegration.captureMode = "screenshot"`
(`PostHog/Replay/PostHogReplayIntegration.swift:1658`). The required/optional tiers,
the two removed keys, and the capture-mode classification are the contract mobile SDKs port; no
mobile code is cited for them.

Covering test: posthog-js `packages/browser/src/__tests__/posthog-core-also.test.ts:102` (the
required/optional split, including the trigger statuses on every event and
`$sdk_debug_replay_pending_trigger_conditions` / `$sdk_debug_session_start` only on
bundle-carrying events). posthog-ios `PostHogTests/PostHogSessionReplayEventTriggersTest.swift:235`
("trigger status reflects pending state before either trigger resolves, then activation as each
fires") at `88f4b6b56`; the `screenshot` value by posthog-ios 4.0 (PostHog/posthog-ios#873)
`PostHogTests/PostHogSDKTest.swift:493` ("captures $recording_status on every event and the full
replay debug bundle on the first eligible SDK event only", `:510`) at `adb99908d`; the merge order is covered by posthog-ios 4.0 (PostHog/posthog-ios#938)
`PostHogTests/PostHogSDKTest.swift:1293` ("registered debug properties override the SDK's, and
caller ones override both"). Planned (mobile): the required/optional split on a custom event. No test on either mobile SDK derives the session start from a caller-supplied UUIDv7
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

#### Scenario: Pending trigger-group conditions name the group
- **GIVEN** the remote config selects trigger groups with one group named "checkout" whose event
  leg has not matched
- **WHEN** an eligible SDK event that the window allows is captured
- **THEN** `$sdk_debug_replay_remote_trigger_matching_config` is `v2_trigger_groups`
- **AND** `$sdk_debug_replay_trigger_groups_count` is `1`
- **AND** `$sdk_debug_replay_pending_trigger_conditions` contains an entry starting with
  `trigger group "checkout": `
- **AND** it does not contain a bare `trigger_groups` entry
- **AND** on mobile `$sdk_debug_replay_event_trigger_status` and
  `$sdk_debug_replay_linked_flag_trigger_status` are both `trigger_disabled`

#### Scenario: A pending group is not listed once another group records
- **GIVEN** session replay is enabled
- **AND** the remote config selects trigger groups and configures a trigger group named "Always" with no conditions and a sample rate of 1.0
- **AND** a trigger group named "Checkout" with event condition "checkout_started" and a sample rate of 1.0
- **WHEN** the client captures an eligible SDK event before "checkout_started" is captured
- **THEN** session recording should be active
- **AND** the event's `$sdk_debug_replay_pending_trigger_conditions`, if present, includes no entry that starts with `trigger group "Checkout": `

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

#### Scenario: Capture mode is always screenshot (mobile)
- **GIVEN** a mobile SDK with the replay module available
- **WHEN** an eligible SDK event that the window allows is captured
- **THEN** `$sdk_debug_replay_capture_mode` is `screenshot`

#### Scenario: Capture mode is never a required key (mobile)
- **GIVEN** a mobile SDK with the replay module available
- **WHEN** a custom event is captured
- **THEN** the event's properties do not include `$sdk_debug_replay_capture_mode`


### Requirement: Out of scope for this capability

This spec SHALL NOT be read as requiring: browser-only keys with no mobile analog (e.g. anything
the browser recorder emits that mobile has no equivalent concept for, including the browser's own
interaction-hold `flush_hold_reason` values, and their presence while `$recording_status` reads
`active`, used for the idle-rotation/fresh-start withholding behavior specified separately in
`session-replay-ingestion-controls`); the browser-only required keys
`$sdk_debug_recording_script_not_loaded`, `$sdk_debug_replay_url_trigger_status` (mobile has no
URL-trigger concept), `$sdk_debug_replay_rrweb_error`, and `$sdk_debug_replay_flushed_size`; the
browser-only optional keys `$sdk_debug_replay_stale_config`,
`$sdk_debug_replay_internal_buffer_size`, `$sdk_debug_rrweb_attached`, and
`$sdk_debug_rrweb_start_attempted` (`packages/browser/src/posthog-core.ts:190-200`,
`session-recording.ts:51-61`, `lazy-loaded-session-recorder.ts:2767-2781` at posthog-js
`origin/main` `928990ded`); the trigger-group keys `$sdk_debug_replay_trigger_groups_count`,
`$sdk_debug_replay_matched_recording_trigger_groups`, and
`$sdk_debug_replay_remote_trigger_matching_config`, which are governed by
`session-replay-trigger-groups` and are not required of an SDK that does not implement trigger
groups; the browser-only `$sdk_debug_extensions_init_method` /
`$sdk_debug_extensions_init_time_ms` keys (`event` exposure,
`persistence-key-policy.ts:189-190`) — these describe the browser's own lazy-extension-loading
path, which mobile SDKs do not have, and are not part of either tier; the browser-only drop
counters on `$snapshot` events (the drop-counter requirement above); the browser-only `$$heatmap`
exclusion (mobile has no such event). The rrweb performance counters the browser used to attach
(full-snapshot timestamps, `$snapshot_max_depth_exceeded`, slowest-full-snapshot and
deferred-stylesheet stats, slowest mutation batch, discarded duration samples, observer init
failures)
were removed from captured events by posthog-js#5144 (merged as `bd66ceef9`) and are emitted by
no platform. The four replay drop counters are the exception: #5144 moved them onto `$snapshot`
events, where the drop-counter requirement above governs them and mobile SDKs are not required to
emit them. The previously planned follow-up `session-replay-debug-counters` change therefore has
no shipped reference to describe beyond those four and is not a pending obligation of this spec;
any other Tier-2 counter stays out of scope, and if one is later needed it starts as a new change
with its own reference. Unity, which has its own recorder
and its own event-property edit site, is tracked as a separate follow-up; React Native, which
builds its own events in JS and does not inherit these properties the way Flutter does, is
tracked as a separate follow-up. The `$sdk_diagnostics_config` event (masking flags,
capture-log/network-telemetry toggles, background-capture mode, sample rate) is a distinct,
non-per-event surface and is out of scope here. Cookieless mode is also out of scope: posthog-js
drops `$recording_status` and every `$sdk_debug_replay_*` key entirely in cookieless mode because
the replay extension is never instantiated (`posthog-core.ts:1180`, `if (ext.sessionRecording &&
!startInCookielessMode)`); mobile SDKs have no cookieless mode, so this divergence does not apply
to them.

#### Scenario: Browser-only and counter keys are not required by this spec
- **GIVEN** an SDK conforming to this spec
- **WHEN** it attaches replay debug keys to a captured event
- **THEN** the absence of the four replay drop counters, of a browser-only interaction-hold
  value, of `$sdk_debug_recording_script_not_loaded`, `$sdk_debug_replay_url_trigger_status`,
  `$sdk_debug_replay_rrweb_error`, `$sdk_debug_replay_flushed_size`,
  `$sdk_debug_replay_stale_config`, `$sdk_debug_replay_internal_buffer_size`,
  `$sdk_debug_rrweb_attached`, `$sdk_debug_rrweb_start_attempted`,
  `$sdk_debug_extensions_init_method`, or `$sdk_debug_extensions_init_time_ms` on a mobile event
  is not a violation of this spec
- **AND** on an SDK that does not implement trigger groups, the absence of
  `$sdk_debug_replay_trigger_groups_count`, `$sdk_debug_replay_matched_recording_trigger_groups`,
  and `$sdk_debug_replay_remote_trigger_matching_config` is not a violation of this spec

#### Scenario: Removed keys are not required by this spec
- **GIVEN** an SDK conforming to this spec
- **WHEN** it attaches replay debug keys to a captured event
- **THEN** the absence of any rrweb performance counter key removed by posthog-js#5144, of
  `$sdk_debug_current_session_duration`, or of `$sdk_debug_replay_throttle_delay_ms` is not a
  violation of this spec
