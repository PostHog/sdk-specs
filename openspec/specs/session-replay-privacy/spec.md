# Session Replay Privacy Specification

## Purpose

`session-replay-privacy` is the client-side subsystem that prevents sensitive UI and supplemental replay data from being captured in session replay payloads.

It exists so session replay can record enough screen, DOM, network, console, and interaction context to debug user sessions while defaulting to conservative redaction for text, inputs, images, explicitly marked views, and sensitive network data.

## Applicability

`client` — this behavior applies to browser and UI/mobile SDKs that own session replay capture. Server SDKs do not observe an ambient UI tree or record replay payloads.

## Public signature(s)

No single canonical public API. Typical surfaces include replay configuration, CSS/classes, native view tags/modifiers, and wrapper components:

```ts
// browser-style replay redaction options
session_recording: {
  maskAllInputs?: boolean
  maskTextSelector?: string
  blockSelector?: string
  maskInputOptions?: { password?: boolean, [inputType: string]: boolean }
  recordHeaders?: boolean | { request: boolean, response: boolean }
  recordBody?: boolean | string[] | { request: boolean | string[], response: boolean | string[] }
  maskCapturedNetworkRequestFn?: (request) => request | undefined
}

// browser-style markup controls
class="ph-no-capture" // block/redact element subtree
class="ph-mask"       // mask text content
class="ph-ignore-input" // ignore input changes

// native/mobile-style replay redaction options
sessionReplayConfig: {
  maskAllTextInputs?: boolean
  maskAllTexts?: boolean
  maskAllImages?: boolean
}

// framework-native explicit masking controls
<PostHogMaskView>{children}</PostHogMaskView>
PostHogMaskWidget(child: ...)
view.postHogMask()
view.postHogNoMask()
Modifier.postHogMask()
Modifier.postHogUnmask()
```

## Behavior

1. **Default to masking sensitive UI.** Replay capture masks text input values by default. Native/mobile implementations also default to masking textual content and images, or at least password/sensitive inputs, unless the local replay configuration disables those categories. For all-text and all-images masking, the local value is combined with the remote `masking.mobile` flags (Behavior item 5).
2. **Honor explicit mask markers.** Elements/views tagged with PostHog masking markers such as `ph-no-capture`, `postHogMask(...)`, `Modifier.postHogMask(...)`, or wrapper components are treated as masked even when broad category masking is disabled.
3. **Honor explicit unmask markers where supported.** Platform-specific unmask controls such as iOS `postHogNoMask()` and Android `Modifier.postHogUnmask(...)` take precedence over automatic category masking and prevent that subtree/node from being redacted.
4. **Apply masks before serialization/upload.** Browser replay passes masking/blocking options into the rrweb recorder before DOM/input events are serialized. Native screenshot replay computes mask rectangles from the current view/render tree and paints opaque masks over screenshots before image encoding. Mask rectangle/element discovery MUST traverse the full matched subtree and include every element that matches a masking rule — not only the first match encountered, and not skipping nodes because a traversal shortcut (e.g. only descending into children that themselves have multiple children) happened to bypass them; a masked wrapper's own rect must be included alongside its matching descendants' rects.
5. **Support remote and local masking configuration.** Browser replay merges client `session_recording` masking settings with remote replay masking config, with client-provided values taking precedence. Native/mobile SDKs expose local replay config for text/image masking and combine the all-text and all-images flags with the remote `sessionRecording.masking.mobile` flags, so the stricter side wins per flag and the server never unmasks. Every other mobile masking category stays local. See "Mobile SDKs read dedicated mobile masking keys" and the requirements after it.
6. **Preserve privacy in screenshots.** Native mobile replay always records screenshots; posthog-ios 4.0 and posthog-android 4.0 removed wireframe recording and its `screenshotMode` / `screenshot` options. Screenshot-based recorders must discover sensitive rectangles synchronously with capture where possible and draw masks into the screenshot bitmap/canvas before converting it to base64/PNG/WebP. If a concurrent screen change makes mask rectangles unreliable, implementations should discard that snapshot rather than upload a potentially stale/unmasked image.
7. **Treat password and sensitive controls specially.** Password/secure text fields remain masked even when broad text masking is disabled. Native implementations inspect secure text traits/input types or obscured text widgets in addition to global masking settings.
8. **Treat images conservatively when configured.** Mobile screenshot implementations mask image views or render-image objects when image masking is enabled, while allowing platform-specific heuristics for safe bundled assets or symbols.
9. **Apply mandatory replay network protections.** Browser network replay capture is opt-in for headers/bodies. Sensitive-header redaction (including authorization, cookies, API keys, and CSRF tokens), payload-size limits, and PostHog ingestion-path filtering apply regardless of custom masking and run before a custom callback. Existing host exclusions remain in force. A request dropped by mandatory filtering does not reach the callback. These cleaners protect callback inputs and are not reapplied to callback outputs; callbacks are responsible for sensitive data they add or restore.
10. **Allow custom body scrubbing to replace default body scrubbing.** Without a custom callback, eligible request and response bodies pass through the default body-content scrubber. When a network capture masking callback (for example, `maskCapturedNetworkRequestFn` in posthog-js) is supplied, it replaces that scrubber: default keyword and other body-content heuristics run neither before nor after the callback. The callback is responsible for sanitizing retained bodies and can modify or drop the request; its inputs have already undergone mandatory cleaning and can contain absent bodies or size-limit replacement markers. The deprecated posthog-js `maskNetworkRequestFn` is a URL-only compatibility shim that also disables default body scrubbing when no modern callback is supplied; use the modern hook to sanitize bodies or disable body capture. The modern callback takes precedence when both hooks are supplied.
11. **Fail closed for uncertain snapshots.** Mask tree discovery/parsing failures, missing contexts, invalid images, timeout/cancellation, or screen changes should skip the affected replay snapshot or emit no maskable payload rather than crash the app or send known-sensitive unredacted data.

