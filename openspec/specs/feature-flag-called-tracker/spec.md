# Feature Flag Called Tracker Specification

## Purpose

`feature-flag-called-tracker` is the internal deduplication component that suppresses duplicate `$feature_flag_called` events for the same flag evaluation outcome.

Its job is to prevent analytics noise when application code repeatedly reads the same flag without the underlying flag value changing.

## Applicability

`both` — audited client and server SDKs use an internal tracker/cache to dedupe `$feature_flag_called` events, though the dedupe key and eviction policy differ.

## Public signature(s)

No direct public API.

Canonical internal operations look like:

```ts
shouldTrack(distinctId?, flagKey, value, groups?): boolean
markSeen(distinctId?, flagKey, value, groups?): void
reset(): void
```

In some SDKs, `shouldTrack` and `markSeen` are combined into one atomic "add if unseen" operation.

## Behavior

1. **Build a dedupe key from the flag access.** Common inputs are:
   - feature flag key
   - evaluated response/value (`true`, `false`, variant string, or `null`/`undefined`)
   - in many server/mobile SDKs, `distinct_id` as well
   - when provided to server-side evaluation, group context (`groups`, such as group type/key pairs) as well
   Group context SHOULD be normalized as a semantic mapping, for example sorted stringified `(group_type, group_key)` pairs, so incidental map/dictionary insertion order does not create a different dedupe key.
2. **Check whether this combination was already reported.**
3. **Suppress duplicate tracking events.** If the same combination has already been seen, do not emit another `$feature_flag_called` event.
4. **Allow new tracking when the response or evaluation context changes.** If a flag's value changes for the same key, or if a server-side call evaluates the same flag/value for a different `distinct_id` or group context, allow a new `$feature_flag_called` event.
5. **Reset on flag reload/change and lifecycle boundaries.** When feature flags are reloaded, caches are reset, identity is reset, or the SDK is closed/shut down, clear the dedupe tracker so post-reset/reloaded SDK state can emit fresh tracking events and shutdown state cannot leak across SDK lifetimes.
6. **Expose tracking controls unevenly at the wrapper layer when applicable.** For example, Flutter delegates to the underlying native/browser trackers and only exposes a per-call suppression flag on `getFeatureFlagResult(sendEvent: ...)`, while `getFeatureFlag(...)`, `getFeatureFlagPayload(...)`, and `isFeatureEnabled(...)` always use the default tracking path.
7. **Cap memory usage where needed.** Larger-scale implementations evict old entries using bounded maps or LRU-style caches. When a bounded tracker reaches its capacity, it SHOULD evict the oldest or least-recently-used entries incrementally. Capacity pressure SHOULD NOT clear the entire tracker, because doing so can flood analytics with duplicate `$feature_flag_called` events. Full tracker clears are reserved for explicit lifecycle/context boundaries such as flag reload/cache reset, identity reset, or SDK close/shutdown.

## State & lifecycle

### State read

- in-memory map/LRU cache of previously-reported flag/value/context combinations

### State written

- newly seen dedupe entries
- tracker reset/eviction state

### Lifecycle behavior

- The tracker starts empty when the SDK initializes.
- Each flag access that would emit `$feature_flag_called` consults the tracker first.
- Flag reloads reset the tracker so new values can be reported again.
- Capacity-based eviction SHOULD remove only selected old/LRU entries instead of clearing the entire tracker.
- SDKs that support identity reset flows MUST clear the tracker because the relevant flag-evaluation context changed.
- SDK close/shutdown flows MUST clear the tracker so in-memory dedupe state does not outlive the SDK instance.
- Wrapper SDKs may not own a separate tracker at all. Flutter mostly inherits tracker lifecycle from the underlying mobile/browser SDKs it delegates to.

## Error handling

- Tracker operations should not throw in normal operation.
- Missing or uninitialized tracker state should be treated as "nothing seen yet".
- If value serialization/comparison is imperfect, the failure mode should be extra tracking or under-tracking, not application crashes.

## Concurrency & ordering guarantees

- Lookups and updates are synchronized or serialized by the SDK's runtime model.
- Atomic "check and add" behavior is preferred so concurrent accesses do not double-emit the same `$feature_flag_called` event.
- Reset operations take effect immediately for subsequent flag accesses.

## Interactions

- **`get-feature-flag` / `is-feature-enabled` / `get-feature-flag-result`** — all commonly use this tracker before capturing `$feature_flag_called`.
- **`get-feature-flag-payload`** — some SDKs route payload lookups through the same tracking/dedupe machinery, while others suppress tracking or expose only a compatibility wrapper.
- **feature-flag cache reloads** — reset the tracker because flag values may have changed.
- **identity resets / context changes** — clear the tracker because subsequent evaluations use a new user context.
- **server-side group context** — where groups are provided for feature-flag evaluation, the group type/key mapping is part of the dedupe context so the same user, flag, and value can be tracked separately for different group evaluations. Equivalent group mappings should dedupe even if represented in a different map/dictionary order.
- **SDK close / shutdown** — clears the tracker as part of teardown so dedupe state does not leak across SDK lifetimes.

## Requirements

### Requirement: Canonical feature-flag-called-tracker behavior

The SDK SHALL implement the canonical `feature-flag-called-tracker` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Tracker emits the first flag-called event for a value (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **THEN** one event named "$feature_flag_called" should be enqueued
- **AND** the enqueued event properties should include:
  | property     | value   |
  | $feature_flag | beta-ui |
  | $feature_flag_response | true |

#### Scenario: Tracker suppresses duplicate events for the same flag value (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **AND** get feature flag "beta-ui" is called again
- **THEN** exactly one event named "$feature_flag_called" should be enqueued for flag "beta-ui"

#### Scenario: Tracker emits again when the flag value changes (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **AND** cached feature flag "beta-ui" changes to "false"
- **AND** get feature flag "beta-ui" is called
- **THEN** two "$feature_flag_called" events should be enqueued for flag "beta-ui"

#### Scenario: Tracker suppresses duplicates for the same server group context (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** local feature flag definitions include a group flag "company-beta" returning true for group type "company"
- **WHEN** get feature flag "company-beta" is called for distinct id "user-123" with groups:
  | type    | key         |
  | company | company-123 |
  | team    | team-1      |
- **AND** get feature flag "company-beta" is called for distinct id "user-123" with groups:
  | type    | key         |
  | team    | team-1      |
  | company | company-123 |
- **THEN** exactly one event named "$feature_flag_called" should be enqueued for flag "company-beta"

#### Scenario: Tracker emits again when server group context changes (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** local feature flag definitions include a group flag "company-beta" returning true for group type "company"
- **WHEN** get feature flag "company-beta" is called for distinct id "user-123" with groups:
  | type    | key         |
  | company | company-123 |
- **AND** get feature flag "company-beta" is called for distinct id "user-123" with groups:
  | type    | key         |
  | company | company-456 |
- **THEN** two "$feature_flag_called" events should be enqueued for flag "company-beta"

#### Scenario: Tracker clears on identity reset (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **AND** reset is called
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **AND** get feature flag "beta-ui" is called
- **THEN** two "$feature_flag_called" events should be enqueued for flag "beta-ui"

#### Scenario: Tracker clears on SDK shutdown (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "beta-ui" is called
- **AND** shutdown is called
- **THEN** feature flag called tracker state should be empty
