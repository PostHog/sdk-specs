## Why

A further re-audit of `posthog-js` `main` found the bootstrap flag serving requirement is missing that only *enabled* flags are served. `initialize()` (`posthog-featureflags.ts:318-337`) filters bootstrap flags through `!!bootstrapFlags[flag]`, so a `false`/disabled flag is dropped, and payloads are kept only for enabled flags. This is asserted by posthog-js's own tests (`posthog-core-also.test.ts:936-985`): `getFeatureFlag('disabled')` is `undefined`, `getFlagVariants()` excludes disabled/undefined keys, and `getFeatureFlagPayload('disabled')` is `undefined`. The spec implied all bootstrap values are served, so `posthog-ios` served `false` flags too.

## What Changes

- Tighten the "Bootstrapped feature flags are served before the first flags response" requirement: only enabled bootstrap flags (boolean `true` or a non-empty variant string) are served; a `false`/empty value is dropped, and payloads are kept only for served flags.
- Add a scenario covering a disabled bootstrap flag and its payload not being served.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `bootstrap`: the flag-serving requirement now specifies enabled-only serving, matching posthog-js.

## Impact

- `openspec/specs/bootstrap/spec.md` and `acceptance/public/bootstrap.feature` gain the enabled-only rule and scenario.
- `posthog-ios` PR #715 filters bootstrap flags to enabled values (and payloads to enabled keys) at `PostHogRemoteConfig.init`.
