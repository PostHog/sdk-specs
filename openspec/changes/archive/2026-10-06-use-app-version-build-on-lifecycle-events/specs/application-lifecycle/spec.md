## MODIFIED Requirements

### Requirement: Canonical application-lifecycle behavior

The SDK SHALL implement the canonical `application-lifecycle` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

Lifecycle events SHALL carry the current app version and build through the common `$app_version` and `$app_build` event properties. They SHOULD NOT also send un-prefixed `version` and `build` properties. An SDK that sends `version` and `build` on lifecycle events today MAY keep sending them until its next major version. `Application Updated` SHALL send `previous_version` and `previous_build` when available.

#### Scenario: First app start captures install and open events
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and application lifecycle capture enabled
- **AND** the platform app version is "1.0.0" and build is "100"
- **WHEN** the application lifecycle integration starts
- **THEN** one event named "Application Installed" should be enqueued
- **AND** one event named "Application Opened" should be enqueued
- **AND** lifecycle storage should remember version "1.0.0" and build "100"

#### Scenario: Version change captures an update event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** lifecycle storage remembers version "1.0.0" and build "100"
- **AND** the platform app version is "1.1.0" and build is "110"
- **WHEN** the application lifecycle integration starts
- **THEN** one event named "Application Updated" should be enqueued
- **AND** the enqueued event properties should include:
  | property         | value |
  | $app_version     | 1.1.0 |
  | $app_build       | 110   |
  | previous_version | 1.0.0 |
  | previous_build   | 100   |

#### Scenario: Background transition captures background event once
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and application lifecycle capture enabled
- **AND** the application is foregrounded
- **WHEN** the application moves to the background
- **THEN** one event named "Application Backgrounded" should be enqueued
- **WHEN** the application moves to the background again
- **THEN** no additional "Application Backgrounded" event should be enqueued

#### Scenario: Disabled lifecycle capture emits no lifecycle analytics events
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and application lifecycle capture disabled
- **WHEN** the application lifecycle integration starts
- **AND** the application moves to the background
- **THEN** no lifecycle analytics events should be enqueued
