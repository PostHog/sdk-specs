## ADDED Requirements

### Requirement: React Native stop result variant

The canonical return contract SHALL remain `void | Promise<void>`. React Native SHALL expose the explicit variant `stopSessionRecording(): Promise<boolean>`. This variant SHALL NOT change Flutter's `Future<void>` or the other SDK signatures.

React Native SHALL return `true` when the native stop call completes, including when recording was already inactive. The result SHALL NOT assert that recording changed from active to inactive. It SHALL return `false` when the SDK is disabled, the platform or integration cannot perform the native stop, the plugin lacks the stop method, or the native stop call fails.

#### Scenario: Native stop completes
- **GIVEN** the native plugin supports manual stop and the SDK is enabled
- **WHEN** the native stop call completes
- **THEN** `stopSessionRecording()` resolves `true`

#### Scenario: Recorder is already inactive
- **GIVEN** recording is inactive and the native stop method is available
- **WHEN** the app calls `stopSessionRecording()` and the native call completes
- **THEN** the promise resolves `true`
- **AND** recording remains inactive

#### Scenario: Native stop is unavailable
- **GIVEN** the SDK is disabled, replay is unsupported, or the native stop method is unavailable
- **WHEN** the app calls `stopSessionRecording()`
- **THEN** the promise resolves `false`

#### Scenario: Native stop fails
- **WHEN** the native stop call rejects
- **THEN** React Native logs the failure and resolves `false`
