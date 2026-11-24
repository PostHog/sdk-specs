## ADDED Requirements

### Requirement: Mobile SDKs read dedicated mobile masking keys

A mobile SDK that owns session replay capture SHALL read two optional remote masking flags from the
remote config `sessionRecording.masking.mobile` object: `maskAllText` and `maskAllImages`. Only the
boolean `true` has an effect. The SDK MUST NOT read any other key of `sessionRecording.masking`. The
web keys `maskAllInputs`, `maskTextSelector`, `blockSelector` and `maskAllElementAttributes` MUST be
ignored on mobile, even when they are present.

`maskAllText` maps to the local all-text flag: `maskAllTextInputs` in posthog-ios, posthog-android,
posthog-react-native and posthog-kmp, and `maskAllTexts` in posthog-flutter. `maskAllImages` maps to
the local `maskAllImages` flag. Every other mobile masking flag, such as `maskAllSandboxedViews` and
`maskCustomPaint`, stays local.

This is new mobile behavior with no reference implementation yet. It diverges from the browser in key
names by decision: the browser reads the web keys (`packages/browser/src/extensions/replay/external/lazy-loaded-session-recorder.ts:682-713`, posthog-js `origin/main` `f05a993f9`).

#### Scenario: A mobile SDK reads the mobile keys
- **GIVEN** the cached remote config has `sessionRecording.masking.mobile` with `maskAllText: true`
- **AND** the local all-text flag is `false`
- **WHEN** the SDK installs session replay
- **THEN** the resolved all-text flag is `true`

#### Scenario: Web keys are ignored on mobile
- **GIVEN** the remote config has `sessionRecording.masking` with `maskAllInputs: true`, `maskTextSelector: "*"` and `blockSelector: "img"`
- **AND** it has no `mobile` object
- **AND** the local all-text and all-images flags are `false`
- **WHEN** a replay frame is captured
- **THEN** the resolved all-text flag is `false`
- **AND** the resolved all-images flag is `false`

### Requirement: The stricter side wins, per flag

A mobile SDK SHALL resolve each remote-controlled masking flag as `resolved = local OR (server == true)`. The resolved all-text flag combines the local all-text flag with `masking.mobile.maskAllText`.
The resolved all-images flag combines the local `maskAllImages` flag with `masking.mobile.maskAllImages`.

The server value counts only when it is the boolean `true`. A missing key, `false`, `null`, a value
of any other type, a missing `masking` object, and a missing `mobile` object each leave the local
value unchanged. The server MUST NOT turn a local `true` into `false`. Changing the local flag in
code does not change the public API or its default.

This is new mobile behavior with no reference implementation yet. It diverges from the browser
by decision. The browser takes the client value first and falls back to the server value, so a local
`false` beats a server `true` (`lazy-loaded-session-recorder.ts:696-698`, test
`packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:1031-1042`).
Mobile follows the existing mobile rule that the more restrictive side wins for boolean switches:
posthog-android Logcat capture needs both local and remote on (`posthog-android/src/main/java/com/posthog/android/replay/internal/PostHogLogCatIntegration.kt:31-32`) and exception autocapture needs both (`posthog/src/main/java/com/posthog/internal/PostHogRemoteConfig.kt:830`), posthog-android `origin/main` `1577cfa5`.

#### Scenario: Server true turns on a mask the local value had off
- **GIVEN** the local all-text flag is `false`
- **AND** the remote config has `masking.mobile.maskAllText: true`
- **WHEN** a replay frame is captured
- **THEN** all text in the frame is masked

#### Scenario: Server false does not turn off a local mask
- **GIVEN** the local all-images flag is `true`
- **AND** the remote config has `masking.mobile.maskAllImages: false`
- **WHEN** a replay frame is captured
- **THEN** images in the frame are masked

