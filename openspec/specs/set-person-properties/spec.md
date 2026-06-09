# Set Person Properties Specification

## Purpose

`set-person-properties` updates the PostHog **person profile** associated with the SDK's current effective user identity.

It is the public API for sending a `$set`-style person update after the SDK already has an ambient `distinct_id`. It lets callers attach or update person properties such as plan, email, or account metadata without performing a full `identify(...)` transition.

## Applicability

`client` — the audited implementations are client/mobile SDKs with ambient identity state. Server SDKs generally express the same operation through identify-style event APIs rather than a shared `setPersonProperties(...)` helper.

## Public signatures

### Canonical client signature

```ts
setPersonProperties(
  propertiesToSet?: Record<string, JsonValue>,
  propertiesToSetOnce?: Record<string, JsonValue>,
): void
```

### Surface variants

- **posthog-js browser:** `setPersonProperties(propertiesToSet?, propertiesToSetOnce?)`
- **flutter:** `setPersonProperties({ userPropertiesToSet?, userPropertiesToSetOnce? }): Future<void>`
- **react-native:** `setPersonProperties(propertiesToSet?, propertiesToSetOnce?, reloadFeatureFlags = true)`
- **iOS:**
  - `setPersonProperties(userPropertiesToSet:)`
  - `setPersonProperties(userPropertiesToSet:userPropertiesToSetOnce:)`
- **Android:** `setPersonProperties(userPropertiesToSet?, userPropertiesToSetOnce?)`

`propertiesToSet` maps to `$set` semantics (overwrite existing values), while `propertiesToSetOnce` maps to `$set_once` semantics (apply only if the property is not already set on the person).

## Behavior

1. **Guard / no-op if unavailable.** Disabled SDK instances do nothing.
2. **Validate input.** If both property dictionaries are missing or empty, do nothing.
3. **Require person processing.** If the SDK is configured not to create/update person profiles, ignore the call rather than emitting a `$set` event.
4. **Determine the current target person.** Use the SDK's current effective `distinct_id` as the person to update.
5. **Deduplicate exact repeats in audited client SDKs.** If the current `distinct_id` plus the effective `$set`/`$set_once` payload matches the immediately cached previous call, ignore the duplicate.
   - In audited browser, iOS, and Android implementations, this duplicate-detection cache is also shared with same-user property updates emitted from `identify(...)`.
   - Deduplication is **not fully identical across SDKs**: browser/js-core-based implementations hash the raw object shape, so semantically identical payloads with different key insertion order can still be treated as different calls, while audited iOS and Android implementations recursively sort keys so reordered maps are deduplicated.
6. **Optionally mirror the merged properties into local feature-flag context.** In audited client SDKs, the SDK may also update the local person-properties-for-flags cache using `propertiesToSetOnce` first and then `propertiesToSet`, so `$set` values win on overlapping keys.
7. **Feature-flag reload behavior is SDK-specific.**
   - Browser/js-core-based implementations reload feature flags immediately by default after updating that local person-properties-for-flags cache.
   - React Native exposes this as a public `reloadFeatureFlags` parameter.
   - iOS and Android update the local flag-evaluation cache but do **not** trigger an immediate flag reload from `set-person-properties(...)` itself.
8. **Emit a `$set` event through the normal capture pipeline.** The event carries the person-property update in PostHog's `$set` / `$set_once` shape and is enriched with the SDK's normal identity/session/super-property context.
9. **Do not change the current identity.** Unlike `identify(...)`, this API updates properties for the current person but does not switch `distinct_id`.

## State & lifecycle

### State read

- SDK enabled / initialization state
- current ambient `distinct_id`
- person-processing configuration/state
- current duplicate-detection cache
- local person-properties-for-flags cache in SDKs that mirror into flag context

### State written

- queued `$set` event payload
- duplicate-detection cache for the most recent person-property update
- local person-properties-for-flags cache in SDKs that mirror those properties for feature evaluation

### Lifecycle behavior

- Each non-ignored call produces one `$set` event attempt for the current person.
- Repeating the exact same call may be ignored by duplicate-detection logic.
- In audited browser and Android implementations, `reset()` clears the duplicate-detection cache so the same later `set-person-properties(...)` call is allowed again.
- This API does not create a new anonymous id, switch `distinct_id`, or clear any prior identity state.

## Error handling

- This API should not throw in normal operation.
- Disabled SDKs no-op.
- Empty inputs no-op.
- Person-processing disallow rules cause the call to be ignored rather than emitted.
- Transport failures happen after the event is queued/captured and follow the SDK's normal retry/drop behavior.

## Concurrency & ordering guarantees

- `set-person-properties(...)` participates in the same ordering guarantees as ordinary capture/event submission within each SDK.
- Duplicate detection is based on the SDK's current cached hash/state, so concurrently racing calls may result in one or both events being sent depending on ordering.
- No stronger ordering guarantees are provided beyond the SDK's normal capture queue semantics.

## Interactions

- **`identify`** — both update person data, but `identify(...)` also changes ambient identity when needed; in audited browser, iOS, and Android implementations, same-user property updates emitted from `identify(...)` share the same duplicate-detection cache as `set-person-properties(...)`.
- **`set-person-properties-for-flags`** — some SDKs mirror the merged `$set`/`$set_once` values into the local flag-evaluation person-property cache.
- **`capture`** — `$set` is ultimately emitted through the normal capture/event path.
- **Feature flag reload/evaluation** — SDKs that mirror properties into local flag context may make those values visible to subsequent flag checks; some also trigger an immediate reload, while others leave reload timing to later calls.

## Requirements

### Requirement: Canonical set-person-properties behavior

The SDK SHALL implement the canonical `set-person-properties` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Set person properties emits profile update properties
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current distinct id is "user-123"
- **WHEN** set person properties is called with properties:
  | property | value          |
  | email    | user@test.test |
- **THEN** one event named "$set" should be enqueued
- **AND** the enqueued event distinct id should be "user-123"
- **AND** the enqueued event property "$set.email" should equal "user@test.test"

#### Scenario: Set person properties can include set-once properties
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** set person properties is called with set properties:
  | property | value          |
  | email    | user@test.test |
- **AND** set-once properties:
  | property   | value      |
  | first_seen | yesterday  |
- **THEN** one event named "$set" should be enqueued
- **AND** the enqueued event property "$set.email" should equal "user@test.test"
- **AND** the enqueued event property "$set_once.first_seen" should equal "yesterday"

#### Scenario: Empty person property updates do not crash
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** set person properties is called with no properties
- **THEN** the call should not throw
