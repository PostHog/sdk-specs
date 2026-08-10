# Surveys Delta: Survey Intro Screen

## ADDED Requirements

### Requirement: Survey intro screen

The SDK SHALL support an optional intro screen shown before the first survey question, configured
via `SurveyAppearance` fields: `displayIntroScreen` (off by default), `introScreenHeader`,
`introScreenDescription`, `introScreenDescriptionContentType`, and `introScreenButtonText`. The
intro screen is a leading mirror of the existing trailing confirmation ("thank you") message,
letting survey authors set context before question 1 without recording a throwaway first
question.

Advancing past the intro screen SHALL NOT emit any capture event, SHALL NOT record a survey
response, and SHALL NOT affect completion or partial-response accounting for the survey.
Question indices SHALL be unaffected by the intro screen's presence — the first real question
keeps its natural index whether or not an intro screen precedes it.

The intro screen SHALL be skipped (the survey starts directly at its first question or
confirmation branch) when either of the following holds:

- the survey is resumed with existing in-progress answers, including answers sourced from a
  URL-prefilled response; or
- the current user has already completed the survey, in which case the confirmation branch takes
  precedence over the intro screen.

Dismissing the intro screen (e.g. via a close/X control) SHALL emit the survey's normal
`survey dismissed` event, the same as dismissing the survey at any other point.

Intro screen copy fields SHALL be translatable using the same per-language translation mechanism
already used for other survey appearance and confirmation-message fields.

#### Scenario: Intro screen is shown before the first question when enabled
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** survey "survey-1" has appearance field `displayIntroScreen` set to true
- **AND** survey "survey-1" is visible
- **WHEN** survey "survey-1" is rendered
- **THEN** the intro screen should be shown before the first question

#### Scenario: Intro screen is off by default
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** survey "survey-1" does not set the `displayIntroScreen` appearance field
- **AND** survey "survey-1" is visible
- **WHEN** survey "survey-1" is rendered
- **THEN** the first question should be shown immediately with no intro screen

#### Scenario: Advancing the intro screen records no response and no event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** survey "survey-1" has appearance field `displayIntroScreen` set to true
- **AND** the intro screen for survey "survey-1" is currently shown
- **WHEN** the user advances past the intro screen
- **THEN** no event should be enqueued
- **AND** no response should be recorded for survey "survey-1"
- **AND** the first question should now be shown

#### Scenario: Intro screen is skipped for a resumed in-progress survey
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** survey "survey-1" has appearance field `displayIntroScreen` set to true
- **AND** survey "survey-1" has an in-progress response already recorded
- **WHEN** survey "survey-1" is rendered
- **THEN** the intro screen should not be shown
- **AND** the survey should resume at its in-progress question

#### Scenario: Dismissing the intro screen emits survey dismissed
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** survey "survey-1" has appearance field `displayIntroScreen` set to true
- **AND** the intro screen for survey "survey-1" is currently shown
- **WHEN** the user dismisses survey "survey-1" from the intro screen
- **THEN** one event named "survey dismissed" should be enqueued
