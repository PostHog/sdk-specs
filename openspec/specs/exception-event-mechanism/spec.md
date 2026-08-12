# Exception Event Mechanism Specification

## Purpose

`exception-event-mechanism` standardizes all common metadata in `$exception_list[].mechanism` for SDK-generated `$exception` events: capture type, handled state, source, and synthetic state.

The capability also defines the related event-level `$exception_level` because SDKs derive severity and mechanism metadata at the same capture boundary. It defines producer behavior only and does not prescribe downstream classification, grouping, or presentation.

## Applicability

`both` — this is internal wire behavior for client and server SDKs that generate `$exception` events. It applies to SDK-owned public/manual and automatic capture paths. Low-level builders without capture-boundary context omit metadata they cannot determine.

The client-only public `capture-exception` capability remains responsible for its API surface. This capability specifies metadata on the resulting event and on automatic events that have no public API call.

## Requirements

### Requirement: Canonical exception mechanism object

When an SDK has mechanism metadata for an exception, it SHALL serialize that metadata as an object at `$exception_list[].mechanism`. The common fields are:

- `type`: a non-empty string naming the capture mechanism;
- `handled`: a boolean describing whether application code handled the exception;
- `source`: a non-empty string naming the more specific origin or relationship when known;
- `synthetic`: a boolean describing whether instrumentation synthesized the exception or stack.

A producer SHALL omit any common field whose value it cannot determine; it MUST NOT represent an unknown value with `false`, an empty string, or `null`. A low-level builder SHALL preserve caller- or integration-supplied common mechanism fields instead of reconstructing a smaller object that drops metadata. Producers MAY include additional JSON-safe platform fields, but this capability does not define their cross-SDK meaning.

#### Scenario: Known mechanism metadata uses canonical field types (@both)
- **WHEN** an SDK-owned capture path creates a `$exception` event with known mechanism metadata
- **THEN** each emitted common mechanism field should use its defined JSON type
- **AND** the mechanism object should not contain null placeholders for unknown fields

#### Scenario: Low-level builder preserves supplied mechanism metadata (@both)
- **GIVEN** a capture integration supplies mechanism `type`, `handled`, `source`, and `synthetic`
- **WHEN** a low-level builder creates the `$exception_list`
- **THEN** the resulting exception mechanism should preserve all four fields and values

#### Scenario: Unknown mechanism fields remain absent (@both)
- **GIVEN** a low-level exception payload producer has no capture-boundary context
- **WHEN** the producer creates a `$exception` event without caller-supplied mechanism metadata
- **THEN** the generated exception mechanism should omit `type`, `handled`, `source`, and `synthetic`
- **AND** the producer should not invent fallback mechanism metadata

### Requirement: Stable mechanism type and source

Every SDK-owned capture boundary SHALL set `mechanism.type` to a stable, non-empty identifier when it knows how the exception was captured. Public or manual capture SHALL use `generic` unless a more specific integration type is known. Automatic integrations SHALL use a stable identifier for their boundary, such as `onuncaughtexception`, `onunhandledrejection`, `onconsole`, `middleware`, `panic`, `signal`, or an equivalent platform-specific name.

The mechanism type identifies the capture path, not the exception class, severity, or handled state. The vocabulary is extensible; SDKs MUST NOT rewrite an unknown non-empty integration type to `generic`.

When an integration knows a more specific origin or relationship than `type` expresses, it SHALL preserve that value in `mechanism.source`. Source values are platform-specific non-empty strings. SDKs SHALL omit `source` when no source is known instead of copying `type` or inventing a generic source.

#### Scenario: Manual capture uses the generic mechanism (@both)
- **WHEN** the SDK's public exception API captures a caught exception without a more specific integration type
- **THEN** the outermost exception should have `mechanism.type` equal to `generic`

#### Scenario: Automatic integration preserves type and source (@both)
- **GIVEN** an automatic integration supplies a stable mechanism type and source
- **WHEN** the integration captures an exception
- **THEN** the outermost exception should preserve both values
- **AND** the SDK should not replace the type with `generic`

#### Scenario: Unknown source remains absent (@both)
- **GIVEN** a capture boundary knows its mechanism type but has no more specific source
- **WHEN** the SDK creates the exception mechanism
- **THEN** the mechanism should omit `source`

### Requirement: Explicit exception handled state

The outermost exception at `$exception_list[0]` SHALL serialize `mechanism.handled` when the capture boundary knows whether application code handled it. Public or manual capture of a caught exception and deliberate logger or console capture SHALL use `true`. An exception that crosses an uncaught application boundary SHALL use `false`.

Each additional cause-chain entry SHALL serialize its own known handled state. A producer MUST NOT infer a nested entry's handled state solely from the outermost entry. When handled state is unknown, the SDK SHALL omit `mechanism.handled`; it MUST NOT serialize an unknown state as `false`. A top-level `$exception_handled` property does not replace the nested mechanism field.

#### Scenario: Manual capture marks the outermost exception handled (@both)
- **WHEN** the SDK's public exception API captures a caught exception
- **THEN** the outermost exception should have `mechanism.handled` equal to `true`

#### Scenario: Uncaught capture marks the outermost exception unhandled (@both)
- **GIVEN** an automatic integration observes an exception crossing an uncaught application boundary
- **WHEN** the integration captures the exception
- **THEN** the outermost exception should have `mechanism.handled` equal to `false`

