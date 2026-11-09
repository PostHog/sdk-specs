## Why

posthog-ios 4.0 and posthog-android 4.0 remove wireframe session replay. Mobile replay always records masked screenshots, and the `screenshotMode` (iOS) and `screenshot` (Android) options are gone. posthog_flutter, `@posthog/react-native-plugin` and posthog-kmp already recorded screenshots or follow the native SDKs.

`session-replay-privacy` and `session-replay-debug-properties` still describe wireframe replay, a `screenshotMode` option, and a `wireframe` capture mode.

## What Changes

- **`session-replay-privacy`.** Drop `screenshotMode` and `screenshot` from the native options and remove wireframe masking from the narrative. The **Android secure windows are recorded fully masked** requirement keeps the solid black frame and drops the wireframe-mode node and its scenario.
- **`session-replay-debug-properties`.** `$sdk_debug_replay_capture_mode` is always `screenshot`. The three mode scenarios become one.
- **`start-session-recording`.** The narrative no longer mentions wireframes.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `session-replay-privacy`: **Android secure windows are recorded fully masked**, plus narrative.
- `session-replay-debug-properties`: **Session, queue, hold-reason, trigger, and mode keys**.
- `start-session-recording`: narrative only.

## Impact

- posthog-ios 4.0 and posthog-android 4.0 already match: both always send `$sdk_debug_replay_capture_mode: screenshot`.
- posthog-ios and posthog-android 3.x keep wireframe replay and still report `wireframe` when their screenshot option is off.
