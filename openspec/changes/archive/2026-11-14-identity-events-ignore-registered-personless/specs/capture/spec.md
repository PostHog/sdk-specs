## ADDED Requirements

### Requirement: Identity events ignore a registered personless setting

On a client SDK, a registered (super) `$process_person_profile` property, and a
`process_person_profile` event option registered as a default for every event, SHALL NOT turn
person processing off on an identity event. The identity events are `$identify`, `$create_alias`,
`$merge_dangerously`, `$groupidentify`, `$set` and `$set_once`, whichever public API emits them.
The SDK SHALL drop the registered value from those events rather than send an explicit `true`:
capture reads an absent `process_person_profile` and `true` the same way, so dropping it leaves the
rest of the identity payload unchanged.

This is a narrow exception to "Caller-supplied event properties take precedence". It covers person
processing on identity events only. Every other key keeps that requirement's layering, and every
other event keeps the registered value, including a registered `false` that makes an ordinary event
personless.

A value the caller passes on the identity call itself SHALL still apply in both directions, whether
it is passed as a `process_person_profile` option or as a `$process_person_profile` property, and
`before_send` SHALL still have the final say wherever the SDK runs the hook for that event. A
person-profiles mode of `never` SHALL still skip these calls entirely: this requirement does not
create person profiles for an app that turned them off.

The reason is that PostHog's ingestion treats an identity event with person processing off as
invalid. It drops `$identify`, `$create_alias`, `$merge_dangerously` and `$groupidentify` with the
ingestion warning `invalid_event_when_process_person_profile_is_false`, and keeps a `$set` or
`$set_once` without its person update. Without this rule, registering the setting once silently
stops an app identifying its users.

Server SDKs reach the same outcome through the call layer rather than through a registered layer,
and a server event whose distinct id the SDK generated stays personless; that behavior is specified
with the rest of the server identity fallbacks, not here.

#### Scenario: A registered personless property does not reach an identify event (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and person profiles mode "always"
- **AND** registered properties are:
  | property                | value |
  | $process_person_profile | false |
- **WHEN** identify is called with distinct id "user-123"
- **AND** the SDK is flushed
- **THEN** one event named "$identify" should be received
- **AND** its person processing setting should not be `false`

#### Scenario: A registered personless event option does not reach a group identify event (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and person profiles mode "always"
- **AND** the event option "process_person_profile" is registered as `false` for every event
- **WHEN** group identify is called for group type "company" and key "id:5"
- **AND** the SDK is flushed
- **THEN** one event named "$groupidentify" should be received
- **AND** its person processing setting should not be `false`

#### Scenario: A personless value passed on the call still applies (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and person profiles mode "always"
- **WHEN** set person properties is called with person processing set to `false` on the call
- **AND** the SDK is flushed
- **THEN** one event named "$set" should be received
- **AND** its person processing setting should be `false`

#### Scenario: An ordinary event keeps the registered personless setting (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and person profiles mode "always"
- **AND** registered properties are:
  | property                | value |
  | $process_person_profile | false |
- **WHEN** capture is called with event "Signed Up"
- **AND** the SDK is flushed
- **THEN** one event named "Signed Up" should be received
- **AND** its person processing setting should be `false`
