## Narrative alignment

When syncing this delta, align the "Session, queue, hold-reason, trigger, and mode keys"
requirement with the requirements below: `$sdk_debug_current_session_duration` is no longer
required of every platform, posthog-js no longer attaches it, and the posthog-js session/queue
scenario no longer asserts it. Where an SDK still attaches the key — mobile SDKs source it from
their own session manager and continue to do so — the rule that it and `$sdk_debug_session_start`
describe the session identified by the event's own `$session_id` is unchanged, as are the mobile
scenarios. Leave every other requirement, divergence note, and scenario in that section intact.

## MODIFIED Requirements

### Requirement: Attach debug properties to every captured event except `$snapshot`

The SDK SHALL attach `$recording_status` and the **required** debug keys of this spec's key list
to every captured event **except** `$snapshot`. The required keys are `$recording_status`, the
platform's queue-depth key (`$sdk_debug_retry_queue_size` on posthog-js,
`$sdk_debug_pending_queue_size` on mobile), `$sdk_debug_replay_internal_buffer_length`,
`$sdk_debug_replay_linked_flag_trigger_status`, `$sdk_debug_replay_event_trigger_status`, and —
where the SDK attaches them at all — `$sdk_debug_replay_rrweb_error`,
`$sdk_debug_replay_flushed_size`, `$sdk_debug_recording_script_not_loaded`, and
`$sdk_debug_replay_url_trigger_status`. These are the keys the recording controls and capture
diagnostics read off an individual event, so an event that reports replay state at all SHALL
report them. Every other `$recording_status`/`$sdk_debug_*` key this spec describes is
**supporting** and MAY be withheld under the rate-limiting requirement below.

`$snapshot` events (the replay payload itself) SHALL carry no required or supporting key — they
are already replay data, not a report about replay. A `$snapshot` MAY carry the cumulative
replay-drop counters `$sdk_debug_replay_unstringifiable_events_dropped`,
`$sdk_debug_replay_throttled_mutations_dropped`,
`$sdk_debug_replay_oversized_mutations_dropped`, and
`$sdk_debug_replay_oversized_mutation_bytes_dropped`, each only when its value exceeds zero.
These counters describe loss in the payload they ride on, so they belong on `$snapshot` and
nowhere else; they accumulate across a session, reset on session rotation, and are not
rate-limited.

When the outgoing event is the minimal `$feature_flag_called` shape (the allowlisted properties
sent when the call is gated and the flag has no experiment), the SDK SHALL strip
`$recording_status` and every `$sdk_debug_*` key along with everything else not on that
allowlist; the full (non-minimal) `$feature_flag_called` shape carries the required keys like any
other event.

Reference: posthog-js merges the debug map inside `calculateEventProperties`
(`packages/browser/src/posthog-core.ts:2165`), after the `$snapshot` early return — so
`$snapshot` never reaches the merge — and filters it against `REQUIRED_REPLAY_PROPERTIES`
(`posthog-core.ts:191`). The snapshot drop counters are attached where the payload is built
(`extensions/replay/external/lazy-loaded-session-recorder.ts`, the `$snapshot` property block).
The minimal `$feature_flag_called` allowlist is built by `minimizeFlagCalledEventProperties`
(`packages/core/src/featureFlagUtils.ts:263`), constructing a new object from an explicit key
list rather than deleting keys, so `$recording_status`/`$sdk_debug_*` are structurally excluded
unless allowlisted.

