## Why

Five SDKs have renamed the project credential configuration option from `apiKey` to `projectToken`: posthog-ios ([#573](https://github.com/PostHog/posthog-ios/pull/573)), posthog-flutter ([#374](https://github.com/PostHog/posthog-flutter/pull/374)), posthog-dotnet ([#183](https://github.com/PostHog/posthog-dotnet/pull/183)), posthog-kmp ([#91](https://github.com/PostHog/posthog-kmp/pull/91)), and posthog-android ([#835](https://github.com/PostHog/posthog-android/pull/835)). The `setup` spec never names the option at all — it says only "project API key/token" — so the contract does not record which name is canonical, that the old name survives as a deprecated alias, or that the rename stops at the public config surface.

## What Changes

- Add a requirement naming `projectToken` the canonical configuration option for the project credential, in each platform's casing.
- Require the previous name to keep working as a deprecated alias that resolves to the same value and logs a warning, until the SDK's next major version.
- State that the rename does not touch wire fields (`api_key`, `token`), stored queue or preference paths, or positional first-argument constructors.
- Note in the narrative that posthog-js (browser, React Native, Node) has not adopted the name, and that the renamed SDKs trim the configured value.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `setup`: name the canonical project-credential configuration option and its deprecated alias.

## Impact

posthog-js is the only audited SDK that still names the option `apiKey`; [posthog-js #5221](https://github.com/PostHog/posthog-js/pull/5221) deliberately kept the name and changed only the documentation and the missing-token error message. Adopting `projectToken` there is a follow-up in that repo, not a prerequisite for this spec change. Every renamed SDK shipped the alias, so no existing caller breaks.
