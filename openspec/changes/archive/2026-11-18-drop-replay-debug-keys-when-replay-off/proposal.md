## Why

SDKs attach `$recording_status` and a set of `$sdk_debug_replay_*` keys to captured events so that a
replay problem can be diagnosed from the event feed. When session replay is intentionally off, those
keys describe nothing. They only add to every event's payload. A customer with a high event volume
asked for them to go.

Today the spec keeps them. A mobile SDK with no replay integration still sends `capture_mode` and
`session_start`. After an explicit stop, `capture_mode` stays on the wire by rule. A browser that
stops replay mid-session keeps reporting the recorder's status and keys, which is the gap
`compliance/posthog-js.md` records as n36.

## What Changes

- **New requirement: Attach only the disabled shape while replay is intentionally off.** Replay is
  off when it is off locally (SDK config, explicit stop, opt-out) or off remotely (`sessionRecording`
  is boolean `false`, including the quota-limited override). While off, an event carries
  `$recording_status: disabled` and none of `$sdk_debug_replay_*`, `$sdk_debug_rrweb_*`,
  `$sdk_debug_recording_script_not_loaded`, or `$sdk_debug_session_start`. This covers the required
  keys, the optional bundle, and session-persisted or registered keys. Sampled-out, any pending
  trigger, awaiting the first remote config, buffering, and paused are not off and keep every key.
  The gate reads replay state, never `$recording_status`, because a sampled-out session reports
  `disabled` too. It is evaluated per event, so a mid-session stop or remote-off takes effect on the
  next event, and turning replay on again restores the keys. Every consumer of the debug map
  (crash-context snapshot, wrapper bridges) gets the gated map.
- **Modified: Attach debug properties to every captured event except `$snapshot`.** The required keys
  are withheld while replay is intentionally off, except `$recording_status`.
- **Modified: Attach the disabled shape when replay is not configured.** The mobile no-integration
  fallback sends only `$recording_status: disabled`. The fallback optional bundle (`capture_mode`,
  `session_start`) and its scenario are gone. The browser no-extension scenario stays.
- **Modified: Stop and uninstall reset the reported state and clear any stale hold reason.** After a
  stop or uninstall, `$recording_status` is `disabled` and no `$sdk_debug_replay_*` key is attached.
  The "config-derived keys remain present" scenario becomes its opposite. A browser scenario covers
  a recorder that stays loaded after the stop.
- **Modified: Session, queue, hold-reason, trigger, and mode keys.** `$sdk_debug_replay_capture_mode`
  is attached only while replay is not intentionally off. The scenario "Session keys are present
  without session replay (mobile)" becomes "The session start is absent without session replay
  (mobile)", and the paragraph that justified the old divergence is withdrawn.
- **Modified: Attach the optional replay debug bundle at most once every 30 seconds, from
  acceptance.** The crash-context snapshot carries the full bundle only while replay is not
  intentionally off.
- **Modified: Debug keys describe the SDK state when the event occurred.** The persisted crash
  snapshot follows the same gate, and a new scenario covers a snapshot taken while replay was off.

Reviewed and not modified: "Attach the optional replay debug bundle only to eligible SDK events",
"The queue-depth key stays on every non-`$snapshot` event", "`$snapshot` events MAY carry the
browser's replay drop counters", "`$recording_status` value set, with a mobile subset", "All debug
keys on one event come from a single consistent snapshot", "Debug properties attach to exception,
identify, and set events", "Reconciliation with `is-session-replay-active` ...", and "Out of scope
for this capability". Scenarios in those requirements that start from "the SDK is initialized with
an active session" and expect a replay key mean that replay is not intentionally off. The new
requirement says so.

At apply time one sentence outside the requirements needs a hand edit in `specs/`, because the delta
cannot reach it: the Purpose paragraph says the crash-context snapshot "always carries the full
bundle".

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `session-replay-debug-properties`: one added requirement and six modified requirements, listed above.

## Impact

- **posthog-js browser.** Off at load already sends `$recording_status` next to any session-persisted
  keys, so only a reload after a remote-off needs the persisted keys filtered. A mid-session stop
  and a mid-session remote-off need a fix: the recorder stays loaded and keeps reporting its status
  and keys. Tracked in compliance n36, which this change extends from the stop case to the
  remote-off case.
- **posthog-js react-native.** The debug builder does not read remote config, so remote-off is
  invisible to it. It also sends `capture_mode` whenever the native plugin is present and
  `session_start` always. It reads remote-off from the cached remote config
  (`sessionRecording === false`) and applies the gate to its own keys, including any trigger keys it
  registers per session.
- **posthog-ios.** The no-integration fallback drops `capture_mode`. After an explicit stop or a
  remote-off, the required keys and the bundle are gated. The crash-context snapshot and the API
  that hands the map to wrapper SDKs return the gated map.
- **posthog-android.** The integration is always registered, so `debugProperties()` runs when replay
  is off. It applies the gate for local-off and remote-off, and the plugin bridge receives the gated
  map. Its snapshot golden for `sessionReplay=false` changes.
- **posthog-flutter.** Native iOS and Android events follow the native SDKs. Web follows posthog-js.
  Windows and Linux already send `$recording_status: disabled` with no replay integration. Their
  open gap in compliance n28 (`$sdk_debug_session_start` on every event) now also violates this
  change.
- No new public API. No new keys. Behavior changes only on events captured while replay is off.
