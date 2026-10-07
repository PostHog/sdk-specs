@public @canonical_behavior @acceptance @evaluate_flags
Feature: Evaluate Flags
  Acceptance tests for the canonical server-side feature flag evaluation snapshot API.

  # serialized_payload_json encodes the serialized input as a JSON string.
  @server
  Scenario Outline: Snapshot payload reads reject malformed JSON
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    Given feature flags are supplied through <source> with these serialized payload bytes:
      | key      | value | serialized_payload_json |
      | checkout | blue  | <input>                 |
      | beta-ui  | true  | "{\"color\":\"green\"}"   |
    When evaluate flags is called for distinct id "user-123"
    And snapshot payload is read for "checkout"
    Then the returned payload should be the language's no-payload value
    And the raw serialized string should not be returned
    And no exception should be thrown
    And reading the payload should not send a feature flag network request
    And no event named "$feature_flag_called" should be enqueued
    And "checkout" should not be added to the snapshot's accessed-key set
    And the snapshot should retain flag "checkout" with value "blue"
    And the snapshot should retain the valid payload for "beta-ui" in the platform's documented representation

    Examples:
      | source            | input     |
      | local evaluation  | "{broken" |
      | local evaluation  | ""        |
      | local evaluation  | "   "     |
      | remote evaluation | "{broken" |
      | remote evaluation | ""        |
      | remote evaluation | "   "     |

  @server
  Scenario: One evaluation snapshot powers multiple flag branches
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: One snapshot replaces separate server getter and capture-time evaluations
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: Snapshot accessors distinguish disabled missing and variant flags
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: Evaluation does not report exposure until a value is accessed
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: Snapshot payload access is silent
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    Given remote feature flag evaluation for distinct id "user-123" returns:
      | key      | value | payload          |
      | checkout | blue  | {"copy":"new"} |
    When evaluate flags is called for distinct id "user-123"
    And snapshot payload is read for "checkout"
    Then the returned snapshot payload for "checkout" should be `{"copy":"new"}`
    And no event named "$feature_flag_called" should be enqueued
    And snapshot only accessed should return no flags
    And exactly one remote feature flag evaluation request should have been sent

  @server
  Scenario: Capture reuses exact snapshot values without reevaluation
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: Only accessed filters the snapshot for capture
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: Only accessed before branching returns an empty snapshot
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    Given remote feature flag evaluation for distinct id "user-123" returns:
      | key     | value |
      | beta-ui | true  |
    When evaluate flags is called for distinct id "user-123"
    And snapshot only accessed is called before a value or enablement read
    Then the filtered snapshot should contain no flags

  @server
  Scenario: Empty request-time key list is a no-op
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    Given cached feature flag evaluation for distinct id "user-123" contains:
      | key     | value |
      | beta-ui | true  |
    And local feature flag definitions resolve "checkout" for distinct id "user-123" as "blue"
    And remote feature flag evaluation for distinct id "user-123" can return:
      | key    | value |
      | search | false |
    When evaluate flags is called for distinct id "user-123" with an empty flag key list
    Then the returned evaluation snapshot should be empty
    And no cached feature flag evaluation result should have been consulted
    And no local feature flag evaluation should have been attempted
    And no remote feature flag evaluation request should have been sent

  @server
  Scenario: Request-time keys and in-memory filtering are distinct
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: First missing requested local definition triggers scoped remote fallback
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: Clean remote omission suppresses probes across identities until refresh
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: Capacity eviction makes a missing key eligible to probe again
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario Outline: Every successful definitions refresh clears missing-key knowledge
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: Failed definitions refresh preserves missing-key knowledge
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario Outline: Every successful refresh invalidates a delayed probe from the previous generation
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario Outline: Inconclusive missing-key fallback allows same-identity retry
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: Concurrent clean omissions share one missing-key probe
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    Given local feature flag definitions resolve "beta-ui" for distinct id "user-123" as true
    And no local feature flag definition is loaded for "deleted-flag"
    And the clean remote response omitting "deleted-flag" is delayed
    When evaluate flags is started concurrently for distinct ids "user-123" and "user-456" with flag key "deleted-flag"
    Then exactly one remote feature flag evaluation request should be in flight
    When the delayed remote feature flag evaluation response is released
    Then both evaluation snapshots should not contain "deleted-flag"
    And exactly one remote feature flag evaluation request should have been sent

  @server
  Scenario: A remotely returned key is evaluated for each identity
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario Outline: A remotely returned key is evaluated for every distinct context
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: A remotely returned key is evaluated separately for each supported device id
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: Unrelated missing-key probes are not serialized
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    Given no local feature flag definitions are loaded for "missing-a" and "missing-b"
    And remote feature flag evaluation responses for "missing-a" and "missing-b" are delayed
    When evaluate flags is started concurrently for disjoint scopes containing "missing-a" and "missing-b"
    Then two remote feature flag evaluation requests should be in flight before either response is released

  @server
  Scenario: Mixed missing-key scope waits for its overlapping probe
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: Positive remote evidence clears an earlier retained omission
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: Delayed non-owned omission cannot overwrite newer positive evidence
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: Request-time keys scope locally evaluated snapshot results
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: Request-time keys scope evaluated results loaded from cache
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
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

  @server
  Scenario: Local-only evaluation never falls back remotely
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    Given local feature flag definitions resolve "beta-ui" for distinct id "user-123" as true
    And local feature flag definitions cannot resolve "checkout" for distinct id "user-123"
    When evaluate flags is called for distinct id "user-123" with local-only evaluation enabled
    Then the snapshot should contain "beta-ui" with value true
    And the snapshot should not contain "checkout"
    And no remote feature flag evaluation request should have been sent

  @server
  Scenario: Remote failure preserves successfully resolved local flags
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    Given local feature flag definitions resolve "beta-ui" for distinct id "user-123" as true
    And local feature flag definitions cannot resolve "checkout" for distinct id "user-123"
    And the next remote feature flag evaluation request fails
    When evaluate flags is called for distinct id "user-123"
    Then the snapshot should contain "beta-ui" with value true
    And the snapshot should not contain "checkout"
    When snapshot enablement is read for "beta-ui"
    Then no additional remote feature flag evaluation request should have been sent

  @server
  Scenario: Missing identity returns an empty no-op snapshot
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    Given request context has no distinct id
    When evaluate flags is called without an explicit distinct id
    Then the returned evaluation snapshot should be empty
    And no remote feature flag evaluation request should have been sent
    When snapshot enablement is read for "beta-ui"
    Then the returned enabled value for "beta-ui" should be false
    And no event named "$feature_flag_called" should be enqueued

  @evaluation_runtime_capable
  @server
  Scenario: Runtime filter is a silent lookup of the local definition
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    Given local feature flag definitions resolve "client-flag" for distinct id "user-123" as true
    And the local feature flag definition for "client-flag" reports evaluation runtime "client"
    And local feature flag definitions resolve "legacy-flag" for distinct id "user-123" as true
    And the local feature flag definition for "legacy-flag" reports no evaluation runtime
    When evaluate flags is called for distinct id "user-123"
    And the snapshot is filtered to evaluation runtime "client"
    Then the filtered snapshot should contain "client-flag" with value true
    And the filtered snapshot should not contain "legacy-flag"
    And no remote feature flag evaluation request should have been sent
    And no event named "$feature_flag_called" should be enqueued
    And snapshot only accessed should return no flags

  @evaluation_runtime_capable
  @server
  Scenario: Remote fallback keeps the local definition's runtime
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    Given local feature flag definitions cannot resolve "gated-flag" for distinct id "user-123"
    And the local feature flag definition for "gated-flag" reports evaluation runtime "all"
    And remote feature flag evaluation for distinct id "user-123" returns:
      | key        | value |
      | gated-flag | true  |
    When evaluate flags is called for distinct id "user-123"
    And the snapshot is filtered to evaluation runtime "all"
    Then the snapshot should contain "gated-flag" with value true
    And the filtered snapshot should contain "gated-flag" with value true

  @evaluation_runtime_capable
  @server
  Scenario: Flag without a local definition never matches a runtime
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    Given no local feature flag definition is loaded for "remote-only-flag"
    And remote feature flag evaluation for distinct id "user-123" returns:
      | key              | value |
      | remote-only-flag | true  |
    When evaluate flags is called for distinct id "user-123"
    And the snapshot is filtered to evaluation runtimes "client", "all" and "server"
    Then the snapshot should contain "remote-only-flag" with value true
    And the filtered snapshot should not contain "remote-only-flag"

  @evaluation_runtime_capable
  @server
  Scenario: Runtime filter keeps the requested runtimes and drops unknown ones
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"
    Given local feature flag definitions resolve for distinct id "user-123":
      | key         | value |
      | client-flag | true  |
      | all-flag    | true  |
      | server-flag | true  |
      | legacy-flag | true  |
    And the local feature flag definition for "client-flag" reports evaluation runtime "client"
    And the local feature flag definition for "all-flag" reports evaluation runtime "all"
    And the local feature flag definition for "server-flag" reports evaluation runtime "server"
    And the local feature flag definition for "legacy-flag" reports no evaluation runtime
    When evaluate flags is called for distinct id "user-123"
    And the snapshot is filtered to evaluation runtimes "client" and "all"
    Then the filtered snapshot should contain flags:
      | key         | value |
      | client-flag | true  |
      | all-flag    | true  |
    And the filtered snapshot should not contain "server-flag"
    And the filtered snapshot should not contain "legacy-flag"
    And no remote feature flag evaluation request should have been sent
    And no event named "$feature_flag_called" should be enqueued
    And snapshot only accessed should return no flags

  @sdk:server
  Scenario: Server snapshot reads share one evaluation and deduplicate exposure
    Given an isolated SDK instance
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"snapshot-user":{"beta-ui":{"value":true},"checkout":{"value":"control"}}}}
      """
    And the snapshot SDK is initialized with JSON configuration:
      """application/json
      {}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"snapshot-user","options":{"only_evaluate_locally":false},"reads":[{"method":"is_enabled","key":"beta-ui"},{"method":"get_flag","key":"beta-ui"},{"method":"get_flag","key":"checkout"},{"method":"is_enabled","key":"checkout"},{"method":"get_flag","key":"checkout"}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"value":true},{"value":true},{"value":"control"},{"value":true},{"value":"control"}]}
      """
    When pending captures are flushed
    Then the flushed snapshot traffic should be:
      """application/json
      {"requests":[{"token":"test-token","distinct_id":"snapshot-user"}],"exposures":[{"distinct_id":"snapshot-user","key":"beta-ui","value":true},{"distinct_id":"snapshot-user","key":"checkout","value":"control"}]}
      """

  @sdk:server
  Scenario: Server snapshot projections distinguish disabled variant and missing flags
    Given an isolated SDK instance
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"snapshot-user":{"disabled":{"value":false},"checkout":{"value":"control"}}}}
      """
    And the snapshot SDK is initialized with JSON configuration:
      """application/json
      {}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"snapshot-user","options":{"only_evaluate_locally":false},"reads":[{"method":"is_enabled","key":"disabled"},{"method":"get_flag","key":"disabled"},{"method":"is_enabled","key":"checkout"},{"method":"get_flag","key":"checkout"},{"method":"is_enabled","key":"missing"},{"method":"get_flag","key":"missing"}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"value":false},{"value":false},{"value":true},{"value":"control"},{"value":false},{"missing":true}]}
      """
    When pending captures are flushed
    Then the flushed snapshot traffic should be:
      """application/json
      {"requests":[{"token":"test-token","distinct_id":"snapshot-user"}],"exposures":[{"distinct_id":"snapshot-user","key":"disabled","value":false},{"distinct_id":"snapshot-user","key":"checkout","value":"control"},{"distinct_id":"snapshot-user","key":"missing","missing":true}]}
      """

  @sdk:server
  Scenario: Server snapshot evaluation without reads delivers no exposure
    Given an isolated SDK instance
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"snapshot-user":{"checkout":{"value":"control"}}}}
      """
    And the snapshot SDK is initialized with JSON configuration:
      """application/json
      {}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"snapshot-user","options":{"only_evaluate_locally":false},"reads":[]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[]}
      """
    When pending captures are flushed
    Then the flushed snapshot traffic should be:
      """application/json
      {"requests":[{"token":"test-token","distinct_id":"snapshot-user"}],"exposures":[]}
      """

  @sdk:server
  Scenario: Server snapshot payload reads are silent and retain JSON semantics
    Given an isolated SDK instance
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"snapshot-user":{"checkout":{"value":"control","payload":{"copy":"new","enabled":false,"attempt":0,"context":{"codes":[1,2],"success":false}}},"no-payload":{"value":true}}}}
      """
    And the snapshot SDK is initialized with JSON configuration:
      """application/json
      {}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"snapshot-user","options":{"only_evaluate_locally":false},"reads":[{"method":"get_flag_payload","key":"checkout"},{"method":"get_flag_payload","key":"checkout"},{"method":"get_flag_payload","key":"no-payload"},{"method":"get_flag_payload","key":"missing"}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"payload":{"copy":"new","enabled":false,"attempt":0,"context":{"codes":[1,2],"success":false}}},{"payload":{"copy":"new","enabled":false,"attempt":0,"context":{"codes":[1,2],"success":false}}},{"missing":true},{"missing":true}]}
      """
    When pending captures are flushed
    Then the flushed snapshot traffic should be:
      """application/json
      {"requests":[{"token":"test-token","distinct_id":"snapshot-user"}],"exposures":[]}
      """

  @sdk:server
  @case:server_snapshot_payload_<case_id>
  Scenario Outline: Server snapshot scalar payload reads preserve type and decoding boundaries
    Given an isolated SDK instance
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"snapshot-user":{"checkout":{"value":"control","payload":<payload>}}}}
      """
    And the snapshot SDK is initialized with JSON configuration:
      """application/json
      {}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"snapshot-user","options":{"only_evaluate_locally":false},"reads":[{"method":"get_flag_payload","key":"checkout"}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"payload":<payload>}]}
      """
    When pending captures are flushed
    Then the flushed snapshot traffic should be:
      """application/json
      {"requests":[{"token":"test-token","distinct_id":"snapshot-user"}],"exposures":[]}
      """

    Examples:
      | case_id | payload |
      | false | false |
      | zero | 0 |
      | null | null |
      | string | "hello" |
      | json_looking_string | "{\"copy\":\"new\"}" |

  @sdk:server
  Scenario: Server snapshot independent requests retain identity and group context
    Given an isolated SDK instance
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"snapshot-user-a":{"checkout":{"value":"control"}},"snapshot-user-b":{"checkout":{"value":"control"}}}}
      """
    And the snapshot SDK is initialized with JSON configuration:
      """application/json
      {}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"snapshot-user-a","options":{"groups":{"organization":"org-a"},"only_evaluate_locally":false},"reads":[{"method":"get_flag","key":"checkout"}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"value":"control"}]}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"snapshot-user-b","options":{"groups":{"organization":"org-b"},"only_evaluate_locally":false},"reads":[{"method":"get_flag","key":"checkout"}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"value":"control"}]}
      """
    When pending captures are flushed
    Then the flushed snapshot traffic should be:
      """application/json
      {"requests":[{"token":"test-token","distinct_id":"snapshot-user-a","groups":{"organization":"org-a"}},{"token":"test-token","distinct_id":"snapshot-user-b","groups":{"organization":"org-b"}}],"exposures":[{"distinct_id":"snapshot-user-a","key":"checkout","value":"control","groups":{"organization":"org-a"}},{"distinct_id":"snapshot-user-b","key":"checkout","value":"control","groups":{"organization":"org-b"}}]}
      """

  @sdk:server
  Scenario: Server snapshot forwards explicit evaluation context
    Given an isolated SDK instance
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"snapshot-user":{"beta-ui":{"value":true}}}}
      """
    And the snapshot SDK is initialized with JSON configuration:
      """application/json
      {}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"snapshot-user","options":{"groups":{"organization":"acme"},"person_properties":{"plan":"free","retryable":false,"attempt":0,"context":{"codes":[1,2]}},"group_properties":{"organization":{"tier":"team","active":false}},"disable_geoip":true,"only_evaluate_locally":false},"reads":[{"method":"get_flag","key":"beta-ui"}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"value":true}]}
      """
    When pending captures are flushed
    Then the flushed snapshot traffic should be:
      """application/json
      {"requests":[{"token":"test-token","distinct_id":"snapshot-user","groups":{"organization":"acme"},"person_properties":{"plan":"free","retryable":false,"attempt":0,"context":{"codes":[1,2]}},"group_properties":{"organization":{"tier":"team","active":false}},"geoip_disable":true}],"exposures":[{"distinct_id":"snapshot-user","key":"beta-ui","value":true,"groups":{"organization":"acme"}}]}
      """

  @sdk:server
  Scenario: Server snapshot request-time key scope and enumeration stay silent
    Given an isolated SDK instance
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"snapshot-user":{"beta-ui":{"value":true},"checkout":{"value":"control","payload":{"copy":"new"}},"search":{"value":false}}}}
      """
    And the snapshot SDK is initialized with JSON configuration:
      """application/json
      {}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"snapshot-user","options":{"flag_keys":["beta-ui","checkout"],"only_evaluate_locally":false},"reads":[{"method":"keys"},{"method":"get_flag_payload","key":"checkout"}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"keys":["beta-ui","checkout"]},{"payload":{"copy":"new"}}]}
      """
    When pending captures are flushed
    Then the flushed snapshot traffic should be:
      """application/json
      {"requests":[{"token":"test-token","distinct_id":"snapshot-user","flag_keys_to_evaluate":["beta-ui","checkout"]}],"exposures":[]}
      """

  @sdk:server
  Scenario: Server snapshot empty request-time keys make no evaluation request
    Given an isolated SDK instance
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"snapshot-user":{"checkout":{"value":"control"}}}}
      """
    And the snapshot SDK is initialized with JSON configuration:
      """application/json
      {}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"snapshot-user","options":{"flag_keys":[]},"reads":[{"method":"keys"}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"keys":[]}]}
      """
    When pending captures are flushed
    Then the flushed snapshot traffic should be:
      """application/json
      {"requests":[],"exposures":[]}
      """

  @sdk:server
  Scenario: Server snapshot explicit-key filters preserve the original and stay silent
    Given an isolated SDK instance
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"snapshot-user":{"beta-ui":{"value":true},"checkout":{"value":"control","payload":{"copy":"new"}},"search":{"value":false}}}}
      """
    And the snapshot SDK is initialized with JSON configuration:
      """application/json
      {}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"snapshot-user","options":{"only_evaluate_locally":false},"reads":[{"method":"keys"},{"method":"get_flag_payload","key":"checkout"},{"method":"only","keys":["checkout","checkout","missing"],"reads":[{"method":"keys"},{"method":"get_flag_payload","key":"checkout"}]},{"method":"only","keys":[],"reads":[{"method":"keys"}]},{"method":"keys"},{"method":"get_flag_payload","key":"checkout"}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"keys":["beta-ui","checkout","search"]},{"payload":{"copy":"new"}},{"results":[{"keys":["checkout"]},{"payload":{"copy":"new"}}]},{"results":[{"keys":[]}]},{"keys":["beta-ui","checkout","search"]},{"payload":{"copy":"new"}}]}
      """
    When pending captures are flushed
    Then the flushed snapshot traffic should be:
      """application/json
      {"requests":[{"token":"test-token","distinct_id":"snapshot-user"}],"exposures":[]}
      """

  @sdk:server
  Scenario: Server snapshot filtered values retain decisions and share exposure dedupe
    Given an isolated SDK instance
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"snapshot-user":{"beta-ui":{"value":true},"checkout":{"value":"control","payload":{"copy":"new"}}}}}
      """
    And the snapshot SDK is initialized with JSON configuration:
      """application/json
      {}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"snapshot-user","options":{"only_evaluate_locally":false},"reads":[{"method":"only","keys":["checkout"],"reads":[{"method":"keys"},{"method":"is_enabled","key":"checkout"},{"method":"get_flag","key":"checkout"},{"method":"get_flag_payload","key":"checkout"}]},{"method":"get_flag","key":"checkout"},{"method":"get_flag","key":"beta-ui"},{"method":"keys"}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"results":[{"keys":["checkout"]},{"value":true},{"value":"control"},{"payload":{"copy":"new"}}]},{"value":"control"},{"value":true},{"keys":["beta-ui","checkout"]}]}
      """
    When pending captures are flushed
    Then the flushed snapshot traffic should be:
      """application/json
      {"requests":[{"token":"test-token","distinct_id":"snapshot-user"}],"exposures":[{"distinct_id":"snapshot-user","key":"checkout","value":"control"},{"distinct_id":"snapshot-user","key":"beta-ui","value":true}]}
      """

  @sdk:server
  Scenario: Server snapshot accessed-key filtering before value use is empty and silent
    Given an isolated SDK instance
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"snapshot-user":{"beta-ui":{"value":true},"checkout":{"value":"control","payload":{"copy":"new"}}}}}
      """
    And the snapshot SDK is initialized with JSON configuration:
      """application/json
      {}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"snapshot-user","options":{"only_evaluate_locally":false},"reads":[{"method":"only_accessed","reads":[{"method":"keys"}]},{"method":"get_flag_payload","key":"checkout"},{"method":"keys"},{"method":"only_accessed","reads":[{"method":"keys"}]}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"results":[{"keys":[]}]},{"payload":{"copy":"new"}},{"keys":["beta-ui","checkout"]},{"results":[{"keys":[]}]}]}
      """
    When pending captures are flushed
    Then the flushed snapshot traffic should be:
      """application/json
      {"requests":[{"token":"test-token","distinct_id":"snapshot-user"}],"exposures":[]}
      """

  @sdk:server
  Scenario: Server snapshot accessed-key filtering selects used flags without parent leakage
    Given an isolated SDK instance
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"snapshot-user":{"beta-ui":{"value":true},"checkout":{"value":"control","payload":{"copy":"new"}},"search":{"value":false}}}}
      """
    And the snapshot SDK is initialized with JSON configuration:
      """application/json
      {}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"snapshot-user","options":{"only_evaluate_locally":false},"reads":[{"method":"get_flag_payload","key":"checkout"},{"method":"keys"},{"method":"is_enabled","key":"beta-ui"},{"method":"get_flag","key":"search"},{"method":"get_flag","key":"missing"},{"method":"only_accessed","reads":[{"method":"keys"}]},{"method":"only","keys":["checkout"],"reads":[{"method":"get_flag","key":"checkout"},{"method":"only_accessed","reads":[{"method":"keys"}]}]},{"method":"only_accessed","reads":[{"method":"keys"}]}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"payload":{"copy":"new"}},{"keys":["beta-ui","checkout","search"]},{"value":true},{"value":false},{"missing":true},{"results":[{"keys":["beta-ui","search"]}]},{"results":[{"value":"control"},{"results":[{"keys":["checkout"]}]}]},{"results":[{"keys":["beta-ui","search"]}]}]}
      """
    When pending captures are flushed
    Then the flushed snapshot traffic should be:
      """application/json
      {"requests":[{"token":"test-token","distinct_id":"snapshot-user"}],"exposures":[{"distinct_id":"snapshot-user","key":"beta-ui","value":true},{"distinct_id":"snapshot-user","key":"search","value":false},{"distinct_id":"snapshot-user","key":"missing","missing":true},{"distinct_id":"snapshot-user","key":"checkout","value":"control"}]}
      """

  @sdk:server @requires:flag_snapshot_enablement_default
  Scenario: Server snapshot supported caller defaults affect only missing enablement
    Given an isolated SDK instance
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"snapshot-user":{"beta-ui":{"value":true},"disabled":{"value":false},"checkout":{"value":"control"}}}}
      """
    And the snapshot SDK is initialized with JSON configuration:
      """application/json
      {}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"snapshot-user","options":{"only_evaluate_locally":false},"reads":[{"method":"is_enabled","key":"missing"},{"method":"is_enabled","key":"missing","options":{"default_value":false}},{"method":"is_enabled","key":"missing","options":{"default_value":true}},{"method":"is_enabled","key":"disabled","options":{"default_value":true}},{"method":"is_enabled","key":"beta-ui","options":{"default_value":false}},{"method":"is_enabled","key":"checkout","options":{"default_value":false}},{"method":"get_flag","key":"missing"}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"value":false},{"value":false},{"value":true},{"value":false},{"value":true},{"value":true},{"missing":true}]}
      """
    When pending captures are flushed
    Then the flushed snapshot traffic should be:
      """application/json
      {"requests":[{"token":"test-token","distinct_id":"snapshot-user"}],"exposures":[{"distinct_id":"snapshot-user","key":"missing","missing":true},{"distinct_id":"snapshot-user","key":"disabled","value":false},{"distinct_id":"snapshot-user","key":"beta-ui","value":true},{"distinct_id":"snapshot-user","key":"checkout","value":"control"}]}
      """

  @sdk:server
  Scenario: Server snapshot missing identity returns safe empty results without traffic
    Given an isolated SDK instance
    And remote snapshot fixtures are:
      """application/json
      {"identities":{}}
      """
    And the snapshot SDK is initialized with JSON configuration:
      """application/json
      {}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"reads":[{"method":"keys"},{"method":"is_enabled","key":"checkout"},{"method":"get_flag","key":"checkout"},{"method":"get_flag_payload","key":"checkout"},{"method":"only","keys":["checkout"],"reads":[{"method":"keys"}]},{"method":"only_accessed","reads":[{"method":"keys"}]}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"keys":[]},{"value":false},{"missing":true},{"missing":true},{"results":[{"keys":[]}]},{"results":[{"keys":[]}]}]}
      """
    When pending captures are flushed
    Then the flushed snapshot traffic should be:
      """application/json
      {"requests":[],"exposures":[]}
      """

  @sdk:server
  Scenario: Server snapshot disabled SDK returns safe empty results without traffic
    Given an isolated SDK instance
    And remote snapshot fixtures are:
      """application/json
      {"identities":{"snapshot-user":{"checkout":{"value":"control"}}}}
      """
    And the snapshot SDK is initialized with JSON configuration:
      """application/json
      {"disabled":true}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"snapshot-user","reads":[{"method":"keys"},{"method":"is_enabled","key":"checkout"},{"method":"get_flag","key":"checkout"},{"method":"get_flag_payload","key":"checkout"},{"method":"only","keys":["checkout"],"reads":[{"method":"keys"}]},{"method":"only_accessed","reads":[{"method":"keys"}]}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"keys":[]},{"value":false},{"missing":true},{"missing":true},{"results":[{"keys":[]}]},{"results":[{"keys":[]}]}]}
      """
    When pending captures are flushed
    Then the flushed snapshot traffic should be:
      """application/json
      {"requests":[],"exposures":[]}
      """

  @sdk:server
  Scenario: Server snapshot remote failure retains safe reads without accessor retries
    Given an isolated SDK instance
    And remote snapshot fixtures are:
      """application/json
      {"identities":{},"status":503}
      """
    And the snapshot SDK is initialized with JSON configuration:
      """application/json
      {"feature_flags_request_max_retries":0}
      """
    When evaluate flags and read is called with JSON arguments:
      """application/json
      {"distinct_id":"snapshot-user","options":{"only_evaluate_locally":false},"reads":[{"method":"keys"},{"method":"is_enabled","key":"checkout"},{"method":"get_flag","key":"checkout"},{"method":"get_flag_payload","key":"checkout"},{"method":"only","keys":["checkout"],"reads":[{"method":"keys"}]},{"method":"only_accessed","reads":[{"method":"keys"}]}]}
      """
    Then the public snapshot outcomes should have these semantics:
      """application/json
      {"results":[{"keys":[]},{"value":false},{"missing":true},{"missing":true},{"results":[{"keys":[]}]},{"results":[{"keys":[]}]}]}
      """
    When pending captures are flushed
    Then the flushed snapshot traffic should be:
      """application/json
      {"requests":[{"token":"test-token","distinct_id":"snapshot-user","status":503}],"exposures":[{"distinct_id":"snapshot-user","key":"checkout","missing":true}]}
      """
