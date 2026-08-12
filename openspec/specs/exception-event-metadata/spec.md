# Exception Event Metadata Specification

## Purpose

`exception-event-metadata` defines the canonical producer envelope and metadata ownership for SDK-generated `$exception` events. It covers capture severity and provenance, the common `$exception_list[].mechanism` fields, nested-exception relationships, native symbolication metadata, and the boundary between SDK-produced and Cymbal-derived properties.

It does not define exception grouping policy, stack parsing, symbol upload, issue presentation, or the public exception-capture API.

## Applicability

`both` — this is internal wire behavior for client and server SDKs that generate `$exception` events. It applies to SDK-owned public/manual and automatic capture paths. Context-free low-level builders preserve supplied metadata and omit values they cannot determine.

The client-only public `capture-exception` capability remains responsible for its API surface. The `exception-steps` capability remains responsible for `$exception_steps`.

## Terminology

- A **capture boundary** is the application, framework, runtime, or integration boundary that decides to create the `$exception` event.
- The **outermost exception** is `$exception_list[0]`, the exception observed by that capture boundary.
- A **nested exception** is a cause, context, aggregate member, suppressed exception, inner exception, or other exception reached from another entry.
- **Producer metadata** is serialized by the SDK before ingestion. **Processor metadata** is derived by Cymbal after ingestion.

## Requirements

### Requirement: Canonical exception event envelope

An SDK-generated exception event SHALL use event name `$exception` and SHALL contain a non-empty `$exception_list`. Each list entry SHALL contain a non-empty string `type` and a string `value`; `value` MAY be empty when the runtime provides no message. An entry MAY include `module`, `thread_id`, `stacktrace`, and `mechanism` when known.

The list SHALL remain outermost-first as defined by the `capture-exception` capability. A low-level builder SHALL preserve valid supplied exception metadata and MUST NOT invent capture-boundary metadata it does not know. If no mechanism field or platform extension is known for an entry, the producer SHALL omit `mechanism` rather than emit an empty object.

#### Scenario: Exception event has a non-empty canonical list (@both)
- **WHEN** an SDK-owned capture boundary creates an exception event
- **THEN** the event name should equal `$exception`
- **AND** `$exception_list` should contain at least one entry
- **AND** every entry should contain a non-empty string `type` and a string `value`

#### Scenario: Context-free builder omits an empty mechanism (@both)
- **GIVEN** a low-level builder has no mechanism metadata or platform mechanism extensions
- **WHEN** it creates an exception-list entry
- **THEN** the entry should omit `mechanism`

### Requirement: Canonical exception mechanism object

When an SDK has mechanism metadata for an exception, it SHALL serialize that metadata as an object at `$exception_list[].mechanism`. The common fields are:

- `type`: a non-empty string naming the semantic mechanism category;
- `handled`: a boolean describing capture disposition at the relevant application boundary;
- `source`: a non-empty string naming a nested exception's relationship to its parent;
- `synthetic`: a boolean describing whether instrumentation synthesized the represented exception or stack.

A producer SHALL omit any common field whose value it cannot determine; it MUST NOT represent unknown with `false`, an empty string, or `null`. A low-level builder SHALL preserve every valid supplied common field instead of reconstructing a smaller object. Producers MAY include and preserve additional JSON-safe platform fields, but this capability does not assign them cross-SDK meaning.

#### Scenario: Known mechanism metadata uses canonical field types (@both)
- **WHEN** an SDK-owned capture path creates an exception event with known mechanism metadata
- **THEN** every emitted common mechanism field should use its defined JSON type
- **AND** the mechanism should not contain null placeholders for unknown fields

#### Scenario: Low-level builder preserves supplied mechanism metadata (@both)
- **GIVEN** an integration supplies valid `type`, `handled`, `source`, and `synthetic` values
- **WHEN** a low-level builder creates `$exception_list`
- **THEN** the resulting mechanism should preserve all four fields and values

### Requirement: Capture category and concrete capture source

