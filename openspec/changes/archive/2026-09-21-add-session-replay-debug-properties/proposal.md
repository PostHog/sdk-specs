## Why

[posthog-android#640](https://github.com/PostHog/posthog-android/issues/640): an OOM
investigation on Android was blocked because `$exception` events don't say whether session
replay was recording at capture time. Ashutosh asked (2026-09-02, on that issue) for a
`$recording_status` property plus `$sdk_debug_replay_*` detail on every event. posthog-js
already attaches this shape on every non-`$snapshot` captured event
(`packages/browser/src/posthog-core.ts:2024`, verified on `origin/main` re-pinned to `d6df4f496`); no
canonical spec exists for it, so the two mobile SDKs picking it up (`posthog-ios#726`,
`posthog-android#640`) have no cross-SDK contract to converge on and no documented list of
which keys are mobile-only versus browser-only.

No `session-replay-debug-properties` capability spec exists today. `is-session-replay-active`
covers the boolean "is replay running" getter; this is a different surface — a per-event debug
snapshot attached automatically to captured events, not a method the caller invokes.

## What Changes

- **New capability `session-replay-debug-properties`:** a platform-agnostic contract for the
  `$recording_status` and `$sdk_debug_*` properties SDKs attach to captured events. Covers the
  attach rule (every non-`$snapshot` event, stripped from the minimal `$feature_flag_called`
  shape), the `$recording_status` value set and the mobile subset (`disabled` / `active` /
  `buffering`, with both mobile holds — awaiting remote config, below minimum duration —
  reporting `buffering`), each shipped key and its source, the always-attach rule when replay
  is unconfigured, and the post-stop/uninstall reset that clears any stale hold reason.
- **Documents the mobile-only keys** (`$sdk_debug_replay_capture_mode`,
  `$sdk_debug_replay_throttle_delay_ms`) and the mobile-only `flush_hold_reason` values
  (`awaiting_remote_config`, `below_minimum_duration`) that have no posthog-js analog, and
  excludes the browser-only keys, config keys, and counter keys covered elsewhere.
- **Pins two rules both mobile ports got wrong:** the session keys describe the session named
  by the event's own `$session_id` (derived from its UUIDv7 timestamp when a bridge supplied the
  id), and an event whose timestamp precedes the current session — a previous process's crash
  reported on this launch — carries the state persisted at that time or none of the keys, never
  the current process's live state.
- **Not in scope for this change:** the deferred counter keys (buffer size/length in bytes,
  flushed size, full-snapshot counts, throttled/oversized-mutation drops, last-snapshot
  metadata) — tracked as a follow-up `session-replay-debug-counters` change — and the
  `$sdk_diagnostics_config` event (masking flags, capture toggles, sample rate), which is a
  separate, non-per-event surface.
- This is the contract, not a build dependency: the posthog-ios and posthog-android
  implementation PRs may open, and may merge, before this change merges.

## Capabilities

### New Capabilities

- `session-replay-debug-properties`: the per-event `$recording_status` / `$sdk_debug_*`
  property attach contract for session replay debugging.

### Modified Capabilities

_None._

## Impact

- `openspec/specs/session-replay-debug-properties/spec.md` — created on archive from this
  change's delta.
- Reference implementation: posthog-js (web), already shipping this shape. Verified against
  `origin/main` re-pinned to `d6df4f496` only — the local posthog-js checkout's `main` is
  diverged and was not used for any citation in this change.
- Downstream per-platform implementation: `posthog-ios` (issue #726, plan at
  `posthog-ios/.claude/plans/replay-debug-properties.md`) and `posthog-android` (issue #640,
  plan at `posthog-android/.claude/plans/replay-debug-properties.md`). `posthog-flutter`
  inherits every key transitively once both native SDKs release, since every Flutter-originated
  event is built by the native `buildProperties`/`buildProperties`-equivalent path; no Flutter
  spec rows are needed. `posthog-unity` and `posthog-react-native` are deferred — Unity needs
  its own edit site and emits a `disabled | active | paused` subset; React Native builds events
  in JS and does not inherit, so it needs a JS-side change plus a native bridge for the
  native-only keys. Both are tracked as follow-up changes, not in scope here.
- posthog-ios ships the replay integration for iOS only: macOS, tvOS, watchOS, and visionOS
  builds report `$recording_status: disabled` and carry none of the `$sdk_debug_replay_*` keys,
  because the replay module itself is not present in those builds — the same "module absent"
  case the always-attach-when-unconfigured requirement covers.
- No backend/ingestion change: these are ordinary event properties, not a new endpoint or wire
  format.
