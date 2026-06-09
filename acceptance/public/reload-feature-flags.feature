@public @canonical_behavior @acceptance @reload_feature_flags @client
Feature: Reload Feature Flags
  Acceptance tests for the canonical reload feature flags behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Reload feature flags fetches flags for the current identity
    Given the SDK is initialized with token "test-token"
    And the current distinct id is "user-123"
    And the mock server will return feature flags:
      | key     | value |
      | beta-ui | true  |
    When reload feature flags is called
    Then the mock server should receive a feature flag request for distinct id "user-123"
    And cached feature flags should be:
      | key     | value |
      | beta-ui | true  |

  Scenario: Reload includes group and property override context
    Given the SDK is initialized with token "test-token"
    And group context contains type "company" and key "company-123"
    And person properties for flags are:
      | property | value |
      | plan     | pro   |
    When reload feature flags is called
    Then the feature flag request should include group "company" with key "company-123"
    And the feature flag request should include person property "plan" with value "pro"

  Scenario: Reload failure keeps existing cached flags
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    And the mock server will fail the next feature flag request with status 503
    When reload feature flags is called
    Then cached feature flags should still include:
      | key     | value |
      | beta-ui | true  |
    And the call should not throw