`mechanism.type` identifies the semantic mechanism by which an exception entry entered the event. On the outermost exception it identifies the capture-boundary category. Public or manual capture SHALL use `generic` unless a more specific integration category is known. Common outermost categories include `logger`, `onconsole`, `onuncaughtexception`, `onunhandledrejection`, `middleware`, `task`, `panic`, `signal`, and `crash_reporter`. A nested exception reached through another entry MAY use `chained`; `mechanism.source` then preserves the specific relationship. The vocabulary is extensible, and builders MUST preserve unknown non-empty typed integration values.

Event-level `$exception_source` identifies the concrete SDK integration or runtime hook that captured the event. Examples include `django.middleware`, `fastapi.exception_handler`, `celery.task_failure`, `python.sys_excepthook`, `browser.window_onerror`, and `php.exception_handler`. First-party values SHOULD be stable lowercase identifiers, SHOULD qualify the technology with the relevant hook, and MUST NOT contain versions, routes, exception classes, source-file paths, or user-controlled values.

A producer SHALL set `$exception_source` only from capture-boundary knowledge. It MUST NOT infer it merely from installed dependencies or stack frames. Generic manual capture SHALL omit `$exception_source` unless a concrete integration owns the call. Technology-specific integration identity belongs in `$exception_source`, not in `mechanism.type`, when a common semantic category describes the boundary.

#### Scenario: Framework boundary separates category from integration (@both)
- **GIVEN** Django middleware observes an exception escaping a request boundary
- **WHEN** the middleware captures the exception
- **THEN** the outermost exception should have `mechanism.type` equal to `middleware`
- **AND** `$exception_source` should equal `django.middleware`

#### Scenario: Generic manual capture omits a concrete source (@both)
- **WHEN** the public exception API captures a caught exception without integration context
- **THEN** the outermost exception should have `mechanism.type` equal to `generic`
- **AND** the event should omit `$exception_source`

#### Scenario: Unknown integration type is preserved (@both)
- **GIVEN** a typed integration supplies an unknown non-empty mechanism type
- **WHEN** a low-level builder creates the exception event
- **THEN** the builder should preserve that type instead of replacing it with `generic`

### Requirement: Explicit exception handled state

The outermost exception SHALL serialize `mechanism.handled` when the capture boundary knows whether the exception escaped the relevant application boundary. It SHALL use `true` when application code deliberately reports or consumes the exception at that boundary, including manual capture, deliberate logger or console capture, and a framework handler that converts the failure into an application response. It SHALL use `false` when the exception escapes that application boundary.

A framework, SDK, global handler, or crash reporter observing an exception does not by itself make the exception handled. When handled state is unknown, the producer SHALL omit `mechanism.handled`; it MUST NOT serialize unknown as `false`. A top-level `$exception_handled` property does not replace the nested mechanism field.

Each nested entry SHALL preserve its own independently known handled state. A producer MUST NOT copy the outermost handled state to nested entries solely because they belong to the same event.

#### Scenario: Manual capture marks the outermost exception handled (@both)
- **WHEN** the public exception API captures a caught exception
- **THEN** the outermost exception should have `mechanism.handled` equal to `true`

#### Scenario: Framework handler that consumes a failure is handled (@both)
- **GIVEN** a framework exception handler converts an exception into an application response
- **WHEN** the handler captures the exception
- **THEN** the outermost exception should have `mechanism.handled` equal to `true`

#### Scenario: Exception escaping application code is unhandled (@both)
- **GIVEN** infrastructure observes an exception after it escapes the relevant application boundary
- **WHEN** the infrastructure captures the exception
- **THEN** the outermost exception should have `mechanism.handled` equal to `false`

#### Scenario: Unknown nested handled state remains absent (@both)
- **GIVEN** a producer knows the outermost handled state but not a nested exception's handled state
- **WHEN** it serializes both entries
- **THEN** the nested exception should omit `mechanism.handled`

