## ADDED Requirements

### Requirement: Caller-supplied event properties take precedence

On client SDKs, a property the caller passes on an event SHALL win over a registered (super) property with the same key and over an SDK context property with the same key, such as `$lib`, `$lib_version`, `$os`, `$app_version`, `$screen_width`, `$current_url`, `$screen_name`, `$feature/<key>` or `$active_feature_flags`. A group the caller passes for the event SHALL win over a registered group of the same type.

The SDK SHALL set `$is_identified` and `$process_person_profile` after merging the caller's properties, so a caller can't override the SDK's identity or person-processing state for a single event.

The SDK MAY also set these SDK-owned per-event keys after merging the caller's properties:

- the session replay debug properties (`$recording_status` and the `$sdk_debug_*` keys), as defined by `session-replay-debug-properties`
- `$session_id` and `$window_id`. posthog-js and `@posthog/core`-based SDKs set the current session; posthog-ios and posthog-android keep a non-empty caller-supplied `$session_id`.
- `$geoip_disable`, when the SDK is configured to disable GeoIP
- posthog-js page and session bookkeeping, such as `token`, `$config_defaults`, `$duration` and the `$session_entry_*` and pageview properties

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

#### Scenario: Caller can't override person-processing state (@client)
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
  | $process_person_profile | false |
  | $is_identified          | false |
