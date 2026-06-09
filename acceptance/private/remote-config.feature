@private @canonical_behavior @acceptance @remote_config @client
Feature: Remote Config
  Acceptance tests for the canonical remote config behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Remote config fetch applies feature settings
    Given the SDK is initialized with token "test-token"
    And the mock server will return remote config:
      | setting                 | value |
      | session_replay_enabled  | true  |
      | surveys_enabled         | true  |
      | feature_flags_available | true  |
    When remote config is reloaded
    Then cached remote config should include setting "session_replay_enabled" with value "true"
    And remote config listeners should be notified

  Scenario: Remote config can trigger feature flag loading
    Given the SDK is initialized with token "test-token"
    And the mock server will return remote config:
      | setting                 | value |
      | feature_flags_available | true  |
    When remote config is reloaded
    And pending SDK tasks are run
    Then a feature flag request should be sent

  Scenario: Remote config failure falls back to cached config
    Given the SDK is initialized with token "test-token"
    And cached remote config includes setting "session_replay_enabled" with value "true"
    And the mock server will fail the next remote config request with status 503
    When remote config is reloaded
    Then cached remote config should still include setting "session_replay_enabled" with value "true"
    And the call should not throw
