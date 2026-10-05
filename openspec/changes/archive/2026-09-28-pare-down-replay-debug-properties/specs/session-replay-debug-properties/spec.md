## ADDED Requirements

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
Custom events (names not starting with `$`) SHALL NOT carry any key of the optional bundle.
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
`:1959`), so a `before_send` rename does not change it. posthog-js is the only reference for the gate. Mobile SDKs port it, and the two rename cases above
are the mobile contract: the eligibility decision made when the properties are built SHALL
survive `beforeSend`, so a rename in either direction does not change it. posthog-js gets this by
reading the original name directly; a mobile SDK needs its own way to carry the decision across
the hook.

Covering test: posthog-js `packages/browser/src/__tests__/posthog-core-also.test.ts:102` ("keeps
replay diagnosis on every event while throttling optional debug properties" — `custom_event`,
`$feature_flag_called`, and `$$heatmap` get the required keys only; `$pageview` gets the full
bundle). Planned (mobile): one test per scenario in this requirement, including both `beforeSend` rename
scenarios.

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

### Requirement: Attach the optional replay debug bundle at most once every 30 seconds, from acceptance

The SDK SHALL attach the optional bundle to at most one eligible SDK event per 30-second window
per SDK instance. When an eligible event is built and no window is open, the SDK SHALL attach the
full optional bundle; while a window is open, further eligible events SHALL carry none of the
optional bundle's keys (they still carry the required keys).

The window SHALL start when the event that carries the optional bundle is *accepted*: after
`beforeSend` has returned it and the SDK has handed it to its send queue (on mobile, stored in the
queue). Time spent in `beforeSend` SHALL NOT shorten the window. An event that carried the bundle
but was not accepted — dropped by `beforeSend`, suppressed as a duplicate (for example a
deduplicated `$set`), or not stored — SHALL NOT start the window, so the next eligible event
carries the bundle. An event that did not carry the bundle SHALL NOT start or move the window,
including when the interval elapses while it is in `beforeSend`. The window is measured on the
wall clock, not against the event's timestamp: a capture with an explicit past or future
timestamp neither attaches the bundle outside the wall-clock rule nor holds the window shut. The
window is per SDK instance, not per event name or per session. A timer (browser) and a stored
acceptance time compared against the current time (mobile) are both conformant; the spec
constrains only the observable behavior. On mobile the stored acceptance time SHALL be cleared
when the SDK instance is closed, so a re-setup of the shared instance starts with no window open.

A property build that does not represent an event being captured for sending — posthog-js's
`calculateEventProperties` called directly (with or without `readOnly`), or the mobile
crash-context snapshot — SHALL NOT start or move the window. The mobile crash-context snapshot
SHALL always carry the full optional bundle regardless of eligibility or window, because it is
the last known replay state a later-launch crash report is stamped with.

Between building an event with the optional bundle and accepting or releasing it, the SDK SHOULD
hold at most one outstanding claim on the window, so an eligible event captured from inside
`beforeSend` (or concurrently on another thread) while the claim is outstanding does not also
carry the bundle. An SDK that holds such a claim MAY treat a claim older than the 30-second
interval as leaked and let a new event replace it. This is stronger than posthog-js, which sets
its paused flag only after `before_send` returns, so an eligible event captured from inside
`before_send` also carries the bundle there; that is a known posthog-js gap, not a behavior to
copy.

Reference: posthog-js `origin/main` `928990ded` — `REPLAY_DEBUG_PROPERTIES_INTERVAL_MS = 30_000`
(`packages/browser/src/posthog-core.ts:202`), `_replayDebugPropertiesPaused` (`:545`); `capture()`
runs `before_send` and returns on a drop (`:1948-1957`), then sets the paused flag and starts the
30-second timer only for an eligible event when `this.sessionRecording` exists and the flag is
not already set (`:1959-1962`), before the event is handed on (`:1971`); `calculateEventProperties`
reads the flag but never sets it (`:2169`). The mobile-only rules below have no posthog-js analog and are stated here as the contract: the
window starts when the event is accepted into the send queue, measured as a stored acceptance
time against the wall clock; a dropped, deduplicated, or unstored event releases its claim; at
most one claim is outstanding (SHOULD); `close()` clears the window; and the crash-context
snapshot never moves it. posthog-js arms a timer after `before_send` returns, has no
deduplication or close path, and does not hold a claim across `before_send`.

Covering test: posthog-js `packages/browser/src/__tests__/posthog-core-also.test.ts:102` (a
direct `calculateEventProperties(..., readOnly: true)` build carries the bundle without arming;
the next `$pageview` carries it; eligible events inside the window get required keys only; at
+29 999 ms still required-only; at +30 000 ms the bundle returns) and `:188` ("does not consume
the replay diagnostic interval on %s" — property enrichment, `before_send` rejection, and
snapshot capture). Planned (mobile): one test per scenario in this requirement: a burst of eligible events, the 29 s
and 30 s boundaries, a slow `beforeSend`, a `beforeSend` drop, a deduplicated `$set`/`$identify`,
a future-dated capture, a non-capture property build, the crash-context snapshot, a capture
nested in `beforeSend`, and the `close()` reset. posthog-js has no test for the nested
`before_send` case, where it diverges.

