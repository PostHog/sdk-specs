## Why

The canonical eligible-autocapture scenario requires `$event_type: click` for every UI interaction, incorrectly rejecting the mobile `touch` convention. [Android PR #798 review feedback](https://github.com/PostHog/posthog-android/pull/798#discussion_r4050722202) identifies this as a spec correction, not a request to change the Android payload.

## What Changes

- Explicitly distinguish browser click interactions (`click`) from mobile tap/touch interactions (`touch`) while retaining the `$autocapture` event name.
- Replace the ambiguous eligible-interaction scenario with explicit browser-click and mobile-touch scenarios.
- Plan matching acceptance feature coverage without broadening privacy, hierarchy, or screen metadata requirements.
- Preserve other platform-specific interaction types; do not normalize every mobile interaction to `touch` or React Native Web clicks to `touch`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `autocapture`: Specify interaction-dependent `$event_type` values and separate browser-click and mobile-touch outcomes.

## Impact

Affects `openspec/specs/autocapture/spec.md` through the delta/archive workflow and `acceptance/private/autocapture.feature` during apply. No SDK implementation, public API, dependency, or Android payload changes are needed.
