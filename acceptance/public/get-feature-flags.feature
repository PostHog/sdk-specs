@public @canonical_behavior @acceptance @get_feature_flags @both
Feature: Get Feature Flags
  Acceptance tests for the canonical get feature flags behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @client
  Scenario: Bulk getter returns all cached flag values
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key      | value |
      | beta-ui  | true  |
      | checkout | blue  |
    When get feature flags is called
    Then the returned feature flags should be:
      | key      | value |
      | beta-ui  | true  |
      | checkout | blue  |

  @server
  Scenario: Bulk getter evaluates all available flags for explicit context
    Given the SDK is initialized with token "test-token"
    And local feature flag definitions include flags:
      | key      | value_for_user_123 |
      | beta-ui  | true               |
      | checkout | blue               |
    When get feature flags is called for distinct id "user-123"
    Then the returned feature flags should be:
      | key      | value |
      | beta-ui  | true  |
      | checkout | blue  |

  @both
  Scenario: Bulk getter can suppress tracking events
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    When get feature flags is called with tracking disabled
    Then no event named "$feature_flag_called" should be enqueued

  # Only SDKs whose getAllFeatureFlags() returns flag result objects (iOS 4.0+, Android 4.0+, Flutter 6.0+, KMP).
  # The value "" is the empty string, a variant PostHog no longer accepts for new flags.
  @client @flag_result_list_capable
  Scenario: Flag result list reads an empty variant as disabled
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key       | value |
      | beta-ui   | true  |
      | legacy-ui | ""    |
    When get all feature flag results is called
    Then the returned feature flag results should include:
      | key       | enabled |
      | beta-ui   | true    |
      | legacy-ui | false   |
    And the returned feature flag result for "legacy-ui" should have variant equal to the JSON value ""
