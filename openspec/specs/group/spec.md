# Group Specification

## Purpose

`group` associates the current client user/session with a **group** (for example a company, team, organization, workspace, or project) so future events carry `$groups` context and can be analyzed at the group level.

When group properties are supplied, `group` also triggers a `$groupidentify` event so PostHog can store metadata on that group.

`group` is primarily a **local state mutation plus an optional analytics event**:

- it persists the current group mapping for future event enrichment
- it may enqueue a `$groupidentify` event immediately
- it may reload feature flags if the active group assignment changed

## Applicability

`client` — this API is a client-side ambient-context operation. Server SDKs generally expose `group_identify` / `$groupidentify` directly, but not a persistent ambient `group(...)` setter.

## Public signatures

### Canonical client signature

```ts
group(
  groupType: string,
  groupKey: string | number,
  groupProperties?: Record<string, unknown>,
): void
```

### Surface variants

- **posthog-js core / browser / react-native:** `group(groupType, groupKey, groupProperties?)`
- **flutter:** `group({ groupType, groupKey, groupProperties? }): Future<void>`
- **iOS:** `group(type: String, key: String, groupProperties?: [String: Any])`
- **Android:** `group(type: String, key: String, groupProperties?: Map<String, Any>)`
- **Unity:** `Group(string groupType, string groupKey, Dictionary<string, object> groupProperties = null)`

## Behavior

1. **Guard / no-op if unavailable.** Disabled SDKs, opted-out users, or clients configured to never process persons/groups no-op.
2. **Persist the group association.** Store or update the current mapping `groupType -> groupKey` in local client state.
3. **Use the stored groups on future events.** After the call completes, subsequent captures include the updated `$groups` context automatically.
4. **Reload feature flags when the active group changes.** If the stored key for `groupType` changed, client SDKs reload feature flags so group-based rollout rules are re-evaluated.
5. **Enqueue `$groupidentify` to synchronize the association and properties.**
   - The emitted event name is `$groupidentify`.
   - Event properties include at least `$group_type` and `$group_key`.
   - If `groupProperties` were provided, they are sent as `$group_set`.
   - Some SDKs emit `$groupidentify` on every `group(...)` call; core-based JS SDKs suppress exact duplicate calls when the same group key is already stored and no new properties were supplied.
6. **Optionally cache group properties for feature-flag evaluation.** Mobile-oriented SDKs commonly store provided `groupProperties` in a local group-properties-for-flags cache so flag evaluation can reflect the new properties before the backend processes the `$groupidentify` event.
7. **Return immediately.** The public API itself returns no event data.

## State & lifecycle

### State read

- current stored groups map
- SDK enabled / opt-out / person-processing state
- optional local feature-flag property caches

### State written

- persisted groups map (`$groups` / equivalent)
- optional group-properties-for-flags cache
- normal outbound queue state when `$groupidentify` is emitted

### Lifecycle behavior

- Group associations persist across app restarts.
- `reset()` clears stored groups so subsequent events no longer carry prior `$groups` context.
- Re-calling `group(...)` with the same `groupType` and a different `groupKey` overwrites the previous mapping for that type.
- Multiple group types can coexist at once (for example `organization` and `project`).

## Error handling

- `group` should not throw in normal operation.
- Empty / invalid type or key values are dropped or logged by implementations.
- Disabled / opted-out / person-processing-disabled clients no-op.
- If `$groupidentify` is dropped by a hook or local validation, the persisted group association may still have been updated locally, depending on implementation ordering.

## Concurrency & ordering guarantees

- Group-state reads/writes are serialized by the SDK's normal storage / locking model.
- A `capture(...)` call issued after `group(...)` completes observes the updated `$groups` mapping.
- If `group(...)` races with `capture(...)`, callers observe either the old or new mapping depending on ordering; no partial group map is exposed.
- Ordering between the persisted local group change and the emitted `$groupidentify` event is implementation-specific, but both are part of the same logical operation.

## Interactions

- **`capture`** — future events include the persisted `$groups` context set by `group(...)`.
- **`group-identify`** — `group(...)` commonly emits `$groupidentify` internally; direct `groupIdentify(...)` is the lower-level operation for sending group properties without necessarily changing ambient group membership.
- **Feature flags** — group changes trigger flag reloads because flag rules may depend on group membership or group properties.
- **`reset`** — clears ambient group membership.
- **`identify` / person-processing** — some SDKs gate group operations behind the same person-processing controls used by identify/alias.

## Requirements

### Requirement: Canonical group behavior

The SDK SHALL implement the canonical `group` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Group stores group context for future events
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** group is called with type "company" and key "company-123"
- **THEN** registered groups should include:
  | group_type | group_key   |
  | company    | company-123 |
- **WHEN** capture is called with event "Viewed Dashboard"
- **THEN** the enqueued event property "$groups" should include group "company" with key "company-123"

#### Scenario: Group can include group properties
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** group is called with type "company", key "company-123", and properties:
  | property | value |
  | plan     | pro   |
- **THEN** one event named "$groupidentify" should be enqueued
- **AND** the enqueued event property "plan" should equal "pro"
- **AND** future events should include group "company" with key "company-123"

#### Scenario: Group rejects missing type or key
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** group is called without a group key
- **THEN** group context should not change
- **AND** the SDK should record a validation warning
