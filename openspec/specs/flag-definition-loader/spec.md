# Flag Definition Loader Specification

## Purpose

`flag-definition-loader` is the internal component that fetches, caches, and refreshes **feature flag definitions for local evaluation**.

It is distinct from the client-side feature-flag value cache:

- **feature-flag-cache** stores evaluated/current flag values and payloads for an identity
- **flag-definition-loader** stores the rule definitions needed to compute flag values locally

This component typically manages:

- polling for local-evaluation definitions
- ETag-based conditional fetches
- in-memory definition state
- optional shared/external definition caches across workers
- startup/shutdown of the polling lifecycle

## Applicability

`both` — audited implementations are especially important for server-side SDKs that support local evaluation, but the abstraction is broadly applicable to any SDK that periodically downloads flag definitions and evaluates locally. Some client wrappers, such as Flutter, expose ordinary feature-flag preload settings without owning a separate local-evaluation definition loader.

## Public signature(s)

No single public API.

Canonical internal operations look like:

```ts
loadDefinitions(force?: boolean): Promise<void>
getDefinitions(): Definitions | undefined
startPolling(): void
stopPolling(): Promise<void> | void
clear(): void
```

## Behavior

1. **Require privileged configuration when necessary.** Local-evaluation definition loading usually requires a personal/admin API key or equivalent privileged auth.
2. **Fetch flag definitions from a dedicated local-evaluation endpoint.** This is separate from per-user `/flags` / `/decide` evaluation requests.
3. **Use conditional requests where supported.** ETags (or equivalent validators) are stored and sent back on subsequent requests so unchanged definitions can return `304 Not Modified`.
4. **Update in-memory definition state on success.** Successful fetches replace the currently loaded definitions and derived indexes/maps.
5. **Preserve prior definitions on non-modified responses.** A `304` keeps current definitions but may still update the stored ETag.
6. **Optionally integrate with shared/external caches.** Some SDKs let only one worker fetch definitions while others read the latest definitions from a distributed cache provider.
7. **Start and maintain a poll loop.** Once enabled, the loader periodically refreshes definitions in the background.
8. **Handle quota or auth errors specially.** Some implementations clear definitions or back off polling when the API key is invalid, quota limited, or not authorized.
9. **Expose readiness to higher layers.** Callers can ask whether local evaluation is ready and then use the loaded definitions in the evaluator.
10. **Clear definitions on explicit reset/clear.** When local evaluation is disabled, quota limited, or reset, the loader drops the in-memory definitions and associated ETag state.
11. **Distinguish local-evaluation definition loading from ordinary feature-flag preloading.** Some wrappers expose only end-user flag preload/config knobs, not the privileged definition-loader itself. Flutter's Dart config includes the project `apiKey` and a `preloadFeatureFlags` toggle, and its setup path forwards those into the platform SDKs or hooks into an existing browser SDK, but it exposes no Dart-side personal/admin API key, ETag state, or definition-polling API for local-evaluation rule documents.

## State & lifecycle

### State read

- personal/admin API key or local-evaluation auth
- poll interval configuration
- prior ETag / cache validator
- optionally external shared cache contents and cache-provider coordination state

### State written

- loaded flag definitions
- derived lookup maps (flags-by-key, group-type mappings, cohort definitions)
- ETag / cache validator
- polling lifecycle state (`started`, next interval / backoff, timers)
- optional shared cache contents via cache-provider callbacks

### Lifecycle behavior

- Loader is usually initialized with the SDK but may stay inactive until local evaluation is requested.
- First load often kicks off background polling.
- Poll loops run until shutdown/disposal.
- Shutdown clears timers/tasks and may release distributed-cache coordination resources.
- Wrapper SDKs may have no definition-loader lifecycle of their own. Flutter forwards setup config to native SDKs over the method channel, and Flutter Web attaches to an already-initialized `posthog-js` instance plus `onFeatureFlags` callback wiring rather than starting a Dart-owned definition poller.

## Error handling

- Definition-load failures should not crash caller code.
- Transient failures keep the last known good definitions when available.
- Unauthorized / invalid-key / quota-limited conditions may clear local definitions and stop or back off polling.
- Shared cache provider failures are logged and generally fall back to direct API fetches.

## Concurrency & ordering guarantees

- Only one definition load should be active per loader instance at a time.
- Concurrent callers should observe either the previous definition set or the newly-loaded set, not a partial update.
- Poll loops and manual refreshes should coordinate through shared state (`loadingPromise`, started flags, atomic references, etc.).

## Interactions

- **local-feature-flag-evaluator** consumes the loaded definitions to compute flags locally.
- **http-client** performs the actual authenticated request to fetch the definitions.
- **feature-flag-cache** is separate: it stores evaluated values, not the definition documents themselves.
- **remote-config** may influence whether local evaluation is enabled, but definition loading is a separate flow.
- **wrapper setup / preload surfaces** can look similar while being semantically different. Flutter's `preloadFeatureFlags` and `onFeatureFlags` settings relate to ordinary feature-flag value loading/callbacks, not to a Dart-owned privileged definition-loader for local evaluation.

## Requirements

### Requirement: Canonical flag-definition-loader behavior

The SDK SHALL implement the canonical `flag-definition-loader` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Loader fetches and caches local evaluation definitions
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** the mock server will return flag definitions:
  | key     | active | rollout |
  | beta-ui | true   | 100     |
- **WHEN** the flag definition loader refreshes
- **THEN** local feature flag definitions should include flag "beta-ui"
- **AND** the definition cache should be marked fresh

#### Scenario: Loader keeps stale definitions when refresh fails
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** local feature flag definitions include flag "beta-ui"
- **AND** the mock server will fail the next flag definition request with status 503
- **WHEN** the flag definition loader refreshes
- **THEN** local feature flag definitions should still include flag "beta-ui"
- **AND** the SDK should record a flag definition refresh warning

#### Scenario: Loader refreshes after polling interval
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** the flag definition polling interval is "30 seconds"
- **WHEN** the SDK clock advances by "30 seconds"
- **THEN** the flag definition loader should request fresh definitions