Covering test: `packages/browser/src/__tests__/__snapshots__/featureflags.test.ts.snap` — the
minimal snapshot ("sends exactly the allowlisted properties when gated and the flag has no
experiment") has no `$recording_status` or `$sdk_debug_*` key; the full snapshot has
`$recording_status: "disabled"`. `packages/browser/src/__tests__/posthog-core-also.test.ts`
(`calculateEventProperties` "returns calculated properties") asserts `$recording_status` and
`$sdk_debug_retry_queue_size` on an ordinary custom event; the snapshot drop-counter tests in
`packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts` cover
accumulation, omission at zero, and reset on rotation.

#### Scenario: Custom event carries the required debug properties
- **GIVEN** the SDK is initialized
- **WHEN** a custom event is captured
- **THEN** the captured event's properties include `$recording_status`

#### Scenario: Snapshot event carries none of the debug properties
- **GIVEN** the SDK is initialized with session replay active
- **AND** no replay data has been dropped in this session
- **WHEN** a `$snapshot` event is captured
- **THEN** the captured event's properties include neither `$recording_status` nor any
  `$sdk_debug_*` key

#### Scenario: Snapshot event carries non-zero cumulative drop counters
- **GIVEN** an SDK that counts replay data it dropped
- **AND** three oversized mutations have been dropped in this session and nothing else has
- **WHEN** a `$snapshot` event is captured
- **THEN** the captured event's properties include
  `$sdk_debug_replay_oversized_mutations_dropped` with value 3
- **AND** they do not include a drop counter whose value is zero
- **AND** they include no other `$recording_status` or `$sdk_debug_*` key
- **WHEN** the session rotates and another `$snapshot` event is captured with nothing dropped
  since
- **THEN** the captured event's properties include no drop counter

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

## ADDED Requirements

### Requirement: Supporting debug keys may be rate-limited

Supporting keys are optional telemetry, not a per-event contract. An SDK MAY attach them to at
most one event per **rate-limiting interval** per SDK instance (posthog-js: 30 seconds), and MAY
restrict them to an **eligible event set** chosen so that high-volume or shape-constrained events
do not carry them (posthog-js: event names beginning with `$`, excluding `$feature_flag_called`,
`$$heatmap`, and `$snapshot`). Required keys SHALL be attached regardless of the interval and of
event eligibility. An SDK that attaches supporting keys to every event remains conformant; this
requirement permits the reduction, it does not mandate it.

An SDK that rate-limits SHALL compute an event's properties before deciding whether that event
consumes the interval, so the event that starts an interval carries the supporting keys rather
than the next one. Only a capture the SDK accepts SHALL consume the interval: an event rejected
by a `before_send` hook, and enrichment of another library's properties that produces no capture,
SHALL leave the interval unconsumed, so a rejected event cannot silence the next accepted one.
Rate limiting is scoped to the SDK instance, not to a session, so the first eligible capture
after initialization carries the supporting keys.

Where a supporting key is withheld by the interval or by event eligibility, its absence SHALL NOT
be read as a violation of any presence rule this spec states for that key. In particular, the
mobile rule that `$sdk_debug_replay_flush_hold_reason` is present exactly while
`$recording_status` is `buffering` constrains the events that carry supporting keys; a withheld
key still means "not reported", never "no hold". A consumer SHALL read a supporting key's absence
as "not reported on this event" and SHALL NOT infer SDK state from it.

`$sdk_debug_current_session_duration` is not required of any SDK. posthog-js no longer attaches
it: the duration is the difference between the event's own timestamp and
`$sdk_debug_session_start`, so sending both spends payload on a value the consumer can compute.
An SDK that still attaches it — mobile SDKs read it from their own session manager — SHALL keep
it consistent with the event's `$session_id` as the keys requirement states.

Reference: posthog-js `REQUIRED_REPLAY_PROPERTIES`, `EVENTS_WITHOUT_REPLAY_DEBUG_PROPERTIES`,
`REPLAY_DEBUG_PROPERTIES_INTERVAL_MS`, and `isReplayDebugEvent`
(`packages/browser/src/posthog-core.ts:191-203`); the interval is consumed after `before_send`
accepts the event (`posthog-core.ts:1959`), while properties are built earlier
(`posthog-core.ts:1800`, `calculateEventProperties` filtering at `:2169-2171`). Introduced in
[posthog-js #5144](https://github.com/PostHog/posthog-js/pull/5144).

Covering test: `packages/browser/src/__tests__/posthog-core-also.test.ts` — the capture
regression tests covering interval consumption, enrichment that does not consume it, and
`before_send` rejections that do not consume it.

#### Scenario: Supporting keys are withheld for the rest of the interval
- **GIVEN** an SDK that rate-limits supporting debug keys, with session replay installed
- **WHEN** an eligible event is captured and accepted
- **THEN** its properties include the supporting keys the platform attaches
- **WHEN** another eligible event is captured within the rate-limiting interval
- **THEN** its properties include every required key
- **AND** they include none of the supporting keys
- **WHEN** another eligible event is captured after the interval has elapsed
- **THEN** its properties include the supporting keys again

#### Scenario: An event outside the eligible set still carries the required keys
- **GIVEN** an SDK that restricts supporting debug keys to an eligible event set
- **WHEN** an event outside that set is captured
- **THEN** its properties include `$recording_status` and the platform's other required keys
- **AND** they include none of the supporting keys

#### Scenario: A rejected capture does not consume the interval
- **GIVEN** an SDK that rate-limits supporting debug keys
- **AND** a `before_send` hook that drops the next event
- **WHEN** an eligible event is captured and the hook drops it
- **AND** another eligible event is captured immediately afterwards and is accepted
- **THEN** the accepted event's properties include the supporting keys

#### Scenario: Omitting the session duration key is not a violation
- **GIVEN** an SDK that does not attach `$sdk_debug_current_session_duration`
- **AND** a session whose start time is available
- **WHEN** an event carrying the supporting keys is captured
- **THEN** the event's properties include `$sdk_debug_session_start`
- **AND** the absence of `$sdk_debug_current_session_duration` is not a violation of this spec
