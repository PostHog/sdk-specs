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

  Scenario: Sync provider results are used where supported
    Given the SDK is initialized with token "test-token", local evaluation enabled, and a synchronous external flag definition cache provider
    And the synchronous cache provider fetch-decision operation returns false
    And the synchronous cache provider returns cached flag definitions:
      | key     | active | rollout |
      | beta-ui | true   | 100     |
    When the flag definition loader refreshes
    Then local feature flag definitions should include flag "beta-ui"
    And no direct flag definition API request should be sent

  Scenario: Loader stores definitions after this instance fetches
    Given the SDK is initialized with token "test-token", local evaluation enabled, and an external flag definition cache provider
    And the cache provider fetch-decision operation returns true
    And the mock server will return flag definitions:
      | key     | active | rollout |
      | beta-ui | true   | 100     |
    When the flag definition loader refreshes
    Then local feature flag definitions should include flag "beta-ui"
    And the cache provider should receive flag definition cache data containing flags, group type mapping, and cohorts

  Scenario: Async provider results are awaited where supported
    Given the SDK is initialized with token "test-token", local evaluation enabled, and an async external flag definition cache provider
    And the async cache provider fetch-decision operation resolves false
    And the async cache provider resolves cached flag definitions:
      | key     | active | rollout |
      | beta-ui | true   | 100     |
    When the flag definition loader refreshes
    Then the loader should wait for the async provider results before completing the refresh
    And local feature flag definitions should include flag "beta-ui"
    And no direct flag definition API request should be sent

  Scenario: Provider read failures preserve previously loaded definitions
    Given the SDK is initialized with token "test-token", local evaluation enabled, and an external flag definition cache provider
    And local feature flag definitions include flag "beta-ui"
    And the cache provider fetch-decision operation returns false
    And the cache provider read operation fails
    When the flag definition loader refreshes
    Then local feature flag definitions should still include flag "beta-ui"
    And the SDK should record a flag definition cache warning
    And the refresh should not throw

  Scenario: Provider fetch-decision failures fail safe to direct fetch
    Given the SDK is initialized with token "test-token", local evaluation enabled, and an external flag definition cache provider
    And the cache provider fetch-decision operation fails
    And the mock server will return flag definitions:
      | key     | active | rollout |
      | beta-ui | true   | 100     |
    When the flag definition loader refreshes
    Then a direct flag definition API request should be sent
    And local feature flag definitions should include flag "beta-ui"
    And the SDK should record a flag definition cache warning

  Scenario: Provider shutdown is invoked and isolated from SDK shutdown
    Given the SDK is initialized with token "test-token", local evaluation enabled, and an external flag definition cache provider
    And the cache provider shutdown operation fails
    When shutdown is called
    Then the cache provider shutdown operation should have been called
    And shutdown should not throw because of the cache provider failure
    And the SDK should record a flag definition cache warning
