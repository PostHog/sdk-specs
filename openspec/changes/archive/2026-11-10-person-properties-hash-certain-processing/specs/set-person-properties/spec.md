## Narrative alignment

When syncing this delta, add a bullet to `set-person-properties` Behavior step 5: only an update that surely processes the person checks or records the cache, per the requirement below. In `openspec/specs/identify/spec.md`, extend "Update cached person-properties hash only if capture accepted the `$identify` event." in the client-side flow and the "Cached person-properties hash" state note to say the hash is updated only when the update surely processes the person, and is cleared otherwise, per the `set-person-properties` requirement. Leave the existing scenarios and unrelated sections unchanged.

## ADDED Requirements

### Requirement: The person-properties hash only tracks updates that surely process the person

A client SDK that skips duplicate person-property updates with a cached hash (from `set-person-properties` or a same-user `$set` from `identify`) SHALL read the person-processing setting of each update as it is sent: a non-null `process_person_profile` option, including a registered one, wins over the legacy `$process_person_profile` property. The SDK SHALL check the update against the hash, and record the hash once the update is queued, only when that setting is missing or the Boolean `true`. For any other value, including `false`, a false string such as `"false"`, a number, or a value PostHog can't read, the SDK SHALL send the update without checking the hash and SHALL clear the stored hash, so a later update back to the previous properties is sent. The SDK SHALL NOT decide that a value is surely personless by parsing it: how PostHog reads such values is defined by the server, and a client that disagrees would keep a hash for an update the server applied. Scenarios that pass a per-call capture option to set person properties are tagged `@per_call_capture_options_capable` and apply only to SDKs whose set person properties call accepts one.

#### Scenario: A personless update does not suppress the same update later (@per_call_capture_options_capable)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current distinct id is "user-123"
- **WHEN** set person properties is called with property "plan" set to "pro"
- **AND** set person properties is called with property "plan" set to "pro" and capture option "process_person_profile" set to false
- **AND** set person properties is called with property "plan" set to "pro"
- **THEN** 3 events named "$set" should be enqueued

#### Scenario: A personless update clears the stored hash (@per_call_capture_options_capable)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current distinct id is "user-123"
- **WHEN** set person properties is called with property "plan" set to "pro"
- **AND** set person properties is called with property "plan" set to "pro" and capture option "process_person_profile" set to "maybe"
- **AND** set person properties is called with property "plan" set to "pro"
- **THEN** 3 events named "$set" should be enqueued

#### Scenario: A repeated update that surely processes the person is skipped (@per_call_capture_options_capable)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current distinct id is "user-123"
- **WHEN** set person properties is called with property "plan" set to "pro" and capture option "process_person_profile" set to true
- **AND** set person properties is called with property "plan" set to "pro"
- **THEN** 1 event named "$set" should be enqueued
