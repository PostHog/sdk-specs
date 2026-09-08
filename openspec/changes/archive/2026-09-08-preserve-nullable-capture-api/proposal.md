## Why

Null-property omission is a serialization rule, not a reason to narrow an SDK's existing public API. Callers that can already supply null or undefined property values must remain compatible, and serialized event caches should use the same cleanup as network payloads.

## What Changes

- Preserve public signatures and property types that already accept null/undefined values. Do not reject previously supported calls or require callers to pre-filter their properties.
- Apply object-member omission during event serialization for both wire delivery and disk-backed event caches/queues.
- Preserve the existing recursive cleanup and array-position rules. Null array elements remain valid, and JavaScript undefined array entries follow normal JSON serialization without compacting arrays.
- Add acceptance scenarios for existing nullable calls and event persistence, including undefined values where supported.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture`: Clarify API compatibility and event serialization boundaries. AI and exception capture inherit the clarification through their existing references to this requirement.

## Impact

Specifications and acceptance scenarios only. This clarification does not require making currently non-nullable APIs nullable, adding disk persistence, changing unrelated caches, or implementing SDK/backend changes. Serialized payloads still change for SDKs currently retaining null-valued object members, but their public input APIs must not be narrowed as part of this work.
