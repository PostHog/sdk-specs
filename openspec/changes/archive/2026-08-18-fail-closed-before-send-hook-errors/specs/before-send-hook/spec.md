## MODIFIED Requirements

### Requirement: Canonical before-send-hook behavior

The SDK SHALL implement the canonical `before-send-hook` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

If any before-send hook throws, the SDK SHALL catch the exception, record a warning, stop the remaining hook chain, and drop the event. The SDK MUST NOT enqueue the original event or the last successfully transformed value because the failed hook may have been responsible for removing sensitive data.

#### Scenario: Before-send can mutate an assembled event before enqueue
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** before-send adds property "privacy" with value "filtered"
- **WHEN** capture is called with event "Checkout Started"
- **THEN** one event named "Checkout Started" should be enqueued
- **AND** the enqueued event property "privacy" should equal "filtered"

#### Scenario: Before-send can drop an event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** before-send drops events named "Secret Event"
- **WHEN** capture is called with event "Secret Event"
- **THEN** no event named "Secret Event" should be enqueued

#### Scenario: Before-send exceptions stop the chain and drop transformed events
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** before-send is configured with a hook chain that transforms the event, then throws, then records invocation
- **WHEN** capture is called with event "Safe Event"
- **THEN** the capture call should not throw
- **AND** no event should be enqueued
- **AND** no network request should be sent
- **AND** the final before-send hook should not be invoked
- **AND** the SDK should record a before-send warning
