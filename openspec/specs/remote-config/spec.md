# Remote Config Specification

## Purpose

`remote-config` is the internal component that fetches and caches project-level configuration from PostHog that is **not just event data**, such as:

- whether feature flags exist and should be preloaded
- session replay configuration
- surveys configuration
- error tracking configuration
- capture-performance/network-timing configuration
- related auxiliary settings returned alongside flags/config responses

It is the bridge between remote project settings and local SDK behavior.

## Applicability

`client` — the audited implementations are client-side remote-config managers that fetch project configuration and apply it locally.

## Public signature(s)

No single public API.

Typical internal operations look like:

```ts
reloadRemoteConfig(callback?): void | Promise<RemoteConfig | undefined>
getRemoteConfig(): RemoteConfig | undefined
processRemoteConfig(response): void
clear(): void
```

In js-core-based SDKs, remote config is partially intertwined with feature-flag loading because the flags response can also carry config fields.

## Behavior

1. **Fetch project config from a dedicated config endpoint.** The remote-config manager calls a config/asset endpoint rather than the normal event-ingestion endpoint.
2. **Cache the fetched config locally.** Successful responses are persisted so the SDK can rehydrate settings on startup before fresh network fetches complete.
3. **Apply config to local SDK features.** Depending on the response, the manager updates internal state for:
   - session replay
   - surveys
   - error tracking
   - capture performance / network timing
   - feature-flag bootstrapping decisions
4. **Optionally trigger feature-flag loading.** If the remote config says feature flags exist and preloading is enabled, the manager kicks off or coordinates a flags load using the current identity/group context.
5. **Notify dependents after config changes.** Integrations and listeners are informed when remote config has been loaded/applied so they can enable/disable behavior.
6. **Allow wrapper SDKs to configure and observe an underlying remote-config manager without owning the fetch path.** Flutter forwards remote-config-relevant setup options like `preloadFeatureFlags`, `sendFeatureFlagEvents`, `sessionReplay`, `sessionReplayConfig`, `surveys`, and `errorTrackingConfig` to the native SDKs, and exposes `onFeatureFlags` as its main callback surface rather than a first-class remote-config API.
7. **Prefer cached values when needed.** On startup, the manager may preload cached remote config into memory so dependent integrations can make early decisions before the network returns.
8. **Avoid duplicate in-flight loads.** Concurrent remote-config fetches are typically deduplicated or ignored while one is already in progress.
9. **Clear config on reset or teardown when user-scoped data must be invalidated.** Cached remote-config-derived state may be removed as part of reset/clear flows.

## State & lifecycle

### State read

- current distinct id / anonymous id / groups when remote config decides whether to load flags next
- cached remote config from persistent storage
- cached feature flags when processing config that depends on current flag values (for example replay gating)
- local SDK feature toggles that are combined with remote config

### State written

- cached remote config payload
- derived caches for surveys/session replay/error tracking/capture performance
- in-memory "loading" flags
- callbacks/listener notifications

### Lifecycle behavior

- Remote config is often preloaded during SDK startup.
- Cached values may be applied before the first network fetch completes.
- Fresh network responses replace cached config and may immediately enable/disable integrations.
- Reset/clear flows remove remote-config-derived caches to avoid stale behavior after identity changes.
- Wrapper SDKs may treat remote config as part of setup rather than as an explicit user-facing subsystem. Flutter configures remote-config-relevant options up front and then reacts to underlying feature-flag/config updates through native notifications or browser callbacks.

## Error handling

- Remote-config fetch failures are logged and treated as recoverable.
- If cached config exists, the SDK may continue operating from that stale value.
- Malformed response fields are ignored or cleared feature-by-feature rather than crashing the SDK.
- Duplicate concurrent reload requests are commonly ignored instead of queued with full callback fanout, depending on implementation.

## Concurrency & ordering guarantees

- Remote-config state is guarded by locks, serialized dispatch queues/executors, or promise deduplication.
- Only one remote-config fetch should be in flight per instance in normal operation.
- Dependent callbacks are invoked after config has been persisted/applied for that cycle.
- If a flags load is triggered from remote config, integrations should treat the combined cycle as eventually consistent: config may apply first, with flags arriving immediately after.

## Interactions

- **feature-flag-cache / reload-feature-flags** — remote config may trigger flag loading and may also reuse fields carried on the flags response.
- **session replay** — replay enablement, sample rate, endpoint, and plugin behavior may be driven by remote config.
- **surveys** — surveys are fetched/cleared from remote config payloads in native SDKs.
- **error tracking / capture performance** — remote config gates whether those subsystems should run.
- **wrapper setup surfaces** — Flutter maps Dart config fields onto the native/browser SDKs' remote-config-relevant options and observes resulting updates through `onFeatureFlags` / native notifications.
- **persistent-storage** — caches remote config and derived config slices across restarts.
- **reset** — clears remote-config-derived user-scoped caches in audited client SDKs.

## Requirements

### Requirement: Canonical remote-config behavior

The SDK SHALL implement the canonical `remote-config` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Remote config fetch applies feature settings
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the mock server will return remote config:
  | setting                 | value |
  | session_replay_enabled  | true  |
  | surveys_enabled         | true  |
  | feature_flags_available | true  |
- **WHEN** remote config is reloaded
- **THEN** cached remote config should include setting "session_replay_enabled" with value "true"
- **AND** remote config listeners should be notified

#### Scenario: Remote config can trigger feature flag loading
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the mock server will return remote config:
  | setting                 | value |
  | feature_flags_available | true  |
- **WHEN** remote config is reloaded
- **AND** pending SDK tasks are run
- **THEN** a feature flag request should be sent

#### Scenario: Remote config failure falls back to cached config
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached remote config includes setting "session_replay_enabled" with value "true"
- **AND** the mock server will fail the next remote config request with status 503
- **WHEN** remote config is reloaded
- **THEN** cached remote config should still include setting "session_replay_enabled" with value "true"
- **AND** the call should not throw
