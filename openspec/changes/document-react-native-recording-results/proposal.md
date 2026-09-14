## Why

[posthog-js#4884](https://github.com/PostHog/posthog-js/pull/4884) adds boolean results to React Native's manual replay controls, while the shared specs still list `Promise<void>`. We need an explicit platform variant before this API ships, without requiring unrelated changes to every SDK.

## What Changes

- Keep `void | Promise<void>` as the canonical start and stop return contract.
- Specify React Native's `Promise<boolean>` variant and its attempt-level meaning, including cancellation and unavailable native state confirmation.
- Describe bounded retries for a refused manual start and the lifecycle events that cancel pending starts.
- Leave Flutter's `Future<void>` and native/browser signatures unchanged. Other bridged SDKs need their own reviewed proposal before adopting boolean results.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `start-session-recording`: Allow the React Native boolean result variant, request supersession, and bounded retries.
- `stop-session-recording`: Allow the React Native boolean result variant for completion of the native stop call, including an already-inactive recorder.

## Impact

This proposal follows the implementation in posthog-js#4884. It does not change any SDK implementation or claim that the pending React Native API has shipped. React Native releases the additional result as a minor version. Website documentation must identify that released version before publication.

After review approves this proposal, apply and archive it on the same PR. Archiving must also update the React Native entries in the existing public-signature sections, so they do not continue to contradict the new requirements.
