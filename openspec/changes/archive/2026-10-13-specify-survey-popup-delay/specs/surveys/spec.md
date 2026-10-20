## ADDED Requirements

### Requirement: Survey popup delay

The SDK SHALL honor a survey's popup delay (`appearance.surveyPopupDelaySeconds`, in seconds)
when the survey definition carries one.
When the delay is a positive number, the SDK SHALL wait that long after deciding to display the
survey before the survey reaches the screen. When the delay is missing, zero, or negative, the SDK
SHALL display the survey immediately; a negative value is clamped to zero and never means "never
show".

The SDK SHALL reserve the survey as the pending prompt **before** the wait starts, not when it is
finally shown. While a survey is reserved, the SDK SHALL NOT display a second copy of it or another
eligible survey, and a repeat of the condition that selected it — the same trigger event captured
again, or another eligibility pass — SHALL NOT restart the wait. The wait is therefore measured from
the first trigger, so a trigger event that keeps firing faster than the delay cannot keep the survey
from being shown. The existing rule that only one prompt is active at a time applies from the moment
of reservation, not from the moment of display.

A survey that has not reached the screen has not been shown. Until it is displayed, the SDK SHALL
NOT emit `survey shown` and SHALL NOT mark the survey seen or write the device-wide last-seen survey
date. If the pending survey is dropped before it is displayed — hidden or cancelled by the
application, superseded, or skipped because the SDK can no longer display it — the SDK SHALL emit
neither `survey shown` nor `survey dismissed` for it, SHALL NOT mark it seen, and SHALL release the
reservation so a later survey can be displayed. The reservation SHALL also be released when the
survey is displayed, and on reset or teardown of the surveys subsystem.

When the delay elapses, the SDK SHOULD re-check that the survey is still eligible before displaying
it, because eligibility can change while the wait runs down (for example an `identify` that reloads
a targeting flag), and SHOULD release the reservation without displaying the survey when it is not.

SDKs that delegate display to a host UI layer (a native delegate, a wrapper, or a framework-native
renderer) SHALL require that layer to report back for every survey handed to it, either as shown or
as closed. A host that silently drops a survey leaves the reservation held and blocks every later
survey until reset, so a host that cannot display the survey SHALL report it closed; closing a
survey before it was shown does not mark it seen and emits no interaction event.

An SDK MAY refine where the wait starts, as the browser does, by resuming the wait from the moment
the survey's trigger fired rather than restarting it on each page load, clamping the elapsed time at
zero so a backwards clock adjustment cannot stretch the wait. An SDK MAY also let an explicit
programmatic display call bypass the configured delay. Neither is required.

#### Scenario: A survey with a popup delay is not shown until the delay elapses
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** cached surveys include an active survey "survey-1" eligible for the current user
- **AND** survey "survey-1" has a popup delay of 3 seconds
- **WHEN** survey eligibility is evaluated
- **THEN** survey display callback should not be invoked for survey "survey-1"
- **AND** no event named "survey shown" should be enqueued
- **WHEN** the SDK clock advances by "3 seconds"
- **THEN** survey display callback should be invoked for survey "survey-1"

#### Scenario: A repeat trigger during the delay does not restart it or show the survey twice
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** cached surveys include an active survey "survey-1" eligible for the current user
- **AND** survey "survey-1" is activated by the event "trigger_event"
- **AND** survey "survey-1" has a popup delay of 3 seconds
- **WHEN** the event "trigger_event" is captured
- **AND** the SDK clock advances by "2 seconds"
- **AND** the event "trigger_event" is captured again
- **AND** the SDK clock advances by "1 second"
- **THEN** survey display callback should be invoked for survey "survey-1"
- **AND** exactly one event named "survey shown" should be enqueued

#### Scenario: A missing or zero popup delay shows the survey immediately
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** cached surveys include an active survey "survey-1" eligible for the current user
- **AND** survey "survey-1" has no popup delay
- **WHEN** survey eligibility is evaluated
- **THEN** survey display callback should be invoked for survey "survey-1"

#### Scenario: A pending survey dropped before it is shown is not seen and emits no events
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and surveys enabled
- **AND** cached surveys include an active survey "survey-1" eligible for the current user
- **AND** survey "survey-1" has a popup delay of 3 seconds
- **WHEN** survey eligibility is evaluated
- **AND** survey "survey-1" is dropped before it is displayed
- **AND** the SDK clock advances by "3 seconds"
- **THEN** survey display callback should not be invoked for survey "survey-1"
- **AND** no event named "survey shown" should be enqueued
- **AND** no event named "survey dismissed" should be enqueued
- **AND** survey "survey-1" should not be marked seen
- **AND** the device-wide last-seen survey date should not be written
