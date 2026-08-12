## Context

Each `$exception_list` entry may carry a `mechanism` object that explains how the exception was captured. The common ingestion model supports four fields:

- `type` for the capture path;
- `handled` for capture disposition;
- `source` for a more specific platform origin or relationship;
- `synthetic` for an instrumentation-created exception or stack.

SDKs do not expose or preserve these fields consistently. JavaScript has a typed `source` field but its shared builder reconstructs a smaller object. Go models handled and synthetic state but not type or source. Several SDKs default missing state before a capture boundary has supplied enough context.

Some SDKs emit additional platform metadata, such as cause linkage or crash diagnostics. Those extension fields are outside the common ingestion model and remain allowed, but this capability does not assign them cross-SDK semantics.

Event-level `$exception_level` is not part of the mechanism object, but the same capture boundary determines it. Keeping its semantics beside the mechanism contract prevents independent defaults from contradicting each other.

This contract applies to SDK-owned manual and automatic capture paths in client and server SDKs. It defines internal `$exception` wire behavior without expanding the client-only public `capture-exception` API.

## Goals / Non-Goals

**Goals:**

- Define all common mechanism fields supported across exception ingestion.
- Preserve known common metadata and represent unknown metadata through omission.
- Give mechanism type, handled state, source, and synthetic state independent meanings.
- Define trustworthy capture-boundary defaults for mechanism metadata and exception level.
- Allow SDKs to converge independently without coordinated releases.

**Non-Goals:**

- Require low-level or third-party producers to guess metadata they cannot know.
- Define an exhaustive mechanism-type or source taxonomy across runtimes.
- Standardize platform extension fields such as cause linkage or native crash diagnostics.
- Define how downstream products classify or present exceptions.
- Change exception grouping, fingerprints, stack ordering, or source context.
- Backfill metadata on historical events.

## Decisions

### 1. Standardize the full common mechanism object

The common fields are `type`, `handled`, `source`, and `synthetic`. SDKs use the canonical names and JSON types whenever they emit those concepts.

Low-level builders preserve all supplied common fields instead of reconstructing a smaller object. Platform-specific JSON-safe extensions remain allowed, but only the four common fields have portable semantics in this capability.

Alternative: standardize only handled state. Rejected because field loss and incompatible type, source, and synthetic semantics would remain SDK-specific.

### 2. Omit unknown values

Absence means the producer could not determine a field. `false`, empty strings, and `null` remain real serialized values and therefore cannot stand in for unknown state.

A boundary-defined default is known metadata. Manual capture therefore knows `type: generic`, `handled: true`, and level `error` even when a caller supplies no override. A context-free payload builder does not know those values and leaves them absent.

Alternative: require a complete mechanism object on every entry. Rejected because legacy, custom, and low-level producers legitimately lack capture-boundary context.

### 3. Keep type, handled, source, synthetic, and level independent

`type` identifies the capture path. `handled` describes whether application code handled the represented exception. `source` preserves a more specific platform origin or relationship. `synthetic` describes whether instrumentation created the exception representation or stack. `$exception_level` describes source severity.

No field derives another. A deliberate fatal logger call is handled. An unhandled runtime exception with its original stack is not synthetic. A synthesized manual message is handled. A mechanism can have a known type without a known source.

Alternative: infer these values from one another. Rejected because each combination occurs in shipped capture paths.

### 4. Keep mechanism types and sources stable but extensible

Manual capture defaults to `generic`. Automatic integrations use stable identifiers such as `onuncaughtexception`, `onunhandledrejection`, `onconsole`, `middleware`, `panic`, `signal`, or platform equivalents.

`source` carries a more specific origin or relationship only when the integration knows one. The contract defines neither field as a closed enum. A builder preserves an unknown non-empty integration value rather than replacing it with a generic value.

Alternative: define one universal vocabulary. Rejected because runtime boundaries expose genuinely different mechanisms and source relationships.

### 5. Derive boundary defaults at the owner

The capture path that owns the boundary supplies defaults:

| Capture boundary | `$exception_level` | `mechanism.type` | `mechanism.handled` |
| --- | --- | --- | --- |
| Public/manual caught exception | `error` | `generic` | `true` |
| Logger or console call | normalized source level | stable logger/console type | `true` |
| Uncaught boundary that may continue | `error` | stable boundary type | `false` |
| Terminating crash, panic, or uncaught boundary | `fatal` | stable crash/boundary type | `false` |
| Context-free low-level producer | omitted | omitted | omitted |

The boundary also sets `synthetic` when it knows how the exception representation or stack was obtained, and `source` when it has more specific origin context. Typed explicit values override defaults after validation and normalization. Generic additional event properties do not constitute typed mechanism metadata.

### 6. Preserve compatibility during SDK convergence

The wire changes are additive. Missing metadata keeps its existing meaning: the producer did not provide it. Consumers decide how to handle absence without changing this producer contract.

Each SDK adds final emitted-payload tests at its public capture boundary and every automatic integration boundary it owns. Tests cover preservation of all four common fields as well as boundary defaults.

## Risks / Trade-offs

- [Platform extensions remain inconsistent] → Limit this capability to fields the common ingestion model preserves and add extension contracts only when consumers support them.
- [Preserving fields can pass invalid values] → Validate common field types before serialization.
- [A logger's `fatal` method may not terminate the process] → Preserve fatal severity while keeping handled state true.
- [Framework middleware may prevent process termination] → Treat failures uncaught by application code as unhandled but non-fatal unless the boundary terminates.
- [Adding metadata can change downstream classification] → Keep classification policy outside this contract and preserve omission for unknown values.

## Migration Plan

1. Archive this change as the canonical internal `exception-event-mechanism` capability and add private acceptance scenarios.
2. Update shared builders first so they preserve supplied type, handled, source, and synthetic metadata.
3. Update capture boundaries to supply accurate mechanism metadata and exception level.
4. Add conformance tests to SDKs whose current primary paths already provide all common fields.
5. Add optional metadata only where a runtime supplies reliable evidence.
6. Monitor field coverage by `$lib` and `$lib_version` without requiring historical versions to conform.

Rollback consists of reverting an SDK release. Older SDKs continue to omit fields, so no coordinated consumer rollback or data migration is required.

## Open Questions

None. SDK-specific API spelling, mechanism vocabulary, platform extensions, and release sequencing remain implementation details within this contract.
