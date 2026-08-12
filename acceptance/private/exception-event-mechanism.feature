@private @canonical_behavior @acceptance @exception_event_mechanism @both
Feature: Exception Event Mechanism
  Acceptance tests for canonical mechanism metadata on SDK-generated exception events.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"

  Scenario: Manual capture emits generic handled error metadata
    When capture exception is called for a caught exception without explicit overrides
    Then one event named "$exception" should be enqueued
    And the enqueued event property "$exception_level" should equal "error"
    And the outermost exception should have "mechanism.type" equal to "generic"
    And the outermost exception should have "mechanism.handled" equal to true

  Scenario: An automatic integration preserves all common mechanism metadata
    Given an automatic integration supplies mechanism type, handled state, source, and synthetic state
    When the integration captures an exception
    Then one event named "$exception" should be enqueued
    And the outermost exception mechanism should preserve all four supplied fields

  Scenario: A preserved runtime stack is not synthetic
    Given an actual runtime exception has a usable stack
    When capture exception is called for the exception
    Then the outermost exception should have "mechanism.synthetic" equal to false

  Scenario: A synthesized current stack is marked synthetic
    Given an exception-like input has no usable stack
    When the SDK synthesizes a current stack while capturing the input
    Then the outermost exception should have "mechanism.synthetic" equal to true

  Scenario: Logger capture normalizes severity and remains handled
    When a logger or console integration captures a "warn" record as an exception
    Then one event named "$exception" should be enqueued
    And the enqueued event property "$exception_level" should equal "warning"
    And the outermost exception should have "mechanism.handled" equal to true

  Scenario: A fatal logger call remains handled
    When a logger integration captures a "fatal" record without terminating the app or process
    Then one event named "$exception" should be enqueued
    And the enqueued event property "$exception_level" should equal "fatal"
    And the outermost exception should have "mechanism.handled" equal to true

  Scenario: A non-fatal uncaught boundary emits unhandled error metadata
    Given an automatic integration observes an uncaught exception without terminating the app or process
    When the integration captures the exception
    Then one event named "$exception" should be enqueued
    And the enqueued event property "$exception_level" should equal "error"
    And the outermost exception should have "mechanism.handled" equal to false

  Scenario: A terminating failure emits fatal unhandled metadata
    Given an automatic integration observes a crash, panic, or uncaught exception expected to terminate the app or process
    When the integration captures the failure
    Then one event named "$exception" should be enqueued
    And the enqueued event property "$exception_level" should equal "fatal"
    And the outermost exception should have "mechanism.handled" equal to false

  Scenario: A low-level producer preserves unknown metadata as absent
    Given a low-level exception payload producer has no capture-boundary context
    When the producer creates a "$exception" event without caller-supplied mechanism metadata
    Then the generated event should omit "$exception_level"
    And the generated exception mechanism should omit "type", "handled", "source", and "synthetic"
