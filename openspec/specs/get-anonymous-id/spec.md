# Get Anonymous ID Specification

## Purpose

`get-anonymous-id` returns the SDK's current **anonymous / device-backed identity** used before a user is explicitly identified.

Unlike `get-distinct-id`, which returns the effective current event identity (identified id when present, otherwise anonymous id), this API always returns the anonymous side of the client identity model.

It is a **pure local read** except that many SDKs lazily create and persist an anonymous id on first access.

## Applicability

`client` — this is a client-side ambient-identity access API.

## Public signatures

### Canonical client signature

```ts
getAnonymousId(): string
```

### Surface variants

- **posthog-js core:** `getAnonymousId(): string`
- **iOS:** `getAnonymousId() -> String`
- **React Native:** inherits the js-core public method (no top-level override)

Some audited client SDKs implement the same underlying concept internally but do **not** expose it as a public method.

## Behavior

1. **Return the persisted anonymous id if one already exists.**
2. **Lazily create one if absent.** On first access, generate a new UUID/UUIDv7-style value (possibly passed through a platform-specific customization hook) and persist it immediately.
3. **Do not switch the current identified user.** Reading the anonymous id does not affect `distinct_id`, `isIdentified`, or person-processing state.
4. **Do not emit events or perform network I/O.**
5. **Remain stable until explicitly rotated/cleared.** The value persists until reset/storage wipe or SDK configuration says to preserve/replace it differently.

## State & lifecycle

### State read

- persisted anonymous id
- optional config hook for anonymous-id customization
- SDK enabled/initialization state in implementations that gate reads

### State written

- anonymous id when lazily initialized
- in-memory cached anonymous id in native SDKs

### Lifecycle behavior

- **Fresh install / first access:** a new anonymous id is generated and stored.
- **Before identify:** this is typically also the effective `distinct_id`.
- **After identify:** the anonymous id continues to exist separately and is often used as `$anon_distinct_id` for future flag/merge-related flows.
- **After reset:** the anonymous id may rotate or be preserved depending on SDK config such as `reuseAnonymousId`.
- **After app reinstall/storage wipe:** a new anonymous id is generated.

## Error handling

- This API should not throw in normal operation.
- Disabled/unavailable SDKs may return an empty string instead of forcing initialization.
- Missing storage values are handled by generating a new anonymous id rather than failing.

## Concurrency & ordering guarantees

- Anonymous-id reads/writes are synchronized with locks or serialized runtime execution.
- Concurrent first-access calls should converge on one persisted value.
- After generation completes, subsequent calls observe the same stored value until rotation/clear.

## Interactions

- **`identify`** — commonly uses the anonymous id as the pre-identify identity and may stamp it as `$anon_distinct_id`.
- **`get-distinct-id`** — returns the identified id when present; otherwise falls back to this anonymous id.
- **feature flags** — many client SDKs include the anonymous id in flag requests when `reuseAnonymousId` is false.
- **`reset`** — may clear or preserve the anonymous id.
- **device-id generation** — some SDKs seed a separate long-lived `device_id` from the anonymous id.

## Requirements

### Requirement: Canonical get-anonymous-id behavior

The SDK SHALL implement the canonical `get-anonymous-id` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Anonymous id is generated on first initialization
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** get anonymous id is called
- **THEN** the returned anonymous id should not be empty
- **AND** persistent storage should contain the same anonymous id

#### Scenario: Anonymous id remains stable after identify
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current anonymous id is "anon-123"
- **WHEN** identify is called with distinct id "user-123"
- **AND** get anonymous id is called
- **THEN** the returned anonymous id should be "anon-123"
- **AND** get distinct id should return "user-123"

#### Scenario: Anonymous id rotates when reset requests a new device id
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current anonymous id is "anon-123"
- **WHEN** reset is called with anonymous id regeneration enabled
- **AND** get anonymous id is called
- **THEN** the returned anonymous id should not be "anon-123"