#### Scenario: Unknown handled state remains absent (@both)
- **GIVEN** a low-level exception payload producer has no capture-boundary context
- **WHEN** the producer creates a `$exception` event without caller-supplied handled state
- **THEN** the generated mechanism should omit `handled`
- **AND** the producer should not default `handled` to `false`

### Requirement: Explicit synthetic state

When the SDK knows whether it synthesized an exception representation or stack, it SHALL serialize `mechanism.synthetic` as a boolean. It SHALL use `true` when instrumentation creates the represented exception or captures a current stack because the original input has no usable stack. It SHALL use `false` when the payload represents an actual runtime exception and preserves its real stack or lack of stack.

When the producer cannot distinguish those cases, it SHALL omit `synthetic`; it MUST NOT default an unknown state to `false`.

#### Scenario: Synthesized stack is marked synthetic (@both)
- **GIVEN** an exception-like input has no usable stack
- **WHEN** the SDK synthesizes a current stack for the exception payload
- **THEN** the exception mechanism should have `synthetic` equal to `true`

#### Scenario: Preserved runtime stack is not synthetic (@both)
- **GIVEN** an actual runtime exception has a usable stack
- **WHEN** the SDK preserves that stack in the exception payload
- **THEN** the exception mechanism should have `synthetic` equal to `false`

#### Scenario: Unknown synthetic state remains absent (@both)
- **GIVEN** a low-level producer cannot determine how the exception stack was obtained
- **WHEN** the producer creates the exception mechanism
- **THEN** the mechanism should omit `synthetic`

### Requirement: Canonical exception level

Every SDK-owned capture boundary SHALL derive event-level `$exception_level` from either the boundary default defined by this capability or an explicit recognized source severity. The SDK SHALL serialize one of `fatal`, `error`, `warning`, `log`, `info`, or `debug`.

The SDK SHALL normalize native severity names as follows: `fatal`, `critical`, `alert`, and `emergency` to `fatal`; `warning` and `warn` to `warning`; `notice` and `info` to `info`; `trace` and `debug` to `debug`; and `error` and `log` to themselves.

The SDK SHALL omit `$exception_level` only when the producer has neither a defined capture-boundary default nor a recognized source severity. A missing caller-supplied level is not unknown when the capture boundary defines a default. Low-level payload builders without capture-boundary context MUST NOT guess a fallback level. Consumers MAY accept legacy aliases, but first-party SDK-generated output SHALL use the canonical vocabulary.

#### Scenario: Native warning level is normalized (@both)
- **WHEN** a logger or console integration captures a `warn` record as an exception
- **THEN** the enqueued event property `$exception_level` should equal `warning`

#### Scenario: Native critical level is normalized (@both)
- **WHEN** a logger integration captures a `critical` record as an exception
- **THEN** the enqueued event property `$exception_level` should equal `fatal`

#### Scenario: Unknown source level remains absent (@both)
- **GIVEN** a low-level exception payload producer has no capture-boundary default
- **WHEN** the producer creates a `$exception` event without a recognized source severity
- **THEN** the generated event should omit `$exception_level`
- **AND** the producer should not default `$exception_level` to `error`

### Requirement: Capture-boundary exception metadata

An SDK-owned capture path SHALL set event-level severity and outermost exception mechanism metadata from the boundary that created the event:

| Capture boundary | `$exception_level` | `mechanism.type` | `mechanism.handled` |
| --- | --- | --- | --- |
| Public or manual capture of a caught exception | `error` by default | `generic` by default | `true` |
| Logger or console call | normalized source level | stable logger/console type | `true` |
| Uncaught boundary that may continue | `error` | stable boundary type | `false` |
| Crash, panic, or uncaught boundary expected to terminate | `fatal` | stable crash/boundary type | `false` |

If a typed exception-capture API accepts an explicit supported level, mechanism type, or source, the SDK SHALL normalize and preserve it instead of the boundary default. Level, type, source, handled state, and synthetic state remain independent. A deliberate `fatal` logger call remains handled, and an unhandled exception is not necessarily synthetic.

#### Scenario: Manual capture emits generic handled error metadata (@both)
- **WHEN** the SDK's public exception API captures a caught exception without explicit overrides
- **THEN** the enqueued event property `$exception_level` should equal `error`
- **AND** the outermost exception should have `mechanism.type` equal to `generic`
- **AND** the outermost exception should have `mechanism.handled` equal to `true`

#### Scenario: Non-fatal uncaught boundary emits unhandled error metadata (@both)
- **GIVEN** an automatic integration observes an uncaught exception without terminating the app or process
- **WHEN** the integration captures the exception
- **THEN** the enqueued event property `$exception_level` should equal `error`
- **AND** the outermost exception should have `mechanism.handled` equal to `false`

#### Scenario: Terminating failure emits fatal unhandled metadata (@both)
- **GIVEN** an automatic integration observes a crash, panic, or uncaught exception expected to terminate the app or process
- **WHEN** the integration captures the failure
- **THEN** the enqueued event property `$exception_level` should equal `fatal`
- **AND** the outermost exception should have `mechanism.handled` equal to `false`

#### Scenario: Fatal logger capture remains handled (@both)
- **WHEN** a logger integration captures a `fatal` record without terminating the app or process
- **THEN** the enqueued event property `$exception_level` should equal `fatal`
- **AND** the outermost exception should have `mechanism.handled` equal to `true`
