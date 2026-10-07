## ADDED Requirements

### Requirement: The survey wait period starts when a survey is shown

The SDK SHALL gate repeat display on two distinct pieces of persisted state: a **per-survey seen
key**, and a single device-wide **last-seen survey date**. They are written at different moments and
SHALL NOT be collapsed into one.

The SDK SHALL write the device-wide last-seen survey date when a survey is shown — at the point the
survey becomes visible, before or alongside the `survey shown` event — and SHALL NOT defer that
write to submit or dismiss. A survey's `seenSurveyWaitPeriodInDays` condition SHALL be evaluated
against that date, so showing any survey starts the wait period for every survey that carries one.

The per-survey seen key is unchanged: it SHALL still be written only when the survey is submitted or
dismissed. Showing a survey SHALL NOT mark it seen, so an unanswered survey without a wait period
can come back.

Deferring the date to submit or dismiss loses the wait period whenever a display does not reach
either: if the application terminates while a survey is on screen, the next launch sees no last-seen
date and can show another survey immediately.

A survey resumed from persisted in-progress response state SHALL be subject to the wait period like
any other display, because the earlier show already wrote the date. An SDK SHALL NOT exempt
in-progress surveys from the check.

The write SHALL happen under whatever lock or serialization guards the active survey, so a `reset`
that lands between the display decision and the write cannot be followed by a stale date. `reset`
SHALL clear the last-seen survey date along with the rest of locally owned survey history.

#### Scenario: Showing a survey starts the wait period for other surveys
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** cached surveys include an active survey "survey-1" eligible for the current user
- **AND** cached surveys include an active survey "survey-2" eligible for the current user with a seen-survey wait period of 7 days
- **WHEN** survey eligibility is evaluated
- **THEN** survey display callback should be invoked for survey "survey-1"
- **WHEN** survey eligibility is evaluated again
- **THEN** survey display callback should not be invoked for survey "survey-2"

#### Scenario: The wait period survives a restart while a survey is open
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** cached surveys include an active survey "survey-1" eligible for the current user
- **AND** cached surveys include an active survey "survey-2" eligible for the current user with a seen-survey wait period of 7 days
- **WHEN** survey eligibility is evaluated
- **THEN** survey display callback should be invoked for survey "survey-1"
- **WHEN** the SDK is restarted against the same persistent storage without survey "survey-1" being submitted or dismissed
- **AND** survey eligibility is evaluated
- **THEN** survey display callback should not be invoked for survey "survey-2"

#### Scenario: Showing a survey does not mark it seen
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** cached surveys include an active survey "survey-1" eligible for the current user with no seen-survey wait period
- **WHEN** survey eligibility is evaluated
- **THEN** survey display callback should be invoked for survey "survey-1"
- **AND** survey "survey-1" should not be marked seen
- **WHEN** the SDK is restarted against the same persistent storage without survey "survey-1" being submitted or dismissed
- **AND** survey eligibility is evaluated
- **THEN** survey display callback should be invoked for survey "survey-1"

#### Scenario: A resumed in-progress survey waits out its wait period
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** cached surveys include an active survey "survey-1" eligible for the current user with a seen-survey wait period of 7 days
- **WHEN** survey eligibility is evaluated
- **THEN** survey display callback should be invoked for survey "survey-1"
- **WHEN** a partial response is recorded for survey "survey-1"
- **AND** the SDK is restarted against the same persistent storage without survey "survey-1" being submitted or dismissed
- **AND** survey eligibility is evaluated
- **THEN** survey display callback should not be invoked for survey "survey-1"
