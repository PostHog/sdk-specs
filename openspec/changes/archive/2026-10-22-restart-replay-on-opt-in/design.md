## Context

`optOut()` in the mobile SDKs no longer just drops events: it uninstalls the integrations, which stops session replay. That makes `optIn()` a replay **start** path, and a start path needs two decisions the spec never made — which session the restarted recording belongs to, and whether to restart at all.

## Goals

- Record the session-rotation rule, so consent is a clean boundary in the replay data.
- Record that opt-in restores the replay the app wanted, and that consent does not override an app's explicit `stopSessionRecording()`.

## Decisions

**Opt-in rotates the session before replay restarts.** posthog-android#242 asked for this directly ("when opting-in a new session should be created"), and posthog-android#839 and posthog-ios#942 both implement it by rotating the session first so the first frame lands in the new session. Rotating afterwards would attribute some post-consent frames to the opted-out session.

**The wrapper owns the rotation where it owns the session id.** Under React Native the native `startSession()` is a no-op because the wrapper owns the session id, so posthog-js#5363 rotates in the wrapper instead. The requirement names the outcome — a new session id — not the layer that produces it.

**The restart follows what the app wanted, not what was recording.** posthog-ios#942 and posthog-js#5336 first restarted replay only if it was recording at opt-out. That dropped a recording the app started with replay off in config, and a start waiting for an event trigger. posthog-ios#959 and posthog-js#5363 replaced it with the rule posthog-android#839 and posthog-flutter already used: replay is wanted when it is enabled in config or the app called `startSessionRecording()`, and the app has not called `stopSessionRecording()` since. Sampling, linked flags and event triggers are evaluated again in the new session.

**An explicit stop survives opt-out.** All four SDKs clear "wanted" on `stopSessionRecording()`, so opt-in leaves a recording the app stopped stopped.

**Calls made while opted out do not count.** Android, iOS and React Native (since posthog-js#5363) ignore start and stop calls made while opted out when tracking what the app wants; Flutter's restart flag is set at opt-out. The decision is taken at opt-out.

**The decision starts from the configuration at launch.** iOS, Android and React Native seed it from the session replay option at setup, and Flutter's native layer does the same, so an app that launched opted out with replay enabled records on its first opt-in. No SDK's `reset()` changes it; React Native's `reset()` after `optOut()` restores replay as `optIn()` does, because it clears the opt-out.

**The new session starts even when a gate holds replay off.** If opt-in rotated only once the linked flag and remote config let replay start, a start after flags loaded later would resume the session that was active while the user was opted out.
