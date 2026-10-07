## ADDED Requirements

### Requirement: Environment-sourced release identifier

A server SDK that can read its process environment SHALL resolve a release identifier from the `POSTHOG_RELEASE_ID` environment variable and report it as the `$release_id` event property.

The SDK SHALL read the variable once, while the client is constructed, and reuse that value for the client's lifetime. The raw value SHALL be trimmed of surrounding whitespace, and a missing, empty, or whitespace-only value SHALL count as unset. When the value is unset, the SDK SHALL omit `$release_id` rather than sending an empty string.

When the value is set, the SDK SHALL stamp `$release_id` on the shared event path that its public event-producing methods pass through, so ordinary captures, exception captures, `identify`, `alias`, and `group_identify` events all carry it. Low-level passthrough APIs that deliberately bypass that shared path are outside this requirement.

The environment value SHALL act as a default, not an override: an explicit `$release_id` supplied in the call's properties, in super/registered properties, or in an ambient request context SHALL win. The SDK SHALL stamp `$release_id` before `before_send` runs, so a hook can inspect, replace, or remove it. The SDK SHALL NOT copy the value into `$set`, `$set_once`, or `$group_set`, because a release identifier is event context rather than a person or group property.

`$release_id` is a static, low-cardinality runtime identity property in the sense of the `feature-flag-called-tracker` minimal-event allowlist, so a minimized `$feature_flag_called` event SHALL retain it when the SDK stamped it.

#### Scenario: Release id from the environment lands on an ordinary event (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to "rel-abc123" before the client is constructed
- **WHEN** capture is called with event "Save"
- **THEN** the enqueued "Save" event should have property "$release_id" equal to "rel-abc123"

#### Scenario: An empty environment value is treated as unset (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to the empty string before the client is constructed
- **WHEN** capture is called with event "Save"
- **THEN** the enqueued "Save" event should omit "$release_id"

#### Scenario: A whitespace-only environment value is treated as unset (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to a value containing only spaces before the client is constructed
- **WHEN** capture is called with event "Save"
- **THEN** the enqueued "Save" event should omit "$release_id"

#### Scenario: Surrounding whitespace is trimmed (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to " rel-abc123 " before the client is constructed
- **WHEN** capture is called with event "Save"
- **THEN** the enqueued "Save" event should have property "$release_id" equal to "rel-abc123"

#### Scenario: Every shared-path event type carries the release id (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to "rel-abc123" before the client is constructed
- **WHEN** the SDK produces an event of type "<event>"
- **THEN** the enqueued event should have property "$release_id" equal to "rel-abc123"
  Examples:
  | event          |
  | $exception     |
  | $identify      |
  | $create_alias  |
  | $groupidentify |

#### Scenario: An explicit release id wins over the environment (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to "rel-from-env" before the client is constructed
- **WHEN** capture is called with event "Save" and property "$release_id" equal to "rel-explicit"
- **THEN** the enqueued "Save" event should have property "$release_id" equal to "rel-explicit"

#### Scenario: A registered release id wins over the environment (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to "rel-from-env" before the client is constructed
- **AND** super properties contain "$release_id" equal to "rel-registered"
- **WHEN** capture is called with event "Save"
- **THEN** the enqueued "Save" event should have property "$release_id" equal to "rel-registered"

#### Scenario: before_send can remove the release id (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to "rel-abc123" before the client is constructed
- **AND** a before_send hook that deletes "$release_id" from the event properties
- **WHEN** capture is called with event "Save"
- **THEN** the delivered "Save" event should omit "$release_id"

#### Scenario: The release id stays out of person and group properties (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to "rel-abc123" before the client is constructed
- **WHEN** the SDK sets person properties and group properties
- **THEN** the enqueued event properties should have "$release_id" equal to "rel-abc123"
- **AND** "$set", "$set_once", and "$group_set" should omit "$release_id"

#### Scenario: A minimized flag-called event keeps the release id (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to "rel-abc123" before the client is constructed
- **AND** the server reports the minimal flag-called event gate for flag "beta-ui" with experiment linkage exactly `false`
- **WHEN** get feature flag "beta-ui" is called
- **THEN** the enqueued "$feature_flag_called" event should be minimized per the allowlist
- **AND** it should have property "$release_id" equal to "rel-abc123"
