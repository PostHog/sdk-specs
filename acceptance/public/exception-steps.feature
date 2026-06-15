@public @canonical_behavior @acceptance @exception_steps @client
Feature: Exception Steps
  Acceptance tests for the canonical exception-steps behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @client
  Scenario: Buffered steps attach to the next captured exception in order
    Given the SDK is initialized with token "test-token"
    When add exception step is called with message "step A"
    And add exception step is called with message "step B"
    And add exception step is called with message "step C"
    And capture exception is called for an exception with type "TypeError" and message "boom"
    Then one event named "$exception" should be enqueued
    And the enqueued event property "$exception_steps" should be an ordered array of steps with messages:
      | $message |
      | step A   |
      | step B   |
      | step C   |

  @client
  Scenario: Each step records a call-time timestamp and user properties
    Given the SDK is initialized with token "test-token"
    When add exception step is called with message "User tapped Checkout" and properties:
      | property | value |
      | screen   | cart  |
    And capture exception is called for an exception with type "TypeError" and message "boom"
    Then the enqueued exception step with message "User tapped Checkout" should include:
      | property   | value                |
      | $timestamp | 2025-01-01T00:00:00Z |
      | screen     | cart                 |

  @client
  Scenario: Reserved keys in step properties are stripped
    Given the SDK is initialized with token "test-token"
    When add exception step is called with message "real message" and properties:
      | property   | value          |
      | $message   | spoofed        |
      | $timestamp | 1999-01-01     |
      | screen     | cart           |
    And capture exception is called for an exception with type "TypeError" and message "boom"
    Then the enqueued exception step with message "real message" should include property "screen" with value "cart"
    And the enqueued exception step should not include user-supplied "$message" or "$timestamp" values
    And a warning should be logged about reserved step keys

  @client
  Scenario: Caller-supplied exception steps are not overwritten
    Given the SDK is initialized with token "test-token"
    When add exception step is called with message "buffered step"
    And capture exception is called with a caller-supplied "$exception_steps" property
    Then the enqueued event property "$exception_steps" should equal the caller-supplied value

  @client
  Scenario: Buffered steps persist across captures
    Given the SDK is initialized with token "test-token"
    When add exception step is called with message "step A"
    And capture exception is called for an exception with type "TypeError" and message "first"
    And add exception step is called with message "step B"
    And capture exception is called for an exception with type "TypeError" and message "second"
    Then the first enqueued "$exception" event should include an exception step with message "step A"
    And the second enqueued "$exception" event should be an ordered array of steps with messages:
      | $message |
      | step A   |
      | step B   |

  @client
  Scenario: Capture does not consume the buffer when an exception is dropped
    Given the SDK is initialized with token "test-token"
    When add exception step is called with message "kept step"
    And an exception is captured but dropped before being sent
    And capture exception is called for an exception with type "TypeError" and message "later"
    Then the enqueued "$exception" event should include an exception step with message "kept step"

  @client
  Scenario: A user identity change does not clear the buffer
    Given the SDK is initialized with token "test-token"
    When add exception step is called with message "before identity change"
    And the current user identity is changed via reset
    And capture exception is called for an exception with type "TypeError" and message "boom"
    Then the enqueued "$exception" event should include an exception step with message "before identity change"

  @client
  Scenario: Steps are cleared on a clean launch
    Given the SDK is initialized with token "test-token"
    When add exception step is called with message "previous run step"
    And the SDK is closed
    And the SDK is launched cleanly with no pending crash report
    And capture exception is called for an exception with type "TypeError" and message "boom"
    Then the enqueued "$exception" event should not include property "$exception_steps"

  @client
  Scenario: Oldest steps are evicted when the byte budget is exceeded
    Given the SDK is initialized with token "test-token" and exception steps max bytes set to a small budget
    When add exception step is called repeatedly until the cumulative step size exceeds the budget
    And capture exception is called for an exception with type "TypeError" and message "boom"
    Then the enqueued event property "$exception_steps" should contain only the newest steps within the byte budget
    And the oldest steps should have been evicted first

  @client
  Scenario: A single oversized step is rejected and existing steps are retained
    Given the SDK is initialized with token "test-token" and exception steps max bytes set to a small budget
    When add exception step is called with message "small step"
    And add exception step is called with a single step larger than the byte budget
    And capture exception is called for an exception with type "TypeError" and message "boom"
    Then the enqueued event property "$exception_steps" should be an ordered array of steps with messages:
      | $message   |
      | small step |

  @client
  Scenario: Empty or invalid step message is ignored
    Given the SDK is initialized with token "test-token"
    When add exception step is called with an empty message
    Then the call should not throw
    And a warning should be logged about an invalid step message
    When capture exception is called for an exception with type "TypeError" and message "boom"
    Then the enqueued "$exception" event should not include property "$exception_steps"

  @client
  Scenario: Disabled exception steps are a no-op
    Given the SDK is initialized with token "test-token" and exception steps disabled
    When add exception step is called with message "step A"
    And capture exception is called for an exception with type "TypeError" and message "boom"
    Then the enqueued "$exception" event should not include property "$exception_steps"

  @client
  Scenario: Steps survive a fatal crash on SDKs that report crashes on next launch
    Given the SDK captures fatal crashes by reporting them on the next launch
    And the SDK is initialized with token "test-token"
    When add exception step is called with message "before crash"
    And the process dies from a fatal crash before any capture
    And the SDK is restarted
    Then the "$exception" event reported for the crash should include an exception step with message "before crash"
    And the persisted crash steps should be cleared once attached so the next launch starts empty
