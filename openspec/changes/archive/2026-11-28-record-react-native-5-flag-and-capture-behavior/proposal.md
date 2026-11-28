## Why

posthog-react-native 5.0 aligns its feature flag API and event building with posthog-ios 4.0,
posthog-android 4.0 and posthog_flutter 6.0, and adds `captureAi()`. Several specs still describe
React Native 4.x: they group it with posthog-js core in surface rows and known gaps it no longer
has, and `is-feature-enabled` names it as an SDK that must keep returning `undefined` with no
default.

Source: PostHog/posthog-js branch `chore/rn-v5` (the 5.0 changeset `.changeset/rn-v5.md`,
`packages/react-native/MIGRATION.md`, `PostHog` in `packages/react-native/src/posthog-rn.ts`, and
`PostHogCoreBase` in `packages/core/src/posthog-core.ts`), including
[posthog-js#5922](https://github.com/PostHog/posthog-js/pull/5922).

## What Changes

- `on-feature-flags`: React Native 5.0 callbacks receive `{ flags, variants, errorsLoading }`, are
  error-aware, are called once with current values when registered after flags loaded, and leave
  `""` flags out. The known gap stays for posthog-js core.
- `reload-feature-flags`: `reloadFeatureFlagsAsync()` resolves with `{ flags, variants, errorsLoading }`.
- `is-feature-enabled`: React Native 5.0 returns `false` with no default, so it moves from the
  three-state group to the `false`-by-construction group.
- `get-feature-flag`: React Native 5.0 returns `undefined` for a key missing from the loaded flags.
- `get-feature-flag-payload`, `get-feature-flags`, `get-feature-flags-and-payloads`: React Native
  5.0 removes `getFeatureFlagPayload()`, `getFeatureFlags()` and `getFeatureFlagsAndPayloads()` and
  joins the `getAllFeatureFlags()` result-list SDKs.
- `get-feature-flag-result`: React Native 5.0 renames the per-call option to `sendFeatureFlagEvent`
  and reads `""` as disabled; the known gap stays for posthog-js core.
- `capture`: React Native 5.0 leaves a registered `$process_person_profile` off identity events and
  `""` flags out of `$active_feature_flags`.
- `flush`: React Native 5.0 `flush()` resolves when a send fails.
- `setup`: React Native 5.0 removes the `PostHogProvider` `apiKey` alias.
- `capture-ai`: allowed variation for a client SDK whose storage backends can't hold large events;
  React Native 5.0 keeps the AI queue on disk only with Expo's file system.

4.x behavior stays recorded next to each 5.0 row.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `on-feature-flags`: **Empty variant is left out of the flags a listener receives**
- `is-feature-enabled`: **Canonical is-feature-enabled behavior**
- `get-feature-flags`: **Flag result list reads an empty variant as disabled**
- `get-feature-flag-result`: **Per-call feature flag event option name**, **Empty variant reads as disabled**
- `capture`: **Caller-supplied event properties take precedence**, **Empty variant is not an active feature flag**
- `capture-ai`: **AI events travel on their own lane to the capture v1 AI endpoint**

Surface rows and non-requirement prose in `reload-feature-flags`, `get-feature-flag`,
`get-feature-flag-payload`, `get-feature-flags-and-payloads`, `flush` and `setup` are updated too.

## Impact

- **posthog-react-native 5.0**: matches. This should merge when 5.0 is released.
- Other SDKs: unaffected. No scenario changes.