## State & lifecycle

### State read

- replay masking config from local SDK config and from remote replay config: the web `masking` keys in the browser, and the cached and live `masking.mobile` flags on mobile
- browser DOM classes/selectors and rrweb masking options
- native view hierarchy, accessibility labels/tags/content descriptions, SwiftUI/Compose semantics, Flutter render tree, and current screenshot/root context
- secure/password input metadata and text/image widget types
- optional replay network-capture settings and masking callbacks

### State written

- recorder masking/blocking options supplied to the replay engine
- mask rectangles collected for screenshot capture
- redacted network request/response headers and bodies
- framework-specific marker state on views/layers/semantics nodes

### Lifecycle behavior

- **Setup:** replay privacy configuration is installed when session replay starts or the replay recorder is initialized.
- **Capture:** every DOM event, screenshot, or replay network event is filtered/redacted before serialization.
- **Remote-config update:** browser replay can update masking and network-capture options from remote config while preserving local overrides. Mobile replay applies the cached `masking.mobile` flags at install and re-resolves them on each remote config update, including mid-session, and drops frames not yet handed to the upload queue when a resolved flag gets stricter.
- **View updates:** explicit mask/unmask modifiers update marker state as UI nodes mount, change, or unmount.
- **Teardown:** stopping replay stops further capture; marker state on app views remains framework-owned unless removed by the modifier/component lifecycle.

## Error handling

- Invalid or unavailable view/screenshot/render-tree state causes that snapshot or mask pass to be skipped and logged where the SDK has a logger.
- Browser missing rrweb record support logs an error and avoids starting capture.
- The network capture masking callback drops an ordinary replay network record and its derived server timings by returning `null` or `undefined`. Initial entries instead retain only pre-callback required timing metadata with an empty URL and no network content or customer-controlled server timings. Mandatory cleaning runs first; default body scrubbing is not a fallback for a drop decision.
- Exceptions from the network capture masking callback are caught per record: drop the affected record and its derived server timings, including initial entries, without retaining unmasked input or any fallback record. Continue processing unrelated records and subsequent batches without letting the exception escape the recorder.
- Native/mobile implementations should avoid throwing into application UI code from mask discovery or screenshot masking paths.

## Concurrency & ordering guarantees

- Masks must be computed against the same UI state that is serialized or screenshotted. If the UI changes during capture and the implementation can detect that race, it should discard the snapshot.
- Explicit unmask markers take precedence over explicit mask markers and global category masks where a platform exposes both concepts.
- Mandatory replay-network header redaction, payload-size limiting, and ingestion-path filtering happen before custom user masking callbacks. Default body-content scrubbing and custom callbacks are alternative strategies, not sequential stages.
- Password/secure input masking takes precedence over disabled broad text masking.

## Interactions

