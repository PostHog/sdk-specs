## MODIFIED Requirements

### Requirement: Caller-supplied event properties take precedence

On client SDKs, an event's properties SHALL be merged in this order, each layer overwriting the one before:

1. Properties the SDK sets itself.
2. Registered (super) properties.
3. The properties the caller passes on the event.

`before_send` (Behavior step 6) then runs over the assembled message and can change any of them.

A registered or caller value for a key the SDK sets itself changes that event only. It SHALL NOT change the SDK's own state: a later event without that key carries the SDK's value again, and a caller `$process_person_profile` does not turn person processing on or off for the SDK.

The project token is request routing, not an event property. Where an SDK carries it on the event (posthog-js stamps `token` on every event and takes the batch `api_key` from it), the SDK SHALL set the configured token on every event, and a registered or caller `token` SHALL NOT replace it.

A group the caller passes for the event SHALL win over a registered group of the same type.

This requirement does not apply to server SDKs. Most server SDKs set `$lib` and `$lib_version` after the caller's properties, and python, go, dotnet and elixir apply their SDK-level default properties after the caller's properties as well.

#### Scenario: Caller property overrides an SDK context property (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** capture is called with event "Signed Up" and properties:
  | property | value      |
  | $lib     | custom-lib |
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event properties should include:
  | property | value      |
  | $lib     | custom-lib |

#### Scenario: Registered property overrides an SDK-set property (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and person profiles mode "never"
- **AND** registered properties are:
  | property       | value |
  | $is_identified | true  |
- **WHEN** capture is called with event "Signed Up"
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event properties should include:
  | property       | value |
  | $is_identified | true  |

#### Scenario: Caller property overrides an SDK-set property (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and person profiles mode "never"
- **WHEN** capture is called with event "Signed Up" and properties:
  | property                | value |
  | $process_person_profile | true  |
  | $is_identified          | true  |
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event properties should include:
  | property                | value |
  | $process_person_profile | true  |
  | $is_identified          | true  |

#### Scenario: Caller property changes that event only (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and person profiles mode "never"
- **WHEN** capture is called with event "Signed Up" and properties:
  | property                | value |
  | $process_person_profile | true  |
  | $is_identified          | true  |
- **AND** capture is called with event "Viewed Dashboard"
- **THEN** one event named "Viewed Dashboard" should be enqueued
- **AND** the enqueued "Viewed Dashboard" event properties should include:
  | property                | value |
  | $process_person_profile | false |
  | $is_identified          | false |
