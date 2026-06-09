# Autocapture Specification

## Purpose

Autocapture is a client-side integration that automatically records user interface interactions without requiring callers to invoke `capture(...)` for every click, tap, control change, or gesture. It is intended to provide coarse interaction analytics by observing platform UI events, extracting a sanitized element hierarchy, and emitting normal analytics events through the SDK capture pipeline.

This component is separate from public `capture(...)`, `screen(...)`, session replay, surveys, exception autocapture, and application lifecycle capture. It may be installed alongside those systems, but its canonical event is `$autocapture` for UI interactions. Platform-specific rage-click/dead-click extensions may emit related events such as `$rageclick`, but those are supplemental to the core autocapture interaction path.

## Applicability

Client SDKs that can observe UI interactions in the host runtime. The canonical behavior is grounded in browser DOM autocapture, React Native touch autocapture, and iOS/UIKit autocapture. Server SDKs are outside this component's scope because they do not own a UI event stream. Client SDKs that only provide automatic screen-view or lifecycle capture, but no generic interaction autocapture, should document that generic interaction autocapture is unsupported rather than treating `screen(...)` or lifecycle events as a replacement.

## Configuration surface

Autocapture is configured during SDK setup. The exact option names and defaults vary by platform, but canonical implementations provide a way to disable interaction collection and to tune what element metadata is captured.

```ts
type AutocaptureConfig =
  | boolean
  | {
      // Whether to capture interaction events for this platform/runtime.
      captureTouches?: boolean
      captureElementInteractions?: boolean

      // Element matching and privacy controls.
      noCaptureSelectorOrProp?: string
      allowlist?: string[]
      ignorelist?: string[]
      elementAttributeIgnorelist?: string[]
      maskText?: boolean
      maskElementAttributes?: boolean

      // Element labelling and payload-size controls.
      customLabelProp?: string
      maxElementsCaptured?: number
      propsToCapture?: string[]
    }
```

Browser SDKs commonly expose a top-level `autocapture` option plus DOM-specific selector, URL, text, and attribute controls. React Native exposes provider-level `autocapture` options for touch capture and label/ignore props. iOS exposes `captureElementInteractions` and view-label APIs, with swizzling required for the integration to install.

## Behavior

When enabled, the SDK installs platform event observers during setup and processes each eligible interaction as follows:

1. **Observe platform UI events**
   - Browser SDKs attach DOM listeners for interaction events such as `click`, `change`, and `submit`, with optional copy/cut capture and rage-click detection.
   - React Native provider-based setup listens for captured touch-end events and walks the React component/Fiber ancestry for the touched target.
   - iOS installs swizzled UIKit hooks for controls, gesture recognizers, scroll views, picker delegates, and text-editing notifications.
2. **Filter ineligible events**
   - Do not capture when autocapture is disabled by local config, remote config, opt-out/disabled instance state, unsupported runtime checks, or missing event targets.
   - Respect explicit no-capture markers on the target or ancestor chain (`ph-no-capture`-style classes/props or platform-specific view markers).
   - Ignore sensitive controls and values such as password fields or values that look unsafe to collect where the platform implementation can detect them.
   - Apply allowlists/ignorelists, URL filters, content filters, and maximum hierarchy sizes where configured.
3. **Build element metadata**
   - Walk from the target element/view/component toward its ancestors until the platform-specific root or configured maximum is reached.
   - Include a sanitized hierarchy representation. Browser and iOS provide an `$elements_chain` string; browser and React Native may provide an `$elements` array of element objects.
   - Include stable non-sensitive metadata such as tag/class/type names, configured labels, selected safe attributes/props, hierarchy positions, and safe visible text.
   - Include interaction metadata such as `$event_type`, touch coordinates, current screen name, selected content for copy/cut capture, or external-link URL when available.
4. **Emit analytics**
   - Emit `$autocapture` through the ordinary SDK capture/enqueue pipeline with the current distinct id and standard SDK context.
   - Autocapture events should inherit consent/opt-out gating, super-property/context enrichment, before-send hooks, queueing, batching, retry, and debug logging behavior unless a wrapper documents that it bypasses a wrapper-layer hook.
   - Supplemental interaction classifiers such as rage-click detection may emit their own fixed event names while reusing the same target filtering and element-metadata model.

## State & lifecycle

- The integration is installed during setup when the relevant local/remote gates allow it.
- Browser autocapture waits for remote configuration before enabling by default unless flag loading is disabled; it persists and caches the server-side `autocapture_opt_out` state.
- React Native touch autocapture is provider-owned; it is enabled by provider render options and is tied to the provider's React event handler lifecycle.
- iOS autocapture is process-global because UIKit swizzling is global; only one autocapture event processor should be active at a time, and uninstall should remove hooks or clear the processor where possible.
- The component does not own long-lived identity or session state. It reads the current SDK identity/session/context from the normal capture pipeline at event time.

## Error handling

Autocapture must not crash the host application. Failures while inspecting event targets, styles, attributes, component props, or view hierarchies should be swallowed or logged in debug mode and should drop only the affected autocapture event or field. If a target cannot be resolved or no useful element metadata remains after filtering, no event should be emitted.

## Concurrency & ordering guarantees

Autocapture preserves the host runtime's event ordering only up to the SDK queue boundary. It should enqueue each accepted interaction in the order the observer processes it, but network delivery follows the SDK's normal batching/retry guarantees.

High-frequency controls should be debounced or otherwise constrained where the platform can identify them, so sliders, scroll views, and similar controls do not emit unbounded interaction streams. Repeated setup should avoid installing duplicate DOM listeners, React handlers, or global swizzles.

## Interactions

- **Capture pipeline**: autocapture events are ordinary analytics captures with a fixed event name and generated properties.
- **Consent gating**: local opt-out/disabled state and server-side remote gates should prevent autocapture emission.
- **Persistent storage / remote config**: browser implementations may persist server-side autocapture opt-out state; other platforms may rely on setup-time config.
- **Session replay privacy**: no-capture and masking markers can overlap with replay privacy markers, but autocapture should still apply its own event-filtering and text/attribute sanitization.
- **Screen tracking**: current screen/route names may be added to autocapture properties, but automatic screen-view events remain part of the separate `screen(...)` / screen-view tracking surface.
- **Application lifecycle**: foreground/background/install/update telemetry is separate from interaction autocapture.

## Requirements

### Requirement: Canonical autocapture behavior

The SDK SHALL implement the canonical `autocapture` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Eligible UI interaction emits an autocapture event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and autocapture enabled
- **WHEN** the user interacts with an element described by:
  | field      | value        |
  | tag        | button       |
  | label      | Sign up      |
  | screen     | Home         |
- **THEN** one event named "$autocapture" should be enqueued
- **AND** the enqueued event properties should include:
  | property       | value   |
  | $event_type    | click   |
  | $screen_name   | Home    |
- **AND** the enqueued event should include sanitized element hierarchy metadata

#### Scenario: No-capture markers suppress autocapture
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and autocapture enabled
- **WHEN** the user interacts with an element marked no-capture
- **THEN** no event named "$autocapture" should be enqueued

#### Scenario: Sensitive input values are not captured
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and autocapture enabled
- **WHEN** the user interacts with a password input containing "secret-password"
- **THEN** no enqueued autocapture property should contain "secret-password"

#### Scenario: Repeated setup does not install duplicate autocapture observers
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and autocapture enabled
- **WHEN** setup is called again with autocapture enabled
- **AND** the user interacts with an element described by:
  | field | value  |
  | tag   | button |
- **THEN** exactly one event named "$autocapture" should be enqueued for that interaction