- **session replay recorder** — consumes masking options, mask rectangles, and redacted network events before replay payload upload.
- **remote config** — may provide replay masking/network-capture settings and replay enablement.
- **public replay controls** — `startSessionRecording`, `stopSessionRecording`, and replay sampling determine whether privacy filtering is active because no replay data is captured while replay is stopped.
- **autocapture/click capture** — browser `ph-no-capture` is also used by autocapture filtering, so a single class can suppress both replay capture and event-property collection in browser contexts.
- **framework UI layers** — React Native, SwiftUI, Jetpack Compose, and Flutter wrappers translate declarative mask controls into native markers that lower-level replay recorders can detect.
## Requirements
### Requirement: Canonical session-replay-privacy behavior

The SDK SHALL implement the canonical `session-replay-privacy` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Replay privacy masks text in masked elements
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and session recording is active
- **WHEN** a replay snapshot is captured for an element marked as masked containing text "secret"
- **THEN** the replay snapshot should not contain text "secret"
- **AND** the replay snapshot should contain masked text only

#### Scenario: Replay privacy masks every matching element in a subtree, not only the first match
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and session recording is active
- **WHEN** a replay snapshot is captured for an explicitly masked subtree containing multiple children, including at least one child that does not itself match any masking rule
- **THEN** the replay snapshot should not reveal any content from that subtree
- **AND** every matching descendant within the subtree should be masked, not only the first one discovered during tree traversal

#### Scenario: Replay privacy excludes no-capture elements
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and session recording is active
- **WHEN** a replay snapshot is captured for an element marked no-capture
- **THEN** the replay snapshot should not include that element or its descendants

#### Scenario: Replay privacy redacts sensitive inputs by default
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and session recording is active
- **WHEN** a replay snapshot is captured for a password input containing "secret-password"
- **THEN** the replay snapshot should not contain text "secret-password"

#### Scenario: Privacy rules apply before replay data is queued
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and session recording is active
- **WHEN** a replay snapshot containing masked text is processed
- **THEN** queued replay data should already be redacted

### Requirement: Browser replay network body scrubber replacement

A **network capture masking callback** is an SDK-provided hook that allows applications to sanitize or drop captured replay network records (for example, `session_recording.maskCapturedNetworkRequestFn` in posthog-js). API names vary by SDK; the SDK MUST follow the behavior below regardless of the hook's API name. It refers to a hook receiving the captured record, not a deprecated URL-only hook.

For browser replay network capture, the SDK MUST apply mandatory sensitive-header redaction, payload-size limits, and PostHog ingestion-path filtering regardless of whether a custom network capture masking callback is supplied. These protections MUST run before invoking a custom callback; requests dropped by mandatory filtering MUST NOT reach that callback. Existing capture opt-ins and host exclusions remain in force. Mandatory cleaning protects the callback input, not arbitrary callback output: the SDK does not reapply these cleaners after the callback. The callback is responsible for sensitive data it adds or restores, including header values.

When no custom callback is supplied, the SDK MUST apply its default body-content scrubber to eligible request and response bodies after mandatory cleaning. When a custom callback is supplied, it MUST replace the default body-content scrubber: the SDK MUST NOT run default keyword or other body-content heuristics either before or after that callback. The callback is responsible for sanitizing the request and response bodies it retains and MAY modify or drop a request. Callback inputs can still contain absent bodies or size-limit replacement markers produced by mandatory cleaning; replacing default scrubbing does not bypass those protections.

For posthog-js compatibility, the deprecated `maskNetworkRequestFn` is adapted into `maskCapturedNetworkRequestFn` when no modern callback is supplied. This adapter also replaces default body-content scrubbing, even though the deprecated hook receives only the URL and cannot sanitize bodies. Applications using this hook with body capture enabled MUST NOT rely on default body scrubbing; they SHOULD migrate to `maskCapturedNetworkRequestFn` to sanitize bodies or disable body capture. When both hooks are supplied, the modern callback takes precedence. Retaining default body scrubbing for the URL-only hook would be a separate SDK behavior change.

For the network capture masking callback, returning `null` or `undefined` MUST drop an ordinary non-initial replay network record and its derived server timings. For an initial performance entry, a nullish return MUST instead retain only required timing metadata, entry type, and the initial-entry flag with an empty URL; headers, bodies, and customer-controlled server timing data MUST NOT be retained. This fallback MUST use metadata preserved before invoking the callback, not callback-mutated values.

If the network capture masking callback throws, the SDK MUST catch the exception per record and drop that record and its derived server timings, including for initial entries. It MUST NOT record the unmasked input, use the default scrubber as a fallback, or retain a timing-only fallback for a thrown callback. Unrelated records in the same batch and subsequent batches MUST continue to be processed, and the exception MUST NOT escape the recorder. These rules affect replay records, not the application's HTTP requests.