#### Scenario: Only the first eligible event in a burst carries the optional bundle
- **GIVEN** the SDK is initialized with an active session
- **WHEN** three eligible SDK events are captured and accepted within one second
- **THEN** every event's properties include `$recording_status`
- **AND** only the first event's properties include `$sdk_debug_session_start`

#### Scenario: The window reopens 30 seconds after the carrying event was accepted
- **GIVEN** an eligible SDK event carrying the optional bundle was accepted at time T
- **WHEN** an eligible SDK event is captured at T + 29 s
- **THEN** it carries `$recording_status` but not `$sdk_debug_session_start`
- **WHEN** an eligible SDK event is captured at T + 30 s
- **THEN** it carries `$sdk_debug_session_start`

#### Scenario: The window starts at acceptance, not at property build
- **GIVEN** a `beforeSend` hook that takes 10 seconds to return an eligible event E
- **AND** E is built with the optional bundle at time T and accepted at T + 10 s
- **WHEN** an eligible SDK event is captured at T + 35 s
- **THEN** it does not carry `$sdk_debug_session_start`
- **WHEN** an eligible SDK event is captured at T + 40 s
- **THEN** it carries `$sdk_debug_session_start`

#### Scenario: An event dropped by beforeSend does not start the window
- **GIVEN** a `beforeSend` hook that drops `$discarded`
- **AND** no window is open
- **WHEN** `$discarded` is captured
- **AND** an eligible SDK event is captured immediately after
- **THEN** the second event carries `$sdk_debug_session_start`

#### Scenario: A deduplicated event does not start the window (mobile)
- **GIVEN** no window is open
- **AND** the person properties of an `$identify`/`$set` event are identical to the last ones sent
- **WHEN** that event is captured and suppressed as a duplicate
- **AND** an eligible SDK event is captured immediately after
- **THEN** the second event carries `$sdk_debug_session_start`

#### Scenario: The window follows the wall clock, not the event timestamp
- **GIVEN** no window is open
- **WHEN** an eligible SDK event with an explicit timestamp one hour in the future is captured and
  accepted
- **AND** 30 seconds of wall-clock time pass
- **AND** another eligible SDK event is captured
- **THEN** both events carry `$sdk_debug_session_start`

#### Scenario: A property build that is not a capture never starts the window
- **GIVEN** no window is open
- **WHEN** properties are built for an SDK event without capturing it (browser), or the
  crash-context snapshot is refreshed (mobile)
- **THEN** the built properties include `$sdk_debug_session_start`
- **AND** the next eligible SDK event captured for sending still carries the optional bundle

#### Scenario: The crash-context snapshot always carries the full bundle (mobile)
- **GIVEN** an eligible SDK event carrying the optional bundle was accepted less than 30 seconds
  ago
- **WHEN** the crash-context snapshot is refreshed (for example by a `register()` call or a
  `$recording_status` transition)
- **THEN** the snapshot includes `$recording_status` and `$sdk_debug_session_start`
- **AND** the snapshot does not include the queue-depth key or
  `$sdk_debug_replay_internal_buffer_length`

#### Scenario: A capture inside beforeSend does not also carry the bundle
- **GIVEN** no window is open
- **AND** a `beforeSend` hook that captures `$inner` while processing `$outer`
- **WHEN** `$outer` is captured
- **THEN** exactly one of `$outer` and `$inner` SHOULD carry `$sdk_debug_session_start`, and it
  is `$outer`

#### Scenario: Closing the SDK instance clears the window (mobile)
- **GIVEN** an eligible SDK event carrying the optional bundle was accepted less than 30 seconds
  ago
- **WHEN** the SDK instance is closed and set up again
- **AND** an eligible SDK event is captured
- **THEN** it carries `$sdk_debug_session_start`

### Requirement: The queue-depth key stays on every non-`$snapshot` event

`$sdk_debug_retry_queue_size` (posthog-js) / `$sdk_debug_pending_queue_size` (mobile) SHALL be
attached to every captured event except `$snapshot` and the minimal `$feature_flag_called`
envelope, whether or not the event is eligible and whether or not a window is open, and whether
or not session replay is configured. It is a point-in-time value and SHALL be stripped from the
mobile crash-context snapshot like the other point-in-time keys. The key-name divergence
(retry-only backlog on the browser vs. combined pending depth on mobile) is unchanged and
specified in the keys requirement.

Reference: posthog-js `origin/main` `928990ded` sets `$sdk_debug_retry_queue_size` outside the
`this.sessionRecording` block (`packages/browser/src/posthog-core.ts:2176`); the minimal envelope
is rebuilt from an allowlist (`:1909-1911`, `packages/core/src/featureFlagUtils.ts:263`).
posthog-ios `origin/main` `88f4b6b56` sets `$sdk_debug_pending_queue_size` from the queue's depth
(`PostHog/PostHogSDK.swift:638-640`) in the shared-properties build (`:714`), so it is on every
non-`$snapshot` event whether or not replay is configured, and lists it in `pointInTimeDebugKeys`
(`:3251-3255`), which `notifyContextDidChange` strips (`:3277-3279`).

