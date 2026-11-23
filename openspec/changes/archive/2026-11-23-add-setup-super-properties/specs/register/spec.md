## ADDED Requirements

### Requirement: Setup-seeded super properties share the register store

On client SDKs (and server SDKs that expose runtime `register()`), super properties provided in setup configuration (`superProperties`, see `setup` — **Super properties at setup**) SHALL be written into the same super-properties store managed by `register(...)` and `unregister(...)` (and `reset()`, where supported):

- A subsequent `register(...)` call for the same key SHALL overwrite the setup-seeded value.
- A subsequent `unregister(key)` call SHALL remove the setup-seeded key from future events in that session.
- On SDKs that support `reset()`, a subsequent `reset()` call SHALL clear setup-seeded super properties along with other registered super properties for the remainder of that session.
- Setup-seeded keys SHALL obey the same validation, sanitization, reserved-key handling, persistence (where supported by the SDK's `register()` store), and per-event precedence rules as keys passed to `register(...)`.

#### Scenario: Runtime register, unregister, and reset mutate setup-seeded super properties (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** setup is called with token "test-token" and super properties:
  | property    | value      |
  | environment | production |
  | plan        | free       |
  | campaign    | launch     |
- **WHEN** register is called with properties:
  | property | value |
  | plan     | pro   |
- **AND** unregister is called for property "campaign"
- **AND** capture is called with event "After Mutation"
- **THEN** the enqueued "After Mutation" event properties should include:
  | property    | value      |
  | environment | production |
  | plan        | pro        |
- **AND** the enqueued "After Mutation" event should omit property "campaign"
- **WHEN** reset is called
- **AND** capture is called with event "After Reset"
- **THEN** the enqueued "After Reset" event should omit properties "environment" and "plan"
