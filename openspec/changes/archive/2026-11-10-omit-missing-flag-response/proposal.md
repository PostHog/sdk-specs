## Why

`feature-flag-called-tracker` says what `$feature_flag_response` holds for a flag that has a
value, including the legacy rendering of a config version 2 record, but it says nothing about a
flag the SDK has no record of. Every SDK had to pick its own encoding, and posthog-android picked
the one that is now ambiguous: `value ?: ""` in `PostHog.sendFeatureFlagCalled` reported a missing
flag as the empty string.

The empty string stopped being free in the 4.0/6.0 majors. An empty variant key reads as disabled
([sdk-specs#193](https://github.com/PostHog/sdk-specs/pull/193), implemented in
[posthog-ios#1037](https://github.com/PostHog/posthog-ios/pull/1037),
[posthog-android#949](https://github.com/PostHog/posthog-android/pull/949) and
[posthog-flutter#711](https://github.com/PostHog/posthog-flutter/pull/711)), and `""` is the legacy
rendering of that value on `$feature_flag_called`. So "flag with an empty variant" and "no such
flag" looked identical in flag analytics on Android.

[posthog-android#951](https://github.com/PostHog/posthog-android/pull/951) (`fix!`, merged
2026-11-09 as `693e2d2`) makes Android omit the property instead, which is where the other SDKs
already were:

| SDK | `$feature_flag_response` for a missing flag |
|---|---|
| posthog-js browser | omitted — `$feature_flag_response: flagValue` with `flagValue` `undefined` (`packages/browser-common/src/feature-flags.ts:1461`) |
| posthog-node | omitted — `response` is `undefined` when there is no record (`packages/node/src/client.ts:1861-1864`) |
| posthog-ios 4.0 | `NSNull()` (`PostHog/PostHogSDK.swift:2724`), dropped on the wire by [#1047](https://github.com/PostHog/posthog-ios/pull/1047) |
| posthog-android 4.0 | omitted (this change) |
| posthog-flutter desktop | `null` (`posthog_flutter/lib/src/core/posthog_core.dart:828`) |
| posthog-python | `None` (`posthog/client.py:4574`) |

Recording the rule keeps the next SDK from reinventing `""`, and gives the empty string a single
meaning on this event.

## What Changes

- Add a `feature-flag-called-tracker` requirement, **A missing flag reports no value**: when a read
  emits `$feature_flag_called` for a flag the SDK has no record of, `$feature_flag_response` is
  absent from the event properties or is JSON `null`, and it is never the empty string.
- Record the existing variation the shared harness already accepts: an SDK whose boolean read
  resolves a missing flag to `false` by construction MAY report `false` from that read path.
  `absent`, `null` and `false` are what the harness accepts for a missing-flag exposure; `""` is
  not.
- Two scenarios: a missing flag reports no value, and the contrast case — a flag whose value is the
  empty variant key still reports `""`, which is why the two cases have to be distinguishable.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `feature-flag-called-tracker`: one new requirement with two scenarios. No existing requirement or
  scenario changes.

## Impact

- **posthog-android**: [#951](https://github.com/PostHog/posthog-android/pull/951) brings the client
  path into line. `PostHogStateless.captureFeatureFlagCalledEvent` keeps `value ?: ""` and is
  reached from `getFeatureFlagStateless` and `posthog-server`, so those paths still report `""` for
  a missing flag and have to change.
- **posthog-js, posthog-node, posthog-ios 4.0, posthog-flutter, posthog-python** already satisfy the
  requirement.
- `acceptance/` is untouched: the available step vocabulary asserts a property is absent or equals a
  value, and the requirement allows absent or `null`, so the scenarios stay in `spec.md`.
- `compliance/` is untouched — those rows come from the weekly audit.
