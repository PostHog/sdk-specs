@private @canonical_behavior @acceptance @flag_definition_loader @server
Feature: Flag Definition Loader
  Acceptance tests for the canonical flag definition loader behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Loader fetches and caches local evaluation definitions
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the mock server will return flag definitions:
      | key     | active | rollout |
      | beta-ui | true   | 100     |
    When the flag definition loader refreshes
    Then local feature flag definitions should include flag "beta-ui"
    And the definition cache should be marked fresh

  Scenario: Loader keeps stale definitions when refresh fails
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag definitions include flag "beta-ui"
    And the mock server will fail the next flag definition request with status 503
    When the flag definition loader refreshes
    Then local feature flag definitions should still include flag "beta-ui"
    And the SDK should record a flag definition refresh warning

  Scenario: Loader refreshes after polling interval
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the flag definition polling interval is "30 seconds"
    When the SDK clock advances by "30 seconds"
    Then the flag definition loader should request fresh definitions
