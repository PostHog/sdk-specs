## Narrative alignment

When syncing this delta, update the iOS surface variant to `reloadFeatureFlags(_ callback: @escaping (PostHogFeatureFlagsLoaded) -> Void)` (4.0+), and add to Error handling that iOS (4.0+) passes the last known flags with `errorsLoading` to the reload completion, the same shape as `onFeatureFlags`. Leave the canonical signature and unrelated scenarios unchanged.

## ADDED Requirements

### Requirement: Reload completion failure reporting

An SDK MAY report whether a reload failed through its reload completion (callback argument, resolved value, or equivalent). An SDK that does MUST report failure when that reload's feature flag request fails, and MUST NOT report failure when it succeeds. When reporting failure, the completion MUST carry the last known cached flags, in the SDK's documented completion representation, rather than discarding them. A representation that omits some values (for example, iOS `PostHogFeatureFlagsLoaded` excludes disabled flags) MAY therefore be empty while cached flags are retained. Classification of quota-limited and partial-computation responses is SDK-specific.

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