#### Scenario: A missing key keeps the local value
- **GIVEN** the remote config has `masking.mobile` with only `maskAllImages: true`
- **AND** the local all-text flag is `true`
- **WHEN** a replay frame is captured
- **THEN** all text in the frame is masked
- **AND** images in the frame are masked

#### Scenario: A missing key does not mask when the local value is off
- **GIVEN** the remote config has `masking.mobile` with only `maskAllImages: true`
- **AND** the local all-text flag is `false`
- **WHEN** a replay frame is captured
- **THEN** all text in the frame is not masked by the category rule

#### Scenario: A value of the wrong type keeps the local value
- **GIVEN** the remote config has `masking.mobile.maskAllText` set to the string `"true"`, and `maskAllImages` set to `null`
- **AND** both local flags are `false`
- **WHEN** a replay frame is captured
- **THEN** both resolved flags are `false`
- **AND** the SDK does not throw

#### Scenario: Each flag resolves on its own
- **GIVEN** the local all-text flag is `true` and the local all-images flag is `false`
- **AND** the remote config has `masking.mobile.maskAllText: false` and `maskAllImages: true`
- **WHEN** a replay frame is captured
- **THEN** the resolved all-text flag is `true`
- **AND** the resolved all-images flag is `true`

### Requirement: Resolved masking follows the cached and live remote config

A mobile SDK SHALL apply the cached remote config's `masking.mobile` flags when session replay is installed, before any frame is captured under the cached config. It SHALL re-resolve the flags on every later remote config update, including one received mid-session, and apply the new values to the next captured frame without restarting replay. Capture reads the resolved value per frame. A cached layer, view hierarchy or mask rectangle computed under an older resolved value MUST NOT be reused.

When a remote config update makes a resolved flag go from `false` to `true`, including the first
live response of the process, the SDK MUST drop every frame it holds unsent and MUST NOT upload it.
Frames held unsent are the frames buffered before the first live remote config response, which were
resolved against the cached config only, the frames held for the minimum recording duration, and a
frame whose masks were computed under the previous resolved flags and which has not been handed to
the upload queue yet. A frame already handed to the upload queue is not dropped. When no flag gets
stricter, held frames are kept. An update that makes a resolved flag go from `true` to `false`
applies only to frames captured after it, and MUST NOT retroactively change frames already captured.

This is new mobile behavior with no reference implementation yet. It diverges from the browser by
decision: the browser reads the masking config once, when the recorder starts
(`lazy-loaded-session-recorder.ts:2980-2985`), and does not re-resolve it mid-session.

In-progress implementations, not merged and not the reference: posthog-android branch
`feat/replay-remote-masking-config` at `9788d4b2a1` stamps each frame with a masking generation and
drops a stale frame in `PostHogReplayQueue` (`isMaskingStale`). posthog-ios branch
`feat/replay-remote-masking-config` at `507ad33a5e` stamps `RRScreenshotFrame.maskingGeneration` and
drops a stale frame in `PostHogReplayQueue`.

#### Scenario: The cached config applies at start
- **GIVEN** the cached remote config has `masking.mobile.maskAllText: true`
- **AND** the local all-text flag is `false`
- **AND** no live remote config response has arrived yet
- **WHEN** the SDK starts replay and captures a frame
- **THEN** all text in the frame is masked

#### Scenario: A live update mid-session applies to the next frame
- **GIVEN** replay is recording with both resolved flags `false`
- **WHEN** a remote config update arrives with `masking.mobile.maskAllImages: true`
- **THEN** the next captured frame masks images
- **AND** replay is not restarted

#### Scenario: A server mask turned off applies to later frames only
- **GIVEN** replay is recording with the local all-text flag `false` and `masking.mobile.maskAllText: true` in the applied config
- **WHEN** a remote config update arrives with `masking.mobile.maskAllText: false`
- **THEN** the next captured frame does not mask text by the category rule
- **AND** frames captured earlier are not changed

