@private @canonical_behavior @acceptance @device_id_generator @client
Feature: Device ID Generator
  Acceptance tests for the canonical device id generator behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  Scenario: Device id is generated and persisted on first use
    Given the SDK is initialized with token "test-token"
    When the device id is requested
    Then the returned device id should not be empty
    And persistent storage should contain the same device id

  Scenario: Device id is reused from persistent storage
    Given persistent storage contains device id "device-123"
    When the SDK is initialized with token "test-token"
    And the device id is requested
    Then the returned device id should be "device-123"

  Scenario: Reset can rotate the device id
    Given the SDK is initialized with token "test-token"
    And the current device id is "device-123"
    When reset is called with device id regeneration enabled
    Then the current device id should not be "device-123"
