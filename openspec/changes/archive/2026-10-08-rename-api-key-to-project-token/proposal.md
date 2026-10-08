## Why

Five SDKs have renamed the project credential configuration option from `apiKey` to `projectToken`: posthog-ios ([#573](https://github.com/PostHog/posthog-ios/pull/573)), posthog-flutter ([#374](https://github.com/PostHog/posthog-flutter/pull/374)), posthog-dotnet ([#183](https://github.com/PostHog/posthog-dotnet/pull/183)), posthog-kmp ([#91](https://github.com/PostHog/posthog-kmp/pull/91)), and posthog-android ([#835](https://github.com/PostHog/posthog-android/pull/835)). The `setup` spec never names the option at all — it says only "project API key/token" — so the contract does not record which name is canonical, that the old name survives as a deprecated alias, or that the rename stops at the public config surface.

## What Changes

- Add a requirement naming `projectToken` the canonical configuration option for the project credential, in each platform's casing.
- Require every SDK that still names the option `apiKey` — including those not yet renamed — to add `projectToken` and keep the old name as a deprecated alias that resolves to the same value, so the rename ships in a minor release. The alias may be dropped only in a later major version.
- Accept a compile-time deprecation as the deprecation signal; a runtime warning is optional. Android, KMP, and Flutter's Dart getter shipped compile-time deprecation only.
- State that the rename does not touch wire fields (`api_key`, `token`), stored queue or preference paths, or positional first-argument constructors.
- Note in the narrative that React Native's `PostHogProvider` `apiKey` prop and Unity's `ApiKey` have not adopted the name, and which SDKs trim the configured value.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `setup`: name the canonical project-credential configuration option and its deprecated alias.

## Impact

React Native and Unity still name the option `apiKey`/`ApiKey`; [posthog-js #5221](https://github.com/PostHog/posthog-js/pull/5221) deliberately kept the React Native name and changed only the documentation and the missing-token error message. This change makes both non-conforming until they add `projectToken` with a deprecated `apiKey` alias, which they can do in a minor release. That work happens in those repos and is not a prerequisite for this spec change. Every renamed SDK shipped the alias, so no existing caller breaks.
