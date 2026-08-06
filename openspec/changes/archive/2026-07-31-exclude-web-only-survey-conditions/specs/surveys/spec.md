## MODIFIED Requirements

### Requirement: Canonical surveys behavior

The SDK SHALL implement the canonical `surveys` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Survey definitions are loaded and cached
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** the mock server will return surveys:
  | id       | name       | active |
  | survey-1 | NPS Survey | true   |
- **WHEN** surveys are loaded
- **THEN** cached surveys should include survey "survey-1"

#### Scenario: Web-only-conditioned surveys are excluded on non-web SDKs (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** the SDK is running on a non-web platform
- **AND** cached surveys include an active survey "survey-1" whose only display condition is a CSS selector or URL match
- **WHEN** survey eligibility is evaluated
- **THEN** survey display callback should not be invoked for survey "survey-1"

#### Scenario: Eligible survey is shown once per presentation rules
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** cached surveys include an active survey "survey-1" eligible for the current user
- **WHEN** survey eligibility is evaluated
- **THEN** survey display callback should be invoked for survey "survey-1"
- **WHEN** survey "survey-1" is dismissed
- **AND** survey eligibility is evaluated again
- **THEN** survey display callback should not be invoked again for survey "survey-1"

#### Scenario: Survey response captures a survey sent event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** survey "survey-1" is visible
- **WHEN** the user submits survey "survey-1" with response "Great"
- **THEN** one event named "survey sent" should be enqueued
- **AND** the enqueued event properties should include:
  | property   | value    |
  | $survey_id | survey-1 |
  | $survey_response | Great |

#### Scenario: Surveys respect opt-out state
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** analytics capture is opted out
- **WHEN** surveys are loaded
- **THEN** no survey response or display event should be enqueued
