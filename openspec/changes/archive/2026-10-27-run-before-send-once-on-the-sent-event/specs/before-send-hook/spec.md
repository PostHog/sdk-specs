## ADDED Requirements

### Requirement: Single before-send invocation on the event as sent

The SDK SHALL invoke the configured before-send hook chain exactly once per captured event. An event that reaches the hook SHALL NOT be passed through the chain a second time, including when a public capture entry point delegates to a shared internal or stateless capture path that also applies hooks.

The event handed to the hook SHALL be the event the SDK would send if the hook returned it unchanged. In particular:

- Group assignments collected through the SDK's group APIs SHALL already be merged into `$groups`.
- When minimized `$feature_flag_called` events are enabled, the event SHALL already be trimmed to the minimal property set.

The SDK SHALL enqueue the event the hook returned rather than rebuilding it from pre-hook values, so hook edits to the event name, properties, distinct ID, timestamp and event UUID are the values that are queued and delivered.

Wrapper SDKs that run a hook at a higher layer than the assembled native event remain subject to the documented wrapper-layer variation above: Flutter's Dart-layer hooks run before native or browser enrichment and do not apply to `$feature_flag_called` events.

#### Scenario: The hook chain runs once per captured event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** before-send is configured with a hook that records each invocation
- **WHEN** capture is called with event "Checkout Started"
- **THEN** the before-send hook should have been invoked once
- **AND** one event named "Checkout Started" should be enqueued

#### Scenario: Hook edits to the event identity are the ones queued
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** before-send sets the event distinct ID to "hooked-distinct-id"
- **WHEN** capture is called with event "Checkout Started"
- **THEN** one event named "Checkout Started" should be enqueued
- **AND** the enqueued event distinct ID should equal "hooked-distinct-id"

#### Scenario: The hook sees merged group assignments
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the event is captured with group "company" set to "acme"
- **AND** before-send records the event property "$groups"
- **WHEN** capture is called with event "Checkout Started"
- **THEN** the before-send hook should have observed group "company" with value "acme"

#### Scenario: The hook sees the minimized feature flag called event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** minimal feature flag called events are enabled
- **AND** before-send adds property "privacy" with value "filtered"
- **WHEN** a "$feature_flag_called" event is captured
- **THEN** the before-send hook should have observed the minimal feature flag called properties
- **AND** the enqueued event property "privacy" should equal "filtered"
