## Why

Four client SDKs now agree on what `optIn()` does to session replay, and the `opt-in` spec does not record any of it. posthog-android ([#839](https://github.com/PostHog/posthog-android/pull/839)) made opt-out uninstall integrations and opt-in restart replay in a new session; posthog-flutter ([#606](https://github.com/PostHog/posthog-flutter/pull/606)) stopped replay on opt-out and restarts it on opt-in; posthog-ios ([#942](https://github.com/PostHog/posthog-ios/pull/942), then [#959](https://github.com/PostHog/posthog-ios/pull/959)) rotates the session in `optIn()` and restarts the replay the app wanted; and React Native ([posthog-js#5336](https://github.com/PostHog/posthog-js/pull/5336), then [posthog-js#5363](https://github.com/PostHog/posthog-js/pull/5363)) adopted the same rule.

The spec says only that "some SDKs stop or restart them when opt state changes". Both the iOS and the React Native PRs noted the gap explicitly while making the change. Without a requirement, a new SDK or a port can keep recording into the opted-out session after consent, drop a replay the app wanted, or silently undo an app's `stopSessionRecording()` call.

## What Changes

- Require a client SDK that stops replay on opt-out to start a **new session** before replay restarts on opt-in, so no post-consent frame is attributed to the session that was active while the user was opted out.
- Require the SDK to decide at opt-out from whether the app **wanted** replay — enabled in config or started with `startSessionRecording()`, and not stopped since — rather than from whether it was recording. Replay held off at opt-out by sampling, a linked flag or an event trigger restarts in the new session, where those gates are evaluated again.
- Require replay the app stopped before opting out to stay stopped, `startSessionRecording()` and `stopSessionRecording()` calls made **while opted out** not to change the decision, and `reset()` to clear it back to the default so an app that launches opted out still gets replay on its first opt-in.
- Record in the narrative that the SDKs still differ on whether opt-in rotates the session when a linked flag or unloaded remote config keeps replay from starting, and leave that case unspecified.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `opt-in`: specify session rotation and the replay restart decision on opt-in.

## Impact

The requirements describe what posthog-ios, posthog-android, posthog-flutter and posthog-react-native already ship. Browser `opt_in_capturing` has its own consent semantics and is not covered here, and posthog-flutter on web leaves replay to posthog-js. The remaining rotation difference is deliberately left out rather than decided by this change.
