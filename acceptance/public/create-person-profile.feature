@public @canonical_behavior @acceptance @create_person_profile @client
Feature: Create Person Profile
  Acceptance tests for the canonical create person profile behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Create person profile emits an empty set event for the current identity
    Given the SDK is initialized with token "test-token" and person profiles mode "identified_only"
    And the current distinct id is "anon-123"
    When create person profile is called
    Then one event named "$set" should be enqueued
    And the enqueued event distinct id should be "anon-123"
    And the enqueued event should contain empty person property updates
    And the current distinct id should remain "anon-123"

  Scenario: Create person profile is a no-op when person profiles are disabled
    Given the SDK is initialized with token "test-token" and person profiles mode "never"
    When create person profile is called
    Then no event should be enqueued
    And the current distinct id should not change

  Scenario: Repeated create person profile calls do not duplicate profile creation
    Given the SDK is initialized with token "test-token" and person profiles mode "identified_only"
    When create person profile is called
    And create person profile is called again
    Then at most one profile creation event should be enqueued for the current identity
