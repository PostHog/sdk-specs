@private @canonical_behavior @acceptance @session_replay_trigger_groups @client
Feature: Session Replay Trigger Groups
  Acceptance tests for the canonical session replay trigger-group (version 2) behavior across
  PostHog SDKs. Trigger groups replace the flat V1 ingestion controls when the remote config
  carries `version: 2` and a non-empty `triggerGroups` array: each group combines its own legs,
  samples on its own rate, and carries its own minimum duration, and the session records when any
  activated group samples it in.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  # Version selection

  Scenario: Version 2 with groups ignores the V1 sample rate
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2 and a V1 sample rate of 0.0
    And the remote config configures a trigger group with a sample rate of 1.0 and no conditions
    When the SDK resolves whether to record the current session
    Then session recording should be active

  Scenario: Version 2 with an empty group list uses the V1 fields
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2 and an empty trigger group list
    And the remote config sets the recording sample rate to 0.0
    When the SDK resolves whether to record the current session
    Then session recording should not be active

  # Group activation

  Scenario: A group with no conditions records at once
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2
    And the remote config configures a trigger group with a sample rate of 1.0 and no conditions
    When the SDK resolves whether to record the current session before any event is captured
    Then session recording should be active

  Scenario: An event leg activates its group
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2
    And the remote config configures a trigger group with event condition "checkout_started" and a sample rate of 1.0
    And session recording is not active because no trigger group has activated
    When the client captures an event named "checkout_started"
    Then session recording should be active

  Scenario: An event leg with failing property filters does not activate
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2
    And the remote config configures a trigger group with event condition "purchase" filtered on event property "amount" greater than 100 and a sample rate of 1.0
    When the client captures an event named "purchase" with property "amount" set to 50
    Then session recording should not be active
    When the client captures an event named "purchase" with property "amount" set to 200
    Then session recording should be active

  Scenario: Same-name event entries are a disjunction
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2
    And the remote config configures a trigger group with two event conditions named "purchase", one filtered on event property "amount" greater than 100 and one filtered on person property "plan" equal to "vip", and a sample rate of 1.0
    And the current person has property "plan" set to "vip"
    When the client captures an event named "purchase" with property "amount" set to 50
    Then session recording should be active

  # Match type within a group

  Scenario: A group with match type all needs every configured leg
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2
    And the remote config configures a trigger group with match type "all", event condition "error", boolean flag condition "replay-flag", and a sample rate of 1.0
    And feature flag "replay-flag" is not enabled for the user
    When the client captures an event named "error"
    Then session recording should not be active
    When feature flag "replay-flag" becomes enabled for the user
    Then session recording should be active

  Scenario: A group with match type any needs one leg
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2
    And the remote config configures a trigger group with match type "any", event condition "error", boolean flag condition "replay-flag", and a sample rate of 1.0
    And feature flag "replay-flag" is not enabled for the user
    When the client captures an event named "error"
    Then session recording should be active

  # Union across groups

  Scenario: One activated group sampled in records
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2
    And the remote config configures a trigger group "A" with event condition "$exception" and a sample rate of 0.0
    And the remote config configures a trigger group "B" with event condition "$pageview" and a sample rate of 1.0
    When the client captures an event named "$exception"
    Then session recording should not be active
    When the client captures an event named "$pageview"
    Then session recording should be active

  Scenario: Every activated group sampled out does not record
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2
    And the remote config configures a trigger group "A" with a sample rate of 0.0 and no conditions
    And the remote config configures a trigger group "B" with a sample rate of 0.0 and no conditions
    When the SDK resolves whether to record the current session
    Then session recording should not be active

  # Sample rate coercion

  Scenario Outline: A blank-string group rate samples out; an unparseable one samples in
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2
    And the remote config configures a trigger group with no conditions and the raw sample rate <rate>
    When the SDK resolves whether to record the current session
    Then session recording should be <state>

    Examples:
      | rate             | state      |
      | ""               | not active |
      | " 1.0 "          | active     |
      | "not-a-number"   | active     |
      | null             | not active |

  # Effective minimum duration

  Scenario: The lowest minimum among activated groups applies
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2
    And the remote config configures a trigger group "A" with no conditions, a sample rate of 1.0, and a minimum duration of 5000 milliseconds
    And the remote config configures a trigger group "B" with no conditions, a sample rate of 0.0, and a minimum duration of 2000 milliseconds
    When the session's captured activity reaches 2000 milliseconds
    Then the buffered replay data should be emitted

  Scenario: Held data ships when a second group lowers the minimum
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2
    And the remote config configures a trigger group "A" with no conditions, a sample rate of 1.0, and a minimum duration of 10000 milliseconds
    And the remote config configures a trigger group "B" with event condition "$exception", a sample rate of 1.0, and a minimum duration of 1000 milliseconds
    And the session has captured 3000 milliseconds of activity and its replay data is held below the minimum duration
    When the client captures an event named "$exception"
    Then the held replay data should be emitted on the next flush

  # URL blocklist (URL-capable SDKs only)

  @url_capable
  Scenario: The URL blocklist pauses recording under trigger groups
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2
    And the remote config configures a trigger group with event condition "$pageview" and a sample rate of 1.0
    And the remote config configures a URL blocklist matching "/account"
    And the client has captured an event named "$pageview" and session recording is active
    When the current URL changes to one matching "/account"
    Then session recording should be paused
    When the current URL changes to one that does not match "/account"
    Then session recording should resume

  # Screen leg (mobile SDKs only)

  @mobile_screen
  Scenario: A screen leg activates on the screen name
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2
    And the remote config configures a trigger group with URL condition matching "Checkout" and a sample rate of 1.0
    And session recording is not active because no trigger group has activated
    When the client captures a "$screen" event with "$screen_name" set to "CheckoutScreen"
    Then session recording should be active

  # Group-level property filters

  Scenario: A group-level person filter gates a screen or URL activation and a positive event filter never matches it
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2
    And the remote config configures a trigger group "A" with URL condition matching "Checkout", a group-level filter on person property "plan" equal to "vip", and a sample rate of 1.0
    And the remote config configures a trigger group "B" with URL condition matching "Checkout", a group-level filter on event property "amount" greater than 100, and a sample rate of 1.0
    And the current person has property "plan" set to "free"
    When the current URL or screen name changes to one matching "Checkout"
    Then session recording should not be active
    When the current person's property "plan" changes to "vip" and the current URL or screen name changes to one matching "Checkout"
    Then session recording should be active
    And trigger group "B" should not be activated

  Scenario: A group-level filter gates an event activation
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2
    And the remote config configures a trigger group with event condition "$exception", a group-level filter on person property "plan" equal to "vip", and a sample rate of 1.0
    And the current person has property "plan" set to "free"
    When the client captures an event named "$exception"
    Then session recording should not be active
    When the current person's property "plan" changes to "vip" and the client captures an event named "$exception"
    Then session recording should be active

  # Session rotation

  Scenario: Activation is re-armed on a new session
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2
    And the remote config configures a trigger group with event condition "checkout_started" and a sample rate of 1.0
    And an event named "checkout_started" has activated the trigger group for the current session
    When the session id rotates to a new session
    Then session recording should not be active until the client captures "checkout_started" again

  # Interaction hold (SDKs that implement the unconfirmed-activity hold)

  Scenario: An event-leg trigger-group activation releases the interaction hold
    Given the SDK is initialized with token "test-token" and session replay enabled
    And the remote config sets the trigger configuration version to 2
    And the remote config configures a trigger group with event condition "$exception" and a sample rate of 1.0
    And the session id rotated because of an inactivity timeout and the rotated epoch's replay data is held with no confirmed user interaction
    When the client captures an event named "$exception"
    Then the held replay data should be released under the rotated session id
    And session recording should be active
