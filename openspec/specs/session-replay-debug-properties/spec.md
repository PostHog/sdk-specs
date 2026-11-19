# Session Replay Debug Properties Specification

## Purpose

`session-replay-debug-properties` is the per-event debug snapshot of the session replay
subsystem: the `$recording_status` property and the `$sdk_debug_*` keys an SDK attaches
automatically to captured events. The keys come in two tiers. A short list of required keys
goes on every event except `$snapshot`, so any event says whether replay was disabled,
buffering, or active when it was captured. Everything else is an optional bundle that goes only
on SDK events (names starting with `$`, excluding `$feature_flag_called`, `$snapshot`, and the
browser's `$$heatmap`), at most once every 30 seconds per SDK instance. One queue-depth key sits
outside both tiers and stays on every non-`$snapshot` event. `$snapshot` events carry none of
these keys; the one exception is four cumulative replay drop counters that the browser attaches
to `$snapshot` while they are above zero. On mobile a crash-time `$exception` reported on a later
launch is stamped from a crash-context snapshot that carries the full bundle while replay is not
intentionally off. While replay is intentionally off (off in local config, explicitly stopped,
opted out, or off in the cached remote config), an event carries at most `$recording_status: disabled`
and no other replay diagnostic key.

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
produces a value for it: a mobile SDK without a replay integration produces only `$recording_status: disabled` (see "Attach the disabled shape when replay is not configured"),
posthog-js without the session-recording extension produces none, and an SDK whose replay is
intentionally off produces only `$recording_status: disabled` (see "Attach only the disabled shape while replay is intentionally off").
While replay is intentionally off, no required key other than `$recording_status` is attached:
the trigger statuses, `$sdk_debug_replay_internal_buffer_length`, and the browser-only required
keys are all withheld. `$snapshot` events (the
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
The off-state exception is posthog-js at `origin/main` `16e3f63b9`: the required list is
`packages/browser/src/posthog-core.ts:193-202` and the merge `:2304-2313`; with no lazy recorder,
`sdkDebugProperties` supplies only `{ $recording_status }` next to the session-persisted keys
(`packages/browser/src/extensions/replay/session-recording.ts:487-499`). posthog-js does not yet
meet the exception after a mid-session stop or remote-off (tracked in compliance n36). The minimal envelope is rebuilt from an explicit allowlist by `minimizeFlagCalledEventProperties`
(`packages/core/src/featureFlagUtils.ts:263`, applied at `posthog-core.ts:1909-1911`).
Mobile SDKs port the required-key split from this requirement; posthog-js is its only reference.
Two behaviors it keeps are already in posthog-ios `origin/main` `88f4b6b56`: `$snapshot` is built with
`appendSharedProps: !isSnapshotEvent` (`PostHog/PostHogSDK.swift:1552`), so it never reaches the
debug-key block (`:666`, `:695-714`), and the minimal envelope is filtered to its allowlist
(`:1561-1562`, applied at `:2612-2617`).

Covering test: posthog-js `packages/browser/src/__tests__/posthog-core-also.test.ts:102` (the
eight required keys on `custom_event`, `$feature_flag_called`, `$$heatmap`, and on in-window
`$exception`, `$identify`, `$set`, `$pageview`, `$autocapture`; `$snapshot` carries none) and
`:806` ("returns calculated properties" — a custom event carries `$recording_status: 'disabled'`; at `16e3f63b9` the test is `:835-850` and also shows no other replay key while the recorder is not started);
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
- **GIVEN** a mobile SDK with its replay integration installed, replay not intentionally off, and
  buffering one snapshot
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

#### Scenario: Required keys other than the status are withheld while replay is intentionally off
- **GIVEN** replay is intentionally off
- **WHEN** a custom event is captured
- **THEN** the captured event's properties include `$recording_status: disabled`
- **AND** they include none of the trigger status keys and no
  `$sdk_debug_replay_internal_buffer_length`

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
including when the interval elapses while it is in `beforeSend`. An eligible event captured while
replay is intentionally off carries no bundle, so it SHALL NOT claim, start, or move the window,
and the first eligible event after replay is turned back on carries the bundle. posthog-js claims
the window for such an event whenever its recording extension is installed (`origin/main`
`04b89402b` `packages/browser/src/posthog-core.ts:2090-2093`); that is a known posthog-js gap, not
a behavior to copy. The window is measured on the
wall clock, not against the event's timestamp: a capture with an explicit past or future
timestamp neither attaches the bundle outside the wall-clock rule nor holds the window shut. The
window is per SDK instance, not per event name or per session. A timer (browser) and a stored
acceptance time compared against the current time (mobile) are both conformant; the spec
constrains only the observable behavior. On mobile the stored acceptance time SHALL be cleared
when the SDK instance is closed, so a re-setup of the shared instance starts with no window open.

A property build that does not represent an event being captured for sending — posthog-js's
`calculateEventProperties` called directly (with or without `readOnly`), or the mobile
crash-context snapshot — SHALL NOT start or move the window. The mobile crash-context snapshot
SHALL carry the full optional bundle regardless of eligibility or window while replay is not
intentionally off, because it is the last known replay state a later-launch crash report is
stamped with. While replay is intentionally off it carries only `$recording_status: disabled`
(see "Attach only the disabled shape while replay is intentionally off").

Between building an event with the optional bundle and accepting or releasing it, the SDK SHOULD
hold at most one outstanding claim on the window, so an eligible event captured from inside
`beforeSend` (or concurrently on another thread) while the claim is outstanding does not also
carry the bundle. An SDK that holds such a claim SHALL NOT expire it by age: a capture that
spends longer than the 30-second interval inside `beforeSend` still holds its claim, because it
already carries the bundle. Every path out of a claiming capture SHALL either start the window
(the event is accepted) or release the claim (the event is dropped, deduplicated, or not stored),
and closing the SDK instance SHALL clear it. This is stronger than posthog-js, which sets
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
a future-dated capture, a non-capture property build, the crash-context snapshot (with replay on, and with replay off), a capture
nested in `beforeSend`, a nested capture after `beforeSend` has outlasted the interval, and the
`close()` reset. posthog-js has no test for the nested
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

#### Scenario: The crash-context snapshot always carries the full bundle while replay is on (mobile)
- **GIVEN** replay is not intentionally off
- **AND** an eligible SDK event carrying the optional bundle was accepted less than 30 seconds
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

#### Scenario: An outstanding claim does not expire while beforeSend runs
- **GIVEN** an SDK that holds one outstanding claim on the window
- **AND** no window is open
- **AND** a `beforeSend` hook that, while processing `$slow`, lets more than 30 seconds of
  wall-clock time pass and then captures `$inner`
- **WHEN** `$slow` is captured and accepted
- **THEN** `$slow` carries `$sdk_debug_session_start`
- **AND** `$inner` does not carry `$sdk_debug_session_start`

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
- **AND** no accepted event in the last 30 seconds carried the optional bundle
- **WHEN** an eligible SDK event is captured
- **THEN** the event's properties include `$sdk_debug_session_start` and
  `$sdk_debug_retry_queue_size`
- **AND** the event's properties do NOT include `$sdk_debug_current_session_duration`

#### Scenario: Session and queue keys are present when a session exists (mobile)
- **GIVEN** a mobile SDK is initialized with session replay enabled and an active session
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
- **AND** the event's properties include `$sdk_debug_pending_queue_size`
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

This requirement applies only where the debug-map build can fail. An SDK whose build cannot
throw (the posthog-ios build is a non-throwing function) never attaches the key, and that is
conformant: the build-failure scenario below does not apply to it, and the SDK is not required
to add a failure path in order to emit the key.

Reference: posthog-js wraps the debug-map build in a try/catch and sets this key only in the
catch branch, `packages/browser/src/posthog-core.ts:2177-2178` at posthog-js `origin/main`
`928990ded`.

Covering test: no dedicated posthog-js test forces the debug-map build to throw — planned test
(repo plan row: native "error path" case), not yet in the repo, for each SDK whose build can
throw.

#### Scenario: A build failure attaches the stringified error and nothing else from the debug map
- **GIVEN** an SDK whose debug properties map build can throw
- **AND** building the debug properties map throws an error
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
`$recording_status` is the only replay key the SDK attaches: the trigger statuses and
`$sdk_debug_replay_internal_buffer_length` come from the integration and are absent, and so are
`$sdk_debug_replay_capture_mode` and `$sdk_debug_session_start`. There is no fallback optional
bundle. An eligible SDK event carries the same single replay key as a custom event, plus the
queue-depth key that every event carries. This is the not-configured case of "Attach only the
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
- **AND** the event's properties include `$sdk_debug_pending_queue_size`

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
uninstalled, and SHALL NOT attach any `$sdk_debug_replay_*` key, `$sdk_debug_session_start`, or other key of
the removal set in "Attach only the disabled shape while replay is intentionally off" on events captured after either, even if a hold reason
was present immediately before the stop/uninstall. An explicit stop and an uninstall both turn
replay off locally, so that requirement governs which keys remain. A getter or property-attach
path that runs after teardown but still surfaces a pre-teardown hold reason, or any other replay
key, is a bug this requirement exists to rule out. On mobile the crash-context snapshot is
refreshed on the same transition, so the crash reporter's copy is reset too.

On the browser the lazy recorder stays loaded after a stop, so this requirement also covers the
status: `$recording_status` SHALL read `disabled` after the stop, and the recorder's own keys SHALL
NOT be attached. posthog-js does not yet meet this (tracked in compliance n36).

Reference: posthog-js clears the hold reason on stop,
`packages/browser/src/extensions/replay/external/lazy-loaded-session-recorder.ts:1522-1523` at
posthog-js `origin/main` `928990ded`. posthog-ios `origin/main` `88f4b6b56` computes the hold reason fresh on every `debugProperties()`
call (`PostHog/Replay/PostHogReplayIntegration.swift:1899-1923`).

At posthog-js `origin/main` `16e3f63b9`, `stopRecording()` keeps the recorder
(`packages/browser/src/extensions/replay/session-recording.ts:230-234`) and the `status` getter
prefers it over `_recordingStatus` (`:101-106`), so the status is wrong after a stop and the full
recorder key set (`lazy-loaded-session-recorder.ts:2822-2836`) still goes out.

Covering test: `lazy-sessionrecording.test.ts` replay-stop tests (posthog-js's fix for the
staleness this requirement generalizes; none asserts `$recording_status` or the other keys after a
stop, so a posthog-js test is planned). posthog-ios `PostHogTests/PostHogSessionReplayRemoteConfigBufferTest.swift:512` ("stopping
recording reports disabled and clears the hold reason") and `:536` ("uninstalling the replay
integration reports disabled and clears the hold reason"), both also asserting
`$sdk_debug_replay_capture_mode` remains present (`:532`, `:555`), at `88f4b6b56`; those two
assertions encode the behavior this requirement now reverses and become assertions that the key
is absent; Android's
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

#### Scenario: No replay debug key remains after stop/uninstall
- **GIVEN** the replay integration was active with `$sdk_debug_replay_capture_mode` present
- **WHEN** recording is stopped, or the replay integration is uninstalled
- **AND** an eligible SDK event that the window allows is captured
- **THEN** the event's `$recording_status` is `disabled`
- **AND** the event's properties include no `$sdk_debug_replay_*` key, including
  `$sdk_debug_replay_capture_mode`, and no `$sdk_debug_session_start`

#### Scenario: A started browser recorder reports disabled after a stop
- **GIVEN** posthog-js has started its lazy recorder and the recorder reports `active`
- **WHEN** the app stops session recording
- **AND** a custom event is captured
- **THEN** the event's `$recording_status` is `disabled`
- **AND** the event's properties include none of the recorder's keys

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

The persisted crash-context snapshot is a property build that is not a capture: it SHALL carry the
full optional bundle while replay is not intentionally off, SHALL carry only
`$recording_status: disabled` while it is (see "Attach only the disabled shape while replay is intentionally off"), SHALL never start or move the
30-second window, and SHALL be
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
(`PostHog/Replay/PostHogReplayIntegration.swift:373`). The rules that the snapshot carries
the full optional bundle while replay is on and never starts or moves the window, and that the window runs on the
wall clock, are the mobile contract; posthog-js has no analog.

Covering test: posthog-ios `PostHogTests/PostHogSessionReplayRemoteConfigBufferTest.swift:580`
("crash context re-snapshots on recording transitions and omits point-in-time counters") at
`88f4b6b56`; iOS's crash-report decode path in `PostHogErrorTrackingAutoCaptureIntegration` (the
`customData` branch, `PostHog/ErrorTracking/PostHogErrorTrackingAutoCaptureIntegration.swift:255-259`)
covers the persisted-snapshot arm. Planned (mobile): the crash-context snapshot carries
the bundle while replay is on, carries only the disabled status while replay is off, and never arms the window, and a far-future eligible capture does not suppress the
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
- **AND** replay was not intentionally off at that time
- **WHEN** that crash report is captured on a later launch
- **THEN** the event carries the mirrored map, not the current process's state
- **AND** the mirrored map includes `$recording_status` and `$sdk_debug_session_start` but not
  the queue-depth key

#### Scenario: A persisted crash snapshot taken while replay was off carries only the status
- **GIVEN** the platform mirrored the debug map into its crash reporter at the time of the crash
- **AND** replay was intentionally off at that time
- **WHEN** that crash report is captured on a later launch
- **THEN** the event carries the mirrored map, which includes `$recording_status: disabled`
- **AND** the mirrored map includes no `$sdk_debug_replay_*` key and no `$sdk_debug_session_start`

#### Scenario: A backdated event within the current session keeps the keys
- **GIVEN** the current session started at T
- **AND** no window is open
- **WHEN** an eligible SDK event is captured with an explicit timestamp later than T
- **THEN** the event carries `$recording_status` and the applicable optional `$sdk_debug_*` keys

### Requirement: Reconciliation with `is-session-replay-active` and `session-replay-ingestion-controls`

The SDK SHALL keep `$recording_status` consistent with the boolean `isSessionReplayActive()`
getter specified by `is-session-replay-active`: a `$recording_status` of `active` SHALL imply that
getter returns `true`, and `disabled` SHALL imply it returns `false`. While
`$recording_status` is `buffering`, this spec makes no claim about the boolean getter's return
value — that getter's own spec governs its `buffering`-equivalent behavior per platform.

A running recorder is never intentionally off (see "Attach only the disabled shape while replay is
intentionally off"). After a remote off, the SDK SHALL keep reporting the running recorder's state,
with every key the other requirements of this capability call for, until the recorder stops. Only
events captured after it stops carry the off shape. Otherwise an event could carry
`$recording_status: disabled` while `isSessionReplayActive()` still returns `true`. The browser
stops its recorder inside `onRemoteConfig` (posthog-js `origin/main` `53e5c0e35`
`packages/browser/src/extensions/replay/session-recording.ts:340-343`), so it has no such interval.
On mobile the recorder can keep running after the remote off arrives (posthog-android
[#992](https://github.com/PostHog/posthog-android/pull/992) `e8809d38`
`posthog/src/main/java/com/posthog/PostHog.kt:2612-2619`; covering test
`posthog/src/test/java/com/posthog/PostHogTest.kt:4233`).

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

#### Scenario: A running recorder keeps its keys after a remote off until it stops (mobile)
- **GIVEN** a mobile SDK whose recorder is running and whose events carry `$recording_status: active`
- **WHEN** a fetched remote config arrives with `sessionRecording` set to the boolean `false`
- **AND** a custom event is captured before the recorder stops
- **THEN** the event's `$recording_status` is not `disabled`
- **AND** the event keeps the keys the other requirements call for
- **WHEN** the recorder stops
- **AND** another custom event is captured
- **THEN** that event's `$recording_status` is `disabled` and it includes none of the removal set

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
carries `$recording_status: 'disabled'` and `$sdk_debug_retry_queue_size`, and no other replay
key); `packages/browser/src/__tests__/extensions/replay/sessionRecording-onRemoteConfig.test.ts:420-426`
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
- **AND** each event includes `$sdk_debug_pending_queue_size`

#### Scenario: Replay off in local config sends only the disabled status (browser)
- **GIVEN** posthog-js is initialized with `disable_session_recording` set to true
- **AND** the session already holds session-persisted replay debug keys from earlier in the session
- **WHEN** a `$pageview` event is captured
- **THEN** the event's `$recording_status` is `disabled`
- **AND** the event includes none of the persisted replay debug keys, no `$sdk_debug_rrweb_*` key,
  and no `$sdk_debug_session_start`
- **AND** the event includes `$sdk_debug_retry_queue_size`

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