#### Scenario: Default body scrubbing runs without a custom callback
- **GIVEN** browser replay body capture is enabled without either a modern or deprecated network masking callback
- **AND** an eligible request and response each have a body below the payload-size limit containing `{"password":"secret"}`
- **WHEN** the request is processed for replay capture
- **THEN** default body-content scrubbing redacts both bodies before they are attached to replay
- **AND** neither recorded body contains `secret`

#### Scenario: Custom body scrubbing replaces default heuristics rather than composing with them
- **GIVEN** browser replay body capture is enabled with a custom network masking callback
- **AND** an eligible request and response each have a body below the payload-size limit containing `{"author":"Ada","password":"secret"}`
- **AND** the callback parses each body as JSON, removes `password`, serializes the remaining object, and returns the request
- **WHEN** the request is processed for replay capture
- **THEN** the callback receives both original JSON bodies without default body-content redaction
- **AND** the recorded request and response bodies each contain `{"author":"Ada"}` and no `password` property
- **AND** the default `auth` substring heuristic does not redact `author` before or after the callback

#### Scenario: Deprecated URL-only masking also replaces default body scrubbing
- **GIVEN** browser replay body capture is enabled with only a deprecated `maskNetworkRequestFn` that returns its input URL unchanged
- **AND** an eligible non-initial request has a body below the payload-size limit containing `{"password":"secret"}`
- **WHEN** the request is processed for replay capture
- **THEN** the deprecated hook receives only the URL
- **AND** the recorded body remains `{"password":"secret"}` because the compatibility adapter bypasses default body-content scrubbing

#### Scenario: Mandatory header redaction runs before a custom callback
- **GIVEN** browser replay header capture is enabled with a custom network masking callback that returns its input
- **AND** an eligible request has an `Authorization` header and its response has a `Set-Cookie` header
- **WHEN** the request is processed for replay capture
- **THEN** neither original sensitive header value is present in the callback input; header names MAY remain with redacted values
- **AND** neither original sensitive header value is recorded in replay

#### Scenario: Mandatory payload-size limits run before a custom callback
- **GIVEN** browser replay body capture is enabled with a custom network masking callback that returns its input
- **AND** an eligible request and response each have a body exceeding the SDK payload-size limit
- **WHEN** the request is processed for replay capture
- **THEN** the callback receives size-limited replacements rather than either oversized body
- **AND** neither oversized body is recorded in replay

#### Scenario: Mandatory ingestion-path filtering cannot be bypassed by a custom callback
- **GIVEN** browser replay network capture is enabled with a custom network masking callback that returns its input
- **WHEN** a request to a PostHog ingestion path covered by mandatory filtering is processed for replay capture
- **THEN** the callback is not invoked for that request
- **AND** that request is not attached to replay

#### Scenario: A custom callback can drop an ordinary network request
- **GIVEN** browser replay network capture is enabled with a network capture masking callback that returns `null` or `undefined`
- **WHEN** an otherwise eligible non-initial fetch request is processed for replay capture
- **THEN** that request is not attached to replay
- **AND** its derived server timings are not attached to replay
- **AND** the default body scrubber is not used as a fallback for the callback's drop decision

#### Scenario: A nullish result for an initial entry retains only timing metadata
- **GIVEN** an initial performance entry contains a URL and customer-controlled server timings
- **AND** the network capture masking callback mutates its input and returns `null` or `undefined`
- **WHEN** the entry is processed for replay capture
- **THEN** only required timing metadata preserved before the callback, entry type, and the initial-entry flag are retained with an empty URL
- **AND** no headers, bodies, or customer-controlled server timing data are recorded

#### Scenario: A throwing callback drops only the affected record
- **GIVEN** a replay network batch contains unrelated records before and after a record with derived server timings
- **AND** the network capture masking callback throws for that record, whether it is initial or non-initial
- **WHEN** the batch is processed for replay capture
- **THEN** the affected record and its derived server timings are not recorded
- **AND** no unmasked input, default-scrubbed record, or timing-only fallback is recorded for the failure
- **AND** unrelated records before and after it and records in subsequent batches are processed normally
- **AND** the exception does not escape the recorder or interfere with the application's HTTP requests

### Requirement: Android secure windows are recorded fully masked

