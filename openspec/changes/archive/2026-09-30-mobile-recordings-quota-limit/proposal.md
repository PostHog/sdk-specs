## Why

PostHog now meters mobile session replay as its own billing resource. [posthog/posthog #103077](https://github.com/PostHog/posthog/pull/103077) makes the server report `quotaLimited: ["mobile_recordings"]` and `["recordings"]` independently, and deliberately keeps `sessionRecording` active for a mobile-only limit because web recording on the same project is still allowed. [posthog-android #825](https://github.com/PostHog/posthog-android/pull/825) implements the SDK side: a `/config` or `/flags` response naming `mobile_recordings` turns replay off and evicts the cached recording config.

No spec covers `quotaLimited` for replay. The enablement gate in `session-replay-ingestion-controls` says replay is active when local config and `sessionRecording` both allow it, which is exactly the state an over-quota mobile project is now in, and the remote-config wire table does not list the field at all. Left as is, the spec says a quota-limited mobile SDK should record.

## What Changes

- Add a `Mobile recording quota limiting` requirement to `session-replay-ingestion-controls`: `mobile_recordings` in `quotaLimited` disables replay in the enablement gate, evicts the cached recording config, is not sticky across later responses, and is independent of the `recordings` and `feature_flags` resources.
- Note that `quotaLimited` arrives on the project remote-config response as well as the flags response.
- Add `quotaLimited` to the remote-config wire-field table with a scenario covering it on the project config response.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `session-replay-ingestion-controls`: quota limiting as part of the replay enablement gate.
- `remote-config`: `quotaLimited` as a documented wire field on the project config response.

## Impact

Records shipped behavior for mobile-source replay SDKs. `posthog-android` conforms; `posthog-ios` and the native layers embedded by `posthog-react-native` and `posthog-flutter` do not yet, which is a conformance gap in those SDKs rather than a spec question. Browser replay and feature-flag quota handling are unchanged. No public API, no new config option, and no change for servers that never send the field.
