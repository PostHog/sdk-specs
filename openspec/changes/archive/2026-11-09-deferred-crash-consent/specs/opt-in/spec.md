## Narrative alignment

When syncing this delta, extend `optOut` step 5 to say that a mobile client SDK whose fatal crashes are recorded by a platform mechanism it cannot turn off records, at opt-out, that consent is off, so a crash recorded after that point is not sent later. Under Interactions, add a **Deferred crash reports** bullet pointing at the requirement below: a crash report follows the consent state at the time of the crash, a report recorded while opted out is never sent, and a consented report found by an opted-out launch waits for opt-in. In `openspec/specs/consent-gating/spec.md`, extend the "exception capture" line under Interactions with one sentence: a crash recorded by a platform mechanism and reconstructed on a later launch follows the consent state at crash time, per the `opt-in` requirement "Deferred crash reports honour consent at crash time". Leave the existing scenarios and unrelated sections unchanged.

## ADDED Requirements

### Requirement: Deferred crash reports honour consent at crash time

A client SDK that reconstructs a terminating failure on a later launch rather than capturing it in-process (a native crash, an out-of-memory termination, or any failure recorded by a platform mechanism that outlives the process; iOS, Android, and React Native and Flutter on a native platform through the native SDK) SHALL decide whether to send the reconstructed `$exception` from the consent state at the time of the failure, not from the consent state at the time the report is found. A report of a failure that occurred while the SDK was opted out SHALL NOT be sent on any later launch, regardless of the consent state at that launch. A report of a failure that occurred while the SDK was opted in SHALL remain deliverable: when the launch that finds it is opted out, the SDK SHALL leave the report in place and deliver it once the user opts in, and SHALL NOT discard or acknowledge it merely because opt-out happened later. The requirement is on the observable outcome, not the mechanism: because the recording mechanism usually cannot be disabled once installed, the SDK MAY mark the recording context at opt-out so that a report recorded after that point carries the marker, or MAY persist the opt-out intervals and compare each report's failure time against them. Where the SDK writes identity or event properties into the crash context (see `exception-steps`, "Crash-durable persistence for fatal-crash SDKs"), opting out SHALL also stop that context from carrying the user's identity or properties into any later failure. Reports recorded by SDK versions that predate the consent signal are out of scope and MAY be sent. This requirement does not apply to the browser SDK, to Flutter on web, or to uncaught-exception handlers that capture in-process, whose `$exception` is gated at capture time by `consent-gating`.

#### Scenario: A crash recorded while opted out is not sent after opt in
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the SDK reconstructs terminating failures on a later launch
- **AND** analytics capture is opted out
- **WHEN** a terminating failure is recorded at "2025-01-01T00:10:00Z"
- **AND** the application is relaunched
- **AND** opt in is called
- **THEN** no event named "$exception" should be enqueued
- **AND** no event named "$exception" should be sent

#### Scenario: A crash recorded while opted in is delivered once consent returns
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the SDK reconstructs terminating failures on a later launch
- **AND** analytics capture is opted in
- **WHEN** a terminating failure is recorded at "2025-01-01T00:10:00Z"
- **AND** the application is relaunched with analytics capture opted out
- **THEN** no event named "$exception" should be enqueued
- **AND** no network request should be sent
- **WHEN** opt in is called
- **THEN** one event named "$exception" should be enqueued
- **AND** that event should describe the failure recorded at "2025-01-01T00:10:00Z"

#### Scenario: A crash after a runtime opt out is not sent after opt in
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the SDK reconstructs terminating failures on a later launch
- **WHEN** opt out is called
- **AND** a terminating failure is recorded at "2025-01-01T00:10:00Z"
- **AND** the application is relaunched
- **AND** opt in is called
- **THEN** no event named "$exception" should be enqueued
- **AND** no event named "$exception" should be sent