#### Scenario: Frames buffered before the first live config are dropped when a flag gets stricter
- **GIVEN** no cached remote config has `masking.mobile`, and both resolved flags are `false`
- **AND** the SDK has buffered replay frames captured before the first live remote config response
- **WHEN** the first live response arrives with `masking.mobile.maskAllText: true`
- **THEN** the buffered frames are dropped and not uploaded
- **AND** frames captured after the response are masked

#### Scenario: Frames held for the minimum duration are dropped when a later update gets stricter
- **GIVEN** replay is recording with both resolved flags `false`
- **AND** the SDK holds unsent frames while the session is shorter than the minimum recording duration
- **WHEN** a remote config update arrives with `masking.mobile.maskAllText: true`
- **THEN** the held frames are dropped and not uploaded
- **AND** frames captured after the update are masked

#### Scenario: A frame collected before a flag gets stricter is dropped
- **GIVEN** replay is recording with both resolved flags `false`
- **AND** a frame is being collected under those flags
- **WHEN** a remote config update arrives with `masking.mobile.maskAllImages: true` before that frame is queued
- **THEN** that frame is not uploaded
- **AND** the next frame masks images

#### Scenario: Frames buffered before the first live config are kept when nothing gets stricter
- **GIVEN** the SDK has buffered replay frames captured before the first live remote config response
- **AND** the cached resolved flags are `true` and `false`
- **WHEN** the first live response resolves to the same two values
- **THEN** the buffered frames are kept and uploaded

### Requirement: Log once when the server turns on a mask the local value had off

A mobile SDK SHOULD write one debug-level log entry when a resolved flag is `true` only because the
server value is `true` and the local value is `false`. The entry SHALL name the flag. It is written
once per flag per process and MUST NOT be written when the local value is already `true`.
It MUST NOT be a warning or an error and MUST NOT change capture.

This is new mobile behavior with no reference implementation yet. The browser warns once when a client value shadows a different project value (`lazy-loaded-session-recorder.ts:721-764`, tests `lazy-sessionrecording.test.ts:6729-6799`). That warning is for the opposite case, because there the client value wins. Mobile logs when the server adds a mask, because the app's local value no longer decides.

#### Scenario: The server turns on a mask the local value had off
- **GIVEN** the local all-text flag is `false`
- **AND** debug logging is on
- **WHEN** a remote config with `masking.mobile.maskAllText: true` is applied twice
- **THEN** one debug log entry names the all-text flag
- **AND** no second entry is written for that flag

#### Scenario: No log when the local value was already on
- **GIVEN** the local all-text flag is `true`
- **WHEN** a remote config with `masking.mobile.maskAllText: true` is applied
- **THEN** no entry is written for the all-text flag

### Requirement: Wrapper SDKs get the resolved flags from native

A wrapper SDK SHALL take the resolved masking flags from the native SDK that owns capture. It MUST NOT
re-implement the remote resolution on top of different inputs.

- posthog-react-native and posthog-kmp keep passing their local flags to the native SDK. The native
  SDK combines them with the remote value, so the wrapper needs no resolution logic.
- A wrapper that renders replay frames itself, such as posthog-flutter for Flutter content, SHALL
  read the resolved flags from the native SDK on each capture and mask with them. The native SDK
  exposes them through the replay state it already returns to the wrapper. Under Flutter, the Dart
  flag `maskAllTexts` combines with `maskAllText` the same way.
- posthog-ios and posthog-android expose the resolved values to wrappers. The local masking
  flags keep their names, types and defaults.

A wrapper SDK MUST NOT read the local flag alone for content it renders after the native SDK has
resolved a stricter value.

This is new mobile behavior with no reference implementation yet.

#### Scenario: React Native and KMP rely on native resolution
- **GIVEN** a React Native app passes `maskAllTextInputs: false` to the native SDK
- **AND** the remote config has `masking.mobile.maskAllText: true`
- **WHEN** a replay frame is captured
- **THEN** all text in the frame is masked