### Requirement: Explicit synthetic state

When the producer knows whether instrumentation synthesized an exception representation or stack, it SHALL serialize `mechanism.synthetic` as a boolean according to the following rules:

| Representation | `mechanism.synthetic` |
| --- | --- |
| Runtime exception with its original usable stack | `false` |
| Runtime exception without a usable stack and without a replacement stack | `false` |
| SDK-generated current stack replacing a missing or unusable original stack | `true` |
| Non-exception input converted into an exception representation | `true` |
| Provenance cannot be determined | omitted |

A producer MUST NOT default unknown synthetic state to `false`. Each nested entry SHALL describe its own representation and MUST NOT inherit synthetic state solely from the outermost entry.

#### Scenario: Synthesized current stack is marked synthetic (@both)
- **GIVEN** an input has no usable stack
- **WHEN** the SDK generates a current stack for the exception payload
- **THEN** that exception should have `mechanism.synthetic` equal to `true`

#### Scenario: Runtime exception without a replacement stack is not synthetic (@both)
- **GIVEN** an actual runtime exception has no usable stack
- **WHEN** the SDK preserves the lack of a stack instead of generating one
- **THEN** that exception should have `mechanism.synthetic` equal to `false`

#### Scenario: Unknown synthetic provenance remains absent (@both)
- **GIVEN** a low-level producer cannot determine the representation's provenance
- **WHEN** it serializes the exception
- **THEN** the mechanism should omit `synthetic`

### Requirement: Nested exception relationship source

For a nested exception, `mechanism.source` identifies the runtime relationship through which that entry was reached from its parent. Examples include `cause`, `context`, `unwrap`, `member`, `suppressed`, and `inner`. It SHALL be a stable, non-empty string when known and SHALL be omitted when the relationship is unknown.

`mechanism.source` SHALL NOT identify a framework or capture integration and SHALL NOT contain a source-file path. It is normally absent from the outermost exception. A producer MUST NOT label every nested relationship `cause`: aggregate members, suppressed exceptions, implicit context, and multi-error unwrapping retain their distinct relationship when known.

`$exception_list` is a flattened representation of a conceptual exception tree. Parents SHALL appear before children. This capability does not yet define portable parent identifiers for branched trees; producers MAY preserve JSON-safe platform linkage extensions such as `exception_id` and `parent_id`, but consumers MUST NOT treat `mechanism.source` alone as complete parent linkage in a branched tree.

#### Scenario: Wrapped cause records its relationship (@both)
- **GIVEN** an outer exception wraps another exception as its cause
- **WHEN** the SDK serializes both exceptions
- **THEN** the outer exception should omit `mechanism.source`
- **AND** the nested exception may have `mechanism.type` equal to `chained`
- **AND** the nested exception should have `mechanism.source` equal to `cause`

#### Scenario: Aggregate member is not mislabeled as a cause (@both)
- **GIVEN** an aggregate exception contains a member exception
- **WHEN** the SDK serializes the aggregate and member
- **THEN** the member should have `mechanism.source` equal to `member` or an equivalent stable platform relationship

### Requirement: Canonical exception level

Every SDK-owned capture boundary SHALL derive event-level `$exception_level` from either a boundary default or an explicit recognized source severity. The serialized value SHALL be one of `fatal`, `error`, `warning`, `log`, `info`, or `debug`.

The SDK SHALL normalize native severity names as follows: `fatal`, `critical`, `alert`, and `emergency` to `fatal`; `warning` and `warn` to `warning`; `notice` and `info` to `info`; `trace` and `debug` to `debug`; and `error` and `log` to themselves.

The SDK SHALL omit `$exception_level` only when the producer has neither a defined boundary default nor a recognized source severity. A context-free low-level builder MUST NOT guess a fallback. Consumers MAY accept legacy aliases, but first-party SDK output SHALL use the canonical vocabulary.

#### Scenario: Native warning level is normalized (@both)
- **WHEN** a logger or console integration captures a `warn` record as an exception
- **THEN** `$exception_level` should equal `warning`

