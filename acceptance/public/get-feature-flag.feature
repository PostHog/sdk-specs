@public @canonical_behavior @acceptance @get_feature_flag @both
Feature: Get Feature Flag
  Acceptance tests for the canonical get feature flag behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @client
  Scenario: Client getter returns the cached boolean flag value
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key      | value |
      | beta-ui  | true  |
    When get feature flag "beta-ui" is called
    Then the returned feature flag value should be true
    And a "$feature_flag_called" event should be enqueued for flag "beta-ui" with value "true"

  @both
  Scenario: Getter returns a variant string for multivariate flags
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key      | value |
      | checkout | blue  |
    When get feature flag "checkout" is called
    Then the returned feature flag value should be "blue"

  @both
  Scenario: Getter can suppress feature flag called tracking
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | true  |
    When get feature flag "beta-ui" is called with tracking disabled
    Then the returned feature flag value should be true
    And no event named "$feature_flag_called" should be enqueued

  @server
  Scenario: Server getter evaluates with explicit context
    Given the SDK is initialized with token "test-token"
    And local feature flag definitions include a flag "beta-ui" rolled out to distinct id "user-123"
    When get feature flag "beta-ui" is called for distinct id "user-123"
    Then the returned feature flag value should be true
