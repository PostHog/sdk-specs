## Why

The published `session-replay-debug-properties` spec (PostHog/sdk-specs#72) says every
non-`$snapshot` event carries `$recording_status` plus the whole `$sdk_debug_*` bundle. The
recording buttons and the replay capture diagnostics read only a few of those keys from
individual events. The rest are read only on the newest SDK event of a session, but every event
still stores them for the whole retention window, and that costs real money.

posthog-js [#5144](https://github.com/PostHog/posthog-js/pull/5144) (merged as `bd66ceef9`)
splits the keys in two. A short list of required keys stays on every event. Everything else
becomes an optional bundle, attached only to SDK events and at most once every 30 seconds. The
window starts when `before_send` accepts the event carrying the bundle.
posthog-ios [#859](https://github.com/PostHog/posthog-ios/pull/859) ports that shape to iOS. It
also holds at most one claim on the window at a time. That closes a gap posthog-js still has: an
event captured from inside `before_send` can also get the bundle. The spec now has to describe
the split, so posthog-android and posthog-flutter have one contract to port against.

## References

- **posthog-js:** `origin/main` `928990ded`, which contains #5144. The spec's posthog-js
  citations are pinned there.
- **posthog-ios#859:** still open. Its citations are pinned to head `fda0e238c`, the commit that
  moved the window start to acceptance and added the one-claim rule. A later merge of `main` into
  the branch (`563de3776`) did not touch the debug-property code. `tasks.md` keeps an open task
  to re-pin the iOS citations once #859 merges.

An earlier draft of this change followed posthog-js#5119, which gated `$recording_status` along
with everything else. #5119 was never merged, and #5144 replaced it with the required/optional
split. This change follows #5144.

## What Changes

- **Attach rule (MODIFIED):** the every-event requirement now covers the *required keys* only:
  `$recording_status`, `$sdk_debug_replay_event_trigger_status`,
  `$sdk_debug_replay_linked_flag_trigger_status`, and `$sdk_debug_replay_internal_buffer_length`.
  The browser adds four browser-only keys to that list. They go on every event when available,
  custom events and full-envelope `$feature_flag_called` included. `$snapshot` and the minimal
  `$feature_flag_called` envelope still carry none.
- **Optional bundle (ADDED):** every other replay debug key goes only on *eligible SDK events*:
  names that start with `$`, excluding `$feature_flag_called`, `$snapshot`, and the browser's
  `$$heatmap`. Eligibility is decided on the captured name, before `beforeSend` runs.
- **30-second window (ADDED):** the optional bundle goes on at most one eligible event per 30
  seconds. The window starts when the event carrying it is accepted, meaning after `beforeSend`
  and into the send queue. An event dropped by `beforeSend`, deduplicated, or not stored does not
  start it. The window runs on the wall clock, not the event's timestamp. A property build that
  is not a capture never starts it, and the mobile crash-context snapshot always carries the full
  bundle. Holding at most one outstanding claim is a SHOULD, and posthog-js's gap is named.
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
  requirements are updated for the split. The backdated-capture rule from the earlier draft is
  gone, because iOS now uses the wall clock. The error-capture requirement's citation is re-pinned.
- **Not in scope:** the `$sdk_diagnostics_config` event; Unity and React Native (separate
  follow-ups, unchanged); Android and Flutter implementation (their own PRs).

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `session-replay-debug-properties`: required keys on every event, an optional bundle limited to
  eligible SDK events and a 30-second window that starts at acceptance, the queue-depth key
  outside both tiers, a mobile-only optional capture-mode key, and two keys removed.

## Impact

- `openspec/specs/session-replay-debug-properties/spec.md` is updated on archive from this
  change's delta. The README capability row is unchanged (same scope and status).
- Reference implementations: posthog-js#5144 (merged) and posthog-ios#859 (open).
- Downstream: posthog-android and posthog-flutter port the same shape in their own PRs. Flutter
  inherits the native `buildProperties` path, and its `throttleDelay` forwarding follow-up is moot
  now that the key is gone.
- No backend or ingestion change. Events carry fewer ordinary properties, with no new endpoint
  or wire format.
