## MODIFIED Requirements

### Requirement: Canonical register behavior

The SDK SHALL implement the canonical `register` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Register adds super properties to future events
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** register is called with properties:
  | property | value |
  | plan     | pro   |
  | region   | eu    |
- **AND** capture is called with event "Viewed Dashboard"
- **THEN** the enqueued event properties should include:
  | property | value |
  | plan     | pro   |
  | region   | eu    |

#### Scenario: Later register calls override existing super properties
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** registered properties are:
  | property | value |
  | plan     | free  |
- **WHEN** register is called with properties:
  | property | value |
  | plan     | pro   |
- **THEN** registered property "plan" should equal "pro"

#### Scenario: Registered properties persist across SDK initialization
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** persistent storage contains registered properties:
  | property | value |
  | plan     | pro   |
- **WHEN** the SDK is initialized with token "test-token"
- **AND** capture is called with event "Loaded"
- **THEN** the enqueued event property "plan" should equal "pro"

#### Scenario: Per-event property overrides a registered property
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** registered properties are:
  | property | value |
  | plan     | free  |
- **WHEN** capture is called with event "Upgraded" and properties:
  | property | value |
  | plan     | pro   |
- **THEN** the enqueued event property "plan" should equal "pro"
- **AND** registered property "plan" should equal "free"
