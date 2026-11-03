## Narrative alignment

When syncing this delta, replace the Android entry in **Surface variants** with:

- **Android:** `onFeatureFlags(PostHogFeatureFlagsCallback): PostHogFeatureFlagsSubscription` on the
  instance and on the static `PostHog` facade (4.0+), whose handle exposes `unsubscribe()`;
  `PostHogConfig.onFeatureFlags = callback` and `reloadFeatureFlags(callback?)` remain for the
  single config-time callback. Before 4.0 the config field and the reload completion were the only
  surfaces.

In **Behavior** item 5, group Android's `onFeatureFlags(...)` registration (4.0+) with browser and
iOS as a surface that invokes a newly registered listener once with the current values when flags
are already loaded. Android's config field and reload completion keep their existing behavior and
are not part of that group.

In **Concurrency & ordering guarantees**, extend the main-thread note to record that posthog-android
4.0 delivers `onFeatureFlags(...)` listeners on the main thread after its getters already return the
new values, while `PostHogConfig.onFeatureFlags` and the `reloadFeatureFlags` completion stay on the
SDK's background thread — the same split posthog-ios makes.

## ADDED Requirements

### Requirement: Lifetime of a runtime listener registration

A runtime listener registration — a method that registers a callback and returns an unsubscribe
handle or function, as posthog-js, posthog-ios 4.0 and posthog-android 4.0 do — SHALL stay active
until the caller unsubscribes it, including across a `close()`/`setup()` cycle. Unsubscribing SHALL
stop delivery for that registration only, and SHALL be safe to call more than once. A config-time
callback field has no handle to outlive anything and is out of scope.

#### Scenario: A registration keeps receiving loads after a teardown and re-setup
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** a feature flag listener is registered
- **WHEN** the SDK is closed
- **AND** the SDK is initialized with token "test-token"
- **AND** feature flags are loaded with values:
  | key     | value |
  | beta-ui | true  |
- **THEN** the feature flag listener should be invoked with flags:
  | key     | value |
  | beta-ui | true  |

### Requirement: Loads discarded by reset or close reach no listener

A flag load already in flight when `reset()` or `close()` ran SHALL NOT be delivered to a listener
when it completes, and SHALL NOT be replayed to a listener registered afterwards: it carries the
flags of the identity or instance the caller just discarded. The SDK MAY drop such a load by any
means it chooses.

#### Scenario: A load in flight across reset is not delivered
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** a feature flag listener is registered
- **WHEN** a feature flag load starts
- **AND** the SDK is reset before that load completes
- **AND** that load completes with values:
  | key     | value |
  | beta-ui | true  |
- **THEN** the feature flag listener should not be invoked

#### Scenario: A load dropped by reset is not replayed to a later listener
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** a feature flag load starts
- **AND** the SDK is reset before that load completes
- **AND** that load completes with values:
  | key     | value |
  | beta-ui | true  |
- **AND** a feature flag listener is registered
- **THEN** the feature flag listener should not be invoked
