## MODIFIED Requirements

### Requirement: Caller-supplied event properties take precedence

On client SDKs, an event's properties SHALL be merged in this order, each layer overwriting the one before:

1. Global properties: registered (super) properties and every property the SDK sets itself, such as SDK context (`$lib`, `$lib_version`, `$os`, `$app_version`, `$screen_width`, `$current_url`, `$screen_name`, `$feature/<key>`, `$active_feature_flags`), `$is_identified`, `$process_person_profile`, `$geoip_disable`, `$session_id`, `$window_id` and the session replay debug properties.
2. The properties the caller passes on the event.
3. `before_send`.

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