#### Scenario: Flutter content follows the resolved flags
- **GIVEN** a Flutter app sets `maskAllTexts: false`
- **AND** the remote config has `masking.mobile.maskAllText: true`
- **WHEN** Dart captures a frame of Flutter content
- **THEN** the replay state it reads from native reports the resolved all-text flag as `true`
- **AND** the Flutter text in the frame is masked

#### Scenario: A wrapper sees a live update
- **GIVEN** a Flutter app is recording with the resolved all-images flag `false`
- **WHEN** a remote config update arrives with `masking.mobile.maskAllImages: true`
- **THEN** the next capture reads `true` from native
- **AND** images in that frame are masked

### Requirement: Always-mask rules are unchanged by remote masking

Remote `masking.mobile` flags MUST NOT change the rules in Behavior items 2, 3 and 7. Password and
secure fields, `ph-no-capture` or its platform equivalent, and explicit mask markers stay masked
whatever the resolved flags say. A resolved flag of `false` MUST NOT unmask them. Explicit unmask markers keep
their precedence over category masking, so a view marked unmasked stays unmasked when a server flag is `true`, as it does for a local flag.

This is new mobile behavior with no reference implementation yet. It adds no new masking categories.

#### Scenario: A server flag of false does not unmask a password field
- **GIVEN** the remote config has `masking.mobile.maskAllText: false`
- **AND** the local all-text flag is `false`
- **WHEN** a replay frame is captured with a password field containing "secret-password"
- **THEN** the frame does not contain "secret-password"

#### Scenario: A marked view stays masked
- **GIVEN** the remote config has `masking.mobile` with both flags `false`
- **AND** a view carries an explicit mask marker
- **WHEN** a replay frame is captured
- **THEN** the view is masked

#### Scenario: An unmask marker keeps its precedence
- **GIVEN** the remote config has `masking.mobile.maskAllText: true`
- **AND** a view carries an explicit unmask marker on a platform that supports one
- **WHEN** a replay frame is captured
- **THEN** that view is not masked by the category rule

### Requirement: Browser masking precedence is unchanged

Browser replay SHALL keep merging client `session_recording` masking options with the project's
remote `masking` object per field as `client ?? server`, applying the result when the recorder
starts, with `maskAllInputs` defaulting to `true`. Browser replay MUST NOT read `masking.mobile`.
This requirement records the baseline the mobile requirements diverge from and changes no browser
behavior.

Reference: posthog-js `origin/main` `f05a993f9`, `packages/browser/src/extensions/replay/external/lazy-loaded-session-recorder.ts:682-713` (merge), `:721-764` (warning when a client value shadows a different project value), `:2980-2985` (applied at recorder start). Tests: `packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:1031-1042` (client value overrides server value, in full and per field), `:6580` (remote masking options reach rrweb) and `:6729-6799` (shadow warning).

#### Scenario: The client value wins in the browser
- **GIVEN** `session_recording.maskAllInputs` is `false` in the client config
- **AND** the remote `masking` has `maskAllInputs: true` and `maskTextSelector: "*"`
- **WHEN** the recorder starts
- **THEN** rrweb receives `maskAllInputs` `false`
- **AND** rrweb receives `maskTextSelector` `"*"`

#### Scenario: The server value fills an unset client value in the browser
- **GIVEN** `session_recording.maskAllInputs` is unset in the client config
- **AND** the remote `masking` has `maskAllInputs: true` and `maskTextSelector: "*"`
- **WHEN** the recorder starts
- **THEN** rrweb receives `maskAllInputs` `true` and `maskTextSelector` `"*"`

#### Scenario: The browser ignores the mobile keys
- **GIVEN** the remote `masking` has `mobile: { maskAllText: true, maskAllImages: true }` and no web keys
- **WHEN** the recorder starts
- **THEN** rrweb receives no masking options from the remote config