On Android, while a window captured by session replay is a **secure window** — its `WindowManager.LayoutParams` flags include `FLAG_SECURE` — the SDK SHALL record that window fully masked rather than skip it.

This applies to every SDK whose Android session replay captures that window, including wrapper SDKs that render replay frames themselves (posthog-flutter) or delegate capture to posthog-android (posthog-react-native, posthog-kmp). posthog-kmp conforms once its pinned posthog-android version includes this behavior. posthog-unity captures its own Android frames and does not implement this requirement yet; its conformance is a named follow-up. It is not applicable on iOS, which has no window-level secure flag and masks sensitive inputs per field under the existing rules.

Recording a secure window fully masked means the SDK SHALL record an opaque, solid black frame with the window's dimensions and MUST NOT record or upload any of the window's pixels. posthog-android before 4.0 also had a wireframe mode, where it recorded one masked node covering the window instead; 4.0 removed wireframe recording.

The SDK SHALL check the window's secure state when capture starts and again before the captured frame is recorded, and SHALL record the frame fully masked if the window was secure at either check.

The SDK MUST NOT record touch interactions that occur on a secure window. The touch MUST still be delivered to the application.

The SDK SHALL evaluate each window by its own flags. A window without `FLAG_SECURE`, such as a dialog shown over a secure activity, is captured under the normal masking rules.

#### Scenario: A secure window is recorded as a masked frame
- **GIVEN** Android session replay is recording
- **AND** the captured window has `FLAG_SECURE`
- **WHEN** a replay frame is captured
- **THEN** the recorded frame is fully masked with the window's dimensions
- **AND** the frame is solid black
- **AND** no pixels from the window are recorded or uploaded

#### Scenario: A window that becomes secure during capture is masked
- **GIVEN** Android session replay is recording
- **AND** the captured window does not have `FLAG_SECURE` when capture starts
- **WHEN** the window gains `FLAG_SECURE` before the captured frame is recorded
- **THEN** the recorded frame is fully masked

#### Scenario: A frame captured on a secure window stays masked after the flag clears
- **GIVEN** Android session replay is recording
- **AND** the captured window has `FLAG_SECURE` when capture starts
- **WHEN** the window loses `FLAG_SECURE` before the captured frame is recorded
- **THEN** the recorded frame is fully masked

#### Scenario: Touches on a secure window are not recorded
- **GIVEN** Android session replay is recording
- **AND** the window has `FLAG_SECURE`
- **WHEN** the user taps the window
- **THEN** no touch interaction is recorded for that tap
- **AND** the application still receives the tap

#### Scenario: A window without the flag follows the normal masking rules
- **GIVEN** Android session replay is recording
- **AND** a dialog window without `FLAG_SECURE` is shown over an activity window that has `FLAG_SECURE`
- **WHEN** a replay frame of the dialog window is captured
- **THEN** the dialog window is captured under the normal masking rules

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
`packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:1030-1041`).
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
live response of the process, the SDK MUST drop each frame not yet handed to the upload queue and
MUST NOT upload it. Those frames are:

- frames buffered before the first live remote config response, which were resolved against the
  cached config only
- frames held for the minimum recording duration
- a frame whose masks were computed under the previous resolved flags and which was not yet handed to
  the upload queue when the update arrived

A frame already handed to the upload queue is kept and uploaded. When no flag gets stricter, every
held frame is kept. An update that makes a resolved flag go from `true` to `false`
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
- **WHEN** a remote config update arrives with `masking.mobile.maskAllImages: true` before that frame is handed to the upload queue
- **THEN** that frame is not uploaded
- **AND** the next frame masks images

#### Scenario: A frame already in the upload queue is kept when a flag gets stricter
- **GIVEN** replay is recording with both resolved flags `false`
- **AND** a frame captured under those flags was already handed to the upload queue
- **WHEN** a remote config update arrives with `masking.mobile.maskAllText: true`
- **THEN** that frame is still uploaded
- **AND** frames captured after the update are masked

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

Reference: posthog-js `origin/main` `f05a993f9`, `packages/browser/src/extensions/replay/external/lazy-loaded-session-recorder.ts:682-713` (merge), `:721-764` (warning when a client value shadows a different project value), `:2980-2985` (applied at recorder start). Tests: `packages/browser/src/__tests__/extensions/replay/lazy-sessionrecording.test.ts:1030-1041` (client value overrides server value, in full and per field), `:6580` (remote masking options reach rrweb) and `:6729-6799` (shadow warning).

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

