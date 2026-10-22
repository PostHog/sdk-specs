## Narrative alignment

When syncing this delta, update the Public signatures section so `ClientSetupConfig` is described as containing the **project token** plus runtime options, and note under the surface variants that iOS, Android, Flutter, and KMP configs name the credential `projectToken` (`ProjectToken` in .NET's server options), that React Native's `PostHogProvider` `apiKey` prop and Unity's `ApiKey` have not been renamed yet, and that positional constructors (browser `init`, React Native `new PostHog`) are unaffected. Add to Behavior step 1 that iOS, Android, Flutter, and React Native trim leading and trailing whitespace from the configured value. Leave the setup scenarios and unrelated sections unchanged.

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

An SDK whose public configuration still names the project token option `apiKey` (or `ApiKey`) SHALL add `projectToken` and keep the old name as a deprecated alias in the same release, so the rename does not require a major version. The alias SHALL resolve to the same value and SHALL be marked deprecated in whatever way the platform expresses deprecation, naming `projectToken` as the replacement: a compile-time deprecation where the platform has one, otherwise a logged warning. An SDK MAY additionally log a runtime warning when the alias is used. The alias MAY be removed only in a major version released after the one that added `projectToken`. Where the configuration surface accepts both names at once — an options object, a provider's props, or a manifest or `Info.plist` key — `projectToken` SHALL win.

#### Scenario: Deprecated alias configures the same token (@legacy_token_alias)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK has not been initialized
- **WHEN** setup is called with the deprecated project credential option set to "test-token" and host "https://mock.posthog.test"
- **THEN** the SDK should be initialized
- **WHEN** capture is called with event "Hello"
- **AND** flush is called
- **THEN** the mock server should have received a batch with API key "test-token"

#### Scenario: Project token option wins over the deprecated alias (@both_token_names_capable)
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
- **GIVEN** persistent storage contains a queued event named "Earlier"
- **WHEN** setup is called with the project token option set to "test-token" and host "https://mock.posthog.test"
- **AND** flush is called
- **THEN** the mock server should have received a batch with API key "test-token"
- **AND** the batch should contain an event named "Earlier"
