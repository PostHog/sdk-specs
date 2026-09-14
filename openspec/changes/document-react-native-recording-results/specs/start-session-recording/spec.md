## ADDED Requirements

### Requirement: React Native start result variant

The canonical return contract SHALL remain `void | Promise<void>`. React Native SHALL expose the explicit variant `startSessionRecording(resumeCurrent = true): Promise<boolean>`. This variant SHALL NOT change Flutter's `Future<void>` or the other SDK signatures.

React Native SHALL resolve the result of the current request's initial attempt without waiting for later retries. A completed native start with active recorder confirmation SHALL return `true`. A disabled or opted-out SDK, unavailable integration, unsupported platform, failed start, or refused start SHALL return `false`. If the native start completes but the state-confirmation call rejects, React Native SHALL log a warning and return `true` without claiming confirmed activation. Neither result SHALL guarantee future recording state or server-side replay delivery.

#### Scenario: Native start is confirmed active
- **GIVEN** React Native has an available replay plugin and an enabled, opted-in SDK
- **WHEN** the native start completes and native state confirmation reports active
- **THEN** `startSessionRecording()` resolves `true`

#### Scenario: Native recorder refuses an early start
- **GIVEN** native config has not loaded and the native recorder refuses a start
- **WHEN** the bridge call completes and native state confirmation reports inactive
- **THEN** `startSessionRecording()` resolves `false` without waiting for retries

#### Scenario: Replay cannot be started
- **GIVEN** the SDK is disabled or opted out, replay is unsupported, or the native integration is unavailable
- **WHEN** the app calls `startSessionRecording()`
- **THEN** the promise resolves `false`

#### Scenario: Native start fails
- **WHEN** the native start call rejects
- **THEN** React Native logs the failure and resolves `false`

#### Scenario: Native state confirmation is unavailable
- **GIVEN** the native start call completes
- **WHEN** the subsequent native state-confirmation call rejects
- **THEN** React Native logs a warning and resolves `true`
- **AND** the result does not establish that the recorder is active

### Requirement: React Native manual start supersession

React Native SHALL let a newer manual start supersede an unfinished manual start request. The superseded request SHALL resolve `false`. It SHALL NOT restore its pending intent after an in-flight native call finishes. Replay operations SHALL remain serialized so cancellation cleanup does not stop a newer completed start.

#### Scenario: Two starts are queued without awaiting either
- **GIVEN** the first call requests a new session with `resumeCurrent = false`
- **WHEN** a second call with `resumeCurrent = true` supersedes it before its native attempt begins
- **AND** the second call successfully starts recording
- **THEN** the first promise resolves `false` and the second resolves `true`
- **AND** the cancelled first call does not rotate the session

### Requirement: React Native bounded manual start retries

After a refused manual start with initialized native replay and an available `startRecording` bridge method, React Native SHALL schedule at most five timer retries per explicit request. The successive delays SHALL be 1, 2, 4, 8, and 16 seconds. Timer retries SHALL NOT request JS feature flags. Later retries SHALL resume the current session rather than repeat a requested initial session rotation.

While the request remains pending, later feature flags loads SHALL also retry it. Exhausting the timer budget SHALL NOT guarantee recovery or prevent a later flags-driven retry. An explicit new start SHALL receive its own retry budget. Stop, reset, opt-out, and shutdown SHALL cancel the pending request, including queued and in-flight work. A successful retry SHALL cancel remaining retries.

#### Scenario: Native readiness arrives without a JS flags reload
- **GIVEN** native refuses the initial manual start
- **WHEN** native becomes ready before a later timer attempt
- **THEN** that attempt can start recording without another JS flags request
- **AND** no more retries are scheduled after success

#### Scenario: Timer budget is exhausted
- **GIVEN** native refuses the initial attempt and all five timer retries
- **WHEN** more time passes without a flags load or an explicit start
- **THEN** React Native does not schedule another timer retry
- **AND** a later flags load can retry the pending request

#### Scenario: Stop cancels an in-flight retry
- **GIVEN** a native retry is in flight when the app calls `stopSessionRecording()`
- **WHEN** the retry completes successfully after cancellation
- **THEN** React Native stops that recorder on the serialized replay chain
- **AND** the cancelled request does not schedule another retry

#### Scenario: A lifecycle operation cancels pending intent
- **GIVEN** a manual start is queued or pending retry
- **WHEN** the app resets, opts out, or shuts down the SDK
- **THEN** that request does not start recording after cancellation
