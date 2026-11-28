## MODIFIED Requirements

### Requirement: Caller-supplied event properties take precedence

On client SDKs, an event's properties SHALL be merged in this order, each layer overwriting the one before:

1. Properties the SDK sets itself.
2. Registered (super) properties.
3. The properties the caller passes on the event.

On capture v1, `$lib` and `$lib_version` are the one exception: the SDK fills its own pair after these layers and before `before_send`, as **Events name their own library** describes.

`before_send` (Behavior step 6) then runs over the assembled message and can change any of them.

A registered or caller value for a key the SDK sets itself changes that event only. It SHALL NOT change the SDK's own state: a later event without that key carries the SDK's value again, and a caller `process_person_profile` option (on legacy capture, the `$process_person_profile` property) does not turn person processing on or off for the SDK.

A registered `$process_person_profile`, and a `process_person_profile` option a wrapper SDK registers, SHALL NOT be sent with the identity events `$identify`, `$create_alias`, `$merge_dangerously`, `$groupidentify`, `$set` and `$set_once`. With person processing off, PostHog drops the first four and ignores the person update in `$set` and `$set_once`, so a registered `false` would stop `identify`, `alias`, `group` and `setPersonProperties` from working. A value passed on the call or set in `before_send` still applies. posthog-ios 4.0, posthog-android 4.0, posthog-flutter 6.0 and posthog-react-native 5.0 do this. posthog-js and posthog-react-native 4.x still send the registered value.

The project token is request routing, not an event property. Where an SDK carries it on the event (posthog-js stamps `token` on every event and takes the batch `api_key` from it), the SDK SHALL set the configured token on every event, and a registered or caller `token` SHALL NOT replace it.

A group the caller passes for the event SHALL win over a registered group of the same type.

This requirement does not apply to server SDKs. Server SDKs that deliver through capture v1 follow **Server SDKs build every event in one layer order**: the call's values win, including a caller's `$lib` and `$lib_version`, and the SDK's own identity fills only what the event leaves unset. Server SDKs still on legacy capture set `$lib` and `$lib_version` after the caller's properties, and python 7.x, go 1.x, dotnet and elixir apply their SDK-level default properties after the caller's properties as well.

#### Scenario: Caller property overrides an SDK context property (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** capture is called with event "Signed Up" and properties:
  | property  | value      |
  | $app_name | custom-app |
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event properties should include:
  | property  | value      |
  | $app_name | custom-app |

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

#### Scenario: A registered personless setting does not reach identity events (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** registered properties are:
  | property                | value |
  | $process_person_profile | false |
- **WHEN** identify is called with distinct id "user-123"
- **THEN** one event named "$identify" should be enqueued
- **AND** the enqueued "$identify" event should not include property "$process_person_profile"

### Requirement: Empty variant is not an active feature flag

When a client SDK stamps cached feature flags onto a captured event, a flag whose value is the empty string `""` SHALL NOT be listed in `$active_feature_flags`. Its `$feature/<key>` property SHALL still carry `""`.

posthog-react-native 5.0 leaves it out. Known gap: posthog-js core (and posthog-react-native 4.x) list every cached flag key in `$active_feature_flags`, including one whose value is `""`. A follow-up should leave it out there.

#### Scenario: Empty variant flag is left out of active feature flags (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key       | value |
  | beta-ui   | true  |
  | legacy-ui | ""    |
- **WHEN** capture is called with event "Signed Up"
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event property "$active_feature_flags" should contain "beta-ui"
- **AND** the enqueued event property "$active_feature_flags" should not contain "legacy-ui"
- **AND** the enqueued event property "$feature/legacy-ui" should equal ""
