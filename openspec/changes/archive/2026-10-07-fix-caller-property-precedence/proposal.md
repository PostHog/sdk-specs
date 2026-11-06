## Why

The capture spec contradicts itself and the register spec on which value wins when the caller passes a key the SDK also sets. Capture's Behavior step 4 lists the merge order as "caller-supplied properties, then SDK environment, then super/registered properties, … (later values win)", so registered properties and SDK context would override the caller. Register's step 6 says the opposite: "the per-event value wins".

The client SDKs don't agree either:

| SDK | Caller vs `register()` | Caller vs SDK context (`$lib`, `$app_version`, `$screen_width`, …) | Caller vs `$is_identified` / `$process_person_profile` |
|---|---|---|---|
| posthog-js (browser) | caller wins | caller wins | SDK wins |
| posthog-android | caller wins | caller wins | SDK wins |
| posthog-react-native, posthog-js-lite (`@posthog/core` `PostHogCore`) | caller wins | SDK wins | SDK wins |
| posthog-ios 3.x | SDK wins | SDK wins | SDK wins |
| posthog-flutter | follows the native SDK (web: posthog-js) | | |

A caller who passes a property on an event means it for that event. posthog-js and posthog-android already let it win, so they're the canonical behavior.

## What Changes

- Capture's Behavior step 4 states the client precedence from lowest to highest: registered properties, then SDK context and feature flag properties, then the caller's properties. `$is_identified` and `$process_person_profile` are set after the caller's properties, so a caller can't override them.
- A new capture requirement, **Caller-supplied event properties take precedence**, with client scenarios for an SDK context key and for the person-processing keys.
- Register's **Canonical register behavior** requirement gains a scenario: a per-event property overrides a registered property with the same key.
- Some SDK-owned per-event keys may still be set after the caller's properties: the replay debug properties (`$recording_status`, `$sdk_debug_*`), and on posthog-js and `@posthog/core` the current `$session_id`. The spec lists these as allowed variation rather than forcing one answer, since iOS and Android let a non-empty caller `$session_id` win.
- Server SDKs are unchanged. Most stamp `$lib`, `$lib_version` and SDK-level default/super properties (python `super_properties`, go `DefaultEventProperties`, dotnet `SuperProperties`, elixir `global_properties`) over the caller's properties. Step 4 now describes the server order separately instead of implying one list fits both.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `capture`: new **Caller-supplied event properties take precedence** requirement; Behavior step 4.
- `register`: **Canonical register behavior** requirement gains a scenario.

## Impact

- **posthog-ios**: breaking; ships in 4.0 (`chore/v4-remove-deprecated`).
- **posthog-react-native**, **posthog-js-lite** (via `@posthog/core` `PostHogCore`): SDK context no longer overrides caller properties. Stateless/server clients built on `PostHogCoreStateless` (posthog-node) are unchanged.
- **posthog-js (browser)**, **posthog-android**: already conform.
- **posthog-flutter**: no change; follows the native SDK on iOS and Android, and posthog-js on web.
- **Server SDKs**: no change.
- **Acceptance adapters**: the new scenarios reuse existing steps (`registered properties are:`, `capture is called with event … and properties:`, `the SDK is initialized with token … and person profiles mode …`, `the enqueued event properties should include:`).
