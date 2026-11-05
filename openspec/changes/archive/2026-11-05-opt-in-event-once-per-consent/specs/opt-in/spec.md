## ADDED Requirements

### Requirement: Consent event is captured once per opt-in transition

An SDK that captures a consent event when the caller opts in — `$opt_in` in the browser — SHALL
capture it only when the call changes the stored consent state. When the caller is already opted
in, the SDK SHALL capture no consent event.

Consent managers commonly call the opt-in API from a consent-change callback that fires on every
page load once consent is stored, so capturing on every call sends one consent event per page view
that records nothing the previous one did not.

A caller-supplied consent event name is the same event under another name and SHALL be suppressed
on the same terms.

Consent already stored and read back by a later page load or SDK instance counts as already opted
in. Opting out and opting back in, and a `reset()` followed by an opt-in, are transitions and SHALL
capture the consent event again.

Suppression covers the consent event only. Everything else the opt-in path does — persisting the
consent state, resuming capture, draining queued work, restarting subsystems such as session replay
and surveys, and any initial pageview the SDK sends on opt-in — SHALL still run on a repeat call.

#### Scenario: Opting in twice captures one consent event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the SDK captures a consent event on opt in
- **WHEN** opt in is called
- **THEN** one consent event should be enqueued
- **WHEN** opt in is called again
- **THEN** no further consent event should be enqueued

#### Scenario: A custom consent event name is suppressed on the same terms
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the SDK captures a consent event on opt in
- **AND** analytics capture is opted in
- **WHEN** opt in is called with a custom consent event name
- **THEN** no event with that name should be enqueued

#### Scenario: Stored consent read on a later load captures no consent event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** the mock PostHog server is reset
- **AND** persistent storage contains opt-out state "false"
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the SDK captures a consent event on opt in
- **WHEN** opt in is called
- **THEN** no consent event should be enqueued

#### Scenario: Opting out and back in captures the consent event again
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the SDK captures a consent event on opt in
- **AND** analytics capture is opted in
- **WHEN** opt out is called
- **AND** opt in is called
- **THEN** one consent event should be enqueued

#### Scenario: A repeat opt in still resumes capture
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** analytics capture is opted in
- **WHEN** opt in is called again
- **THEN** is opt out should return false
- **AND** persistent storage should contain opt-out state "false"
- **WHEN** capture is called with event "Allowed"
- **THEN** one event named "Allowed" should be enqueued
