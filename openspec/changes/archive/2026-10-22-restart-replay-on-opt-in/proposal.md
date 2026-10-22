## Why

Four client SDKs now agree on what `optIn()` does to session replay, and the `opt-in` spec does not record any of it. posthog-android ([#839](https://github.com/PostHog/posthog-android/pull/839)) made opt-out uninstall integrations and opt-in restart replay in a new session; posthog-flutter ([#606](https://github.com/PostHog/posthog-flutter/pull/606)) stopped replay on opt-out; posthog-ios ([#942](https://github.com/PostHog/posthog-ios/pull/942)) matched Android by rotating the session in `optIn()` and keeping a stopped recording stopped; and React Native ([posthog-js#5336](https://github.com/PostHog/posthog-js/pull/5336)) replaced its own rule with the native one.

The spec says only that "some SDKs stop or restart them when opt state changes". Both the iOS and the React Native PR noted the gap explicitly while making the change. Without a requirement, a new SDK or a port can keep recording into the opted-out session after consent, or silently undo an app's `stopSessionRecording()` call.

## What Changes

- Require a client SDK that stops replay on opt-out to start a **new session** before replay restarts on opt-in, so no post-consent frame is attributed to the session that was active while the user was opted out.
- Require the SDK to remember, at opt-out, whether the app wanted replay, and to leave replay stopped on opt-in when the app had called `stopSessionRecording()` first.
- Require `startSessionRecording()` and `stopSessionRecording()` calls made **while opted out** not to change that remembered decision, and require `reset()` to clear it back to the default so an app that launches opted out still gets replay on its first opt-in.
- Record in the narrative that the SDKs still diverge when replay is enabled but held off at opt-out by sampling, a linked flag, an event trigger, or unloaded remote config, and leave that case unspecified.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `opt-in`: specify session rotation and the replay restart decision on opt-in.

## Impact

The requirements describe what posthog-ios, posthog-android and posthog-react-native already ship. posthog-flutter stops replay on opt-out but its opt-in restart path has not been audited against these scenarios, so it may need a follow-up in that repository; that work is not a prerequisite for this spec change. Browser `opt_in_capturing` has its own consent semantics and is not covered here. The still-divergent gate-pending case is deliberately left out rather than decided by this change.
