## Why

SDKs should omit null/undefined-valued object properties when serializing captured events, while preserving array positions and existing public APIs that accept those values. The owner selected object-member omission to align with planned backend removal; that backend work is still in progress.

## What Changes

- Omit null/undefined-valued custom object members recursively during event serialization for wire delivery and disk-backed event queues/caches.
- Preserve null array elements, array positions, non-null values, and objects made empty by cleanup.
- Preserve public signatures, property types, and runtime acceptance for existing nullable/undefined inputs. Do not require callers to pre-filter their properties.
- Apply the shared contract to queued, immediate, AI, and exception capture, including values introduced by `before_send`.
- Add ten acceptance scenarios covering wire output, existing API compatibility, and event persistence/restore.
- **BREAKING** serialized-output change for SDKs currently retaining null-valued object members. SDK compatibility review and rollout remain separate; public inputs must not be narrowed.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture`: Define object-member omission at serialization boundaries, preserve array positions, and protect existing public input APIs.
- `capture-ai`: Apply the shared contract to the AI route.
- `capture-exception`: Apply the shared contract to additional custom properties without changing SDK-owned metadata rules.

## Impact

Specifications and acceptance scenarios only. No SDK or backend implementation changes. This does not require widening currently non-nullable APIs, adding disk persistence, or changing unrelated caches, privacy controls, reserved-field validation, or OTLP logs/traces rules.

Context: https://github.com/PostHog/posthog-python/pull/926
