## Why

`on-feature-flags` enumerates the public listener surface per SDK. posthog-ios is absent from that
list because it had no such API — only a payload-free `PostHogSDK.didReceiveFeatureFlags`
notification, which forced apps to re-read every flag.

posthog-ios [#897](https://github.com/PostHog/posthog-ios/pull/897) (merged 2026-10-03) adds
`onFeatureFlags`, explicitly built against this spec: it hands the callback the enabled flag keys,
their variants, and whether the latest load failed, and returns a subscription with `unsubscribe()`.
The spec's surface list is now out of date, and the `errorsLoading` field it names in the canonical
signature has no requirement behind it even though it is now the observable the second SDK ships.

## What Changes

- Record the iOS surface variant and its payload-carrying shape alongside the existing entries.
- Add one scenario to the canonical requirement: when a flag load fails, the listener is still
  invoked, `errorsLoading` reports the failure, and the payload carries the last known flags rather
  than an empty set.
- Note in the narrative that iOS, like browser, invokes a late-registered listener once with the
  current values, and delivers after the getters already return the new values.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `on-feature-flags`: the **Canonical on-feature-flags behavior** requirement, plus the surface and
  behavior narrative.

## Impact

Not a breaking change. No signature in the spec changes; the delta records a surface that now exists
and pins an observable the canonical signature already names.

- **posthog-ios** conforms as of #897: payload on the main thread after getters update, one delivery
  for a late registration, `errorsLoading: true` with the cached flags on a failed load.
- **posthog-js** (browser) carries `errorsLoading` but reached consumers as `undefined` on six call
  paths; [posthog-js #5045](https://github.com/PostHog/posthog-js/pull/5045) makes it an explicit
  boolean. That PR is still open, so browser conforms only once it lands.
- SDKs whose listener is a payload-free readiness signal (Android, Flutter, Unity) are unaffected:
  the scenario is about invoking the listener on a failed load, not about carrying a payload.
