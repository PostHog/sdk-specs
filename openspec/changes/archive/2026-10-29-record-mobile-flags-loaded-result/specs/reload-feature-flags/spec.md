## Narrative alignment

When syncing this delta, update two **Surface variants** entries:

- **flutter:** `reloadFeatureFlags(): Future<PostHogFeatureFlagsLoaded>` (6.0+); before 6.0 it
  returned `Future<void>`.
- **Android:** `reloadFeatureFlags(onFeatureFlags: PostHogFeatureFlagsCallback? = null): void`
  (4.0+); before 4.0 the callback was `PostHogOnFeatureFlags`, which took no arguments.

In **Error handling**, replace the iOS-only bullet with: iOS (4.0+), Android (4.0+) and Flutter
(6.0+) pass the last known flags with `errorsLoading` to the reload completion, the same
`PostHogFeatureFlagsLoaded` shape as `onFeatureFlags`. Flutter returns it from the `Future` rather
than through a callback argument. Leave the canonical signature unchanged.

## MODIFIED Requirements

### Requirement: Reload completion failure reporting

An SDK MAY report whether a reload failed through its reload completion (callback argument, resolved value, or equivalent). An SDK that does MUST report failure when that reload's feature flag request fails, and MUST NOT report failure when it succeeds. When reporting failure, the completion MUST carry the last known cached flags, in the SDK's documented completion representation, rather than discarding them. A representation that omits some values (for example, the `PostHogFeatureFlagsLoaded` shape used by posthog-ios 4.0, posthog-android 4.0 and posthog-flutter 6.0 excludes disabled flags) MAY therefore be empty while cached flags are retained. Classification of quota-limited and partial-computation responses is SDK-specific.

A reload that never issues its feature flag request, because the SDK has no usable distinct id to evaluate for, is not a success. An SDK that reports through the completion SHALL report that reload as a failure carrying the last known flags, rather than resolving it as a load that returned nothing. Other paths that skip the request (a disabled or opted-out SDK) are not settled across SDKs and stay SDK-specific.

#### Scenario: Reload completion reports success with the loaded flags
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the SDK reports reload failure through its reload completion
- **AND** the mock server will return feature flags:
  | key     | value |
  | beta-ui | true  |
- **WHEN** reload feature flags is called
- **THEN** the reload completion should not report a failure
- **AND** the reload completion flags should include:
  | key     | value |
  | beta-ui | true  |

#### Scenario: Reload completion reports failure with the last known flags
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the SDK reports reload failure through its reload completion
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **AND** the mock server will fail the next feature flag request with status 503
- **WHEN** reload feature flags is called
- **THEN** the reload completion should report a failure
- **AND** the reload completion flags should include:
  | key     | value |
  | beta-ui | true  |

#### Scenario: Reload completion reports a skipped request as a failure
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the SDK reports reload failure through its reload completion
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **AND** the current distinct id is empty
- **WHEN** reload feature flags is called
- **THEN** the mock server should not receive a feature flag request
- **AND** the reload completion should report a failure
- **AND** the reload completion flags should include:
  | key     | value |
  | beta-ui | true  |
