## 1. Spec delta

- [x] 1.1 Add the **A missing flag reports no value** requirement to `feature-flag-called-tracker`
- [x] 1.2 Give it two scenarios: the missing flag, and the empty-variant contrast case
- [x] 1.3 Leave `acceptance/` and `compliance/` unchanged

## 2. Validation

- [x] 2.1 Sync the delta into `specs/feature-flag-called-tracker/spec.md` and archive the change
- [x] 2.2 `openspec validate --specs --strict --no-interactive` with `@fission-ai/openspec@1.4.1`, the version CI pins: 69 passed, 0 failed

## 3. Provenance

| Normative sentence | Implementation |
|---|---|
| A missing flag's `$feature_flag_response` is absent or `null` | posthog-js `packages/browser-common/src/feature-flags.ts:1461`; posthog-node `packages/node/src/client.ts:1861-1864`; posthog-ios `PostHog/PostHogSDK.swift:2724` with the null drop from [posthog-ios#1047](https://github.com/PostHog/posthog-ios/pull/1047); posthog-flutter `posthog_flutter/lib/src/core/posthog_core.dart:828`; posthog-python `posthog/client.py:4574` |
| It is never the empty string | [posthog-android#951](https://github.com/PostHog/posthog-android/pull/951), merged 2026-11-09 as `693e2d2664912c9d3dad5e8f753ae6c9bfb9893c`; test `assertMissingFlagReportsNoValue` in `PostHogFeatureFlagsTest` |
| `false` is tolerated | harness cases `flag_snapshot_exposure_missing_*`; `is-feature-enabled`, "Allowed variation for the no-default call" |
| An empty variant key still renders as `""` | [sdk-specs#193](https://github.com/PostHog/sdk-specs/pull/193) and the 4.0/6.0 reads it describes |

`PostHogStateless.captureFeatureFlagCalledEvent` on Android (and `posthog-server` through it) still
uses `value ?: ""`; [#951](https://github.com/PostHog/posthog-android/pull/951) deliberately left it
alone. That path does not yet satisfy the requirement.
