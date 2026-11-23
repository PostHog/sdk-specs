## Why

Client SDKs with application lifecycle hooks (`posthog-ios`, `posthog-android`, `posthog-flutter`, `posthog-react-native`, `posthog-kmp`, `posthog-unity`, `posthog-godot`, `posthog-unreal`, `posthog-roblox`) emit initial lifecycle events (`Application Installed`, `Application Updated`, `Application Opened`, or platform startup events) during `setup()` before callers can invoke `register(...)`. As reported in `PostHog/posthog-flutter#739`, dashboards filtering on app-level super properties (such as `environment`, `app`, or `locale`) silently drop installs and cold opens for new users.

Across our server SDKs, four (`posthog-python`, `posthog-dotnet`, `posthog-go`, `posthog-elixir`) already accept init-time event properties under different names (`super_properties`, `SuperProperties`, `DefaultEventProperties`, `global_properties`), while the remaining server SDKs (`posthog-node`, `posthog-ruby`, `posthog-php`, `posthog-java`, `posthog-rs`) and all 11 client SDKs have no setup-time super-properties option.

## What Changes

- **`setup`**: Add requirement **Super properties at setup** specifying an optional `superProperties` configuration map (adapted to platform casing: `super_properties`, `SuperProperties`) across both client and server SDKs.
  - On client SDKs, setup merges configured `superProperties` into the SDK's `register()` super-properties store **after** restoring persisted storage and **before** `bootstrap` identity reconciliation and lifecycle/autocapture integration installation, overwriting matching persisted keys on relaunch while preserving other persisted keys. Subsequent `register()`, `unregister()`, and `reset()` calls mutate the same store.
  - On server SDKs, configured super properties apply immediately from client initialization to every event on the shared capture path (and on capture v1 align with `capture`'s global default options rule).
  - Canonical precedence is **per-event properties win** (client: `SDK-set properties < super properties < caller event properties`; server: `SDK-added defaults < configured super properties < ambient request context < caller event properties`), matching `capture`'s **Caller-supplied event properties take precedence** and **Server SDKs build every event in one layer order**. Existing server SDKs that currently let init-time properties overwrite per-event properties (`posthog-python` 7.x, `posthog-go` 1.x, `posthog-dotnet`, `posthog-elixir`) are recorded as legacy divergences converging on caller-wins in their capture v1 / next major releases.
  - Record an explicit deprecated-alias rule for SDKs that already ship another name (`DefaultEventProperties`, `global_properties`).
- **`register`**: Add requirement **Setup-seeded super properties share the register store** specifying that setup-seeded super properties share the same store, validation/sanitization rules, runtime override (`register`), removal (`unregister`), and clearing (`reset`, where supported) semantics.
- **`application-lifecycle`**: Add requirement **Startup lifecycle events carry setup super properties** specifying that initial lifecycle events captured during setup (`Application Installed`, `Application Updated`, and initial `Application Opened`) carry setup-configured super properties.
- **Acceptance features**: Add declarative scenarios in `acceptance/public/setup.feature`, `acceptance/public/register.feature`, and `acceptance/private/application-lifecycle.feature`.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `setup`: add setup-time `superProperties` configuration option, lifecycle ordering, client store seeding, server init-time attachment, precedence, and legacy alias/divergence rules.
- `register`: specify how setup-seeded super properties share the `register` persistent store and lifecycle (`register`, `unregister`, `reset`).
- `application-lifecycle`: specify that startup lifecycle events emitted during setup carry setup-configured super properties.

## Impact

Specifications and acceptance scenarios only. Requires follow-up implementation across client SDKs (native `posthog-ios`, `posthog-android`, `posthog-js` browser/react-native, `posthog-unity`, `posthog-godot`, `posthog-unreal`, `posthog-roblox`, plus wrapper forwarding in `posthog-flutter` and `posthog-kmp`) and server SDKs lacking init-time super properties (`posthog-node`, `posthog-ruby`, `posthog-php`, `posthog-java`, `posthog-rs`), plus major-version precedence/name alignment in legacy server SDKs (`posthog-dotnet`, `posthog-elixir`; `posthog-python` 8.0 and `posthog-go` v2 already reverse precedence on capture v1).
