## ADDED Requirements

### Requirement: Remote config does not resume a stopped recording

After the application calls `stopSessionRecording()`, a remote config or `/config` load in the same process SHALL NOT resume session replay. Only the start API (`startSessionRecording()` or the platform's equivalent) SHALL resume it in that process. A new process (on the browser, a new page load) starts from the configuration again: the local configuration and the loaded remote config decide whether replay starts, and a stop from an earlier process does not carry over.

On a mobile client SDK (iOS, Android, React Native, or Flutter on a native platform), a `stopSessionRecording()` call made while the SDK is opted out SHALL NOT set this explicit stop, because replay is already stopped or uninstalled then: `opt-in` ("Opt-in restarts the session replay the app wanted at opt-out") decides whether opt-in restarts replay, and a later remote config load follows that decision. A stop call made before opt-out sets the explicit stop as above. The browser SDK and Flutter on web are unchanged: a browser `stopSessionRecording()` sets the explicit stop also when the application calls it while opted out, and it stays in effect through opt-out and opt-in.

This requirement applies to all replay-capable client SDKs.

Reference: posthog-js `origin/main` `ffdb355c4` (`packages/browser/src/posthog-core.ts:4548`: `stopSessionRecording` sets `disable_session_recording: true`; `:4530`: `startSessionRecording` sets it back to `false`; `packages/browser/src/extensions/replay/session-recording.ts:154-155`: `_isRecordingEnabled` refuses while `disable_session_recording` is set; `:342-365`: `onRemoteConfig` persists the config and calls `startIfEnabledOrStop`, which reads `_isRecordingEnabled`). The flag lives in the in-memory config, so a new page load starts from the configuration again. The browser stop has no opt-out guard: `stopSessionRecording` at `packages/browser/src/posthog-core.ts:4552-4554` (`origin/main` `f05a993f9d`) sets the flag whatever the consent state. The mobile opt-out exception is mobile-only and decision-based, with no posthog-js reference: `openspec/specs/opt-in/spec.md` ("Opt-in restarts the session replay the app wanted at opt-out", scenario "Stopping a recording while opted out does not block the restart") and `session-replay-trigger-groups` ("Explicit stop and start").

Covering test: posthog-js `packages/browser/src/__tests__/posthog-core.set_config.test.ts:431` ("should update disable_session_recording config") asserts only the flag. Surviving a remote config load: no posthog-js test on `origin/main` covers this; decision-based (the web code path above).

#### Scenario: A remote config load does not resume a stopped recording
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** session replay is configured and eligible to start
- **AND** session recording is active
- **WHEN** stop session recording is called
- **AND** remote config is reloaded
- **THEN** session recording should remain inactive
- **WHEN** start session recording is called
- **THEN** session recording should be active
