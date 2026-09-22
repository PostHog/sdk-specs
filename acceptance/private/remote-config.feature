@private @canonical_behavior @acceptance @remote_config @both
Feature: Remote Config
  Acceptance specifications for client and server SDKs that implement project remote configuration.
  SDKs without this capability are out of scope. Feature-specific scenarios apply only where supported.

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

  Scenario Outline: JSON remote config uses the correct asset base
    Given the SDK is initialized with token "phc_test" and host "<host>"
    When the SDK fetches the JSON remote config representation
    Then a GET request should be sent to "<url>"
    And the request body should be empty
    And the request should not require a personal API key or secret key
    And the SDK should not add a bearer Authorization header
    And the request should not contain user identity or person or group properties

    Examples:
      | host                                  | url                                                       |
      | https://us.i.posthog.com               | https://us-assets.i.posthog.com/array/phc_test/config       |
      | https://eu.i.posthog.com               | https://eu-assets.i.posthog.com/array/phc_test/config       |
      | https://analytics.example.com/posthog  | https://analytics.example.com/posthog/array/phc_test/config |

  Scenario: JSON remote config tolerates unknown and omitted optional fields
    Given the SDK is initialized with token "phc_test"
    And the mock remote config endpoint will return HTTP 200 with JSON:
      """
      {"hasFeatureFlags":false,"sessionRecording":false,"surveys":false,"futureSetting":{"enabled":true}}
      """
    When the SDK fetches the JSON remote config representation
    Then the SDK should apply the supported remote config fields
    And the unknown "futureSetting" field should not invalidate the response
    And omitted optional fields should not invalidate the response
    And remote config listeners should be notified
    And the call should not throw

  @browser
  Scenario: Browser applies preloaded project configuration without a JSON request
    Given the token-specific loader has preloaded valid project configuration for "phc_test"
    When the browser SDK initializes its remote config subsystem with token "phc_test"
    Then the preloaded project configuration should be applied
    And no request should be sent to "/array/phc_test/config"
