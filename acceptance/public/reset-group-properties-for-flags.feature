@public @canonical_behavior @acceptance @reset_group_properties_for_flags @both
Feature: Reset Group Properties For Flags
  Acceptance tests for the canonical reset group properties for flags behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @both
  Scenario: Reset group properties clears all local group flag overrides
    Given the SDK is initialized with token "test-token"
    And group properties for flags are:
      | group_type | group_key   | property | value |
      | company    | company-123 | plan     | pro   |
    When reset group properties for flags is called
    Then group properties for flags should be empty

  @both
  Scenario: Reset group properties affects subsequent flag evaluations
    Given the SDK is initialized with token "test-token"
    And group properties for flags are:
      | group_type | group_key   | property | value |
      | company    | company-123 | plan     | pro   |
    When reset group properties for flags is called
    And reload feature flags is called
    Then the feature flag request should not include group property "plan"
