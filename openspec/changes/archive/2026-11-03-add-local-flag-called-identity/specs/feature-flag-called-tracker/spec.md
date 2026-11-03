## ADDED Requirements

### Requirement: Flag definition identity on flag-called events

A `$feature_flag_called` event SHALL identify the flag definition that produced the value through
`$feature_flag_id` and `$feature_flag_version`, whether the value came from a remote evaluation
response or from local evaluation.

- A remotely evaluated read SHALL take both values from the flag's evaluation metadata in the response.
- A locally evaluated read SHALL take them from the `id` and `version` of the local flag definition that
  produced the value. An SDK SHALL NOT treat local definitions as carrying no version.
- The SDK SHALL read the local definition from the same definitions snapshot that produced the value,
  not from its current definitions state, so a definitions refresh between evaluation and capture cannot
  report another revision's identity.
- Each property SHALL be omitted when its source does not carry it. A missing `version` SHALL NOT
  suppress `$feature_flag_id`, and an absent definition SHALL NOT fail the read or the event.
- Every read path that emits `$feature_flag_called` SHALL follow this rule, including value-only,
  enabled-state and structured-result getters, and a payload read that the caller opted into tracking.
- A structured snapshot read (`evaluate-flags`) SHALL record the same `id` and `version` on the locally
  evaluated flag record it exposes, so an exposure captured from the snapshot carries them too.

`$feature_flag_id` and `$feature_flag_version` are already on the minimal-event allowlist, so a minimized
event carries whichever of them the read resolved.

#### Scenario: A locally evaluated read reports the definition's id and version (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and a personal API key for local evaluation
- **AND** local feature flag definitions include a flag "local-flag" with id 4211 and version 7 rolled out to distinct id "user-123"
- **WHEN** get feature flag "local-flag" is called for distinct id "user-123"
- **THEN** no remote flag evaluation request should be sent
- **AND** one event named "$feature_flag_called" should be enqueued
- **AND** the enqueued event properties should include:
  | property                | value      |
  | $feature_flag           | local-flag |
  | locally_evaluated       | true       |
  | $feature_flag_id        | 4211       |
  | $feature_flag_version   | 7          |

#### Scenario: A local definition without a version still reports its id (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and a personal API key for local evaluation
- **AND** local feature flag definitions include a flag "unversioned-flag" with id 4212 and no version rolled out to distinct id "user-123"
- **WHEN** get feature flag "unversioned-flag" is called for distinct id "user-123"
- **THEN** one event named "$feature_flag_called" should be enqueued
- **AND** the enqueued event properties should include:
  | property         | value |
  | $feature_flag_id | 4212  |
- **AND** the enqueued event properties should not include "$feature_flag_version"

#### Scenario: A snapshot read carries the local definition's identity (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and a personal API key for local evaluation
- **AND** local feature flag definitions include a flag "local-flag" with id 4211 and version 7 rolled out to distinct id "user-123"
- **WHEN** flags are evaluated once for distinct id "user-123"
- **AND** the enabled state of "local-flag" is read from the resulting snapshot
- **THEN** one event named "$feature_flag_called" should be enqueued
- **AND** the enqueued event properties should include:
  | property                | value |
  | $feature_flag_id        | 4211  |
  | $feature_flag_version   | 7     |
