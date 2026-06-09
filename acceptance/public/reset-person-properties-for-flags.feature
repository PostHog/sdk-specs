@public @canonical_behavior @acceptance @reset_person_properties_for_flags @both
Feature: Reset Person Properties For Flags
  Acceptance tests for the canonical reset person properties for flags behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @both
  Scenario: Reset person properties clears local person flag overrides
    Given the SDK is initialized with token "test-token"
    And person properties for flags are:
      | property | value |
      | plan     | pro   |
    When reset person properties for flags is called
    Then person properties for flags should be empty

  @both
  Scenario: Reset person properties affects subsequent flag evaluations
    Given the SDK is initialized with token "test-token"
    And person properties for flags are:
      | property | value |
      | plan     | pro   |
    When reset person properties for flags is called
    And reload feature flags is called
    Then the feature flag request should not include person property "plan"
