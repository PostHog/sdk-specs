## MODIFIED Requirements

### Requirement: Canonical capture-exception behavior

The SDK SHALL implement the canonical `capture-exception` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

The canonical exception type and message for a standard captured exception SHALL be represented by the primary exception entry at `$exception_list[0].type` and `$exception_list[0].value`. Legacy top-level `$exception_type` and `$exception_message` properties are not required for standard capture paths. SDKs MAY continue to emit them for compatibility, but SDKs and consumers MUST treat `$exception_list` as the source of truth when it is present.

#### Scenario: Capturing a handled exception emits an exception event (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the test exception has stack information
- **WHEN** capture exception is called for an exception with type "TypeError" and message "boom"
- **THEN** one event named "$exception" should be enqueued
- **AND** the enqueued event's exception list should have "TypeError" at index 0
- **AND** the enqueued event's primary exception message should be "boom"
- **AND** the enqueued event should include exception stack information
