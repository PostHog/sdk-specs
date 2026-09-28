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
  screenshotMode?: boolean
  screenshot?: boolean
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

1. **Default to masking sensitive UI.** Replay capture masks text input values by default. Native/mobile implementations also default to masking textual content and images, or at least password/sensitive inputs, unless the local replay configuration disables those categories.
2. **Honor explicit mask markers.** Elements/views tagged with PostHog masking markers such as `ph-no-capture`, `postHogMask(...)`, `Modifier.postHogMask(...)`, or wrapper components are treated as masked even when broad category masking is disabled.
3. **Honor explicit unmask markers where supported.** Platform-specific unmask controls such as iOS `postHogNoMask()` and Android `Modifier.postHogUnmask(...)` take precedence over automatic category masking and prevent that subtree/node from being redacted.
4. **Apply masks before serialization/upload.** Browser replay passes masking/blocking options into the rrweb recorder before DOM/input events are serialized. Native screenshot replay computes mask rectangles from the current view/render tree and paints opaque masks over screenshots before image encoding. Native wireframe replay replaces sensitive text values with masked strings and omits or placeholders sensitive image content before wireframes are converted to dictionaries/payloads. Mask rectangle/element discovery MUST traverse the full matched subtree and include every element that matches a masking rule — not only the first match encountered, and not skipping nodes because a traversal shortcut (e.g. only descending into children that themselves have multiple children) happened to bypass them; a masked wrapper's own rect must be included alongside its matching descendants' rects.
5. **Support remote and local masking configuration.** Browser replay merges client `session_recording` masking settings with remote replay masking config, with client-provided values taking precedence. Native/mobile SDKs expose local replay config for text/image masking; remote config may separately control whether replay runs, but masking categories are applied by the local replay capture path where implemented.
6. **Preserve privacy in screenshot mode.** Screenshot-based recorders must discover sensitive rectangles synchronously with capture where possible and draw masks into the screenshot bitmap/canvas before converting it to base64/PNG/WebP. If a concurrent screen change makes mask rectangles unreliable, implementations should discard that snapshot rather than upload a potentially stale/unmasked image.
7. **Treat password and sensitive controls specially.** Password/secure text fields remain masked even when broad text masking is disabled. Native implementations inspect secure text traits/input types or obscured text widgets in addition to global masking settings.
8. **Treat images conservatively when configured.** Mobile screenshot/wireframe implementations mask image views or render-image objects when image masking is enabled, while allowing platform-specific heuristics for safe bundled assets or symbols.
9. **Apply mandatory replay network protections.** Browser network replay capture is opt-in for headers/bodies. Sensitive-header redaction (including authorization, cookies, API keys, and CSRF tokens), payload-size limits, and PostHog ingestion-path filtering apply regardless of custom masking and run before a custom callback. Existing host exclusions remain in force. A request dropped by mandatory filtering does not reach the callback.
10. **Allow custom body scrubbing to replace default body scrubbing.** Without a custom callback, eligible request and response bodies pass through the default body-content scrubber. When `maskCapturedNetworkRequestFn` is supplied, it replaces that scrubber: default keyword and other body-content heuristics run neither before nor after the callback. The callback is responsible for sanitizing retained bodies and can modify or drop the request; its inputs have already undergone mandatory cleaning and can contain absent bodies or size-limit replacement markers. Deprecated URL/request masking hooks remain compatibility shims where supported.
11. **Fail closed for uncertain snapshots.** Mask tree discovery/parsing failures, missing contexts, invalid images, timeout/cancellation, or screen changes should skip the affected replay snapshot or emit no maskable payload rather than crash the app or send known-sensitive unredacted data.

## State & lifecycle

### State read

- replay masking config from local SDK config and, where supported, remote replay config
- browser DOM classes/selectors and rrweb masking options
- native view hierarchy, accessibility labels/tags/content descriptions, SwiftUI/Compose semantics, Flutter render tree, and current screenshot/root context
- secure/password input metadata and text/image widget types
- optional replay network-capture settings and masking callbacks

### State written

- recorder masking/blocking options supplied to the replay engine
- mask rectangles collected for screenshot capture
- masked wireframe text/image values
- redacted network request/response headers and bodies
- framework-specific marker state on views/layers/semantics nodes

### Lifecycle behavior

- **Setup:** replay privacy configuration is installed when session replay starts or the replay recorder is initialized.
- **Capture:** every DOM event, wireframe snapshot, screenshot, or replay network event is filtered/redacted before serialization.
- **Remote-config update:** browser replay can update masking and network-capture options from remote config while preserving local overrides.
- **View updates:** explicit mask/unmask modifiers update marker state as UI nodes mount, change, or unmount.
- **Teardown:** stopping replay stops further capture; marker state on app views remains framework-owned unless removed by the modifier/component lifecycle.

## Error handling

- Invalid or unavailable view/screenshot/render-tree state causes that snapshot or mask pass to be skipped and logged where the SDK has a logger.
- Browser missing rrweb record support logs an error and avoids starting capture.
- Network masking callbacks may drop a request by returning `undefined`; mandatory header redaction, payload-size limiting, and ingestion-path filtering run first. Default body-content scrubbing does not run as a fallback for a callback's drop decision.
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

For browser replay network capture, the SDK MUST apply mandatory sensitive-header redaction, payload-size limits, and PostHog ingestion-path filtering regardless of whether a custom `session_recording.maskCapturedNetworkRequestFn` is supplied. These protections MUST run before invoking a custom callback; requests dropped by mandatory filtering MUST NOT reach that callback. Existing capture opt-ins and host exclusions remain in force.

When no custom callback is supplied, the SDK MUST apply its default body-content scrubber to eligible request and response bodies after mandatory cleaning. When a custom callback is supplied, it MUST replace the default body-content scrubber: the SDK MUST NOT run default keyword or other body-content heuristics either before or after that callback. The callback is responsible for sanitizing the request and response bodies it retains and MAY modify or drop a request. Callback inputs can still contain absent bodies or size-limit replacement markers produced by mandatory cleaning; replacing default scrubbing does not bypass those protections.

#### Scenario: Default body scrubbing runs without a custom callback
- **GIVEN** browser replay body capture is enabled without a custom network masking callback
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

#### Scenario: Mandatory header redaction runs before a custom callback
- **GIVEN** browser replay header capture is enabled with a custom network masking callback that returns its input
- **AND** an eligible request has an `Authorization` header and its response has a `Set-Cookie` header
- **WHEN** the request is processed for replay capture
- **THEN** neither sensitive header is present in the callback input
- **AND** neither sensitive header is recorded in replay

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
- **GIVEN** browser replay network capture is enabled with a custom network masking callback that returns `undefined`
- **WHEN** an otherwise eligible non-initial fetch request is processed for replay capture
- **THEN** that request is not attached to replay
- **AND** the default body scrubber is not used as a fallback for the callback's drop decision
