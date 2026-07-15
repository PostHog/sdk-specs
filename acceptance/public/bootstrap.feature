@public @canonical_behavior @acceptance @bootstrap @client
Feature: Bootstrap
  Acceptance tests for the canonical bootstrap behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Bootstrapped flags are readable immediately after setup
    Given the SDK is initialized with token "test-token" and bootstrap feature flags:
      | key     | value |
      | beta-ui | true  |
    When get feature flag "beta-ui" is called
    Then the returned feature flag value should be true
    And no feature flag network request should be sent

  Scenario: Bootstrapped payload is served with its flag
    Given the SDK is initialized with token "test-token" and bootstrap feature flags:
      | key     | value     | payload          |
      | beta-ui | variant-a | {"color":"blue"} |
    When get feature flag "beta-ui" is called
    Then the returned feature flag value should be "variant-a"
    And the returned feature flag payload for "beta-ui" should be {"color":"blue"}

  Scenario: Bootstrap snapshot takes precedence over persisted flags
    Given persistent storage contains feature flags:
      | key      | value |
      | checkout | false |
    When setup is called with token "test-token" and bootstrap feature flags:
      | key      | value |
      | checkout | true  |
    And get feature flag "checkout" is called
    Then the returned feature flag value should be true

  Scenario: Bootstrapped identity seeds a fresh install
    Given persistent storage is empty
    When setup is called with token "test-token" and bootstrap distinct id "anon-abc"
    Then get anonymous id should return "anon-abc"
    And the current user should be anonymous

  Scenario: Bootstrapped identity is ignored when identity already persisted
    Given persistent storage contains anonymous id "existing-anon"
    When setup is called with token "test-token" and bootstrap distinct id "anon-abc"
    Then get anonymous id should return "existing-anon"

  Scenario: Identified bootstrap marks the user identified
    Given persistent storage is empty
    When setup is called with token "test-token" and bootstrap identified distinct id "user-123"
    Then get distinct id should return "user-123"
    And the current user should be identified

  Scenario: Identified bootstrap does not become the device id
    Given persistent storage is empty
    When setup is called with token "test-token" and bootstrap identified distinct id "user-123"
    Then get distinct id should return "user-123"
    And the device id should not equal "user-123"

  Scenario: Identified bootstrap merges an anonymous local user
    Given persistent storage contains anonymous id "anon-abc"
    When setup is called with token "test-token" and bootstrap identified distinct id "user-123"
    Then get distinct id should return "user-123"
    And one event named "$identify" should be enqueued

  Scenario: Identified bootstrap preserves a different identified user
    Given persistent storage contains identified distinct id "user-existing"
    When setup is called with token "test-token" and bootstrap identified distinct id "user-123"
    Then get distinct id should return "user-existing"
    And a warning should be logged that the existing identity is preserved

  Scenario: Identified bootstrap upgrades a matching anonymous id to identified
    Given persistent storage contains anonymous id "user-123"
    When setup is called with token "test-token" and bootstrap identified distinct id "user-123"
    Then get distinct id should return "user-123"
    And the current user should be identified
    And no event named "$identify" should be enqueued

  Scenario: Identified bootstrap reconciles an anonymous user while opted out
    Given persistent storage contains opt-out state "true"
    And persistent storage contains anonymous id "anon-abc"
    When setup is called with token "test-token" and bootstrap identified distinct id "user-123"
    Then get distinct id should return "user-123"
    And the current user should be identified
    And no events should be enqueued

  Scenario: A complete flags response overrides the bootstrapped value
    Given the SDK is initialized with token "test-token" and bootstrap feature flags:
      | key     | value |
      | beta-ui | true  |
    When feature flags are loaded with values:
      | key     | value |
      | beta-ui | false |
    And get feature flag "beta-ui" is called
    Then the returned feature flag value should be false

  Scenario: A complete flags load drops bootstrapped-only keys
    Given the SDK is initialized with token "test-token" and bootstrap feature flags:
      | key     | value |
      | beta-ui | true  |
      | legacy  | true  |
    When feature flags are loaded with values:
      | key     | value |
      | beta-ui | false |
    And get feature flag "legacy" is called
    Then the returned feature flag value should not be true

  Scenario: A complete flags load replaces the bootstrapped payload
    Given the SDK is initialized with token "test-token" and bootstrap feature flags:
      | key     | value     | payload          |
      | beta-ui | variant-a | {"color":"blue"} |
    When feature flags are loaded with values:
      | key     | value     |
      | beta-ui | variant-b |
    And get feature flag "beta-ui" is called
    Then the returned feature flag value should be "variant-b"
    And the returned feature flag payload for "beta-ui" should be null

  Scenario: A partial or errored response preserves un-recomputed flags
    Given the SDK is initialized with token "test-token" and bootstrap feature flags:
      | key     | value |
      | beta-ui | true  |
      | legacy  | true  |
    When feature flags are loaded with errors while computing and values:
      | key     | value |
      | beta-ui | false |
    And get feature flag "legacy" is called
    Then the returned feature flag value should be true

  Scenario: Bootstrapped flags are not resurrected after reset
    Given the SDK is initialized with token "test-token" and bootstrap feature flags:
      | key    | value |
      | legacy | true  |
    And feature flags are loaded with values:
      | key     | value |
      | beta-ui | true  |
    When reset is called
    And feature flags are loaded with values:
      | key     | value |
      | beta-ui | true  |
    And get feature flag "legacy" is called
    Then the returned feature flag value should not be true

  Scenario: Flag call before the first flags response reports bootstrap use
    Given the SDK is initialized with token "test-token" and bootstrap feature flags:
      | key     | value |
      | beta-ui | true  |
    When get feature flag "beta-ui" is called
    Then one event named "$feature_flag_called" should be enqueued
    And the enqueued event properties should include:
      | property                            | value   |
      | $feature_flag                       | beta-ui |
      | $feature_flag_bootstrapped_response | true    |
      | $used_bootstrap_value               | true    |

  Scenario: Flag call after a complete flags response reports bootstrap not used
    Given the SDK is initialized with token "test-token" and bootstrap feature flags:
      | key     | value |
      | beta-ui | true  |
    And feature flags are loaded with values:
      | key     | value |
      | beta-ui | true  |
    When get feature flag "beta-ui" is called
    Then one event named "$feature_flag_called" should be enqueued
    And the enqueued event properties should include:
      | property              | value |
      | $used_bootstrap_value | false |

  Scenario: Flag call after a partial or errored flags response reports bootstrap not used
    Given the SDK is initialized with token "test-token" and bootstrap feature flags:
      | key    | value |
      | legacy | true  |
    And feature flags are loaded with errors while computing and values:
      | key     | value |
      | beta-ui | false |
    When get feature flag "legacy" is called
    Then one event named "$feature_flag_called" should be enqueued
    And the enqueued event properties should include:
      | property              | value |
      | $used_bootstrap_value | false |

  Scenario: Valid bootstrapped session id continues the session
    Given the SDK is initialized with token "test-token" and bootstrap session id "01900000-0000-7000-8000-000000000000"
    When get session id is called
    Then the returned session id should equal "01900000-0000-7000-8000-000000000000"

  Scenario: Invalid bootstrapped session id falls back to a generated id
    Given the SDK is initialized with token "test-token" and bootstrap session id "not-a-uuid"
    When get session id is called
    Then an error should be logged
    And the returned session id should not equal "not-a-uuid"
    And the returned session id should be a non-empty value
