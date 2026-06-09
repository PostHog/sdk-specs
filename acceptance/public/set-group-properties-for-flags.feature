@public @canonical_behavior @acceptance @set_group_properties_for_flags @both
Feature: Set Group Properties For Flags
  Acceptance tests for the canonical set group properties for flags behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @both
  Scenario: Set group properties stores overrides for future flag evaluation
    Given the SDK is initialized with token "test-token"
    When set group properties for flags is called for group type "company" and group key "company-123" with properties:
      | property | value |
      | plan     | pro   |
    Then group properties for flags should include:
      | group_type | group_key   | property | value |
      | company    | company-123 | plan     | pro   |

  @both
  Scenario: Group property overrides are sent with flag reloads
    Given the SDK is initialized with token "test-token"
    And group properties for flags are:
      | group_type | group_key   | property | value |
      | company    | company-123 | plan     | pro   |
    When reload feature flags is called
    Then the feature flag request should include group property "plan" with value "pro"
