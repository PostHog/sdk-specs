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

  Scenario: Missing requested local definition triggers scoped remote fallback
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
