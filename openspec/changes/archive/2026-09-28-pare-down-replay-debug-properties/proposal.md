## Why

The published `session-replay-debug-properties` spec (PostHog/sdk-specs#72) says every
non-`$snapshot` event carries `$recording_status` plus the whole `$sdk_debug_*` bundle. The
recording buttons and the replay capture diagnostics read only a few of those keys from
individual events. The rest are read only on the newest SDK event of a session, but every event
still stores them for the whole retention window, and that costs real money.

posthog-js [#5144](https://github.com/PostHog/posthog-js/pull/5144) (merged as `bd66ceef9`)
splits the keys in two. A short list of required keys stays on every event. Everything else
becomes an optional bundle, attached only to SDK events and at most once every 30 seconds. The
window starts when `before_send` accepts the event carrying the bundle. #5144 also keeps four
cumulative replay drop counters on `$snapshot` events, each only while it is above zero.

The spec has to describe that split so the mobile SDKs have one contract to port against. Where
mobile needs a rule posthog-js lacks, the spec states it as the contract: for example, holding at
most one outstanding claim on the window, which closes a gap posthog-js still has, where an event
captured from inside `before_send` can also get the bundle.

## References

- **posthog-js:** `origin/main` `928990ded`, which contains #5144. The spec's posthog-js
  citations are pinned there.
- **posthog-ios:** `origin/main` `88f4b6b56`. The spec cites it only for behavior already there,
  such as capture-mode derivation, the hold reason, and the crash-context snapshot. Rules with
  no posthog-js analog and no mobile code yet are stated as the contract, with their mobile tests
  marked planned.

## What Changes

- **Attach rule (MODIFIED):** the every-event requirement now covers the *required keys* only:
  `$recording_status`, `$sdk_debug_replay_event_trigger_status`,
  `$sdk_debug_replay_linked_flag_trigger_status`, and `$sdk_debug_replay_internal_buffer_length`.
  The browser adds four browser-only keys to that list. They go on every event when available,
  custom events and full-envelope `$feature_flag_called` included. The minimal
  `$feature_flag_called` envelope still carries none, and `$snapshot` carries none of these keys
  apart from the browser's drop counters (below).
- **Optional bundle (ADDED):** every other replay debug key goes only on *eligible SDK events*:
  names that start with `$`, excluding `$feature_flag_called`, `$snapshot`, and the browser's
  `$$heatmap`. Eligibility is decided on the captured name, before `beforeSend` runs.
- **30-second window (ADDED):** the optional bundle goes on at most one eligible event per 30
  seconds. The window starts when the event carrying it is accepted, meaning after `beforeSend`
  and into the send queue. An event dropped by `beforeSend`, deduplicated, or not stored does not
  start it. The window runs on the wall clock, not the event's timestamp. A property build that
  is not a capture never starts it, and the mobile crash-context snapshot always carries the full
  bundle. Holding at most one outstanding claim is a SHOULD, and posthog-js's gap is named.
- **Drop counters (ADDED):** `$snapshot` events MAY carry four cumulative browser replay drop
  counters, `$sdk_debug_replay_unstringifiable_events_dropped`,
  `$sdk_debug_replay_throttled_mutations_dropped`, `$sdk_debug_replay_oversized_mutations_dropped`,
  and `$sdk_debug_replay_oversized_mutation_bytes_dropped`, each only while above zero. They reset
  on session rotation, ignore the 30-second window and event eligibility, and appear on no other
  event. They are browser-only as implemented, and mobile SDKs are not required to add them.
- **Queue-depth key (ADDED):** `$sdk_debug_retry_queue_size` / `$sdk_debug_pending_queue_size`
  stays on every non-`$snapshot` event outside both tiers.
- **Key list (MODIFIED):** each key is labelled required or optional.
  `$sdk_debug_current_session_duration` and `$sdk_debug_replay_throttle_delay_ms` MUST NOT be
  attached. `$sdk_debug_replay_capture_mode` is specified as mobile-only and optional, with values
  `screenshot` / `wireframe` and a stated derivation rule. The trigger statuses move to required;
  pending trigger conditions stay optional.
- **Other requirements (MODIFIED):** the value set, `$exception`/`$identify`/`$set`, unconfigured
  replay (mobile puts `$recording_status: disabled` on every event and adds capture mode and
  session start only with the optional bundle), stop/uninstall, event-time, and out-of-scope
  requirements are updated for the split. The out-of-scope requirement no longer lists the four
  drop counters among the removed counters. The backdated-capture rule is gone, because the
  window runs on the wall clock. The error-capture requirement's citation is re-pinned, and the
  requirement is scoped to SDKs whose debug-map build can throw.
- **Not in scope:** the `$sdk_diagnostics_config` event; Unity and React Native (separate
  follow-ups, unchanged); Android and Flutter implementation (their own PRs).

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `session-replay-debug-properties`: required keys on every event, an optional bundle limited to
  eligible SDK events and a 30-second window that starts at acceptance, the queue-depth key
  outside both tiers, four browser drop counters allowed on `$snapshot` events, a mobile-only
  optional capture-mode key, and two keys removed.

## Impact

- `openspec/specs/session-replay-debug-properties/spec.md` is updated on archive from this
  change's delta. The README capability row is unchanged (same scope and status).
- Reference implementation: posthog-js#5144 (merged).
- Downstream: posthog-ios, posthog-android, and posthog-flutter port this contract in their own
  repositories. Flutter inherits the native `buildProperties` path, and its `throttleDelay` forwarding follow-up is moot
  now that the key is gone.
- No backend or ingestion change. Events carry fewer ordinary properties, with no new endpoint
  or wire format.
