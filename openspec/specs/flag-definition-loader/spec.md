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

### Requirement: External flag definition cache providers

The SDK SHALL treat an external flag definition cache provider as the canonical extension point for sharing local-evaluation flag definitions across distributed or stateless SDK instances. Implementations MAY adapt provider type names, method names, return types, and field casing to platform idioms, but the provider contract SHALL preserve these operations and outcomes:

- retrieve cached flag definition data, returning data or an absent value when the shared cache is empty
- decide whether the current SDK instance should fetch fresh definitions from PostHog
- receive freshly fetched definitions after a successful PostHog API load so they can be stored in the shared cache
- clean up provider resources during SDK shutdown

The cached data SHALL contain the complete local-evaluation definition set: feature flag definitions, group type mapping, cohort definitions, and the top-level `property_matching_version` associated with that snapshot. Older cached data omitting the version SHALL load as legacy; freshly hydrated data omitting it SHALL NOT inherit a previous v2 selector. Every supported provider representation, API projection, on-disk cache, or database-backed definition store SHALL retain the version together with the rules on serialization and hydration. This requirement does not require adding a new cache backend. SDKs MAY expose this as typed data, JSON-compatible maps, or equivalent structures, and MAY use idiomatic casing such as `groupTypeMapping` or `group_type_mapping`.

On each loader refresh with a provider configured, the SDK SHALL call the provider's fetch-decision operation before making a direct flag-definition API request. If the provider says this instance should fetch, the SDK SHALL fetch from PostHog, update in-memory definitions, and then call the provider's store operation with the fetched data. If the provider says this instance should not fetch, the SDK SHALL try to load definitions from the provider cache and update in-memory definitions from that data without making a direct API request. If the provider cache is empty or unavailable while previous definitions are loaded, the SDK SHALL keep using the previous in-memory definitions rather than clearing local evaluation. If no definitions are loaded and privileged local-evaluation auth is configured, the SDK MAY bypass the negative fetch decision and fetch directly so local evaluation can recover from an empty shared cache.

Provider methods MAY be synchronous or asynchronous where appropriate for the language/runtime. SDKs that expose or accept asynchronous provider methods SHALL wait for provider results before deciding the refresh, store, or shutdown outcome, and SHALL bound or otherwise contain asynchronous waits so a misbehaving provider cannot hang the SDK indefinitely. SDKs MAY expose a synchronous/blocking convenience provider surface in runtimes where that is idiomatic, including by adapting blocking methods into the asynchronous provider contract.

Provider errors, rejected asynchronous results, malformed cache data, and provider timeouts SHALL be handled defensively: they SHALL be logged or reported as SDK warnings, SHALL NOT crash application code, and SHALL NOT erase previously loaded valid definitions. A fetch-decision failure SHALL default to a direct PostHog fetch when privileged local-evaluation auth is available. A store failure SHALL leave freshly fetched in-memory definitions usable. A shutdown failure SHALL NOT prevent the rest of SDK shutdown from proceeding.

#### Scenario: Sync provider results are used where supported
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token", local evaluation enabled, and a synchronous external flag definition cache provider
- **AND** the synchronous cache provider fetch-decision operation returns false
- **AND** the synchronous cache provider returns cached flag definitions:
  | key     | active | rollout |
  | beta-ui | true   | 100     |
- **WHEN** the flag definition loader refreshes
- **THEN** local feature flag definitions should include flag "beta-ui"
- **AND** no direct flag definition API request should be sent

#### Scenario: Loader stores definitions after this instance fetches
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token", local evaluation enabled, and an external flag definition cache provider
- **AND** the cache provider fetch-decision operation returns true
- **AND** the mock server will return flag definitions:
  | key     | active | rollout |
  | beta-ui | true   | 100     |
- **WHEN** the flag definition loader refreshes
- **THEN** local feature flag definitions should include flag "beta-ui"
- **AND** the cache provider should receive flag definition cache data containing flags, group type mapping, cohorts, and the snapshot matching version (legacy when omitted)

#### Scenario: Async provider results are awaited where supported
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token", local evaluation enabled, and an async external flag definition cache provider
- **AND** the async cache provider fetch-decision operation resolves false
- **AND** the async cache provider resolves cached flag definitions:
  | key     | active | rollout |
  | beta-ui | true   | 100     |
- **WHEN** the flag definition loader refreshes
- **THEN** the loader should wait for the async provider results before completing the refresh
- **AND** local feature flag definitions should include flag "beta-ui"
- **AND** no direct flag definition API request should be sent

#### Scenario: Provider read failures preserve previously loaded definitions
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token", local evaluation enabled, and an external flag definition cache provider
- **AND** local feature flag definitions include flag "beta-ui"
- **AND** the cache provider fetch-decision operation returns false
- **AND** the cache provider read operation fails
- **WHEN** the flag definition loader refreshes
- **THEN** local feature flag definitions should still include flag "beta-ui"
- **AND** the SDK should record a flag definition cache warning
- **AND** the refresh should not throw

#### Scenario: Provider fetch-decision failures fail safe to direct fetch
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token", local evaluation enabled, and an external flag definition cache provider
- **AND** the cache provider fetch-decision operation fails
- **AND** the mock server will return flag definitions:
  | key     | active | rollout |
  | beta-ui | true   | 100     |
