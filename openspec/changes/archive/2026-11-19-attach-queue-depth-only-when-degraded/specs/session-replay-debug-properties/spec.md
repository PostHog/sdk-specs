## RENAMED Requirements

- FROM: `### Requirement: The queue-depth key stays on every non-`$snapshot` event`
- TO: `### Requirement: The queue-depth key is attached only while the send queue is backed up`

## MODIFIED Requirements

### Requirement: The queue-depth key is attached only while the send queue is backed up

`$sdk_debug_retry_queue_size` (posthog-js) / `$sdk_debug_pending_queue_size` (mobile) SHALL be
attached only while it shows that delivery is behind. The key reports a backlog; a value that says
the queue is healthy adds bytes to every event and tells nobody anything.

The SDK SHALL NOT attach the queue-depth key when the queue's depth is `0`. On the browser the
retry queue only holds requests that failed and are backing off, so any depth above `0` is a
backlog, and posthog-js SHALL attach `$sdk_debug_retry_queue_size` whenever the retry queue is not
empty. On mobile the single pending queue also holds events waiting for an ordinary flush, so a
depth below the SDK's `flushAt` threshold is normal batching. A mobile SDK SHOULD attach
`$sdk_debug_pending_queue_size` when the depth is at or above its configured `flushAt` (a flush is
due and has not happened: offline, failing, backing off, or suspended), and MAY omit it below that
threshold. Every first-party mobile SDK, including wrappers that build their own events (React
Native, Flutter desktop), omits it below `flushAt`.

When the key is attached, it SHALL be attached the same way on every captured event except
`$snapshot` and the minimal `$feature_flag_called` envelope, whether or not the event is eligible,
whether or not a window is open, and whether or not session replay is configured or
intentionally off. The depth is read when the event's properties are built. It is a
point-in-time value and SHALL be stripped from the mobile crash-context snapshot like the other
point-in-time keys. The key-name divergence (retry-only backlog on the browser vs. combined pending
depth on mobile) is unchanged and specified in the keys requirement.

The queue-depth key is SDK-owned. While the queue is not backed up, the SDK SHALL remove a
registered or caller-supplied value of the same name instead of sending it, so a value the app set
cannot make a healthy queue look backed up. While the queue is backed up, the SDK-computed depth
replaces such a value, as every SDK does today. This is an exception to the caller-wins rule in
"Session, queue, hold-reason, trigger, and mode keys" for this one key.

A missing key therefore means the queue was not backed up when the event was built (or, for an
event from an SDK version that predates this rule, that the value was not reported). Consumers use
`$lib` and `$lib_version` to tell the two apart.

Reference: posthog-js `origin/main` `928990ded` sets `$sdk_debug_retry_queue_size` outside the
`this.sessionRecording` block (`packages/browser/src/posthog-core.ts:2176`), from the retry queue's
length; the retry queue holds only requests that failed and are retrying
(`packages/browser/src/retry-queue.ts`). The minimal envelope is rebuilt from an allowlist
(`:1909-1911`, `packages/core/src/featureFlagUtils.ts:263`). posthog-ios `origin/main` `88f4b6b56`
sets `$sdk_debug_pending_queue_size` from the queue's depth (`PostHog/PostHogSDK.swift:638-640`) in
the shared-properties build (`:714`) and lists it in `pointInTimeDebugKeys` (`:3251-3255`), which
`notifyContextDidChange` strips (`:3277-3279`). At those commits every SDK attaches the key on
every non-`$snapshot` event, including at depth `0`; this requirement replaces that rule.