#### Scenario: Native critical level is normalized (@both)
- **WHEN** a logger integration captures a `critical` record as an exception
- **THEN** `$exception_level` should equal `fatal`

#### Scenario: Unknown source level remains absent (@both)
- **GIVEN** a low-level producer has no capture-boundary default
- **WHEN** it creates an exception event without a recognized source severity
- **THEN** the event should omit `$exception_level`

### Requirement: Capture-boundary metadata and precedence

An SDK-owned capture path SHALL apply the following defaults:

| Capture boundary | `$exception_level` | `mechanism.type` | `mechanism.handled` | `$exception_source` |
| --- | --- | --- | --- | --- |
| Public/manual caught exception | `error` | `generic` | `true` | omitted unless integration-owned |
| Logger call | normalized source level | `logger` | `true` | concrete logger integration |
| Console call | normalized source level | `onconsole` | `true` | concrete console integration |
| Framework handler that consumes the failure | `error` | `middleware` | `true` | concrete framework hook |
| Failure escaping a request boundary | `error` | `middleware` | `false` | concrete framework hook |
| Background task failure escaping application code | `error` | `task` | `false` | concrete task integration |
| Uncaught boundary that may continue | `error` | stable boundary category | `false` | concrete runtime hook |
| Crash, panic, signal, or uncaught boundary expected to terminate | `fatal` | stable terminating category | `false` | concrete runtime hook |
| Context-free low-level producer | omitted | omitted | omitted | omitted |

For each field, precedence SHALL be: a valid typed integration override; recognized native source metadata; the capture-boundary default; then omission. Invalid or unknown values MUST NOT be converted into misleading defaults by a context-free builder. Level, type, source, handled state, and synthetic state remain independent.

#### Scenario: Manual capture emits canonical defaults (@both)
- **WHEN** the public exception API captures a caught exception without overrides
- **THEN** `$exception_level` should equal `error`
- **AND** the outermost exception should have `mechanism.type` equal to `generic`
- **AND** the outermost exception should have `mechanism.handled` equal to `true`
- **AND** the event should omit `$exception_source`

#### Scenario: Fatal logger capture remains handled (@both)
- **WHEN** a logger integration captures a `fatal` record without terminating the app or process
- **THEN** `$exception_level` should equal `fatal`
- **AND** the outermost exception should have `mechanism.handled` equal to `true`

#### Scenario: Terminating failure is fatal and unhandled (@both)
- **GIVEN** a capture boundary observes a failure expected to terminate the app or process
- **WHEN** it captures the failure
- **THEN** `$exception_level` should equal `fatal`
- **AND** the outermost exception should have `mechanism.handled` equal to `false`

### Requirement: Native debug image metadata

When an SDK emits native stack frames with runtime instruction addresses and can identify the loaded binaries containing them, it SHALL attach those binaries at event-level `$debug_images`. SDKs that do not capture native address-based frames SHALL omit `$debug_images`.

Each emitted debug image SHALL contain a non-empty `debug_id` matching the identifier used by the symbol-upload pipeline and a non-empty hexadecimal `image_addr` representing the runtime load address. It MAY contain `type` (`macho`, `elf`, `pe`, or another supported object format), `image_vmaddr`, `image_size`, `code_file`, and `arch`. `image_addr` and `image_vmaddr` SHALL be hexadecimal strings with a `0x` prefix, and `image_size` SHALL be a non-negative integer number of bytes.

A native frame SHALL use `instruction_addr` for its runtime instruction address and SHOULD use `image_addr` to identify its loaded image. Address-bearing frame fields SHALL be hexadecimal strings with a `0x` prefix. The referenced image SHALL have the same `image_addr` or a declared address range containing the instruction. Producers MUST NOT invent debug identifiers, SHALL deduplicate equivalent image entries, and SHOULD omit unreferenced process images where practical. Images without an authoritative `debug_id` SHALL be omitted.

