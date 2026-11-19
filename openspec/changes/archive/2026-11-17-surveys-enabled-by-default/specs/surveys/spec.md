## ADDED Requirements

### Requirement: The local surveys option defaults to enabled

A client SDK SHALL default its local surveys switch to enabled. The switch is the configuration
option that turns the surveys subsystem on and off locally: `surveys`, or an inverted
`disableSurveys` / `disable_surveys`. An application that sets no option SHALL get the surveys
subsystem installed and survey definitions loaded under "Canonical surveys behavior", and the
project's remote configuration SHALL decide whether any survey is delivered to it.

The local switch is a kill switch, not the feature's on-ramp. A project with no surveys, or with
surveys turned off in its project settings, sends no survey definitions, so an enabled default
neither renders UI nor adds a request beyond the remote-config load the SDK already makes. An
application that sets the switch off SHALL still get a disabled subsystem: it returns empty
results or no-ops rather than rendering UI, as the narrative above requires.

Where an SDK renders survey UI through a renderer or delegate that the application installs
separately, the enabled default SHALL NOT make the SDK do survey matching work while no renderer
is installed. With only a no-op default delegate in place, the SDK SHALL keep the loaded survey
definitions and SHALL skip eligibility matching, so no `$feature_flag_called` event is emitted
for a survey's linked feature flag and no survey property filters run over captured events, for a
survey the application cannot display. Installing a renderer or delegate SHALL resume matching
under the normal eligibility rules.

#### Scenario: Surveys are enabled when the application sets no option (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and no surveys option set
- **AND** the mock server will return surveys:
  | id       | name       | active |
  | survey-1 | NPS Survey | true   |
- **WHEN** surveys are loaded
- **THEN** cached surveys should include survey "survey-1"

#### Scenario: An explicit local off disables the subsystem (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys disabled
- **AND** the mock server will return surveys:
  | id       | name       | active |
  | survey-1 | NPS Survey | true   |
- **WHEN** surveys are loaded
- **THEN** cached surveys should be empty

#### Scenario: An enabled default does no matching work without a renderer (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and no surveys option set
- **AND** the SDK has no survey renderer or delegate installed
- **AND** cached surveys include an active survey "survey-1" linked to feature flag "survey-flag"
- **WHEN** survey eligibility is evaluated
- **THEN** survey display callback should not be invoked for survey "survey-1"
- **AND** no event named "$feature_flag_called" should be enqueued