Covering test: posthog-js `packages/browser/src/__tests__/posthog-core-also.test.ts:806`
("returns calculated properties" — a custom event carries `$sdk_debug_retry_queue_size: 0`) and
`packages/browser/src/__tests__/__snapshots__/featureflags.test.ts.snap:103` (the full
`$feature_flag_called` envelope carries it). posthog-ios `PostHogTests/PostHogSDKTest.swift:474` ("reports disabled recording status with no
replay keys on non-iOS platforms": the queue-depth key is present, `:486`), `:695` (the minimal
envelope carries no `$sdk_debug_*` key), and
`PostHogTests/PostHogSessionReplayRemoteConfigBufferTest.swift:580` ("crash context re-snapshots on
recording transitions and omits point-in-time counters") at `88f4b6b56`.

#### Scenario: A custom event carries the queue-depth key
- **GIVEN** the SDK is initialized
- **WHEN** a custom event is captured
- **THEN** the event's properties include `$sdk_debug_retry_queue_size` (posthog-js) or
  `$sdk_debug_pending_queue_size` (mobile)

#### Scenario: An eligible event inside the window still carries the queue-depth key
- **GIVEN** an eligible SDK event carrying the optional bundle was accepted less than 30 seconds
  ago
- **WHEN** another eligible SDK event is captured
- **THEN** the event's properties include the queue-depth key
- **AND** they do not include `$sdk_debug_session_start`

### Requirement: `$snapshot` events MAY carry the browser's replay drop counters

An SDK that reports the browser's replay drop counters SHALL attach each one only to the
`$snapshot` events it flushes, and only while its value is greater than zero, as posthog-js does.
The browser recorder keeps four cumulative counts of replay data it dropped:

- `$sdk_debug_replay_unstringifiable_events_dropped`: events dropped because their JSON could not
  be stringified (longer than the engine's maximum string length);
- `$sdk_debug_replay_throttled_mutations_dropped`: attribute mutations dropped by the mutation
  throttler's per-node rate limit;
- `$sdk_debug_replay_oversized_mutations_dropped`: mutation events dropped for exceeding the
  mutation byte budget;
- `$sdk_debug_replay_oversized_mutation_bytes_dropped`: the summed estimated compressed size, in
  bytes, of those oversized mutations.

An SDK that attaches these counters SHALL attach each one only while its value is greater than
zero, never as `0`. Each is cumulative for the current session: it grows until the SDK rotates to a
new session id, and it SHALL reset to zero on that rotation, so the first `$snapshot` event of the
new session carries none of them until something is dropped again. A `$snapshot` event carries
every counter that is currently above zero. The counters are independent of the 30-second window
and of event eligibility: they neither open, hold, nor consume the window, and an open window
does not hide them.

A `$snapshot` event SHALL carry nothing else from this spec: no required key, no optional-bundle
key, and no queue-depth key. The counters SHALL NOT be attached to any other event. They are not
part of the recorder's debug-properties map, so the required/optional merge cannot put them on a
custom or SDK event.

The counters are browser-only as implemented: they count drops in rrweb's mutation pipeline and
in the browser's JSON encoder. iOS has no analog (no `_dropped` counter exists in posthog-ios), so
a mobile `$snapshot` event carries none of them, and a mobile SDK that omits them does not violate
this spec. This spec does not require a mobile SDK to count or attach them. A mobile SDK that later
adds a drop counter of its own starts a new change with its own reference.

Reference: posthog-js `origin/main` `928990ded` (posthog-js#5144, merged as `bd66ceef9`; the
`$snapshot` placement is the PR's last commit, "preserve mutation drop counters on snapshots").
The declaration, increment, reset, and attach sites below (`:531-536`, `:1716`, `:1618-1621`,
`:2388-2401`, `:2954-2967`) are at the same lines on `origin/main` `6538babc7`. Counters declared
in `packages/browser/src/extensions/replay/external/lazy-loaded-session-recorder.ts:531-536`.
Incremented: unstringifiable events in `_captureProcessedEvent` when the event size is
`UNSTRINGIFIABLE_EVENT_SIZE` (`:1715-1719`); throttled attribute mutations through
`onDroppedAttributeMutations` (`:2954`, called at `mutation-throttler.ts:140`); oversized mutations
and their bytes through `onDroppedOversizedMutation` (`:2958-2968`, called at
`mutation-throttler.ts:159` with the estimated event size). Reset: `_restartForSessionIdChange`
zeroes all four (`:1618-1621`), and no other site resets them. Attached: the `$snapshot` flush in
`_flushBuffer` adds each counter with a `> 0` spread guard to the properties of every chunk it
captures (`:2380-2403`), through `_captureSnapshot` (`:2537-2545`). Not part of the debug map:
`sdkDebugProperties` (`:2767-2781`) lists none of them. `calculateEventProperties` returns a
`$snapshot` event's caller-supplied properties without adding any debug key
(`packages/browser/src/posthog-core.ts:2133-2143`), and `isReplayDebugEvent` excludes `$snapshot`
(`:201-204`), so a `$snapshot` neither carries nor arms the window.

Covering test: posthog-js
`packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:4455`
("reports cumulative %s mutation drops only on snapshots and resets on rotation", run for
`attribute` and `oversized`: absent at zero, cumulative values after each drop, the other counters
absent, absent from `sdkDebugProperties`, and absent again on the first `$snapshot` after
`_onSessionIdCallback` rotates the session);
`packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording-compression.test.ts:394`
("counts an event dropped for being too large to stringify") and `:427` ("includes the drop counts
in the encoded surviving snapshot on %s", all four counters on the `$snapshot` sent on
`_onBeforeUnload` and `_onPageHide`). `posthog-core-also.test.ts:102` covers the other side: a
`$snapshot` captured with no counters carries no replay debug key. No test resets the
unstringifiable counter on rotation or checks a counter against an open window; the source covers
both (`:1618-1621`; `:2380-2403` never consults the window). No iOS test applies, since iOS has
no counters.

#### Scenario: Non-zero counters ride on `$snapshot` events and accumulate (browser)
- **GIVEN** posthog-js is recording and the mutation throttler has dropped 3 attribute mutations
  in the current session
- **AND** no other drop counter is above zero
- **WHEN** a `$snapshot` event is flushed
- **THEN** its properties include `$sdk_debug_replay_throttled_mutations_dropped` with value 3
- **AND** they include none of the other three counters
- **WHEN** 3 more attribute mutations are dropped and the next `$snapshot` event is flushed
- **THEN** its `$sdk_debug_replay_throttled_mutations_dropped` is 6

#### Scenario: A zero counter is omitted (browser)
- **GIVEN** posthog-js is recording and an oversized mutation of 2048 estimated bytes has been
  dropped in the current session
- **AND** no event was dropped for being unstringifiable and no attribute mutation was throttled
- **WHEN** a `$snapshot` event is flushed
- **THEN** its properties include `$sdk_debug_replay_oversized_mutations_dropped` with value 1 and
  `$sdk_debug_replay_oversized_mutation_bytes_dropped` with value 2048
- **AND** they include neither `$sdk_debug_replay_unstringifiable_events_dropped` nor
  `$sdk_debug_replay_throttled_mutations_dropped`, not even with value 0

#### Scenario: Counters reset on session rotation (browser)
- **GIVEN** posthog-js is recording and at least one drop counter is above zero
- **WHEN** the session rotates to a new session id
- **AND** the next `$snapshot` event is flushed
- **THEN** its properties include none of the four drop counters

#### Scenario: Counters ignore the 30-second window and carry nothing else (browser)
- **GIVEN** an eligible SDK event carrying the optional bundle was accepted 5 seconds ago
- **AND** an oversized mutation has been dropped in the current session
- **WHEN** a `$snapshot` event is flushed
- **THEN** its properties include `$sdk_debug_replay_oversized_mutations_dropped`
- **AND** they include no required key, no optional-bundle key, and no queue-depth key
- **AND** the flush does not change when the window reopens

#### Scenario: Counters never ride on other events (browser)
- **GIVEN** posthog-js is recording and a drop counter is above zero
- **WHEN** a custom event, an eligible SDK event the window allows, and a `$feature_flag_called`
  event are captured
- **THEN** none of them includes any of the four drop counters

#### Scenario: A mobile `$snapshot` event carries no drop counters
- **GIVEN** a mobile SDK recording session replay
- **WHEN** a `$snapshot` event is captured
- **THEN** its properties include none of the four drop counters
- **AND** that absence is not a violation of this spec

## MODIFIED Requirements

### Requirement: Attach debug properties to every captured event except `$snapshot`

The replay debug properties SHALL come in two tiers. The *required keys* are the ones the recording
buttons and the replay capture diagnostics read from individual events:

- on every platform: `$recording_status`, `$sdk_debug_replay_event_trigger_status`,
  `$sdk_debug_replay_linked_flag_trigger_status`, and `$sdk_debug_replay_internal_buffer_length`;
- on the browser only, additionally: `$sdk_debug_recording_script_not_loaded`,
  `$sdk_debug_replay_url_trigger_status`, `$sdk_debug_replay_rrweb_error`, and
  `$sdk_debug_replay_flushed_size`.

Every other replay debug key belongs to the *optional replay debug bundle*, which is gated and
throttled by the two requirements that follow; the queue-depth key belongs to neither tier and has
its own requirement.

The SDK SHALL attach each required key that is available to every captured event **except**
`$snapshot`: custom events, `$feature_flag_called`, `$$heatmap`, and eligible SDK events inside a
throttle window all carry them. A required key is *available* when the SDK's current replay state
produces a value for it: a mobile SDK without a replay integration produces only
`$recording_status: disabled` (see "Attach the disabled shape when replay is not configured"),
and posthog-js without the session-recording extension produces none. `$snapshot` events (the
replay payload itself) SHALL carry neither the required keys, the optional bundle, nor the
queue-depth key — they are already replay data, not a report about replay. The only replay debug
keys a `$snapshot` event MAY carry are the browser's four drop counters (see "`$snapshot` events
MAY carry the browser's replay drop counters"). When the outgoing event is the minimal
`$feature_flag_called` envelope (the allowlisted properties sent when the call is gated and the
flag has no experiment), the SDK SHALL strip `$recording_status` and every `$sdk_debug_*` key
along with everything else not on that allowlist; the full `$feature_flag_called` envelope carries
the required keys like any other event.

Reference: posthog-js `origin/main` `928990ded` (posthog-js#5144) — `REQUIRED_REPLAY_PROPERTIES`
(`packages/browser/src/posthog-core.ts:190-200`); `calculateEventProperties` copies a key when
it is required or the optional bundle is allowed (`:2166-2175`), after the `$snapshot` early
return (`:2133`); `$snapshot` is also listed in `EVENTS_WITHOUT_REPLAY_DEBUG_PROPERTIES` (`:201`).
The minimal envelope is rebuilt from an explicit allowlist by `minimizeFlagCalledEventProperties`
(`packages/core/src/featureFlagUtils.ts:263`, applied at `posthog-core.ts:1909-1911`).
Mobile SDKs port the required-key split from this requirement; posthog-js is its only reference.
Two behaviors it keeps are already in posthog-ios `origin/main` `88f4b6b56`: `$snapshot` is built with
`appendSharedProps: !isSnapshotEvent` (`PostHog/PostHogSDK.swift:1552`), so it never reaches the
debug-key block (`:666`, `:695-714`), and the minimal envelope is filtered to its allowlist
(`:1561-1562`, applied at `:2612-2617`).

Covering test: posthog-js `packages/browser/src/__tests__/posthog-core-also.test.ts:102` (the
eight required keys on `custom_event`, `$feature_flag_called`, `$$heatmap`, and on in-window
`$exception`, `$identify`, `$set`, `$pageview`, `$autocapture`; `$snapshot` carries none) and
`:806` ("returns calculated properties" — a custom event carries `$recording_status: 'disabled'`);
`packages/browser/src/__tests__/__snapshots__/featureflags.test.ts.snap:72` (minimal envelope,
no debug keys) and `:103` (full envelope, `$recording_status: "disabled"` at `:145`).
posthog-ios `PostHogTests/PostHogSDKTest.swift:407` ("excludes $recording_status and $sdk_debug_*
properties from $snapshot events"), `:695` ("sends minimal feature flag event when gated and flag
has no experiment": no debug key, `:732-733`) and `:783` ("sends full feature flag event when gated
but flag has an experiment": `$recording_status` present, `:800`) at `88f4b6b56`. Planned (mobile): a
custom event and an in-window eligible event from an installed replay integration carry exactly
the four required keys.

#### Scenario: Custom event carries debug properties
- **GIVEN** the SDK is initialized
- **WHEN** a custom event is captured
- **THEN** the captured event's properties include `$recording_status`

#### Scenario: Required keys come from an installed replay integration (mobile)
- **GIVEN** a mobile SDK with its replay integration installed and buffering one snapshot
- **WHEN** a custom event is captured
- **THEN** the event's properties include `$recording_status`,
  `$sdk_debug_replay_event_trigger_status`, `$sdk_debug_replay_linked_flag_trigger_status`, and
  `$sdk_debug_replay_internal_buffer_length`

#### Scenario: Snapshot event carries none of the debug properties when nothing was dropped
- **GIVEN** the SDK is initialized with session replay active
- **AND** no replay drop counter is above zero (always the case on mobile)
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

`$recording_status` is a required key, so the value is observable on every non-`$snapshot` event
except the minimal `$feature_flag_called` envelope, and, on mobile, on the crash-context
snapshot.

Reference: the full value set is `sessionRecordingStatuses`
(`packages/browser/src/extensions/replay/external/triggerMatching.ts:85-96` at posthog-js
`origin/main` `928990ded`); the mobile three-value mapping is
`PostHog/Replay/PostHogReplayIntegration.swift:1918-1920` at posthog-ios `origin/main` `88f4b6b56`.

Covering test: no covering test in posthog-js for the mobile subset (mobile has no browser
analog to test). posthog-ios `PostHogTests/PostHogSessionReplayRemoteConfigBufferTest.swift:486` ("holding for
remote config or minimum duration reports buffering with a hold reason, then active once
resolved") at `88f4b6b56`; Android's equivalent (`PostHogReplayIntegrationTest.kt` "buffering to
active") is not yet in the repo.

#### Scenario: Replay not configured reports disabled
- **GIVEN** a mobile SDK is initialized without session replay configured
- **WHEN** any event other than `$snapshot` is captured
- **THEN** the event's `$recording_status` is `disabled`

#### Scenario: Holding for remote config or minimum duration reports buffering
- **GIVEN** the replay integration is installed and enabled
- **AND** it is awaiting its first remote config, or the session has not yet passed the
  minimum duration
- **WHEN** any event other than `$snapshot` is captured
- **THEN** the event's `$recording_status` is `buffering`

#### Scenario: Neither holding nor disabled reports active
- **GIVEN** the replay integration is installed, enabled, has received remote config, and the
  session has passed the minimum duration
- **WHEN** any event other than `$snapshot` is captured
- **THEN** the event's `$recording_status` is `active`

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

SDK-computed `$recording_status` and `$sdk_debug_*` values SHALL take precedence over a
caller-supplied event property or a registered super property of the same name; the merge writes
the debug map last.

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
session manager's start snapshot (`PostHog/PostHogSDK.swift:633-635`); the debug map merged so it
overrides a same-named property (`:705`, `:714`, `{ _, new in new }`). The required/optional tiers,
the two removed keys, and the capture-mode classification are the contract mobile SDKs port; no
mobile code is cited for them.

Covering test: posthog-js `packages/browser/src/__tests__/posthog-core-also.test.ts:102` (the
required/optional split, including the trigger statuses on every event and
`$sdk_debug_replay_pending_trigger_conditions` / `$sdk_debug_session_start` only on
bundle-carrying events). posthog-ios `PostHogTests/PostHogSDKTest.swift:441` ("reports screenshot capture mode for the
flutter host"), `:457` ("SDK-computed debug keys win over a same-named registered super
property"), and `PostHogTests/PostHogSessionReplayEventTriggersTest.swift:235` ("trigger status
reflects pending state before either trigger resolves, then activation as each fires") at
`88f4b6b56`. Planned (mobile): the required/optional split on a custom event, and the `wireframe`
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

#### Scenario: Debug values win over same-named caller or registered properties
- **GIVEN** a super property or a caller-supplied event property named `$recording_status`
- **WHEN** any event other than `$snapshot` is captured
- **THEN** the event's `$recording_status` is the SDK-computed value, not the supplied one

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

### Requirement: `$sdk_debug_error_capturing_properties` is attached only on a build failure

`$sdk_debug_error_capturing_properties` SHALL be attached to a captured event, carrying the
stringified error, if and only if building the `$recording_status` / `$sdk_debug_*` debug map
throws. On a successful build, the key SHALL be absent.

Reference: posthog-js wraps the debug-map build in a try/catch and sets this key only in the
catch branch, `packages/browser/src/posthog-core.ts:2177-2178` at posthog-js `origin/main`
`928990ded`.

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

`$exception`, `$identify`, and `$set` events are eligible SDK events. They SHALL carry the
available required keys, including `$recording_status`, on every capture, and SHALL carry the
optional bundle whenever the 30-second window allows, exactly like `$screen` or `$pageview`. They
are not special-cased like `$snapshot` or `$feature_flag_called`; this requirement exists because
`$exception` was the original OOM-investigation trigger for this spec and `$identify`/`$set` are
commonly assumed (incorrectly) to be special-cased. Because `$recording_status` is required, a
crash-time `$exception` captured in the current process carries the replay state at capture
time even inside a window; for a crash reported on a later launch, the crash-context snapshot
supplies it (the "Debug keys describe the SDK state when the event occurred" requirement).

Reference: posthog-js `origin/main` `928990ded` — `isReplayDebugEvent` accepts any `$`-prefixed
name not in `EVENTS_WITHOUT_REPLAY_DEBUG_PROPERTIES` (`packages/browser/src/posthog-core.ts:201-204`),
so `$exception`, `$identify`, and `$set` qualify, and the required keys are copied regardless
(`:2166-2175`). Mobile SDKs port the same gate and the same required-key copy for every capture path, including
`$identify`, `$screen`, `$create_alias`, and `$groupidentify`.

Covering test: posthog-js `packages/browser/src/__tests__/posthog-core-also.test.ts:102` (inside
a window, `$exception`, `$identify`, and `$set` carry exactly the required keys; after the window
`$autocapture` carries the bundle and the following `$exception` the required keys only).
Planned (mobile): `$exception`, `$identify`, and `$set` inside a window carry the required keys
and not the optional bundle.

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

#### Scenario: An exception inside the window carries the required keys only
- **GIVEN** a `$screen` event carrying the optional bundle was accepted 5 seconds ago
- **WHEN** an `$exception` event is captured
- **THEN** the captured event's properties include `$recording_status`
- **AND** they do not include `$sdk_debug_session_start`

### Requirement: Attach the disabled shape when replay is not configured

A mobile SDK SHALL attach `$recording_status: disabled` to every captured event except
`$snapshot` and the minimal `$feature_flag_called` envelope even when session replay is not
configured at all (no replay integration installed, or the platform module that provides it is
absent) — an event captured under these conditions is exactly the case the OOM investigation
that motivated this spec needed to distinguish from an active or buffering replay. In that state
`$recording_status` is the only required key available: the trigger statuses and
`$sdk_debug_replay_internal_buffer_length` come from the integration and are absent. The optional
fallback bundle, attached only to an eligible SDK event the window allows, is
`$sdk_debug_replay_capture_mode` when the platform ships the replay module and
`$sdk_debug_session_start` when a session start is available; where the replay module itself is
entirely absent (posthog-ios on macOS, tvOS, watchOS, visionOS), the capture-mode key is absent
too.

This is a deliberate mobile divergence from posthog-js. The browser attaches no replay debug key
when the session-recording extension is not instantiated — `calculateEventProperties` requires
`this.sessionRecording` before merging, so a browser build without session recording (or in
cookieless mode, where the extension is never created) carries no `$recording_status` at all.
When the extension exists but the lazy recorder has not loaded, the browser attaches
`{ $recording_status: <extension status> }` plus the session-persisted replay debug keys, each
tier filtered as usual.

Reference: posthog-js `origin/main` `928990ded` — `if (this.sessionRecording)` guards the merge
(`packages/browser/src/posthog-core.ts:2166-2175`); the pre-load fallback is
`SessionRecording.sdkDebugProperties`
(`packages/browser/src/extensions/replay/session-recording.ts:487-499`, the
`{ $recording_status: this.status }` arm at `:497`); the extension is created only when
`ext.sessionRecording && !startInCookielessMode` (`posthog-core.ts:1180`). posthog-ios `origin/main` `88f4b6b56` — the no-integration fallback sets `$recording_status:
disabled` and `$sdk_debug_replay_capture_mode` on iOS and only `$recording_status: disabled` on
other Apple platforms (`PostHog/PostHogSDK.swift:703-713`); `$sdk_debug_session_start` comes from
the session manager (`:633-635`, merged at `:714`). Splitting that fallback into required and
optional keys is the contract mobile SDKs port.

Covering test: posthog-js `packages/browser/src/__tests__/posthog-core-also.test.ts:806`
("returns calculated properties" — the extension is present but not started, so a custom event
carries `$recording_status: 'disabled'`); no posthog-js test asserts the no-extension case.
posthog-ios `PostHogTests/PostHogSDKTest.swift:474` ("reports disabled recording status with no
replay keys on non-iOS platforms") at `88f4b6b56`. Planned (mobile): with no integration installed, a
custom event carries `$recording_status: disabled` only, and an eligible event the window allows
adds capture mode and session start. Android's `PostHogTest.kt` "with no handler" is not yet in
the repo.

#### Scenario: No replay integration installed still reports disabled
- **GIVEN** a mobile SDK is initialized with no session replay integration installed
- **WHEN** a custom event is captured
- **THEN** the event's `$recording_status` is `disabled`
- **AND** the event's properties include neither `$sdk_debug_replay_capture_mode` nor
  `$sdk_debug_session_start`

#### Scenario: No replay integration installed adds the fallback bundle to an eligible event (mobile)
- **GIVEN** a mobile SDK is initialized with no session replay integration installed
- **AND** no accepted event in the last 30 seconds carried the optional bundle
- **WHEN** a `$screen` event is captured
- **THEN** the event's `$recording_status` is `disabled`
- **AND** the event's properties include `$sdk_debug_session_start`
- **AND** the event's properties include `$sdk_debug_replay_capture_mode` if the platform ships
  the replay module

#### Scenario: No session-recording extension attaches nothing (browser)
- **GIVEN** posthog-js is initialized without the session-recording extension (not bundled, or
  cookieless mode)
- **WHEN** a `$pageview` event is captured
- **THEN** the event's properties include neither `$recording_status` nor any
  `$sdk_debug_replay_*` key
- **AND** the event's properties include `$sdk_debug_retry_queue_size`

### Requirement: Stop and uninstall reset the reported state and clear any stale hold reason

The SDK SHALL report `$recording_status: disabled` on events captured after session replay is
stopped (an explicit `stopSessionRecording()`-equivalent call) or the replay integration is
uninstalled, and SHALL NOT attach `$sdk_debug_replay_flush_hold_reason` on bundle-carrying events
captured after either, even if a hold reason was present immediately before the stop/uninstall.
A getter or property-attach path that runs after teardown but still surfaces a pre-teardown hold
reason is a bug this requirement exists to rule out. On mobile the crash-context snapshot is
refreshed on the same transition, so the crash reporter's copy is reset too.

Reference: posthog-js clears the hold reason on stop,
`packages/browser/src/extensions/replay/external/lazy-loaded-session-recorder.ts:1522-1523` at
posthog-js `origin/main` `928990ded`. posthog-ios `origin/main` `88f4b6b56` computes the hold reason fresh on every `debugProperties()`
call (`PostHog/Replay/PostHogReplayIntegration.swift:1899-1923`).

Covering test: `lazy-sessionrecording.test.ts` replay-stop tests (posthog-js's fix for the
staleness this requirement generalizes). posthog-ios `PostHogTests/PostHogSessionReplayRemoteConfigBufferTest.swift:512` ("stopping
recording reports disabled and clears the hold reason") and `:536` ("uninstalling the replay
integration reports disabled and clears the hold reason"), both also asserting
`$sdk_debug_replay_capture_mode` remains present (`:532`, `:555`), at `88f4b6b56`; Android's
`PostHogReplayIntegrationTest.kt` "stopped integration" is not yet in the repo.

#### Scenario: Stopping recording clears the hold reason
- **GIVEN** the replay integration is buffering with a hold reason present
- **WHEN** recording is stopped
- **AND** an eligible SDK event that the window allows is captured
- **THEN** the event's `$recording_status` is `disabled`
- **AND** `$sdk_debug_replay_flush_hold_reason` is absent

#### Scenario: Uninstalling the integration clears the hold reason
- **GIVEN** the replay integration is buffering with a hold reason present
- **WHEN** the replay integration is uninstalled
- **AND** an eligible SDK event that the window allows is captured
- **THEN** the event's `$recording_status` is `disabled`
- **AND** `$sdk_debug_replay_flush_hold_reason` is absent

#### Scenario: Config-derived keys remain present after stop/uninstall while status is disabled
- **GIVEN** the replay integration was active with `$sdk_debug_replay_capture_mode` present
- **WHEN** recording is stopped, or the replay integration is uninstalled
- **AND** an eligible SDK event that the window allows is captured
- **THEN** the event's `$recording_status` is `disabled`
- **AND** `$sdk_debug_replay_capture_mode` remains present, because it derives from the
  platform config module rather than from integration install/active state

### Requirement: Debug keys describe the SDK state when the event occurred

`$recording_status` and every `$sdk_debug_*` key SHALL describe the SDK's state at the moment
the event occurred — for an ordinary event, the moment of capture. An event captured with an
explicit timestamp that precedes the current session's start did not occur in this session; the
canonical case is an `$exception` reported on a later launch for a crash in a previous process
(Android's NDK tombstone path in `PostHogNativeCrashIntegration`, iOS's PLCrashReporter reports).
For such an event the SDK SHALL attach the state it persisted at the time the event occurred if
the platform captured one (iOS mirrors the debug map into the crash reporter's `customData`
through `onEventContextChanged`), and otherwise SHALL attach none of these keys. It MUST NOT
attach the current process's live state to an event from a previous process; this rule takes
precedence over the every-event rule for required keys.

The persisted crash-context snapshot is a property build that is not a capture: it SHALL always
carry the full optional bundle, SHALL never start or move the 30-second window, and SHALL be
refreshed on every `$recording_status` transition so it is the last known replay state at crash
time. Point-in-time keys that would be stale by the next launch (the queue-depth key,
`$sdk_debug_replay_internal_buffer_length`) SHALL be stripped from it.

An explicit timestamp that falls inside the current session (a backdated capture) keeps the
required keys, and the optional bundle when the window allows: the state at capture is still the
state of the session the event belongs to. The window is measured on the wall clock, so the
event's own timestamp neither opens nor holds it (the 30-second requirement above).

Reference: no posthog-js analog — a browser page does not report previous-process crashes. The
principle is posthog-js's own, though: `calculateEventProperties` resolves the session against
the event's timestamp rather than "now" (`timestamp.getTime()` passed into
`checkAndGetSessionAndWindowId`, `packages/browser/src/posthog-core.ts:2153-2159` at posthog-js
`origin/main` `928990ded`). posthog-ios `origin/main` `88f4b6b56` resolves the session against `eventTime = timestamp ?? now()`
(`PostHog/PostHogSDK.swift:660-663`); the crash-context snapshot is `notifyContextDidChange`
(`:3262-3290`: `readOnlySession: true`, `pointInTimeDebugKeys` stripped), and the replay
integration refreshes it whenever `$recording_status` can change
(`PostHog/Replay/PostHogReplayIntegration.swift:373`). The rules that the snapshot always carries
the full optional bundle and never starts or moves the window, and that the window runs on the
wall clock, are the mobile contract; posthog-js has no analog.

Covering test: posthog-ios `PostHogTests/PostHogSessionReplayRemoteConfigBufferTest.swift:580`
("crash context re-snapshots on recording transitions and omits point-in-time counters") at
`88f4b6b56`; iOS's crash-report decode path in `PostHogErrorTrackingAutoCaptureIntegration` (the
`customData` branch, `PostHog/ErrorTracking/PostHogErrorTrackingAutoCaptureIntegration.swift:255-259`)
covers the persisted-snapshot arm. Planned (mobile): the crash-context snapshot always carries
the bundle and never arms the window, and a far-future eligible capture does not suppress the
bundle once the wall clock catches up. Planned — `PostHogTest.kt` "a previous-run exception
carries none of the debug keys" and "a backdated event within the current session keeps the debug
keys" on Android.

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
- **AND** the mirrored map includes `$recording_status` and `$sdk_debug_session_start` but not
  the queue-depth key

#### Scenario: A backdated event within the current session keeps the keys
- **GIVEN** the current session started at T
- **AND** no window is open
- **WHEN** an eligible SDK event is captured with an explicit timestamp later than T
- **THEN** the event carries `$recording_status` and the applicable optional `$sdk_debug_*` keys

### Requirement: Out of scope for this capability

This spec SHALL NOT be read as requiring: browser-only keys with no mobile analog (e.g. anything
the browser recorder emits that mobile has no equivalent concept for, including the browser's own
interaction-hold `flush_hold_reason` values, and their presence while `$recording_status` reads
`active`, used for the idle-rotation/fresh-start withholding behavior specified separately in
`session-replay-ingestion-controls`); the browser-only required keys
`$sdk_debug_recording_script_not_loaded`, `$sdk_debug_replay_url_trigger_status` (mobile has no
URL-trigger concept), `$sdk_debug_replay_rrweb_error`, and `$sdk_debug_replay_flushed_size`; the
browser-only optional keys `$sdk_debug_replay_stale_config`,
`$sdk_debug_replay_matched_recording_trigger_groups`,
`$sdk_debug_replay_remote_trigger_matching_config`, `$sdk_debug_replay_trigger_groups_count`,
`$sdk_debug_replay_internal_buffer_size`, `$sdk_debug_rrweb_attached`, and
`$sdk_debug_rrweb_start_attempted` (`packages/browser/src/posthog-core.ts:190-200`,
`session-recording.ts:51-61`, `lazy-loaded-session-recorder.ts:2767-2781` at posthog-js
`origin/main` `928990ded`); the browser-only `$sdk_debug_extensions_init_method` /
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
  `$sdk_debug_replay_stale_config`, `$sdk_debug_replay_matched_recording_trigger_groups`,
  `$sdk_debug_replay_remote_trigger_matching_config`, `$sdk_debug_replay_trigger_groups_count`,
  `$sdk_debug_replay_internal_buffer_size`, `$sdk_debug_rrweb_attached`,
  `$sdk_debug_rrweb_start_attempted`, `$sdk_debug_extensions_init_method`, or
  `$sdk_debug_extensions_init_time_ms` on a mobile event is not a violation of this spec

#### Scenario: Removed keys are not required by this spec
- **GIVEN** an SDK conforming to this spec
- **WHEN** it attaches replay debug keys to a captured event
- **THEN** the absence of any rrweb performance counter key removed by posthog-js#5144, of
  `$sdk_debug_current_session_duration`, or of `$sdk_debug_replay_throttle_delay_ms` is not a
  violation of this spec
