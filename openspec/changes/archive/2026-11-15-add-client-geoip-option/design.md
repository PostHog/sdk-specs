## Context

Each SDK was read at `origin/main` on 2026-11-15 (posthog-ios and posthog-android cloned at depth 1,
posthog-js sparse). "Code reading" means no SDK was run end to end here; the behavior claims come
from the source plus the merged PRs' own test descriptions.

| SDK | Option | Default | Where the marker is stamped | Flags request | Notes |
|---|---|---|---|---|---|
| posthog-ios | `PostHogConfig.disableGeoIp` | `false` | `PostHogSDK.swift:808`, after the caller-property merge, inside the shared-props branch | `PostHogApi.swift:360` sends `geoip_disable` for both values | Comment at `:800` states the ordering is deliberate so the opt-out can't be overridden per event, "matching posthog-js and posthog-android". `$snapshot` has no shared props, so it is not marked. |
| posthog-android | `PostHogConfig.disableGeoIp` | `false` (`PostHogConfig.kt:378`) | `PostHog.kt:840` and `PostHogStateless.kt:214`, after caller properties | `PostHogApi.kt:259` → `PostHogFlagsRequest.kt:41` | `$geoip_disable` is in the minimized `$feature_flag_called` allowlist (`PostHogStateless.kt:800`). PR #971 states `beforeSend` can still change the marker and replay snapshots are not marked. |
| posthog-flutter | `disableGeoIp` | `false` | Native config on iOS/Android; Dart core on Windows/Linux. Added **after** the Flutter `beforeSend` | Yes, on iOS, Android and desktop | PR #720 records both divergences: the post-`beforeSend` stamp (native SDKs and the desktop core add SDK properties after Dart callbacks) and web, where the option does nothing and a debug warning points at posthog-js `before_send`. |
| posthog-js core (node, react-native) | `disableGeoip` | `false` in stateful mode (`packages/core/src/posthog-core.ts:83`) | `posthog-core-stateless.ts:1425` | `posthog-core-stateless.ts:1117` | Stateless/server mode keeps the server default. `$geoip_disable` is in the minimal flag-event allowlist (`featureFlagUtils.ts:237`). |
| posthog-js browser | none | — | — | — | Callers use `before_send`. |

## Goals / Non-Goals

**Goals:** Record what a client SDK's GeoIP opt-out means, so the next client SDK to add one matches
the three that have it, and so the Flutter divergences are visible rather than folded in silently.

**Non-Goals:**

- Requiring the option. A client SDK runs in the end user's network context, so enrichment is the
  intended default and an SDK without the option conforms.
- Requiring a per-call override on client SDKs. None has one, and the client APIs mostly do not take
  an options bag on every event-producing call.
- Changing the server requirement's substance, including the posthog-php and posthog-rs default
  carve-out.

## Decisions

**Marker precedence over caller properties.** The server requirement protects a caller-supplied
`$geoip_disable`. On iOS and Android the SDK stamp deliberately wins over caller properties when the
option is on, so an app screen cannot silently re-enable enrichment. The new requirement states that
asymmetry explicitly rather than leaving the two readings in tension: the SDK stamp wins when the
option disables enrichment, and a caller-supplied marker survives when it does not.

**`beforeSend` ordering is SHOULD-strength for the stamp, with Flutter named.** iOS, Android and
posthog-js core stamp before the hook; Flutter cannot without reordering how native SDKs and the
desktop core add SDK properties. Naming Flutter keeps the requirement honest without declaring the
shipped behavior non-conformant on a point nobody has asked to change.