#### Scenario: Native frame carries matching debug image metadata (@both)
- **GIVEN** an SDK captures a native frame and knows its loaded binary and authoritative debug identifier
- **WHEN** it creates the exception event
- **THEN** the frame should contain `instruction_addr` and `image_addr`
- **AND** `$debug_images` should contain a matching image with `debug_id` and `image_addr`

#### Scenario: Interpreted stack omits debug images (@both)
- **GIVEN** an exception event contains no native address-based frames
- **WHEN** the SDK creates the event
- **THEN** it should omit `$debug_images`

### Requirement: Explicit grouping override and release inputs

When a typed SDK API accepts an explicit custom exception fingerprint, the SDK SHALL serialize it as a non-empty string at `$exception_fingerprint` and SHALL preserve it through low-level builders. SDKs MUST NOT invent a custom fingerprint when none was supplied. The meaning and selection of automatic fingerprints remain processor concerns outside this capability.

Exception events SHALL retain ordinary release/build context added by the capture pipeline, including `$release_id` where supplied and platform application namespace, version, or build properties. Exception-specific builders MUST NOT discard that context or independently invent release identifiers. Release creation, selection, and symbol upload are outside this capability.

#### Scenario: Explicit custom fingerprint is preserved (@both)
- **GIVEN** a typed capture path supplies a non-empty custom exception fingerprint
- **WHEN** the low-level builder creates the event
- **THEN** `$exception_fingerprint` should preserve the supplied value

#### Scenario: Missing fingerprint remains absent at the producer (@both)
- **WHEN** an SDK creates an exception event without an explicit fingerprint
- **THEN** the producer should omit `$exception_fingerprint`

### Requirement: Producer and processor metadata ownership

SDKs and Cymbal SHALL treat metadata ownership as follows:

| Property | Producer input | Processor behavior |
| --- | --- | --- |
| `$exception_list` | SDK canonical exception data | validates, normalizes, and resolves frames |
| `$exception_level` | SDK severity | preserves for querying and downstream use |
| `$exception_source` | SDK concrete capture integration or hook | preserves; does not infer from source files |
| `$debug_images` | SDK native image metadata | validates, consumes for symbolication, and preserves supported fields |
| `$exception_fingerprint` | optional SDK/user override | selects the explicit or automatic fingerprint |
| `$exception_handled` | legacy input only; not authoritative | derives from outermost `mechanism.handled` |
| `$exception_types` | none | derives from the exception list |
| `$exception_values` | none | derives from the exception list |
| `$exception_sources` | none | derives from in-app stack-frame source-file paths |
| `$exception_functions` | none | derives from in-app stack-frame functions |
| `$exception_fingerprint_version` | none | derives from automatic grouping |
| `$exception_fingerprint_record` | none | derives from grouping |
| `$exception_issue_id` | none | derives from issue linking |
| `$exception_release` | none | derives from release resolution |
| `$cymbal_errors` | none | derives from processing diagnostics |

First-party SDKs SHALL use the producer fields as their source of truth and SHALL NOT synthesize processor-owned properties. Cymbal MAY accept or overwrite legacy producer values for compatibility, but SDK conformance is measured against the ownership in this table. In particular, `$exception_source` and `$exception_sources` are distinct: the singular property is a capture integration supplied by the SDK, while the plural property is a list of source-code files derived by Cymbal.

#### Scenario: SDK does not confuse capture source with source files (@both)
- **GIVEN** Django middleware captures an exception whose stack contains `app/views.py`
- **WHEN** the SDK enqueues the raw event
- **THEN** `$exception_source` should equal `django.middleware`
- **AND** the SDK should omit `$exception_sources`

#### Scenario: Nested handled state is authoritative producer metadata (@both)
- **GIVEN** the outermost exception contains `mechanism.handled`
- **WHEN** the SDK enqueues the raw event
- **THEN** the SDK should not rely on top-level `$exception_handled` as a replacement
