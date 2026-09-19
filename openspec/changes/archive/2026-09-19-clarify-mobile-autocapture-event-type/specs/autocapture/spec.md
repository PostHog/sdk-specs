## MODIFIED Requirements

### Requirement: Canonical autocapture behavior

The SDK SHALL implement the canonical `autocapture` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

For eligible tap/touch interactions captured by mobile touch autocapture (including Android, iOS, and React Native), the SDK SHALL emit `$event_type: touch`. For eligible browser click interactions, the SDK SHALL emit `$event_type: click`, including clicks captured by React Native Web. These values describe the captured interaction, not merely the SDK name: other supported interactions retain their platform-specific event types (for example, browser `change`/`submit` or iOS `value_changed`/`swipe`). The event name SHALL remain `$autocapture`.

#### Scenario: Eligible browser click emits an autocapture event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and autocapture enabled
- **WHEN** the user clicks a browser element described by:
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

#### Scenario: Eligible mobile touch emits an autocapture event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and autocapture enabled
- **WHEN** the user taps a mobile element handled by touch autocapture described by:
  | field      | value        |
  | tag        | button       |
  | label      | Sign up      |
  | screen     | Home         |
- **THEN** one event named "$autocapture" should be enqueued
- **AND** the enqueued event properties should include:
  | property       | value   |
  | $event_type    | touch   |
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
