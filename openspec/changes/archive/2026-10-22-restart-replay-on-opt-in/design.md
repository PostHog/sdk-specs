## Context

`optOut()` in the mobile SDKs no longer just drops events: it uninstalls the integrations, which stops session replay. That makes `optIn()` a replay **start** path, and a start path needs two decisions the spec never made — which session the restarted recording belongs to, and whether to restart at all.

## Goals

- Record the session-rotation rule, so consent is a clean boundary in the replay data.
- Record that consent does not override an app's explicit `stopSessionRecording()`.
- Leave the one case where the SDKs genuinely still differ unspecified rather than picking a winner without a product decision.

## Decisions

**Opt-in rotates the session before replay restarts.** posthog-android#242 asked for this directly ("when opting-in a new session should be created"), and posthog-android#839 and posthog-ios#942 both implement it by rotating the session first so the first frame lands in the new session. Rotating afterwards would attribute some post-consent frames to the opted-out session.

**The wrapper owns the rotation where it owns the session id.** Under React Native the native `startSession()` is already a no-op because the wrapper owns the session id, and posthog-js#5336 rotates in the wrapper instead. The requirement names the outcome — a new session id — not the layer that produces it.

**An explicit stop survives opt-out.** iOS remembers `replayIntegration?.isActive()` at opt-out and stops the recording that install just started when the flag is false; Android remembers whether the app "wanted" replay, which `stopSessionReplay()` clears. Both agree on the converged case: the app called stop, so opt-in must not silently restart.

**Calls made while opted out do not count.** Android ignores `startSessionReplay()`/`stopSessionReplay()` while opted out; on iOS the integration is uninstalled, so there is nothing to stop. React Native changed to match, which the posthog-js changeset calls out as a behavior change from 4.81.3. The decision is taken at opt-out.

**`reset()` clears the remembered decision.** iOS resets its flag to the default in `reset()`, and React Native treats `reset()` after `optOut()` as an opt-in. Otherwise an app that launched opted out would never get replay.

## Open questions

When replay is enabled but **not recording** at opt-out because sampling, a linked flag, an event trigger, or unloaded remote config held it off, iOS and React Native leave it stopped on opt-in (they remember "was recording"), while Android restarts it in a new session and lets the normal gates decide (it remembers "was wanted"). A replay held off this way can still start later through a flags reload on both. This change does not pick a winner; it needs a product decision and a separate spec change.
