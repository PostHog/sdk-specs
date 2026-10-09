## ADDED Requirements

### Requirement: Build-invariant context properties

A property whose value changes only when the app binary is rebuilt — the wrapper runtime version, or the build toolchain — SHALL ride `Application Installed` and `Application Updated`, and SHALL NOT be added to the common event context. It SHALL be omitted when the platform reports no value. Where the runtime has no lifecycle events, or lifecycle capture is disabled, it is not sent at all. `$lib`, `$lib_version`, `$app_version` and `$app_build` are exempt and SHALL stay on every event.

#### Scenario: A build-invariant property rides install and update only
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and application lifecycle capture enabled
- **AND** the platform reports this SDK's build-invariant property, such as `$flutter_version` on Flutter, `$react_native_version` on React Native, or `$app_build_xcode` on iOS
- **WHEN** the application lifecycle integration starts
- **AND** the app captures an event named "custom event"
- **THEN** the enqueued "Application Installed" event properties should include that property
- **AND** the enqueued "custom event" properties should not include that property

#### Scenario: Missing platform metadata omits the property
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and application lifecycle capture enabled
- **AND** the platform reports no value for this SDK's build-invariant property
- **WHEN** the application lifecycle integration starts
- **THEN** one event named "Application Installed" should be enqueued
- **AND** that event's properties should not include the property key

#### Scenario: Common context properties are unaffected
- **GIVEN** a fresh SDK acceptance test harness
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and application lifecycle capture enabled
- **WHEN** the app captures an event named "custom event"
- **THEN** the enqueued "custom event" properties should include `$lib`, `$lib_version`, `$app_version` and `$app_build`
