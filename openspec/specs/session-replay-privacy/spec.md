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
4. **Apply masks before serialization/upload.** Browser replay passes masking/blocking options into the rrweb recorder before DOM/input events are serialized. Native screenshot replay computes mask rectangles from the current view/render tree and paints opaque masks over screenshots before image encoding. Native wireframe replay replaces sensitive text values with masked strings and omits or placeholders sensitive image content before wireframes are converted to dictionaries/payloads.
5. **Support remote and local masking configuration.** Browser replay merges client `session_recording` masking settings with remote replay masking config, with client-provided values taking precedence. Native/mobile SDKs expose local replay config for text/image masking; remote config may separately control whether replay runs, but masking categories are applied by the local replay capture path where implemented.
6. **Preserve privacy in screenshot mode.** Screenshot-based recorders must discover sensitive rectangles synchronously with capture where possible and draw masks into the screenshot bitmap/canvas before converting it to base64/PNG/WebP. If a concurrent screen change makes mask rectangles unreliable, implementations should discard that snapshot rather than upload a potentially stale/unmasked image.
7. **Treat password and sensitive controls specially.** Password/secure text fields remain masked even when broad text masking is disabled. Native implementations inspect secure text traits/input types or obscured text widgets in addition to global masking settings.
8. **Treat images conservatively when configured.** Mobile screenshot/wireframe implementations mask image views or render-image objects when image masking is enabled, while allowing platform-specific heuristics for safe bundled assets or symbols.
9. **Redact replay network payloads where captured.** Browser network replay capture is opt-in for headers/bodies and runs deny-list/scrubbing logic before custom masking hooks. Authorization, cookies, API keys, CSRF tokens, known sensitive payload keywords, oversized payloads, PostHog ingestion paths, and default denied hosts are removed, redacted, limited, or dropped before data is attached to replay.
10. **Allow user-defined network masking on top of enforced cleaning.** Browser `maskCapturedNetworkRequestFn` can modify or drop a cleaned network request. Deprecated URL/request masking hooks are treated as compatibility shims where still supported.
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
- Network masking callbacks may drop a request by returning `undefined`; enforced cleaners run before custom masking so sensitive headers and PostHog ingestion loops are still guarded.
- Native/mobile implementations should avoid throwing into application UI code from mask discovery or screenshot masking paths.

## Concurrency & ordering guarantees

- Masks must be computed against the same UI state that is serialized or screenshotted. If the UI changes during capture and the implementation can detect that race, it should discard the snapshot.
- Explicit unmask markers take precedence over explicit mask markers and global category masks where a platform exposes both concepts.
- Enforced replay-network redaction happens before custom user masking callbacks.
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
