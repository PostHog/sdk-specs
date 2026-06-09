@public @canonical_behavior @acceptance @set_person_properties_for_flags @both
Feature: Set Person Properties For Flags
  Acceptance tests for the canonical set person properties for flags behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @both
  Scenario: Set person properties stores overrides for future flag evaluation
    Given the SDK is initialized with token "test-token"
    When set person properties for flags is called with properties:
      | property | value |
      | plan     | pro   |
    Then person properties for flags should include:
      | property | value |
      | plan     | pro   |

  @both
  Scenario: Person property overrides are sent with flag reloads
    Given the SDK is initialized with token "test-token"
    And person properties for flags are:
      | property | value |
      | plan     | pro   |
    When reload feature flags is called
    Then the feature flag request should include person property "plan" with value "pro"
