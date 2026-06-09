@private @canonical_behavior @acceptance @application_lifecycle @client
Feature: Application Lifecycle
  Acceptance tests for the canonical application lifecycle behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: First app start captures install and open events
    Given the SDK is initialized with token "test-token" and application lifecycle capture enabled
    And the platform app version is "1.0.0" and build is "100"
    When the application lifecycle integration starts
    Then one event named "Application Installed" should be enqueued
    And one event named "Application Opened" should be enqueued
    And lifecycle storage should remember version "1.0.0" and build "100"

  Scenario: Version change captures an update event
    Given lifecycle storage remembers version "1.0.0" and build "100"
    And the platform app version is "1.1.0" and build is "110"
    When the application lifecycle integration starts
    Then one event named "Application Updated" should be enqueued
    And the enqueued event properties should include:
      | property         | value |
      | version          | 1.1.0 |
      | build            | 110   |
      | previous_version | 1.0.0 |
      | previous_build   | 100   |

  Scenario: Background transition captures background event once
    Given the SDK is initialized with token "test-token" and application lifecycle capture enabled
    And the application is foregrounded
    When the application moves to the background
    Then one event named "Application Backgrounded" should be enqueued
    When the application moves to the background again
    Then no additional "Application Backgrounded" event should be enqueued

  Scenario: Disabled lifecycle capture emits no lifecycle analytics events
    Given the SDK is initialized with token "test-token" and application lifecycle capture disabled
    When the application lifecycle integration starts
    And the application moves to the background
    Then no lifecycle analytics events should be enqueued
