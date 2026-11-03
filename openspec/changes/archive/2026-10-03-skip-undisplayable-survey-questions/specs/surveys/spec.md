## ADDED Requirements

### Requirement: Surveys with undisplayable questions are not shown

A survey SHALL be displayed only when the SDK can display **every** question in it. When a survey
contains a question whose type the SDK cannot display — typically a question type the API gained
after that SDK version shipped — the SDK SHALL treat the whole survey as not displayable: it SHALL
log the reason and return without displaying any part of the survey and without emitting `survey
shown` or any other survey interaction event. A survey skipped this way SHALL NOT be marked seen,
and skipping it SHALL NOT write a seen key or the device-wide last-seen survey date, so a later SDK
version that can display the question type is still able to show it. A skipped survey SHALL NOT
prevent another eligible survey from being displayed.

The SDK SHALL NOT display only the subset of questions it can display. Question identity, branching,
and response keys are computed against the survey's full question list, so a partial display
desynchronizes the displayed question from that list: after the last displayed question the SDK
branches to a question that is not on screen, leaving an inert prompt and no completed `survey sent`
event.

Where the SDK exposes a public renderability check (a `canRenderSurvey`-style API), that check SHALL
report such a survey as not displayable, so a caller that asks before displaying gets the same
answer as the display path. SDKs that delegate display to a host UI layer (custom, wrapper, or
framework-native renderers) SHALL apply the check on the shared path that feeds those renderers
rather than in each renderer.

#### Scenario: Survey containing an undisplayable question type is not shown
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** cached surveys include an active survey "survey-1" eligible for the current user
- **AND** survey "survey-1" contains a question whose type the SDK cannot display
- **AND** cached surveys include an active survey "survey-2" eligible for the current user
- **AND** every question in survey "survey-2" has a type the SDK can display
- **WHEN** survey eligibility is evaluated
- **THEN** survey display callback should not be invoked for survey "survey-1"
- **AND** no survey response or display event should be enqueued for survey "survey-1"
- **AND** survey display callback should be invoked for survey "survey-2"

#### Scenario: A skipped survey is not marked seen
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** cached surveys include an active survey "survey-1" eligible for the current user
- **AND** survey "survey-1" contains a question whose type the SDK cannot display
- **WHEN** survey eligibility is evaluated
- **THEN** survey "survey-1" should not be marked seen
- **AND** the device-wide last-seen survey date should not be written

#### Scenario: A survey whose questions are all displayable is unaffected
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** cached surveys include an active survey "survey-1" eligible for the current user
- **AND** every question in survey "survey-1" has a type the SDK can display
- **WHEN** survey eligibility is evaluated
- **THEN** survey display callback should be invoked for survey "survey-1"
