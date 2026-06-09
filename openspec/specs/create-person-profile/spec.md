# Create Person Profile Specification

## Purpose

`create-person-profile` forces the SDK to begin **person processing** for the current ambient user even if that user has not yet been identified with a new `distinct_id`.

It exists for client SDKs that support a deferred person-profile model such as `identified_only`, where anonymous users normally do not create person profiles until a qualifying action occurs. This API lets callers opt the current user into person-profile creation explicitly.

## Applicability

`client` — this is a client-side identity/profile-control API.

In the audited implementations, this API is present in the `posthog-js` family (shared core, browser, React Native). Other audited client SDKs do not expose an equivalent public method.

## Public signatures

### Canonical client signature

```ts
createPersonProfile(): void
```

### Surface variants

- **posthog-js core:** `createPersonProfile()`
- **browser:** `createPersonProfile()`
- **react-native:** `createPersonProfile()`

## Behavior

1. **Check whether person processing is already enabled.** If the current user already has person processing enabled, do nothing.
2. **Require person processing to be allowed by config.** If person profiles are configured as `never`, log/ignore the call rather than creating a profile.
3. **Enable person-profile creation for the current ambient user.**
4. **Emit an empty `$set` event (or equivalent path that produces one).**
   - The event carries empty `$set` / `$set_once` payloads.
   - The purpose is not to update properties, but to create a person profile on the backend for the current user.
5. **Do not change `distinct_id`.** This API operates on the current effective identity rather than identifying a new user.
6. **Affect future events.** After the `$set` is accepted by the SDK's local person-processing model, subsequent events for the same user are treated as person-processed events.

## State & lifecycle

### State read

- current person-processing state
- current ambient `distinct_id`
- SDK enabled / initialization state
- person-profiles configuration

### State written

- queued `$set` event payload
- local person-processing state as it becomes enabled through the SDK's normal event/identity model

### Lifecycle behavior

- If person processing is already active, repeated calls are no-ops.
- If person processing is disabled by configuration (`never`), the call does nothing.
- Under `identified_only`, this API is the explicit escape hatch that enables person processing without first changing `distinct_id`.

## Error handling

- This API should not throw in normal operation.
- Disabled/unavailable SDKs no-op.
- `personProfiles = 'never'` causes the call to be ignored.
- Transport failures occur after the `$set` event is enqueued/captured and follow the SDK's normal retry/drop behavior.

## Concurrency & ordering guarantees

- `create-person-profile(...)` participates in the same ordering guarantees as normal `$set` / `capture(...)` submission in the SDK.
- If it races with other identity-changing calls, callers observe the usual pre/post ordering of the SDK's event queue and person-processing state.

## Interactions

- **`identify`** — another path that enables person processing, but by changing/confirming user identity.
- **`set-person-properties`** — also emits `$set`, but with actual property updates instead of an empty profile-creation payload.
- **`capture`** — later events may gain person-processing semantics after this API enables them.

## Requirements

### Requirement: Canonical create-person-profile behavior

The SDK SHALL implement the canonical `create-person-profile` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Create person profile emits an empty set event for the current identity
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and person profiles mode "identified_only"
- **AND** the current distinct id is "anon-123"
- **WHEN** create person profile is called
- **THEN** one event named "$set" should be enqueued
- **AND** the enqueued event distinct id should be "anon-123"
- **AND** the enqueued event should contain empty person property updates
- **AND** the current distinct id should remain "anon-123"

#### Scenario: Create person profile is a no-op when person profiles are disabled
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and person profiles mode "never"
- **WHEN** create person profile is called
- **THEN** no event should be enqueued
- **AND** the current distinct id should not change

#### Scenario: Repeated create person profile calls do not duplicate profile creation
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and person profiles mode "identified_only"
- **WHEN** create person profile is called
- **AND** create person profile is called again
- **THEN** at most one profile creation event should be enqueued for the current identity
