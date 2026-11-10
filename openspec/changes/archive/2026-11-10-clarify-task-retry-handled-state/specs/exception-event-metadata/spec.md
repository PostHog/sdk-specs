## MODIFIED Requirements

### Requirement: Explicit exception handled state

The outermost exception SHALL serialize `mechanism.handled` when the capture boundary knows whether the exception escaped the relevant application boundary. It SHALL use `true` when application code deliberately reports or consumes the exception at that boundary, including manual capture, deliberate logger or console capture, and a framework handler that converts the failure into an application response. It SHALL use `false` when the exception escapes that application boundary.

For a framework-managed background job retry, the relevant application boundary SHALL include the framework's job execution and retry handler, not only the user job method. If an integration reports an exception consumed by that handler while scheduling another execution without letting the exception escape job execution, the outermost exception SHALL have `mechanism.handled` equal to `true`. If the exception escapes job execution, including after retry exhaustion without a consuming handler, it SHALL have `mechanism.handled` equal to `false`. This requirement does not require integrations to emit exception events for retries or change their reporting defaults.

A framework, SDK, global handler, or crash reporter observing an exception does not by itself make the exception handled. When handled state is unknown, the producer SHALL omit `mechanism.handled`; it MUST NOT serialize unknown as `false`. A top-level `$exception_handled` property does not replace the nested mechanism field.

Each nested entry SHALL preserve its own independently known handled state. Being wrapped, unwrapped, grouped, suppressed, or reached as a cause does not by itself establish that nested entry's handled state. Unless the runtime or integration supplies an independent disposition for the nested entry, the producer SHALL omit its `mechanism.handled`. It MUST NOT copy, invert, or otherwise derive the value solely from the outermost entry.

#### Scenario: Manual capture marks the outermost exception handled (@both)
- **WHEN** the public exception API captures a caught exception
- **THEN** the outermost exception should have `mechanism.handled` equal to `true`

#### Scenario: Framework handler that consumes a failure is handled (@both)
- **GIVEN** a framework exception handler converts an exception into an application response
- **WHEN** the handler captures the exception
- **THEN** the outermost exception should have `mechanism.handled` equal to `true`

#### Scenario: Framework retry handler consumes the job failure (@server)
- **GIVEN** a job method raises an exception
- **AND** the framework retry handler consumes it and schedules another execution without letting the exception escape job execution
- **WHEN** the integration reports that retry failure
- **THEN** the outermost exception should have `mechanism.handled` equal to `true`

#### Scenario: Exhausted retry failure escapes job execution (@server)
- **GIVEN** a job has exhausted its retry attempts
- **AND** no framework or application handler consumes the terminal exception
- **WHEN** the integration reports the exception escaping job execution
- **THEN** the outermost exception should have `mechanism.handled` equal to `false`

#### Scenario: Exception escaping application code is unhandled (@both)
- **GIVEN** infrastructure observes an exception after it escapes the relevant application boundary
- **WHEN** the infrastructure captures the exception
- **THEN** the outermost exception should have `mechanism.handled` equal to `false`

#### Scenario: Unknown nested handled state remains absent (@both)
- **GIVEN** a producer knows the outermost handled state but not a nested exception's handled state
- **WHEN** it serializes both entries
- **THEN** the nested exception should omit `mechanism.handled`
- **AND** the producer should not infer handled state from the nested exception being a cause or member
