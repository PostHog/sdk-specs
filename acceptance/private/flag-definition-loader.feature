@private @canonical_behavior @acceptance @flag_definition_loader @server
Feature: Flag Definition Loader
  Acceptance tests for the canonical flag definition loader behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Loader fetches and caches local evaluation definitions
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the mock server will return flag definitions:
      | key     | active | rollout |
      | beta-ui | true   | 100     |
    When the flag definition loader refreshes
    Then local feature flag definitions should include flag "beta-ui"
    And the definition cache should be marked fresh

  Scenario: Loader keeps stale definitions when refresh fails
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And local feature flag definitions include flag "beta-ui"
    And the mock server will fail the next flag definition request with status 503
    When the flag definition loader refreshes
    Then local feature flag definitions should still include flag "beta-ui"
    And the SDK should record a flag definition refresh warning

  Scenario: Loader refreshes after polling interval
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the flag definition polling interval is "30 seconds"
    When the SDK clock advances by "30 seconds"
    Then the flag definition loader should request fresh definitions

  Scenario: Sync provider results are used where supported
    Given the SDK is initialized with token "test-token", local evaluation enabled, and a synchronous external flag definition cache provider
    And the synchronous cache provider fetch-decision operation returns false
    And the synchronous cache provider returns cached flag definitions:
      | key     | active | rollout |
      | beta-ui | true   | 100     |
    When the flag definition loader refreshes
    Then local feature flag definitions should include flag "beta-ui"
    And no direct flag definition API request should be sent

  Scenario: Loader stores definitions after this instance fetches
    Given the SDK is initialized with token "test-token", local evaluation enabled, and an external flag definition cache provider
    And the cache provider fetch-decision operation returns true
    And the mock server will return flag definitions:
      | key     | active | rollout |
      | beta-ui | true   | 100     |
    When the flag definition loader refreshes
    Then local feature flag definitions should include flag "beta-ui"
    And the cache provider should receive flag definition cache data containing flags, group type mapping, cohorts, and the snapshot matching version (legacy when omitted)

  Scenario: Async provider results are awaited where supported
    Given the SDK is initialized with token "test-token", local evaluation enabled, and an async external flag definition cache provider
    And the async cache provider fetch-decision operation resolves false
    And the async cache provider resolves cached flag definitions:
      | key     | active | rollout |
      | beta-ui | true   | 100     |
    When the flag definition loader refreshes
    Then the loader should wait for the async provider results before completing the refresh
    And local feature flag definitions should include flag "beta-ui"
    And no direct flag definition API request should be sent

  Scenario: Provider read failures preserve previously loaded definitions
    Given the SDK is initialized with token "test-token", local evaluation enabled, and an external flag definition cache provider
    And local feature flag definitions include flag "beta-ui"
    And the cache provider fetch-decision operation returns false
    And the cache provider read operation fails
    When the flag definition loader refreshes
    Then local feature flag definitions should still include flag "beta-ui"
    And the SDK should record a flag definition cache warning
    And the refresh should not throw

  Scenario: Provider fetch-decision failures fail safe to direct fetch
    Given the SDK is initialized with token "test-token", local evaluation enabled, and an external flag definition cache provider
    And the cache provider fetch-decision operation fails
    And the mock server will return flag definitions:
      | key     | active | rollout |
      | beta-ui | true   | 100     |
    When the flag definition loader refreshes
    Then a direct flag definition API request should be sent
    And local feature flag definitions should include flag "beta-ui"
    And the SDK should record a flag definition cache warning

  Scenario: Provider shutdown is invoked and isolated from SDK shutdown
    Given the SDK is initialized with token "test-token", local evaluation enabled, and an external flag definition cache provider
    And the cache provider shutdown operation fails
    When shutdown is called
    Then the cache provider shutdown operation should have been called
    And shutdown should not throw because of the cache provider failure
    And the SDK should record a flag definition cache warning

  # In version columns, omitted removes the top-level field from the response.
  Scenario Outline: Loader reads the matching selector from the definitions envelope
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the mock server will return this flag definitions response:
      """json
      {
        "flags": [{
          "id": 1,
          "key": "versioned",
          "name": "Versioned",
          "active": true,
          "version": 2,
          "filters": {"groups": [{
            "properties": [{"key": "plan", "type": "person", "operator": "exact", "value": false}],
            "rollout_percentage": 100
          }]}
        }],
        "group_type_mapping": {"0": "company"},
        "cohorts": {},
        "property_matching_version": 2
      }
      """
    And that response has top-level "property_matching_version" <version>
    When the flag definition loader refreshes
    Then the loaded snapshot should retain flags group type mapping cohorts and matching semantics selected by <version>
    When local feature flag "versioned" is evaluated with person property "plan" equal to "banana"
    Then the local evaluation result should be <matches>
    And no remote feature flag evaluation request should have been sent
    And individual flag version 2 should not override the top-level matching selector

    Examples:
      | version | matches |
      | omitted | true    |
      | 1       | true    |
      | 2       | false   |

  Scenario Outline: Version-only reloads replace evaluated results in both directions
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the SDK supports definition refresh through <source>
    And loaded definitions with top-level "property_matching_version" 1 include flag "versioned" matching person property "plan" with operator "exact" and value false
    And local feature flag "versioned" has already evaluated to true for person property "plan" equal to "banana"
    When otherwise identical definitions with top-level "property_matching_version" 2 are loaded through <source>
    And local feature flag "versioned" is evaluated again for the same identity and property context
    Then the local evaluation result should be false
    When otherwise identical definitions with top-level "property_matching_version" 1 are loaded through <source>
    And local feature flag "versioned" is evaluated again for the same identity and property context
    Then the local evaluation result should be true
    And every flag definition and individual flag version should have remained unchanged during both reloads
    And no remote feature flag evaluation request should have been sent

    Examples:
      | source                       |
      | a direct API response        |
      | synchronous cache hydration  |
      | asynchronous cache hydration |

  Scenario Outline: A fresh snapshot without a matching version resets previous v2
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the SDK supports definition refresh through <source>
    And loaded definitions with top-level "property_matching_version" 2 include flag "versioned" matching person property "plan" with operator "exact" and value false
    And local feature flag "versioned" has already evaluated to false for person property "plan" equal to "banana"
    When otherwise identical definitions omitting top-level "property_matching_version" are loaded through <source>
    And local feature flag "versioned" is evaluated again for the same identity and property context
    Then the local evaluation result should be true
    And the loaded snapshot should use legacy matching
    And loading should not throw
    And no remote feature flag evaluation request should have been sent

    Examples:
      | source                       |
      | a direct API response        |
      | synchronous cache hydration  |
      | asynchronous cache hydration |

  Scenario Outline: Failed and non-modified refreshes preserve definitions with their matching version
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And loaded definitions with top-level "property_matching_version" <version> and ETag "current" include flag "versioned" matching person property "plan" with operator "exact" and value false
    And the mock server will respond to the next flag definition request with status <status> and no definition body
    When the flag definition loader refreshes
    Then the prior flags group mapping cohorts and matching selector should remain unchanged
    When local feature flag "versioned" is evaluated with person property "plan" equal to "banana"
    Then the local evaluation result should be <matches>
    And no remote feature flag evaluation request should have been sent

    Examples:
      | version | status | matches |
      | 1       | 503    | true    |
      | 2       | 503    | false   |
      | 1       | 304    | true    |
      | 2       | 304    | false   |

  Scenario: A 304 may update the ETag without resetting the matching version
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And the SDK supports conditional flag definition requests
    And loaded definitions with top-level "property_matching_version" 2 and ETag "current" include flag "versioned" matching person property "plan" with operator "exact" and value false
    And the mock server will return status 304 with ETag "next" and no definition body
    When the flag definition loader refreshes
    Then the definition request should include If-None-Match "current"
    And the loader may retain ETag "current" or update it to "next"
    And the loaded matching selector should remain 2
    When local feature flag "versioned" is evaluated with person property "plan" equal to "banana"
    Then the local evaluation result should be false
    And no remote feature flag evaluation request should have been sent

  Scenario Outline: Unavailable provider data preserves the existing matching snapshot
    Given the SDK is initialized with token "test-token", local evaluation enabled, and an external flag definition cache provider
    And loaded definitions with top-level "property_matching_version" 2 include flag "versioned" matching person property "plan" with operator "exact" and value false
    And the cache provider fetch-decision operation returns false
    And the provider read <outcome>
    When the flag definition loader refreshes
    Then the prior flags group mapping cohorts and matching selector should remain unchanged
    When local feature flag "versioned" is evaluated with person property "plan" equal to "banana"
    Then the local evaluation result should be false
    And the refresh should not throw
    And no remote feature flag evaluation request should have been sent

    Examples:
      | outcome                |
      | returns no cached data |
      | fails                  |
      | returns malformed data |
      | times out              |

  Scenario Outline: Supported definition stores round trip the complete versioned snapshot
    Given the SDK supports <store> for flag definition snapshots
    And the SDK is initialized with token "test-token" and local evaluation enabled
    And a fetched snapshot has top-level "property_matching_version" <version>
    And the snapshot contains a person flag a company group flag and a cohort flag requiring membership in dynamic cohort "42"
    And its group type mapping maps index 0 to "company"
    And cohort "42" is an AND group referencing cohort "43" whose OR group contains one person property leaf
    And all three flags have one effective property condition comparing "plan" with false using operator "exact" at 100 percent rollout
    When the fetched snapshot is serialized into <store>
    And another SDK instance hydrates that snapshot from <store> without a direct definition API request
    Then flags group type mapping cohorts and matching semantics selected by <version> should survive together
    When the second instance evaluates those flags for person property "plan" equal to "banana" and company "acme" with group property "plan" equal to "banana"
    Then each local evaluation result should be <matches>
    And no remote feature flag evaluation request should have been sent

    Examples:
      | store                          | version | matches |
      | a synchronous cache provider   | omitted | true    |
      | a synchronous cache provider   | 1       | true    |
      | a synchronous cache provider   | 2       | false   |
      | an asynchronous cache provider | omitted | true    |
      | an asynchronous cache provider | 1       | true    |
      | an asynchronous cache provider | 2       | false   |
      | an on-disk definition cache    | omitted | true    |
      | an on-disk definition cache    | 1       | true    |
      | an on-disk definition cache    | 2       | false   |
      | a database definition store    | omitted | true    |
      | a database definition store    | 1       | true    |
      | a database definition store    | 2       | false   |

  Scenario: Provider store failure leaves the fresh matching snapshot usable
    Given the SDK is initialized with token "test-token", local evaluation enabled, and an external flag definition cache provider
    And loaded definitions with top-level "property_matching_version" 1 include flag "versioned" matching person property "plan" with operator "exact" and value false
    And the cache provider fetch-decision operation returns true
    And the mock server will return otherwise identical definitions with top-level "property_matching_version" 2
    And the provider store operation fails
    When the flag definition loader refreshes
    And local feature flag "versioned" is evaluated with person property "plan" equal to "banana"
    Then the local evaluation result should be false
    And the loaded matching selector should be 2
    And no remote feature flag evaluation request should have been sent
    And the SDK should record a flag definition cache warning
    And the refresh should not throw

  Scenario: Explicit clearing cannot leak v2 into a later older snapshot
    Given the SDK is initialized with token "test-token" and local evaluation enabled
    And loaded definitions with top-level "property_matching_version" 2 include flag "versioned" matching person property "plan" with operator "exact" and value false
    When the flag definition loader is explicitly cleared
    Then local feature flag definitions and their associated matching state should be cleared
    When the loader loads otherwise identical definitions omitting top-level "property_matching_version"
    And local feature flag "versioned" is evaluated with person property "plan" equal to "banana"
    Then the local evaluation result should be true
    And no remote feature flag evaluation request should have been sent
