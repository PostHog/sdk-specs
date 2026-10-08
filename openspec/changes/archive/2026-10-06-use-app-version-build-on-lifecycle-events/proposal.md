## Why

Lifecycle events send the current app version twice. Every event already carries `$app_version`
and `$app_build` from the SDK's common context properties, and `Application Installed`,
`Application Updated` and `Application Opened` add the same values again as un-prefixed `version`
and `build`.

The posthog-ios 4.0 plan (PostHog/posthog-ios#557) lists "Remove fields eg `properties.build` in
favor of only `properties.$app_build`" as one of the major-version cleanups. React Native has
already removed the un-prefixed pair. In its 4.0 major, posthog-react-native
removed `version` and `build` from lifecycle events "in favor of `$app_version` and `$app_build`",
and kept `previous_version` and `previous_build`. posthog-ios is doing the same in 4.0
(PostHog/posthog-ios#905). Both now fail the **Version change captures an update event** scenario,
which still asserts `version: 1.1.0` and `build: 110`.

| SDK | `version` / `build` on lifecycle events | `$app_version` / `$app_build` on every event |
|---|---|---|
| posthog-react-native (4.0+) | no | yes |
| posthog-ios (4.0, #905) | no | yes |
| posthog-android | yes (Installed, Updated, cold-start Opened) | yes |
| posthog-unity | yes (also on Backgrounded; `build` is `Application.buildGUID`) | yes |
| posthog-flutter, posthog-kmp | follow the native SDK | follow the native SDK |

## What Changes

- The current app version and build on lifecycle events come from the common `$app_version` and
  `$app_build` properties. Lifecycle events SHOULD NOT also send un-prefixed `version` and `build`.
- `previous_version` and `previous_build` on `Application Updated` are unchanged. They have no `$`
  equivalent.
- SDKs that send `version` and `build` today MAY keep sending them until their next major version,
  so the change doesn't break existing event shapes in a minor release.
- The **Version change captures an update event** scenario asserts `$app_version` and `$app_build`
  instead of `version` and `build`.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `application-lifecycle`: the **Canonical application-lifecycle behavior** requirement, and the
  install/update and open steps in the Behavior section.

## Impact

Breaking for event consumers once an SDK drops the un-prefixed pair: insights, cohorts and filters
that use `version` or `build` on lifecycle events need to switch to `$app_version` / `$app_build`.
SDKs ship that change in a major version. No API or service change.

- **posthog-react-native**: already conforms.
- **posthog-ios**: conforms with #905 (4.0).
- **posthog-android**, **posthog-unity**: still pass the updated scenario, since they send
  `$app_version` / `$app_build` on every event. Drop `version` / `build` in the next major.
- **posthog-flutter**, **posthog-kmp**: no change; until Android drops the pair, an app built with
  them sends `version` / `build` from Android but not from iOS.
- **posthog** (`posthog/taxonomy/taxonomy.py`): the `version` and `build` descriptions say mobile
  SDKs send them on lifecycle events. Reword them as legacy.
- **Acceptance adapters**: the `the platform app version is "…" and build is "…"` step has to set
  the metadata the SDK reads `$app_version` / `$app_build` from, not only the value the lifecycle
  integration reads.
