@public @canonical_behavior @acceptance @evaluate_flags @server
Feature: Evaluate Flags
  Acceptance tests for the canonical server-side feature flag evaluation snapshot API.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"

  Scenario: One evaluation snapshot powers multiple flag branches
    Given remote feature flag evaluation for distinct id "user-123" returns:
      | key      | value |
      | beta-ui  | true  |
      | checkout | blue  |
    When evaluate flags is called for distinct id "user-123"
    And snapshot enablement is read for "beta-ui"
    And snapshot value is read for "checkout"
    And snapshot enablement is read again for "beta-ui"
    Then the returned enabled value for "beta-ui" should be true
    And the returned snapshot value for "checkout" should be "blue"
    And exactly one remote feature flag evaluation request should have been sent

  Scenario: One snapshot replaces separate server getter and capture-time evaluations
    Given remote feature flag evaluation for distinct id "user-123" returns:
      | key      | value | payload          |
      | beta-ui  | true  |                  |
      | checkout | blue  | {"copy":"new"} |
    When evaluate flags is called for distinct id "user-123"
    And snapshot enablement is read for "beta-ui"
    And snapshot value is read for "checkout"
    And snapshot payload is read for "checkout"
    And snapshot keys are enumerated
    And an event named "order completed" is captured for distinct id "user-123" with the evaluation snapshot
    Then the snapshot should expose the boolean, value, payload, and both keys from the same evaluation
    And the captured event should have property "$feature/beta-ui" equal to true
    And the captured event should have property "$feature/checkout" equal to "blue"
    And exactly one remote feature flag evaluation request should have been sent

  Scenario: Snapshot accessors distinguish disabled missing and variant flags
    Given remote feature flag evaluation for distinct id "user-123" returns:
      | key      | value |
      | disabled | false |
      | checkout | blue  |
    When evaluate flags is called for distinct id "user-123"
    Then snapshot enablement for "disabled" should be false
    And snapshot value for "disabled" should be false
    And snapshot enablement for "checkout" should be true
    And snapshot value for "checkout" should be "blue"
    And snapshot enablement for "missing" should be false
    And snapshot value for "missing" should be absent

  Scenario: Evaluation does not report exposure until a value is accessed
    Given remote feature flag evaluation for distinct id "user-123" returns:
      | key     | value |
      | beta-ui | true  |
    When evaluate flags is called for distinct id "user-123"
    Then no event named "$feature_flag_called" should be enqueued
    When snapshot enablement is read for "beta-ui"
    Then a "$feature_flag_called" event should be enqueued for flag "beta-ui" with value "true"
    When snapshot value is read for "beta-ui"
    And snapshot enablement is read again for "beta-ui"
    Then only one deduped "$feature_flag_called" event should be enqueued for flag "beta-ui" with value "true"

  Scenario: Snapshot payload access is silent
    Given remote feature flag evaluation for distinct id "user-123" returns:
      | key      | value | payload          |
      | checkout | blue  | {"copy":"new"} |
    When evaluate flags is called for distinct id "user-123"
    And snapshot payload is read for "checkout"
    Then the returned snapshot payload for "checkout" should be `{"copy":"new"}`
    And no event named "$feature_flag_called" should be enqueued
    And snapshot only accessed should return no flags
    And exactly one remote feature flag evaluation request should have been sent

  Scenario: Capture reuses exact snapshot values without reevaluation
    Given remote feature flag evaluation for distinct id "user-123" returns:
      | key      | value |
      | beta-ui  | false |
      | checkout | blue  |
    When evaluate flags is called for distinct id "user-123"
    And an event named "order completed" is captured for distinct id "user-123" with the evaluation snapshot
    Then the captured event should have property "$feature/beta-ui" equal to false
    And the captured event should have property "$feature/checkout" equal to "blue"
    And the captured event property "$active_feature_flags" should contain "checkout"
    And the captured event property "$active_feature_flags" should not contain "beta-ui"
    And exactly one remote feature flag evaluation request should have been sent

  Scenario: Only accessed filters the snapshot for capture
    Given remote feature flag evaluation for distinct id "user-123" returns:
      | key      | value |
      | beta-ui  | true  |
      | checkout | blue  |
      | search   | false |
    When evaluate flags is called for distinct id "user-123"
    And snapshot enablement is read for "beta-ui"
    And snapshot value is read for "search"
    And snapshot only accessed is called
    Then the filtered snapshot should contain flags:
      | key     | value |
      | beta-ui | true  |
      | search  | false |
    And the filtered snapshot should not contain "checkout"
    And no additional remote feature flag evaluation request should have been sent

  Scenario: Only accessed before branching returns an empty snapshot
    Given remote feature flag evaluation for distinct id "user-123" returns:
      | key     | value |
      | beta-ui | true  |
    When evaluate flags is called for distinct id "user-123"
    And snapshot only accessed is called before a value or enablement read
    Then the filtered snapshot should contain no flags

  Scenario: Request-time keys and in-memory filtering are distinct
    Given remote feature flag evaluation for distinct id "user-123" can return:
      | key      | value |
      | beta-ui  | true  |
      | checkout | blue  |
      | search   | false |
    When evaluate flags is called for distinct id "user-123" with flag keys:
      | key      |
      | beta-ui  |
      | checkout |
    Then the remote feature flag evaluation request should include only flag keys "beta-ui" and "checkout"
    And the snapshot should not contain "search"
    When snapshot only is called with flag keys "beta-ui" and "missing"
    Then the filtered snapshot should contain only "beta-ui"
    And no additional remote feature flag evaluation request should have been sent

  Scenario: First missing requested local definition triggers scoped remote fallback
    Given local feature flag definitions resolve "beta-ui" for distinct id "user-123" as true
    And no local feature flag definition is loaded for "checkout"
    And remote feature flag evaluation for distinct id "user-123" returns:
      | key      | value |
      | beta-ui  | false |
      | checkout | blue  |
    When evaluate flags is called for distinct id "user-123" with flag keys:
      | key      |
      | beta-ui  |
      | checkout |
    Then exactly one remote feature flag evaluation request should have been sent
    And the remote feature flag evaluation request should include only flag keys "beta-ui" and "checkout"
    And the snapshot should contain "beta-ui" with value true
    And the snapshot should contain "checkout" with value "blue"

  Scenario: Clean remote omission suppresses probes across identities until refresh
    Given the SDK supports successful local feature flag definition refreshes
    And local feature flag definitions resolve "beta-ui" for distinct id "user-123" as true
    And no local feature flag definition is loaded for "deleted-flag"
    And remote feature flag evaluation for distinct id "user-123" returns no flags
    When evaluate flags is called for distinct id "user-123" with flag keys:
      | key          |
      | beta-ui      |
      | deleted-flag |
    And evaluate flags is called for distinct id "user-456" with flag keys:
      | key          |
      | beta-ui      |
      | deleted-flag |
    Then exactly one remote feature flag evaluation request should have been sent
    And both evaluation snapshots should not contain "deleted-flag"

  Scenario: Capacity eviction makes a missing key eligible to probe again
    Given the SDK supports successful local feature flag definition refreshes
    And clean remote omissions have filled the missing-key knowledge store to its configured capacity
    When one additional clean remote omission is retained
    Then one previously retained missing key should be evicted
    And the missing-key knowledge store should not exceed its configured capacity
    Given no local feature flag definition is loaded for the evicted key
    And remote feature flag evaluation for distinct id "user-123" returns no flags
    When evaluate flags is called for distinct id "user-123" with the evicted flag key
    Then one additional remote feature flag evaluation request should have been sent
    And the evaluation snapshot should not contain the evicted key

  Scenario Outline: Every successful definitions refresh clears missing-key knowledge
    Given local feature flag definitions resolve "beta-ui" for distinct id "user-123" as true
    And no local feature flag definition is loaded for "deleted-flag"
    And remote feature flag evaluation for distinct id "user-123" returns no flags
    When evaluate flags is called for distinct id "user-123" with flag keys:
      | key          |
      | beta-ui      |
      | deleted-flag |
    And local feature flag definitions are refreshed successfully using "<refresh result>" and still omit "deleted-flag"
    And no complete cached feature flag evaluation result exists for distinct id "user-456"
    And remote feature flag evaluation for distinct id "user-456" returns no flags
    And evaluate flags is called for distinct id "user-456" with flag keys:
      | key          |
      | beta-ui      |
      | deleted-flag |
    Then exactly two remote feature flag evaluation requests should have been sent

    Examples:
      | refresh result               |
      | changed definitions          |
      | unchanged definitions        |
      | 304 not modified             |
      | successful shared-cache load |

  Scenario: Failed definitions refresh preserves missing-key knowledge
    Given local feature flag definitions resolve "beta-ui" for distinct id "user-123" as true
    And no local feature flag definition is loaded for "deleted-flag"
    And remote feature flag evaluation for distinct id "user-123" returns no flags
    When evaluate flags is called for distinct id "user-123" with flag keys:
      | key          |
      | beta-ui      |
      | deleted-flag |
    And the next local feature flag definitions refresh fails
    And local feature flag definitions are refreshed
    And evaluate flags is called for distinct id "user-456" with flag keys:
      | key          |
      | beta-ui      |
      | deleted-flag |
    Then exactly one remote feature flag evaluation request should have been sent

  Scenario Outline: Every successful refresh invalidates a delayed probe from the previous generation
    Given the SDK supports successful local feature flag definition refreshes
    And no local feature flag definition is loaded for "deleted-flag"
    And the first clean remote response omitting "deleted-flag" is delayed
    And the following remote feature flag evaluation response returns no flags
    When evaluate flags is started for distinct id "user-123" with flag key "deleted-flag"
    Then exactly one remote feature flag evaluation request should be in flight
    When local feature flag definitions are refreshed successfully using "<refresh result>" and still omit "deleted-flag"
    And the delayed remote feature flag evaluation response is released
    And no complete cached feature flag evaluation result exists for distinct id "user-456"
    And evaluate flags is called for distinct id "user-456" with flag key "deleted-flag"
    Then exactly two remote feature flag evaluation requests should have been sent
    And both evaluation snapshots should not contain "deleted-flag"

    Examples:
      | refresh result               |
      | changed definitions          |
      | unchanged definitions        |
      | 304 not modified             |
      | successful shared-cache load |

  Scenario Outline: Inconclusive missing-key fallback allows same-identity retry
    Given local feature flag definitions resolve "beta-ui" for distinct id "user-123" as true
    And no local feature flag definition is loaded for "new-flag"
    And the next remote feature flag evaluation request has outcome "<outcome>"
    And the following remote feature flag evaluation request returns:
      | key      | value |
      | new-flag | true  |
    When evaluate flags is called twice for distinct id "user-123" with flag keys:
      | key      |
      | beta-ui  |
      | new-flag |
    Then exactly two remote feature flag evaluation requests should have been sent
    And the second evaluation snapshot should contain "new-flag" with value true

    Examples:
      | outcome                       |
      | transport failure             |
      | feature flag quota limited    |
      | errors while computing flags  |

  Scenario: Concurrent clean omissions share one missing-key probe
    Given local feature flag definitions resolve "beta-ui" for distinct id "user-123" as true
    And no local feature flag definition is loaded for "deleted-flag"
    And the clean remote response omitting "deleted-flag" is delayed
    When evaluate flags is started concurrently for distinct ids "user-123" and "user-456" with flag key "deleted-flag"
    Then exactly one remote feature flag evaluation request should be in flight
    When the delayed remote feature flag evaluation response is released
    Then both evaluation snapshots should not contain "deleted-flag"
    And exactly one remote feature flag evaluation request should have been sent

  Scenario: A remotely returned key is evaluated for each identity
    Given no local feature flag definition is loaded for "remote-flag"
    And the delayed remote feature flag evaluation response for distinct id "user-123" returns:
      | key         | value |
      | remote-flag | true  |
    And the following remote feature flag evaluation response for distinct id "user-456" returns:
      | key         | value |
      | remote-flag | false |
    When evaluate flags is started concurrently for distinct ids "user-123" and "user-456" with flag key "remote-flag"
    Then exactly one remote feature flag evaluation request should be in flight
    When the delayed remote feature flag evaluation response is released
    Then exactly two remote feature flag evaluation requests should have been sent
    And the first evaluation snapshot should contain "remote-flag" with value true
    And the second evaluation snapshot should contain "remote-flag" with value false

  Scenario Outline: A remotely returned key is evaluated for every distinct context
    Given no local feature flag definition is loaded for "remote-flag"
    And two evaluations for distinct id "user-123" differ only in "<context input>"
    And the delayed remote feature flag evaluation response for the first context returns:
      | key         | value |
      | remote-flag | true  |
    And the following remote feature flag evaluation response for the second context returns:
      | key         | value |
      | remote-flag | false |
    When both evaluate flags calls are started concurrently with flag key "remote-flag"
    Then exactly one remote feature flag evaluation request should be in flight
    When the delayed remote feature flag evaluation response is released
    Then exactly two remote feature flag evaluation requests should have been sent
    And the first evaluation snapshot should contain "remote-flag" with value true
    And the second evaluation snapshot should contain "remote-flag" with value false

    Examples:
      | context input       |
      | groups              |
      | person properties   |
      | group properties    |
      | GeoIP control       |
      | requested key scope |

  Scenario: A remotely returned key is evaluated separately for each supported device id
    Given the SDK supports device-continuity feature flag evaluation
    And no local feature flag definition is loaded for "remote-flag"
    And two evaluations for distinct id "user-123" have different device ids
    And the delayed remote feature flag evaluation response for the first device id returns:
      | key         | value |
      | remote-flag | true  |
    And the following remote feature flag evaluation response for the second device id returns:
      | key         | value |
      | remote-flag | false |
    When both evaluate flags calls are started concurrently with flag key "remote-flag"
    Then exactly one remote feature flag evaluation request should be in flight
    When the delayed remote feature flag evaluation response is released
    Then exactly two remote feature flag evaluation requests should have been sent
    And the first evaluation snapshot should contain "remote-flag" with value true
    And the second evaluation snapshot should contain "remote-flag" with value false

  Scenario: Unrelated missing-key probes are not serialized
    Given no local feature flag definitions are loaded for "missing-a" and "missing-b"
    And remote feature flag evaluation responses for "missing-a" and "missing-b" are delayed
    When evaluate flags is started concurrently for disjoint scopes containing "missing-a" and "missing-b"
    Then two remote feature flag evaluation requests should be in flight before either response is released

  Scenario: Mixed missing-key scope waits for its overlapping probe
    Given no local feature flag definitions are loaded for "missing-a" and "missing-b"
    And the first clean remote response omitting "missing-a" is delayed
    And the following remote feature flag evaluation response returns:
      | key       | value |
      | missing-b | true  |
    When evaluate flags is started for distinct id "user-123" with flag key "missing-a"
    And evaluate flags is started for distinct id "user-456" with flag keys:
      | key       |
      | missing-a |
      | missing-b |
    Then exactly one remote feature flag evaluation request should be in flight
    When the delayed remote feature flag evaluation response is released
    Then exactly two remote feature flag evaluation requests should have been sent
    And the second remote feature flag evaluation request should include only flag keys "missing-a" and "missing-b"
    And the second evaluation snapshot should contain "missing-b" with value true

  Scenario: Positive remote evidence clears an earlier retained omission
    Given the SDK supports successful local feature flag definition refreshes
    And no local feature flag definitions are loaded for "previously-missing" and "other-missing"
    And remote feature flag evaluation for distinct id "user-123" returns no flags
    When evaluate flags is called for distinct id "user-123" with flag key "previously-missing"
    And remote feature flag evaluation for distinct id "user-456" returns:
      | key                | value |
      | previously-missing | true  |
      | other-missing      | true  |
    And evaluate flags is called for distinct id "user-456" with flag keys:
      | key                |
      | previously-missing |
      | other-missing      |
    And remote feature flag evaluation for distinct id "user-789" returns:
      | key                | value |
      | previously-missing | false |
    And evaluate flags is called for distinct id "user-789" with flag key "previously-missing"
    Then exactly three remote feature flag evaluation requests should have been sent
    And the second evaluation snapshot should contain "previously-missing" with value true
    And the third evaluation snapshot should contain "previously-missing" with value false

  Scenario: Delayed non-owned omission cannot overwrite newer positive evidence
    Given the SDK supports successful local feature flag definition refreshes
    And no local feature flag definitions are loaded for "previously-missing", "missing-a", and "missing-b"
    And remote feature flag evaluation for distinct id "user-123" returns no flags
    When evaluate flags is called for distinct id "user-123" with flag key "previously-missing"
    And the delayed remote feature flag evaluation response for distinct id "user-456" returns no flags
    And remote feature flag evaluation for distinct id "user-789" returns:
      | key                | value |
      | previously-missing | true  |
      | missing-a           | true  |
    And evaluate flags is started for distinct id "user-456" with flag keys:
      | key                |
      | previously-missing |
      | missing-b           |
    And evaluate flags is called for distinct id "user-789" with flag keys:
      | key                |
      | previously-missing |
      | missing-a           |
    Then the third evaluation snapshot should contain "previously-missing" with value true
    When the delayed remote feature flag evaluation response is released
    And remote feature flag evaluation for distinct id "user-final" returns:
      | key                | value |
      | previously-missing | false |
    And evaluate flags is called for distinct id "user-final" with flag key "previously-missing"
    Then exactly four remote feature flag evaluation requests should have been sent
    And the fourth evaluation snapshot should contain "previously-missing" with value false

  Scenario: Request-time keys scope locally evaluated snapshot results
    Given local feature flag definitions resolve for distinct id "user-123":
      | key      | value |
      | beta-ui  | true  |
      | checkout | blue  |
      | search   | false |
    When evaluate flags is called for distinct id "user-123" with flag keys:
      | key      |
      | beta-ui  |
      | checkout |
    Then the snapshot should contain "beta-ui" with value true
    And the snapshot should contain "checkout" with value "blue"
    And the snapshot should not contain "search"

  Scenario: Request-time keys scope evaluated results loaded from cache
    Given cached feature flag evaluation for distinct id "user-123" contains:
      | key      | value |
      | beta-ui  | true  |
      | checkout | blue  |
      | search   | false |
    When evaluate flags is called for distinct id "user-123" with flag keys:
      | key      |
      | beta-ui  |
      | checkout |
    Then the snapshot should contain "beta-ui" with value true
    And the snapshot should contain "checkout" with value "blue"
    And the snapshot should not contain "search"

  Scenario: Local-only evaluation never falls back remotely
    Given local feature flag definitions resolve "beta-ui" for distinct id "user-123" as true
    And local feature flag definitions cannot resolve "checkout" for distinct id "user-123"
    When evaluate flags is called for distinct id "user-123" with local-only evaluation enabled
    Then the snapshot should contain "beta-ui" with value true
    And the snapshot should not contain "checkout"
    And no remote feature flag evaluation request should have been sent

  Scenario: Remote failure preserves successfully resolved local flags
    Given local feature flag definitions resolve "beta-ui" for distinct id "user-123" as true
    And local feature flag definitions cannot resolve "checkout" for distinct id "user-123"
    And the next remote feature flag evaluation request fails
    When evaluate flags is called for distinct id "user-123"
    Then the snapshot should contain "beta-ui" with value true
    And the snapshot should not contain "checkout"
    When snapshot enablement is read for "beta-ui"
    Then no additional remote feature flag evaluation request should have been sent

  Scenario: Missing identity returns an empty no-op snapshot
    Given request context has no distinct id
    When evaluate flags is called without an explicit distinct id
    Then the returned evaluation snapshot should be empty
    And no remote feature flag evaluation request should have been sent
    When snapshot enablement is read for "beta-ui"
    Then the returned enabled value for "beta-ui" should be false
    And no event named "$feature_flag_called" should be enqueued
