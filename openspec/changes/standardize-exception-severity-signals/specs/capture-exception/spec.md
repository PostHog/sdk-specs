## ADDED Requirements

### Requirement: Explicit exception handled state

For every SDK-generated `$exception_list` entry, the SDK SHALL serialize `mechanism.handled` as a boolean when the capture boundary knows whether application code handled the exception. The SDK SHALL use `true` for a public/manual capture of a caught exception or a logger/console call, and SHALL use `false` for an exception that crosses an uncaught application boundary. When the capture boundary cannot determine handled state, the SDK SHALL omit `mechanism.handled`; it MUST NOT serialize an unknown state as `false`.

When one capture attempt serializes a cause chain, the SDK SHALL apply the same known handled state to every generated entry because the value describes the capture boundary. A top-level `$exception_handled` property does not replace the nested mechanism field.

#### Scenario: Manual capture marks every exception handled (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **AND** the caught exception "WrapperError" wraps a cause "RootError"
- **WHEN** capture exception is called for "WrapperError"
- **THEN** one event named "$exception" should be enqueued
- **AND** every entry in the enqueued event's exception list should have `mechanism.handled` equal to `true`

#### Scenario: Uncaught capture marks every exception unhandled (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **AND** an automatic exception integration observes an exception crossing an uncaught application boundary
- **WHEN** the integration captures the exception
- **THEN** one event named "$exception" should be enqueued
- **AND** every entry in the enqueued event's exception list should have `mechanism.handled` equal to `false`

#### Scenario: Unknown handled state remains absent (@both)
- **GIVEN** a low-level exception payload producer that cannot determine whether application code handled the exception
- **WHEN** the producer creates a `$exception` event
- **THEN** the generated exception mechanism should omit `handled`
- **AND** the producer should not default `handled` to `false`

### Requirement: Canonical exception level

When an SDK-generated `$exception` capture path knows the source severity, the SDK SHALL serialize event-level `$exception_level` using one of `fatal`, `error`, `warning`, `log`, `info`, or `debug`. The SDK SHALL normalize native severity names as follows: `fatal`, `critical`, `alert`, and `emergency` to `fatal`; `warning` and `warn` to `warning`; `notice` and `info` to `info`; `trace` and `debug` to `debug`; and `error` and `log` to themselves.

When source severity is missing or unrecognized, the SDK SHALL omit `$exception_level`; it MUST NOT guess a fallback level. Receivers MAY accept legacy aliases, but first-party SDK-generated output SHALL use the canonical vocabulary.

#### Scenario: Native warning level is normalized (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **WHEN** a logger or console integration captures a `warn` record as an exception
- **THEN** one event named "$exception" should be enqueued
- **AND** the enqueued event property `$exception_level` should equal `warning`

#### Scenario: Native critical level is normalized (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **WHEN** a logger integration captures a `critical` record as an exception
- **THEN** one event named "$exception" should be enqueued
- **AND** the enqueued event property `$exception_level` should equal `fatal`

#### Scenario: Unknown source level remains absent (@both)
- **GIVEN** a low-level exception payload producer with no recognized source severity
- **WHEN** the producer creates a `$exception` event
- **THEN** the generated event should omit `$exception_level`
- **AND** the producer should not default `$exception_level` to `error`

### Requirement: Capture-boundary exception signals

An SDK-owned capture path SHALL set `$exception_level` and `mechanism.handled` from the boundary that created the event:

- public/manual capture of a caught exception SHALL default to `error` and `true`;
- logger or console capture SHALL use the normalized source level and `true`;
- an uncaught request, task, thread, promise, or process boundary that may continue SHALL use `error` and `false`;
- a crash, panic, or uncaught boundary expected to terminate the app or process SHALL use `fatal` and `false`.

If a typed exception-capture API accepts an explicit supported level, the SDK SHALL normalize and preserve that level instead of the boundary's default. These signals SHALL NOT affect exception grouping or fingerprint construction.

#### Scenario: Manual capture emits handled error signals (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **WHEN** capture exception is called for a caught exception without an explicit level
- **THEN** one event named "$exception" should be enqueued
- **AND** the enqueued event property `$exception_level` should equal `error`
- **AND** every entry in the exception list should have `mechanism.handled` equal to `true`

#### Scenario: Non-fatal uncaught boundary emits unhandled error signals (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **AND** an automatic integration observes an uncaught exception without terminating the app or process
- **WHEN** the integration captures the exception
- **THEN** one event named "$exception" should be enqueued
- **AND** the enqueued event property `$exception_level` should equal `error`
- **AND** every entry in the exception list should have `mechanism.handled` equal to `false`

#### Scenario: Terminating failure emits fatal unhandled signals (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **AND** an automatic integration observes a crash, panic, or uncaught exception expected to terminate the app or process
- **WHEN** the integration captures the failure
- **THEN** one event named "$exception" should be enqueued
- **AND** the enqueued event property `$exception_level` should equal `fatal`
- **AND** every entry in the exception list should have `mechanism.handled` equal to `false`

#### Scenario: Logger capture preserves severity and remains handled (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **WHEN** a logger or console integration captures a warning record as an exception
- **THEN** one event named "$exception" should be enqueued
- **AND** the enqueued event property `$exception_level` should equal `warning`
- **AND** every entry in the exception list should have `mechanism.handled` equal to `true`

#### Scenario: Explicit supported level overrides the manual default (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **AND** the SDK exposes a typed exception-level override
- **WHEN** capture exception is called for a caught exception with level `warning`
- **THEN** one event named "$exception" should be enqueued
- **AND** the enqueued event property `$exception_level` should equal `warning`
- **AND** every entry in the exception list should have `mechanism.handled` equal to `true`
