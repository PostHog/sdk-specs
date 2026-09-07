## MODIFIED Requirements

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


## ADDED Requirements

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