- **WHEN** the flag definition loader refreshes
- **THEN** a direct flag definition API request should be sent
- **AND** local feature flag definitions should include flag "beta-ui"
- **AND** the SDK should record a flag definition cache warning

#### Scenario: Provider shutdown is invoked and isolated from SDK shutdown
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token", local evaluation enabled, and an external flag definition cache provider
- **AND** the cache provider shutdown operation fails
- **WHEN** shutdown is called
- **THEN** the cache provider shutdown operation should have been called
- **AND** shutdown should not throw because of the cache provider failure
- **AND** the SDK should record a flag definition cache warning

### Requirement: Definition snapshots retain the property matching version

The loader SHALL deserialize the definitions response's top-level `property_matching_version` and retain it with the complete definition snapshot, including flags, group type mapping, cohorts, and derived indexes. Exactly numeric `2` SHALL select explicit property matching. Missing or `1` SHALL select released service legacy semantics. Other versions SHALL NOT enable v2; the evaluator SHALL use legacy fallback unless it has an existing safe-inconclusive policy for unsupported versions. Ordinary older responses and cached snapshots SHALL load without throwing. This selector SHALL NOT be inferred from individual flag `version` or the `/flags?v=2` evaluated-response format.

A successful fresh response SHALL atomically replace definitions and matching version. A fresh response or cache hydration omitting the field SHALL reset matching to legacy even after v2. A transient API failure, `304 Not Modified`, or empty/unavailable/failed provider read that preserves existing definitions SHALL preserve their matching version as well. A `304` MAY update the ETag without replacing the snapshot. If existing loader policy explicitly clears definitions (for example reset, unauthorized, or quota handling), it SHALL clear the associated version state too; the next older snapshot SHALL default to legacy.

A change of matching version alone SHALL count as a definition-state change even if all flag definitions and individual flag versions are identical. Any locally cached evaluation results SHALL be invalidated or isolated by the new snapshot/version before subsequent evaluations. In-flight evaluations SHALL retain their captured snapshot. The rule applies to direct API fetches and every supported provider/cache hydration path, including synchronous and asynchronous paths.

#### Scenario: Initial definitions select missing 1 and 2 semantics

- **WHEN** initial definitions contain a flag comparing `false` to present property `"banana"`
- **THEN** an omitted version or `1` should evaluate to true locally
- **AND** version `2` should evaluate to false locally
- **AND** individual flag version `2` alone should not select explicit matching

#### Scenario: Version-only refreshes invalidate evaluated results

- **GIVEN** a version-1 snapshot has cached a true result for `exact false` against `"banana"`
- **WHEN** otherwise identical definitions are refreshed with version `2`
- **THEN** the next local result should be false
- **WHEN** otherwise identical definitions are refreshed with version `1`
- **THEN** the next local result should be true
- **AND** no remote evaluation should be needed to obtain any of these results

#### Scenario: Fresh omission resets a previous explicit snapshot

- **GIVEN** version-2 definitions are loaded
- **WHEN** a successful API response or cache hydration supplies a new snapshot without `property_matching_version`
- **THEN** the newly loaded snapshot should use legacy semantics rather than retaining version 2

#### Scenario: Failed or non-modified refresh preserves snapshot and version

- **GIVEN** version-2 definitions with ETag `current` are loaded
- **WHEN** the next refresh fails with `503`, returns `304`, or reads an empty or failed provider cache
- **THEN** the previous definitions and version 2 should remain paired and usable
- **AND** `exact false` against `"banana"` should still return false locally

#### Scenario: Cached definitions round trip the matching selector

- **GIVEN** the loader successfully fetched definitions with version `2`, a company group mapping, and a recursive dynamic cohort
- **WHEN** the snapshot is stored and hydrated by another instance through a supported definition cache
- **THEN** flags, group mapping, cohorts, and version 2 should survive together
- **AND** the second instance should use explicit property matching without a direct definition API request
- **WHEN** an older cache entry omitting the version is hydrated
- **THEN** it should load without throwing and use legacy matching, even if the instance previously held v2

#### Scenario: Clearing definitions clears matching state

- **GIVEN** version-2 definitions are loaded
- **WHEN** the loader explicitly clears definitions and later loads an older snapshot without a version
- **THEN** that snapshot should use legacy matching and no v2 evaluation cache should be reused

### Requirement: Holdout metadata survives definition loading and caching

The definition loader SHALL preserve `filters.holdout.id` and `filters.holdout.exclusion_percentage` when hydrating local evaluator definitions. Typed models, API projections, and supported definition-cache serialization and deserialization SHALL retain these fields without truncating fractional percentages. Refreshes SHALL replace holdout configuration with the new definition snapshot, including removing a previous holdout when the refreshed definition omits it. This does not require a new cache backend.

#### Scenario: Shared cache retains holdout membership (@server)
- **GIVEN** the definition API returns an active flag with holdout id 727 and exclusion percentage 12.5
- **WHEN** one SDK instance stores those definitions in a configured shared cache and another instance loads them
- **THEN** the loaded flag should retain holdout id 727 and exclusion percentage 12.5
- **AND** both instances should calculate identical holdout membership for the same bucketing identity

#### Scenario: Refresh removes an old holdout (@server)
- **GIVEN** cached definitions contain an active flag with a 100 percent holdout
- **WHEN** a replacement definition snapshot omits that flag's holdout configuration
- **THEN** subsequent local evaluations should use ordinary release conditions rather than the previous holdout

