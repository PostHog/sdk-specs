## Context

Client SDKs that capture application lifecycle events emit `Application Installed`, `Application Updated`, and often the initial `Application Opened` synchronously inside `setup()` (or inside the async init chain before `ready()` resolves on React Native). Because `register(...)` either no-ops before `setup()` completes or runs after lifecycle capture, callers have no cross-SDK way to ensure app-level super properties (such as `environment`, `app`, or `locale`) are present on the first launch events.

Audit across all 21 official SDKs (2026-11-23):

| SDK | Category | Current init-time properties | Initial startup event timing |
|---|---|---|---|
| `posthog-ios` | client | None | `Application Installed` / `Updated` sync in `setup()` (`PostHogAppLifeCycleIntegration.install`) |
| `posthog-android` | client | None | `Application Installed` / `Updated` sync in `setup()`; `Application Opened` sync on main thread |
| `posthog-flutter` | client wrapper | None (native `PosthogFlutterPlugin.addBeforeSend` in `6.0.0+` only) | Delegates to native iOS/Android; desktop runs `DesktopAppLifecycle.start()` in setup |
| `posthog-kmp` | client wrapper | None | Delegates to native Android/iOS |
| `posthog-js` (browser / react) | client | None (`loaded` callback runs before `setTimeout(..., 1)` `$pageview`, after bootstrap `$identify`) | Bootstrap `$identify` sync in `_init()`; `$pageview` deferred via `setTimeout(..., 1)` |
| `posthog-js` (react-native) | client | None (`customAppProperties` is static `$app_*` metadata) | `captureAppLifecycleEvents()` runs in `initAfterStorage()` before `ready()` resolves |
| `posthog-unity` | client | None | `LifecycleHandler.Initialize()` captures synchronously in `Setup()` (currently before `LoadSuperProperties()`) |
| `posthog-godot` | client | None | `_capture_startup()` runs synchronously inside `setup()` |
| `posthog-unreal` | client | None (`FPostHogConfig::Context` is static context) | Initial `Application Opened` runs in `Tick()` before `OnSetupCompleted` |
| `posthog-roblox` | client | None | `Server Started` captured synchronously in `Init()` |
| `posthog-python` | server | `super_properties` (constructor & module attr) | No startup lifecycle events; 7.x overwrites per-event props, 8.0 reverses on capture v1 |
| `posthog-dotnet` | server | `PostHogOptions.SuperProperties` | No startup lifecycle events; currently overwrites per-event props |
| `posthog-go` | server | `Config.DefaultEventProperties` | No startup lifecycle events; 1.x overwrites per-event props, v2 reverses on capture v1 |
| `posthog-elixir` | server | `:global_properties` in config | No startup lifecycle events; currently overwrites per-event props |
| `posthog-node` | server | None (runtime `register()` + `withContext()`) | No startup lifecycle events |
| `posthog-ruby` / `rails`, `posthog-php`, `posthog-java`, `posthog-rs` | server | None | No startup lifecycle events |

## Goals / Non-Goals

**Goals:**
- Provide one canonical setup/init configuration option (`superProperties` / `super_properties` / `SuperProperties`) across client and server SDKs.
- Guarantee on client SDKs that configured super properties are present on every event emitted during `setup()` (including `Application Installed`, `Application Updated`, `Application Opened`, bootstrap `$identify`, initial `$pageview`, and Roblox `Server Started`) without requiring `beforeSend` shims.
- Unify precedence across client and server SDKs so per-event caller properties win.

**Non-Goals:**
- Introducing a browser-style `loaded(client)` callback across mobile/game/server SDKs.
- Changing runtime `register()` / `unregister()` / `reset()` method signatures or introducing a second client-side super-property layer.
- Forcing breaking renames or breaking precedence flips in minor releases of existing server SDKs (`posthog-dotnet`, `posthog-elixir`, `posthog-go` 1.x, `posthog-python` 7.x).

## Decisions

### 1. Declarative config map (`superProperties`) instead of a `loaded` callback
- **Decision:** Add an optional `superProperties` map on the SDK configuration object rather than standardizing a pre-lifecycle `loaded(client)` callback.
- **Rationale:** A plain key-value map serializes cleanly across wrapper/platform channels (Flutter MethodChannel, KMP bridges), works in declarative configs (Unity `PostHogSettings`, Godot `.tres`, Unreal `UPostHogSettings`, native auto-init manifests), avoids re-entrancy under native `setupLock`, and matches existing server precedent (`posthog-python`, `posthog-dotnet`).
- **Alternative rejected:** Pre-lifecycle `loaded` callback (browser precedent). Cannot run synchronously across Flutter's async MethodChannel during native `setup()`, cannot be expressed declaratively, and invites lock re-entrancy issues.

