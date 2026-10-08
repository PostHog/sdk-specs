## Narrative alignment

When syncing this delta, update the Public signatures section so `ClientSetupConfig` is described as containing the **project token** plus runtime options, and update the surface variants to `new PostHog(apiKey, options?)` for React Native (unchanged, still `apiKey`) while noting that iOS, Android, Flutter, .NET, and KMP configs name the credential `projectToken`. Add to Behavior step 1 that the renamed SDKs trim leading and trailing whitespace from the configured value, and that posthog-js (browser, React Native, Node) has not adopted the name. Leave the setup scenarios and unrelated sections unchanged.

## ADDED Requirements

### Requirement: Project token configuration option name

The project credential a client SDK is configured with is a PostHog project token, not an API key. The SDK SHALL name the configuration option carrying it `projectToken`, adapted to platform casing — `ProjectToken`, or `com.posthog.posthog.PROJECT_TOKEN` for a manifest or `Info.plist` auto-init key.

#### Scenario: Setup accepts the project token option
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK has not been initialized
- **WHEN** setup is called with the project token option set to "test-token" and host "https://mock.posthog.test"
- **THEN** the SDK should be initialized
- **WHEN** capture is called with event "Hello"
- **AND** flush is called
- **THEN** the mock server should have received a batch with API key "test-token"

### Requirement: Deprecated project credential alias

An SDK that previously named the project token option `apiKey` SHALL keep the old name as a deprecated alias rather than removing it in the same release. The alias SHALL resolve to the same value, SHALL be marked deprecated in whatever way the platform expresses deprecation, and SHALL log a warning naming `projectToken` as the replacement. The alias MAY be removed in the SDK's next major version. When both names are supplied, `projectToken` SHALL win.

#### Scenario: Deprecated alias configures the same token and warns (@legacy_token_alias)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK has not been initialized
- **WHEN** setup is called with the deprecated project credential option set to "test-token" and host "https://mock.posthog.test"
- **THEN** the SDK should be initialized
- **AND** a deprecation warning naming the project token option should be logged
- **WHEN** capture is called with event "Hello"
- **AND** flush is called
- **THEN** the mock server should have received a batch with API key "test-token"

#### Scenario: Project token option wins over the deprecated alias (@legacy_token_alias)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK has not been initialized
- **WHEN** setup is called with the project token option set to "new-token" and the deprecated project credential option set to "old-token"
- **THEN** the SDK should be initialized
- **WHEN** capture is called with event "Hello"
- **AND** flush is called
- **THEN** the mock server should have received a batch with API key "new-token"

### Requirement: Project token rename stops at the public configuration surface

Renaming the option SHALL NOT change anything below the public configuration surface. Wire payload fields (`api_key`, `token`) keep their names and carry the same value, and persisted queue and preference paths are unchanged so data stored before the rename survives the upgrade. Positional first-argument constructors are unaffected, because the parameter name is not part of the call.

#### Scenario: Setup reads a queue persisted before the rename
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** the mock PostHog server is reset
- **GIVEN** persistent storage contains a queued event named "Earlier" written before the rename
- **WHEN** setup is called with the project token option set to "test-token" and host "https://mock.posthog.test"
- **AND** flush is called
- **THEN** the mock server should have received a batch with API key "test-token"
- **AND** the batch should contain an event named "Earlier"
