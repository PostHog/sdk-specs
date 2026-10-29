## Why

Android apps set `WindowManager.LayoutParams.FLAG_SECURE` on screens that must never be screenshotted (login, payment, PIN entry). `session-replay-privacy` doesn't mention it, and session replay on Android recorded those windows anyway: screenshot mode copied their pixels, wireframe mode serialized their view tree and text, and taps on them were recorded. Other parts of posthog-android (element interaction capture, interaction response snapshots) already skip secure windows, so replay was inconsistent with the rest of the SDK.

## What Changes

- New requirement in `session-replay-privacy`: while the window being captured has `FLAG_SECURE`, Android session replay records that window **fully masked** rather than skipping it, in every replay mode. Recordings show that something private was on screen instead of freezing on the previous frame.
  - Screenshot mode: an opaque masked frame the size of the window; none of the window's pixels are recorded or uploaded.
  - Wireframe mode: one masked node covering the window, with no child views, text or images.
- The secure state is checked when capture starts and again before the frame is recorded; the frame is masked if the window was secure at either point.
- Touch interactions on a secure window are not recorded. The app still receives them.
- Each window follows its own flag: a window without `FLAG_SECURE` (for example a dialog shown over a secure activity) is captured under the normal masking rules, as Android's own screenshots do.
- iOS has no window-level secure flag; the requirement is not applicable there, and iOS keeps masking sensitive inputs per field under the existing rules.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `session-replay-privacy`: adds the **Android secure windows are recorded fully masked** requirement.

## Impact

- **posthog-android**: screenshot mode, touches in screenshot mode, and the post-copy re-check in PostHog/posthog-android#910; wireframe mode and touches in every mode in PostHog/posthog-android#912 (stacked on #910). Both target `main` (3.x) and reach 4.0 when `main` is merged into the 4.0 branches; 4.0 removes wireframe mode (PostHog/posthog-android#908).
- **posthog-flutter**: Flutter renders its own Android replay frames, so it implements the screenshot behaviour in its plugin (PostHog/posthog-flutter#685). Native-screen captures and touch recording come from posthog-android.
- **posthog-react-native**: Android replay runs through posthog-android; the plugin's pinned version is bumped in PostHog/posthog-js#5483.
- **posthog-ios**, **posthog-js (browser)**, server SDKs: not applicable.
- Behaviour change for apps that set `FLAG_SECURE`: those screens now appear as solid masked frames in recordings, without taps.