Covering test: posthog-js `packages/browser/src/__tests__/__snapshots__/featureflags.test.ts.snap:103`
(the full `$feature_flag_called` envelope) and posthog-ios `PostHogTests/PostHogSDKTest.swift:695`
(the minimal envelope carries no `$sdk_debug_*` key) and
`PostHogTests/PostHogSessionReplayRemoteConfigBufferTest.swift:580` ("crash context re-snapshots on
recording transitions and omits point-in-time counters") at `88f4b6b56`. The existing tests that
expect the key at depth `0` (posthog-js `posthog-core-also.test.ts:806`, posthog-ios
`PostHogSDKTest.swift:474`) encode the replaced rule. Planned (every SDK): an empty queue attaches no
key; a backed-up queue attaches it on a custom event and on an eligible event inside the window.

#### Scenario: An empty queue attaches no queue-depth key
- **GIVEN** the SDK is initialized
- **AND** its queue is empty (posthog-js: no request waiting to be retried; mobile: no pending event)
- **WHEN** a custom event is captured
- **THEN** the event's properties include neither `$sdk_debug_retry_queue_size` nor
  `$sdk_debug_pending_queue_size`

#### Scenario: A non-empty retry queue attaches the key (browser)
- **GIVEN** posthog-js has at least one request waiting in its retry queue
- **WHEN** a custom event is captured
- **THEN** the event's properties include `$sdk_debug_retry_queue_size` with the retry queue's length

#### Scenario: Ordinary batching below `flushAt` may omit the key (mobile)
- **GIVEN** a mobile SDK whose pending queue holds more than `0` and fewer than `flushAt` events
- **WHEN** a custom event is captured
- **THEN** the event's properties MAY omit `$sdk_debug_pending_queue_size`

#### Scenario: A queue at or above `flushAt` attaches the key (mobile)
- **GIVEN** a mobile SDK whose pending queue holds at least `flushAt` events, because a flush is
  failing, backing off, or has not run
- **WHEN** a custom event is captured
- **THEN** the event's properties SHOULD include `$sdk_debug_pending_queue_size` with the queue's depth
- **AND** they do not include `$sdk_debug_retry_queue_size`

#### Scenario: A registered or caller value does not reach a healthy event
- **GIVEN** the app registered `$sdk_debug_pending_queue_size` (or `$sdk_debug_retry_queue_size` on
  the browser) as a super property
- **AND** the queue is not backed up
- **WHEN** a custom event is captured with the same key as a caller-supplied property
- **THEN** the event's properties do not include that key

#### Scenario: A backed-up queue attaches the key on an eligible event inside the window
- **GIVEN** the queue is backed up, so the SDK attaches the queue-depth key
- **AND** an eligible SDK event carrying the optional bundle was accepted less than 30 seconds
  ago
- **WHEN** another eligible SDK event is captured
- **THEN** the event's properties include the queue-depth key
- **AND** they do not include `$sdk_debug_session_start`

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
own requirement, "The queue-depth key is attached only while the send queue is backed up").

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
in the optional bundle, never in the required keys. Its value SHALL be `screenshot`, because mobile
session replay always records masked screenshots. posthog-ios and posthog-android before 4.0
reported `wireframe` when their screenshot option was off and the host SDK was not
`posthog-flutter`; 4.0 removed wireframe recording and that option. No other value is defined.
It derives from configuration, not from integration state, but it is a replay diagnostic, so it
is attached only while replay is not intentionally off (see "Attach only the disabled shape while replay is intentionally off"). It is absent on
events captured after replay is stopped or the integration is uninstalled, and the no-integration
fallback does not include it (see "Attach the disabled shape when replay is not configured"). It is
not a point-in-time key and stays in the crash-context snapshot while replay is not intentionally
off. `$sdk_debug_replay_throttle_delay_ms` (the configured
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
- **AND** at least one request is waiting in its retry queue
- **AND** no accepted event in the last 30 seconds carried the optional bundle
- **WHEN** an eligible SDK event is captured
- **THEN** the event's properties include `$sdk_debug_session_start` and
  `$sdk_debug_retry_queue_size`
- **AND** the event's properties do NOT include `$sdk_debug_current_session_duration`

#### Scenario: Session and queue keys are present when a session exists (mobile)
- **GIVEN** a mobile SDK is initialized with session replay enabled and an active session
- **AND** its pending queue holds at least `flushAt` events
- **AND** no accepted event in the last 30 seconds carried the optional bundle
- **WHEN** an eligible SDK event is captured
- **THEN** the event's properties include `$sdk_debug_session_start` and
  `$sdk_debug_pending_queue_size`
- **AND** the event's properties do NOT include `$sdk_debug_retry_queue_size`,
  `$sdk_debug_current_session_duration`, or `$sdk_debug_replay_throttle_delay_ms`

#### Scenario: The session start is absent without session replay (mobile)
- **GIVEN** a mobile SDK is initialized without session replay configured
- **AND** a session is active
- **WHEN** an eligible SDK event that the window allows is captured
- **THEN** the event's `$recording_status` is `disabled`
- **AND** the event's properties do not include `$sdk_debug_session_start`

Mobile SDKs source `$sdk_debug_session_start` from the SDK's own session manager, not from the
replay recorder, but they attach it only while replay is not intentionally off. This matches
posthog-js, where the key lives in the recorder's `sdkDebugProperties` getter and is absent when no
recorder runs (`lazy-loaded-session-recorder.ts:2822-2836`, key at `:2830`, at posthog-js
`origin/main` `16e3f63b9`). An earlier version of this spec kept the key on replay-off events
because the SDK owns the session; that rule is withdrawn, because the key has no diagnostic value
when replay is off and it adds to every event's payload. Its presence says that replay is not
intentionally off, not that replay is recording; `$recording_status` says that.

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

#### Scenario: Capture mode is always screenshot (mobile)
- **GIVEN** a mobile SDK with the replay module available and replay not intentionally off
- **WHEN** an eligible SDK event that the window allows is captured
- **THEN** `$sdk_debug_replay_capture_mode` is `screenshot`

#### Scenario: Capture mode is absent while replay is intentionally off (mobile)
- **GIVEN** a mobile SDK with the replay module available
- **AND** replay is intentionally off
- **WHEN** an eligible SDK event that the window allows is captured
- **THEN** the event's properties do not include `$sdk_debug_replay_capture_mode`

#### Scenario: Capture mode is never a required key (mobile)
- **GIVEN** a mobile SDK with the replay module available
- **WHEN** a custom event is captured
- **THEN** the event's properties do not include `$sdk_debug_replay_capture_mode`

### Requirement: Attach the disabled shape when replay is not configured

A mobile SDK SHALL attach `$recording_status: disabled` to every captured event except
`$snapshot` and the minimal `$feature_flag_called` envelope even when session replay is not
configured at all (no replay integration installed, or the platform module that provides it is
absent) — an event captured under these conditions is exactly the case the OOM investigation
that motivated this spec needed to distinguish from an active or buffering replay. In that state
`$recording_status` is the only replay key the SDK attaches: the trigger statuses and
`$sdk_debug_replay_internal_buffer_length` come from the integration and are absent, and so are
`$sdk_debug_replay_capture_mode` and `$sdk_debug_session_start`. There is no fallback optional
bundle. An eligible SDK event carries the same single replay key as a custom event, plus the
queue-depth key while the queue is backed up. This is the not-configured case of "Attach only the
disabled shape while replay is intentionally off".

This is a deliberate mobile divergence from posthog-js. The browser attaches no replay debug key
when the session-recording extension is not instantiated — `calculateEventProperties` requires
`this.sessionRecording` before merging, so a browser build without session recording (or in
cookieless mode, where the extension is never created) carries no `$recording_status` at all.
When the extension exists but the lazy recorder has not loaded, the browser attaches
`{ $recording_status: <extension status> }` plus the session-persisted replay debug keys, each
tier filtered as usual, except while replay is intentionally off, when it attaches only
`$recording_status: disabled`.

Reference: posthog-js `origin/main` `16e3f63b9` — `if (this.sessionRecording)` guards the merge
(`packages/browser/src/posthog-core.ts:2304-2313`); the pre-load fallback is
`SessionRecording.sdkDebugProperties`
(`packages/browser/src/extensions/replay/session-recording.ts:487-499`, the
`{ $recording_status: this.status }` arm at `:497`, the session-persisted keys read first at
`:489-496`); the extension is created only when `ext.sessionRecording && !startInCookielessMode`
(`posthog-core.ts:1180` at `928990ded`; not re-read at `16e3f63b9`). posthog-ios `origin/main`
`88f4b6b56` — the no-integration fallback sets `$recording_status: disabled` and
`$sdk_debug_replay_capture_mode` on iOS and only `$recording_status: disabled` on other Apple
platforms (`PostHog/PostHogSDK.swift:703-713`); `$sdk_debug_session_start` comes from the session
manager (`:633-635`, merged at `:714`). This change removes both extra keys from that fallback.
The contract mobile SDKs port is the single-key fallback.

Covering test: posthog-js `packages/browser/src/__tests__/posthog-core-also.test.ts:835-850`
("returns calculated properties" — the extension is present but not started, so a custom event
carries `$recording_status: 'disabled'` and no other replay key); no posthog-js test asserts the
no-extension case. posthog-ios `PostHogTests/PostHogSDKTest.swift:474` ("reports disabled
recording status with no replay keys on non-iOS platforms") at `88f4b6b56`. Planned (mobile): with
no integration installed, a custom event and an eligible event the window allows both carry
`$recording_status: disabled` and no other replay key. Android's `PostHogTest.kt` "with no
handler" is not yet in the repo.

#### Scenario: No replay integration installed still reports disabled
- **GIVEN** a mobile SDK is initialized with no session replay integration installed
- **WHEN** a custom event is captured
- **THEN** the event's `$recording_status` is `disabled`
- **AND** the event's properties include neither `$sdk_debug_replay_capture_mode` nor
  `$sdk_debug_session_start`

#### Scenario: No replay integration installed adds nothing to an eligible event (mobile)
- **GIVEN** a mobile SDK is initialized with no session replay integration installed
- **AND** no accepted event in the last 30 seconds carried the optional bundle
- **WHEN** a `$screen` event is captured
- **THEN** the event's `$recording_status` is `disabled`
- **AND** the event's properties include neither `$sdk_debug_session_start` nor
  `$sdk_debug_replay_capture_mode`

#### Scenario: No session-recording extension attaches nothing (browser)
- **GIVEN** posthog-js is initialized without the session-recording extension (not bundled, or
  cookieless mode)
- **WHEN** a `$pageview` event is captured
- **THEN** the event's properties include neither `$recording_status` nor any
  `$sdk_debug_replay_*` key

### Requirement: Attach only the disabled shape while replay is intentionally off

An SDK SHALL NOT attach any replay diagnostic key to a captured event while session replay is
*intentionally off*. Replay is intentionally off when it is off locally or off remotely.

Replay is *off locally* when any of these holds:

- The SDK's own config turns replay off. Mobile: no replay integration is installed, or
  `sessionReplay` is false and the app has not started replay manually. Browser:
  `disable_session_recording` is true. A hybrid wrapper that builds its own debug map applies the
  same test to its own config (React Native: replay is not enabled and has not been started
  manually).
- The app has explicitly stopped replay (`stopSessionRecording()` or its platform equivalent).
- The user has opted out of capture. No event is captured while opted out, so this affects only
  the mobile crash-context snapshot and a hybrid wrapper's debug map.

Replay is *off remotely* when the SDK's cached remote config turns replay off: `sessionRecording`
is the boolean `false`. On mobile, a remote config whose `quotaLimited` list contains
`mobile_recordings` is off remotely too, because the mobile SDKs force `sessionRecording` to
`false` in that case (posthog-ios `origin/main` `a0a71796c2` `PostHog/PostHogRemoteConfig.swift:373-375`,
`:636-640`; posthog-android `origin/main` `1101d79b` `posthog/src/main/java/com/posthog/internal/PostHogRemoteConfig.kt:326`).
The SDK SHALL read the cached config value, not derived replay-flag state. Derived state can be
cleared on `reset()` while the cached config still enables replay (posthog-ios
`PostHog/PostHogRemoteConfig.swift:1389-1393`, `:1403-1406`). No remote config yet is not off
remotely: the SDK is awaiting config and keeps its keys. A `/config` response with no
`sessionRecording` key is not off remotely either, but an SDK MAY treat it as off. The server always
sends the key, as `false` or a config object (PostHog/posthog `c1fe8dcf295`
`posthog/models/remote_config.py:305-326`), so the two readings differ only for a response the
server does not produce. posthog-android treats it as off, because its decoder defaults the key to
`false` (posthog-android `origin/main` `1101d79b`
`posthog/src/main/java/com/posthog/internal/PostHogRemoteConfigResponse.kt:10`). posthog-js treats it
like a failed fetch: it keeps the persisted config, and with none persisted it reports
`missing_config` and does not record (posthog-js `origin/main` `53e5c0e35`
`packages/browser/src/extensions/replay/session-recording.ts:326-339`).

A running recorder is not off remotely. Replay becomes off remotely when the recorder stops (see
"Reconciliation with `is-session-replay-active` and `session-replay-ingestion-controls`").

Replay is **not** intentionally off, and every key the other requirements of this capability call
for stays, when replay is enabled and is in any of these states: sampled out, waiting on a trigger
(URL, event, or linked flag), awaiting its first remote config, buffering, or paused. These
states are the observability this capability exists for.

The gate SHALL read the SDK's replay state: enabled locally AND enabled remotely. It SHALL NOT
read `$recording_status`. A sampled-out session reports `$recording_status: disabled` too, so a
gate on that value would drop the diagnostics of a session that replay is still sampling.

While replay is intentionally off, a captured event SHALL carry `$recording_status: disabled`
wherever the SDK attaches that key (the required-key rule and the disabled-shape rule decide where),
and SHALL carry none of the following (the *removal set*):

- any `$sdk_debug_replay_*` key;
- any `$sdk_debug_rrweb_*` key;
- `$sdk_debug_recording_script_not_loaded`;
- `$sdk_debug_session_start`.

This covers the required keys, the optional bundle, and every replay diagnostic that the SDK keeps
in session storage or registers as a session or super property. The gate filters at attach time.
It SHALL NOT delete the stored keys, so that they come back when replay is turned on again and
they are still valid.

The gate removes keys and never adds one. Keys that are not replay diagnostics are untouched:
`$sdk_debug_retry_queue_size` (browser), `$sdk_debug_pending_queue_size` (mobile),
`$sdk_debug_error_capturing_properties`, and the browser's `$sdk_debug_extensions_init_method` and
`$sdk_debug_extensions_init_time_ms`. The gate constrains what the SDK attaches itself. A caller
who supplies or registers a key by name keeps the caller-wins rule in "Session, queue, hold-reason,
trigger, and mode keys". The `$snapshot` drop counters are outside the gate: they exist only while
the recorder runs, and their own requirement governs them.

The SDK SHALL evaluate the gate every time it builds the debug map for an event. Turning replay
off in mid-session gives the next event the off shape. That includes a browser whose lazy recorder
stays loaded after the stop, where `$recording_status` SHALL read `disabled` and the recorder's own
keys SHALL be left out. Turning replay on again gives the next event the normal shape. The gate and
the keys it lets through SHALL come from one consistent snapshot of replay state (see "All debug
keys on one event come from a single consistent snapshot").

Every consumer of the debug map SHALL receive the gated map. On mobile that includes the
crash-context snapshot and any API that hands the map to a wrapper SDK. A snapshot taken while
replay is off carries `$recording_status: disabled` and nothing else from the gate's removal set,
and it is refreshed when replay turns off or on.

This is the same rule on every platform. posthog-js is the reference for the shape and the gate
state. It does not yet meet this requirement after a mid-session stop or a mid-session remote-off
(tracked in compliance n36).

Reference: posthog-js `origin/main` `16e3f63b9` — `_isRecordingEnabled` is the remote `enabled`
flag AND the client flag AND not opted out (`packages/browser/src/extensions/replay/session-recording.ts:139-144`).
That getter is also false while no remote config is persisted, so the browser gate reads the
persisted remote config's `enabled` value and not this getter alone: awaiting the first config
(`AWAITING_CONFIG`, `:102-104`) is not off. Off at load, locally or remotely, leaves no lazy recorder,
and `sdkDebugProperties` returns `{ $recording_status }` (`:497`) next to the session-persisted keys
it reads first (`:489-496`; the key list is `:51-61`). `$sdk_debug_session_start` is emitted only
by the recorder's getter (`lazy-loaded-session-recorder.ts:2822-2836`, key at `:2830`), so it is
absent without a recorder. The required list is `REQUIRED_REPLAY_PROPERTIES`
(`packages/browser/src/posthog-core.ts:193-202`), merged at `:2304-2313`; the queue-depth key is set
outside that block (`:2314`). Sampled-out reports `disabled` (`triggerMatching.ts:780-782`) and a
pending trigger reports `buffering` (`:772-774`), both under
`packages/browser/src/extensions/replay/external/`. posthog-js does **not** yet meet this
requirement mid-session. A local stop runs `startIfEnabledOrStop`, which sets `_recordingStatus`
to `DISABLED` and calls `stopRecording()` (`session-recording.ts:166-169`), and `stopRecording()`
keeps the lazy recorder (`:230-234`). The `status` getter prefers the recorder (`:101-106`), whose
strategies hardcode `isRecordingEnabled: true` (`external/recording-strategies.ts:208`, `:391`), so
the post-stop status and the recorder's keys are wrong. A remote `sessionRecording: false` persists
the config and discards the recording, with no status change (`session-recording.ts:335-339`).
The persisted session keys are also merged when no recorder exists (`:489-496`), so a page reload in
the same session after a remote-off still attaches them.

Covering test: posthog-js `packages/browser/src/__tests__/posthog-core-also.test.ts:835-850`
("returns calculated properties" — with the extension present and not started, a custom event
carries `$recording_status: 'disabled'` and no other replay key); `packages/browser/src/__tests__/extensions/replay/sessionRecording-onRemoteConfig.test.ts:420-426`
(`sessionRecording: false` from the server leaves status `disabled`) and `:428-454` (remote-off after
a cached start discards the recording and persists `enabled: false`, without asserting the status
or the keys); `packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:565`
and `:605-608` (client-disabled config does not load the script and `_isRecordingEnabled` is
false). Planned (posthog-js): a stop and a remote-off on a started recorder, each followed by an
event that carries `$recording_status: disabled` and none of the removal set, and a reload after
remote-off that attaches no persisted replay key. Planned (mobile): one test per scenario in this
requirement.

#### Scenario: Replay off in local config sends only the disabled status (mobile)
- **GIVEN** a mobile SDK whose config does not enable session replay and that has not started it
  manually
- **AND** a session is active
- **WHEN** a custom event is captured
- **AND** an eligible SDK event that the window allows is captured
- **THEN** each event's `$recording_status` is `disabled`
- **AND** neither event includes any `$sdk_debug_replay_*` key, `$sdk_debug_session_start`, or
  `$sdk_debug_recording_script_not_loaded`

#### Scenario: Replay off in local config sends only the disabled status (browser)
- **GIVEN** posthog-js is initialized with `disable_session_recording` set to true
- **AND** the session already holds session-persisted replay debug keys from earlier in the session
- **WHEN** a `$pageview` event is captured
- **THEN** the event's `$recording_status` is `disabled`
- **AND** the event includes none of the persisted replay debug keys, no `$sdk_debug_rrweb_*` key,
  and no `$sdk_debug_session_start`

#### Scenario: An explicit stop mid-session switches the next event to the off shape
- **GIVEN** replay is active and a custom event carried the required keys
- **WHEN** the app stops session replay
- **AND** another custom event is captured
- **THEN** the second event's `$recording_status` is `disabled`
- **AND** it includes none of the removal set, including the trigger status keys and
  `$sdk_debug_replay_internal_buffer_length`
- **AND** this holds on the browser even though its lazy recorder stays loaded after the stop

#### Scenario: Remote config with `sessionRecording: false` switches events to the off shape
- **GIVEN** replay is enabled locally and a cached remote config enabled it
- **WHEN** a fetched remote config arrives with `sessionRecording` set to the boolean `false`
- **AND** the recorder has stopped
- **AND** a custom event is captured
- **THEN** the event's `$recording_status` is `disabled`
- **AND** the event includes none of the removal set

#### Scenario: A quota-limited project is off remotely (mobile)
- **GIVEN** a mobile SDK with replay enabled locally
- **AND** the cached remote config's `quotaLimited` list contains `mobile_recordings`
- **WHEN** a custom event is captured
- **THEN** the event's `$recording_status` is `disabled`
- **AND** the event includes none of the removal set

#### Scenario: An event captured while replay is off does not use up the window
- **GIVEN** replay is enabled locally and remotely and no 30-second window is open
- **AND** the app stops session replay
- **WHEN** an eligible SDK event is captured and accepted
- **AND** the app starts session replay again within 30 seconds
- **AND** another eligible SDK event is captured
- **THEN** the first event's `$recording_status` is `disabled` and it includes none of the removal set
- **AND** the second event carries the optional bundle

#### Scenario: A sampled-out session keeps every key
- **GIVEN** replay is enabled locally and remotely
- **AND** the session was sampled out, so `$recording_status` is `disabled`
- **WHEN** a custom event is captured
- **THEN** the event includes the trigger status keys and `$sdk_debug_replay_internal_buffer_length`
  that the other requirements call for

#### Scenario: A pending linked flag keeps every key
- **GIVEN** replay is enabled locally and remotely
- **AND** a linked flag trigger is configured and has not matched
- **WHEN** a custom event is captured
- **THEN** `$sdk_debug_replay_linked_flag_trigger_status` is `trigger_pending`
- **AND** the event includes the other required keys

#### Scenario: A pending event trigger keeps every key
- **GIVEN** replay is enabled locally and remotely
- **AND** an event trigger is configured and has not matched
- **WHEN** a custom event is captured
- **THEN** `$sdk_debug_replay_event_trigger_status` is `trigger_pending`
- **AND** the event includes the other required keys

#### Scenario: Awaiting the first remote config keeps every key
- **GIVEN** replay is enabled locally
- **AND** the SDK has not yet received any remote config
- **WHEN** an eligible SDK event that the window allows is captured
- **THEN** the event keeps the keys that the replay state produces at that moment, including
  `$sdk_debug_replay_flush_hold_reason` set to `awaiting_remote_config` on mobile
- **AND** the SDK has not treated the missing config as remote-off

#### Scenario: Turning replay on again restores the normal shape
- **GIVEN** replay was stopped and a custom event carried only `$recording_status: disabled`
- **WHEN** the app starts session replay again
- **AND** another custom event is captured
- **THEN** the second event carries the required keys of the current replay state
- **AND** a replay debug key held in session storage is attached again only if it is still valid

#### Scenario: Keys that are not replay diagnostics stay while replay is off
- **GIVEN** replay is intentionally off
- **AND** the queue is backed up, so the SDK attaches the queue-depth key
- **WHEN** a custom event is captured
- **THEN** the event includes the queue-depth key
- **AND** the browser's `$sdk_debug_extensions_init_method` and `$sdk_debug_extensions_init_time_ms`
  are unchanged where the SDK attaches them

#### Scenario: The crash-context snapshot is gated (mobile)
- **GIVEN** replay is intentionally off
- **WHEN** the crash-context snapshot is refreshed
- **THEN** the snapshot includes `$recording_status: disabled`
- **AND** it includes no `$sdk_debug_replay_*` key and no `$sdk_debug_session_start`

#### Scenario: A debug map handed to a wrapper SDK is gated
- **GIVEN** replay is intentionally off
- **WHEN** a wrapper SDK reads the replay debug map through the native SDK's bridge API
- **THEN** the map includes `$recording_status: disabled` and none of the removal set

#### Scenario: Replay diagnostics registered by the SDK do not reach events while replay is off
- **GIVEN** a hybrid SDK registers replay diagnostics as session or super properties
- **AND** replay is intentionally off
- **WHEN** a custom event is captured
- **THEN** the event includes none of those registered keys
