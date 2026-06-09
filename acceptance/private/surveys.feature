@private @canonical_behavior @acceptance @surveys @client
Feature: Surveys
  Acceptance tests for the canonical surveys behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Survey definitions are loaded and cached
    Given the SDK is initialized with token "test-token" and surveys enabled
    And the mock server will return surveys:
      | id       | name       | active |
      | survey-1 | NPS Survey | true   |
    When surveys are loaded
    Then cached surveys should include survey "survey-1"

  Scenario: Eligible survey is shown once per presentation rules
    Given the SDK is initialized with token "test-token" and surveys enabled
    And cached surveys include an active survey "survey-1" eligible for the current user
    When survey eligibility is evaluated
    Then survey display callback should be invoked for survey "survey-1"
    When survey "survey-1" is dismissed
    And survey eligibility is evaluated again
    Then survey display callback should not be invoked again for survey "survey-1"

  Scenario: Survey response captures a survey sent event
    Given the SDK is initialized with token "test-token" and surveys enabled
    And survey "survey-1" is visible
    When the user submits survey "survey-1" with response "Great"
    Then one event named "survey sent" should be enqueued
    And the enqueued event properties should include:
      | property   | value    |
      | $survey_id | survey-1 |
      | $survey_response | Great |

  Scenario: Surveys respect opt-out state
    Given the SDK is initialized with token "test-token" and surveys enabled
    And analytics capture is opted out
    When surveys are loaded
    Then no survey response or display event should be enqueued