### 2. Seed into the client `register()` store (overwrite matching persisted keys on relaunch)
- **Decision:** On client SDKs, `setup()` restores persisted super properties first, then merges `config.superProperties` into the same `register()` store before `bootstrap` identity reconciliation and before lifecycle/autocapture integrations install. Matching keys in `config.superProperties` overwrite previously persisted values; other persisted keys are preserved. Later `register()`, `unregister()`, and `reset()` operate on the same store.
- **Rationale:**
  - Keeps one mental model and one storage layer on client SDKs.
  - Launch-varying tags such as `app_version`, `environment`, or `locale` update cleanly before `Application Updated` / `Application Opened` fire on a new build.
  - Because the properties enter the super-properties store rather than a `beforeSend` hook, persisted queued events and crash reports from an earlier launch keep the properties they were recorded with.
- **Alternatives rejected:**
  - *Separate non-persisted static config layer surviving `reset()`:* Introduces a second client super-properties layer that `unregister()` and `reset()` cannot clear, diverging from how client SDKs model super properties.
  - *`registerOnce`-style non-overwriting seed:* Would leave stale launch-1 values (e.g. old `locale` or `environment`) on `Application Updated` / `Application Opened` across launches.

### 3. Canonical caller-wins precedence across both client and server SDKs
- **Decision:** Per-event caller properties always win over configured super properties (client: `SDK-set properties < super properties < caller event properties`; server: `SDK-added defaults < configured super properties < ambient request context < caller event properties`), aligning with `capture`'s **Caller-supplied event properties take precedence** (client) and **Server SDKs build every event in one layer order** (capture v1 server). On capture v1, server SDKs adding `superProperties` also follow `capture`'s **Per-event options replace the legacy option properties** rule for global default options (`superOptions` / `super_options` / `SuperOptions`, with existing names such as Go's `DefaultEventOptions` allowed as deprecated aliases).
- **Rationale:** Reversing precedence between client and server SDKs is a recurring footgun. `posthog-python` 8.0 and `posthog-go` v2 already reverse legacy config-wins to caller-wins for capture v1; recording `.NET` and `Elixir` as legacy divergences gives every SDK one target contract.
- **Alternative rejected:** Permanently splitting precedence (caller-wins on client, config-wins on server). Preserves an accidental legacy divergence across the SDK family.

### 4. Option naming and legacy alias path
- **Decision:** Standardize on `superProperties` adapted to platform casing (`super_properties`, `SuperProperties`). SDKs already shipping an init-time property map under another name (`DefaultEventProperties` in Go, `global_properties` in Elixir) add the canonical name while keeping the existing name as a deprecated alias (when both are non-empty, canonical wins key by key; an absent/empty canonical map falls back to the alias), or rename in a major release.
- **Rationale:** Mirrors the `projectToken` / `apiKey` alias policy in `setup/spec.md`, enabling adoption without forcing breaking changes in minor versions.

## Risks / Trade-offs

- **Relaunch overwrite of mutated keys on client SDKs** → If a caller puts a key in `config.superProperties` and later mutates or unregisters it at runtime, the next `setup()` will re-apply the configured value. Mitigated by documenting clearly that `config.superProperties` is for launch-time properties supplied on each setup, while user-mutated persistent state belongs in runtime `register()`.
- **Unity load-order defect** → `posthog-unity` currently invokes `LifecycleHandler.Initialize()` before `LoadSuperProperties()`. Fixing that order is a prerequisite when implementing `SuperProperties` in Unity.
- **Legacy server SDK precedence flip** → Changing `.NET` and `Elixir` from config-wins to caller-wins is a breaking change and MUST wait for a major release (matching Python 8.0 and Go v2).
- **Flutter Web attachment** → Because Flutter Web attaches to an already-initialized `posthog-js` instance, `Posthog().setup(config)` can only register properties after `posthog.init(...)` ran; docs must note that web apps needing them on `posthog-js`'s initial `$pageview` should pass `super_properties` to `posthog.init(...)`.
