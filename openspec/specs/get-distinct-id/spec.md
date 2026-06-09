# Get Distinct ID Specification

## Purpose

`get-distinct-id` returns the SDK's **current effective user identifier** for event attribution.

On client SDKs, this is the same identifier that `capture(...)` will attach as `distinct_id` if called immediately after. Before the user is identified, it falls back to the current anonymous / device-backed id. After `identify(...)`, it returns the identified id instead.

This API is a **pure local read**. It does not emit events or perform network I/O.

## Applicability

`client` — this is a client-side state access API. Server SDKs are stateless per call and generally do not expose a comparable ambient-identity getter.

## Public signatures

### Canonical client signature

```ts
getDistinctId(): string
```

### Surface variants

- **posthog-js core / react-native:** `getDistinctId(): string`
- **browser:** `get_distinct_id(): string`
- **flutter:** `getDistinctId(): Future<string>`
- **iOS:** `getDistinctId() -> String`
- **Android:** `distinctId(): String`
- **Unity:** `PostHog.DistinctId` / `PostHogSDK.DistinctId` static property

## Behavior

1. **Return the current identified id if one is stored.** If `identify(...)` previously set a persistent `distinct_id`, return that value.
2. **Otherwise fall back to the anonymous id.** If no identified id is stored, return the current anonymous / device-backed id instead.
3. **Lazily initialize the anonymous id if needed.** In SDKs that persist anonymous ids, calling this API may create and persist a new anonymous id on first access.
4. **Do not mutate identified state.** Reading the current distinct id does not mark the user as identified and does not enqueue any event.
5. **Do not contact the network.** Any value returned comes entirely from in-memory or persisted local state.

## State & lifecycle

### State read

- persisted `distinct_id`
- persisted anonymous / device id
- SDK enabled / initialized state in implementations that gate reads

### State written

Usually none, except for lazy anonymous-id creation on first access when no anonymous id has yet been stored.

### Lifecycle behavior

- **Fresh install / first launch:** returns a newly-created anonymous id (or empty / null when the SDK is unavailable and refuses initialization).
- **After `identify(newId)`:** returns `newId`.
- **After `reset()`:** returns the new anonymous id, or the preserved anonymous id when `reuseAnonymousId` is enabled.
- **After app restart:** returns the persisted distinct id or anonymous fallback from storage.

## Error handling

- This API should not throw in normal operation.
- Implementations that are disabled or not yet initialized may return an empty string (JS core, Flutter, iOS, Android) or `null` (Unity static property before initialization) instead of forcing initialization.
- Missing stored identity is handled by falling back to, or creating, an anonymous id rather than raising an error.

## Concurrency & ordering guarantees

- Reads are lock-protected or event-loop serialized in all audited client SDKs.
- The value observed is consistent with the SDK's current local identity state at the moment of the call.
- If `identify(...)` or `reset()` is racing on another thread, callers observe either the pre-change or post-change id depending on ordering; no partial value is exposed.

## Interactions

- **`identify`** — sets the persisted `distinct_id` that this getter will subsequently return.
- **`reset`** — clears the identified id so this getter falls back to the anonymous id again.
- **`capture`** — uses the same effective id that this getter returns when no per-call override is supplied.
- **Feature flags** — client-side flag requests typically use the same current distinct id (and sometimes the anonymous id alongside it) when evaluating or reloading flags.
- **`get-anonymous-id`** — if exposed separately, that API returns the anonymous/device id specifically; `get-distinct-id` returns the identified id when present, otherwise that anonymous id.

## Requirements

### Requirement: Canonical get-distinct-id behavior

The SDK SHALL implement the canonical `get-distinct-id` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Client distinct id starts as the anonymous id (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current anonymous id is "anon-123"
- **WHEN** get distinct id is called
- **THEN** the returned distinct id should be "anon-123"

#### Scenario: Client distinct id changes after identify (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** identify is called with distinct id "user-123"
- **AND** get distinct id is called
- **THEN** the returned distinct id should be "user-123"

#### Scenario: Server SDKs do not expose ambient distinct id state (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** get distinct id is called on a server SDK
- **THEN** the SDK should report that no ambient distinct id is available
