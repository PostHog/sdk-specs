# Device ID Generator Specification

## Purpose

`device-id-generator` is the internal component that creates and persists the SDK's **anonymous / device-backed identifier** used before a user is explicitly identified.

It provides the stable fallback identity behind:

- `getDistinctId()` before `identify(...)`
- `$anon_distinct_id` stamping during client-side identify flows
- feature-flag requests that include anonymous/device context

In most client SDKs, this component is effectively the **anonymous id generator and store**. Some SDKs additionally expose a separate long-lived `device_id` concept for flag bucketing.

## Applicability

`client` — this is an internal client-side identity bootstrap component.

## Public signature(s)

No single public API.

Canonical internal operations look like:

```ts
getAnonymousId(): string
setAnonymousId(id: string): void
reset(keepAnonymousId?: boolean): void
```

Some SDKs also support a configurable transformation hook applied to newly-generated ids.

## Behavior

1. **Read a previously-persisted anonymous id if one exists.** Reuse it across restarts and future events.
2. **Generate a new id lazily when missing.** On first access, create a new time-sortable UUID / UUIDv7-style identifier.
3. **Persist the generated id immediately.** Once created, write it to storage so subsequent accesses reuse the same value.
4. **Return the anonymous id as the fallback distinct id.** Higher layers use it whenever no identified `distinct_id` has been stored.
5. **Allow controlled replacement.** Identify/reset flows may replace or preserve the anonymous id depending on SDK configuration such as `reuseAnonymousId`.
6. **Optionally pass generated ids through a platform hook.** Native SDKs like iOS/Android can transform the freshly-generated UUID before persisting it.
7. **Allow wrapper SDKs to delegate identity bootstrap to an underlying platform generator.** Flutter's Dart layer does not generate or persist a second anonymous/device id of its own; it delegates `identify(...)`, `getDistinctId()`, and `reset()` to the native/browser SDKs' underlying identity stores.
8. **Remain stable until explicitly cleared or rotated.** The anonymous/device id is intended to be durable for a given install unless reset, storage clearing, or SDK policy changes it.

## State & lifecycle

### State read

- persisted anonymous id
- optional config hook for anonymous-id transformation
- identified distinct id in higher layers that may supersede anonymous-id usage

### State written

- persisted anonymous id
- in-memory cached anonymous id

### Lifecycle behavior

- **Fresh install / first use:** no anonymous id exists, so one is generated and stored.
- **Normal anonymous usage:** the same id is reused for future events and flag requests.
- **After identify:** many client SDKs keep the prior anonymous id around so `$anon_distinct_id` can be sent and future anonymous resets have a value to return to.
- **After reset:** the anonymous id may be rotated or preserved, depending on `reuseAnonymousId`.
- **After storage wipe/app reinstall:** a brand-new id is generated.
- **Wrapper-layer delegation:** Flutter continues to use the platform/browser SDK's anonymous-id lifecycle directly instead of layering a separate Dart-owned device-id concept on top.

## Error handling

- Generation/storage should not throw in normal operation.
- Storage failures are logged and the SDK falls back to empty/default state until it can regenerate or reload.
- Missing ids are handled by generating a new one rather than surfacing an error.

## Concurrency & ordering guarantees

- Anonymous-id reads/writes are synchronized with locks or serialized runtime execution.
- Concurrent first-access calls should converge on one persisted value, not generate divergent active identities.
- After generation or replacement completes, subsequent reads observe the persisted value consistently.

## Interactions

- **`get-distinct-id`** — returns the anonymous id when no identified id exists.
- **`identify`** — uses the anonymous id as the prior identity and often stamps it as `$anon_distinct_id`.
- **`reset`** — may clear or preserve the anonymous id.
- **feature flags** — client-side flag reload/evaluation often includes the anonymous id alongside the current distinct id.
- **persistent storage** — backs the lifetime of the anonymous/device id across restarts.
- **wrapper SDKs** — Flutter forwards identity reads/mutations to the underlying native/browser identity store, while React Native adds a separate long-lived `device_id` layer documented separately as platform-specific behavior.

## Requirements

### Requirement: Canonical device-id-generator behavior

The SDK SHALL implement the canonical `device-id-generator` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Device id is generated and persisted on first use
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** the device id is requested
- **THEN** the returned device id should not be empty
- **AND** persistent storage should contain the same device id

#### Scenario: Device id is reused from persistent storage
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** persistent storage contains device id "device-123"
- **WHEN** the SDK is initialized with token "test-token"
- **AND** the device id is requested
- **THEN** the returned device id should be "device-123"

#### Scenario: Reset can rotate the device id
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current device id is "device-123"
- **WHEN** reset is called with device id regeneration enabled
- **THEN** the current device id should not be "device-123"
