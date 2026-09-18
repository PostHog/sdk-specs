## Why

`start-session-recording` describes crash-containment only in prose. The spec says the call "should not throw" and unavailable replay integrations "no-op or log", and `session-replay-privacy` says capture must "fail closed ... rather than crash the app". No acceptance scenario tests it. Nothing forces two SDKs to converge on the same behavior when replay setup fails.

A customer upgraded posthog-android and posthog-ios together and hit a host-app crash on both platforms during replay setup, before the first masked frame. The direct fixes land in the two SDK repos. This change closes the spec gap so both SDKs are held to the same bar.

## What Changes

- Add a canonical requirement to `start-session-recording`: when the replay configuration is invalid, or the replay integration is unavailable or fails to initialize, the SDK MUST no-op or log and MUST NOT throw into host application code.
- Require session recording to stay inactive after a contained setup failure, and promise-returning variants to resolve rather than reject.
- Add public acceptance coverage for both failure inputs.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `start-session-recording`: Require replay setup and configuration failures to be contained so they never crash the host application.

## Impact

The change affects the canonical `start-session-recording` specification and its public acceptance coverage. The direct crash fixes still land in `posthog-android` and `posthog-ios`; this spec change holds both SDKs to the same crash-containment contract.
