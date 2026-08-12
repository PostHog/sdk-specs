@private @canonical_behavior @acceptance @exception_event_metadata @both
Feature: Exception Event Metadata
  Acceptance tests for canonical metadata on SDK-generated exception events.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset
    And the SDK is initialized with token "test-token"

  Scenario: Manual capture emits canonical defaults
    When capture exception is called for a caught exception without explicit overrides
    Then one event named "$exception" should be enqueued
    And the enqueued event property "$exception_level" should equal "error"
    And the enqueued event should omit "$exception_source"
    And the outermost exception should have "mechanism.type" equal to "generic"
    And the outermost exception should have "mechanism.handled" equal to true

  Scenario: Framework middleware identifies category and concrete source
    Given Django middleware observes an exception escaping the application request boundary
    When the middleware captures the exception
    Then one event named "$exception" should be enqueued
    And the enqueued event property "$exception_source" should equal "django.middleware"
    And the outermost exception should have "mechanism.type" equal to "middleware"
    And the outermost exception should have "mechanism.handled" equal to false

  Scenario: A nested cause identifies its relationship
    Given an outer exception wraps another exception as its cause
    When the SDK captures the outer exception
    Then the outermost exception should omit "mechanism.source"
    And the nested exception should have "mechanism.source" equal to "cause"

  Scenario: A preserved runtime stack is not synthetic
    Given an actual runtime exception has a usable stack
    When capture exception is called for the exception
    Then the outermost exception should have "mechanism.synthetic" equal to false

  Scenario: A synthesized current stack is marked synthetic
    Given an exception-like input has no usable stack
    When the SDK synthesizes a current stack while capturing the input
    Then the outermost exception should have "mechanism.synthetic" equal to true

  Scenario: Logger capture normalizes severity and remains handled
    When a logger integration captures a "warn" record as an exception
    Then one event named "$exception" should be enqueued
    And the enqueued event property "$exception_level" should equal "warning"
    And the outermost exception should have "mechanism.type" equal to "logger"
    And the outermost exception should have "mechanism.handled" equal to true

  Scenario: A fatal logger call remains handled
    When a logger integration captures a "fatal" record without terminating the app or process
    Then one event named "$exception" should be enqueued
    And the enqueued event property "$exception_level" should equal "fatal"
    And the outermost exception should have "mechanism.handled" equal to true

  Scenario: A terminating failure emits fatal unhandled metadata
    Given an automatic integration observes a crash, panic, signal, or uncaught exception expected to terminate the app or process
    When the integration captures the failure
    Then one event named "$exception" should be enqueued
    And the enqueued event property "$exception_level" should equal "fatal"
    And the outermost exception should have "mechanism.handled" equal to false

  Scenario: A deferred native crash retains original boundary metadata
    Given a native crash reporter records a terminating failure for next-launch delivery
    When the SDK reconstructs and enqueues the event on the next launch
    Then the enqueued event property "$exception_level" should equal "fatal"
    And the outermost exception should have "mechanism.handled" equal to false

  Scenario: Native frame carries matching debug image metadata
    Given the SDK captures a native frame with an authoritative debug identifier
    When the SDK captures the exception
    Then the native frame should contain "instruction_addr" and "image_addr"
    And the enqueued event property "$debug_images" should contain a matching "debug_id" and "image_addr"

  Scenario: Capture source remains distinct from processor-derived source files
    Given Django middleware captures an exception whose stack contains "app/views.py"
    When the middleware captures the exception
    Then the enqueued event property "$exception_source" should equal "django.middleware"
    And the SDK-generated event should omit "$exception_sources"

  Scenario: Generic properties cannot override canonical exception metadata
    Given generic caller properties contain reserved exception metadata that conflicts with the capture boundary
    When capture exception is called for a caught exception
    Then the SDK-generated "$exception_list" and "$exception_level" should win
    And event creation should not throw

  Scenario: Malformed supplied mechanism metadata is omitted safely
    Given a typed integration supplies one malformed common mechanism field and one valid common field
    When the integration captures an exception
    Then the malformed mechanism field should be omitted
    And the valid mechanism field should be preserved
    And event creation should not throw

  Scenario: A low-level producer preserves unknown metadata as absent
    Given a low-level exception payload producer has no capture-boundary context
    When the producer creates a "$exception" event without caller-supplied metadata
    Then the generated event should omit "$exception_level", "$exception_source", "$exception_fingerprint", and "$debug_images"
    And the generated exception entry should omit "mechanism"
