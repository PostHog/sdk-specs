@public @canonical_behavior @acceptance @get_feature_flags_and_payloads @both
Feature: Get Feature Flags And Payloads
  Acceptance tests for the canonical get feature flags and payloads behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @both
  Scenario: Bulk getter returns flags and payloads together
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key      | value | payload               |
      | beta-ui  | true  | {"color":"green"} |
      | checkout | blue  | {"copy":"new"}    |
    When get feature flags and payloads is called
    Then the returned feature flag values should be:
      | key      | value |
      | beta-ui  | true  |
      | checkout | blue  |
    And the returned feature flag payloads should be:
      | key      | payload             |
      | beta-ui  | {"color":"green"} |
      | checkout | {"copy":"new"}    |

  @both
  Scenario: Bulk values and payloads are empty when no flags are known
    Given the SDK is initialized with token "test-token"
    And cached feature flags are empty
    When get feature flags and payloads is called
    Then the returned feature flag values should be empty
    And the returned feature flag payloads should be empty

  # serialized_payload_json encodes the serialized input as a JSON string.
  @client
  Scenario Outline: Single and bulk cache reads isolate malformed payloads consistently
    Given the SDK is initialized with token "test-token"
    And feature flags are supplied through <source> with these serialized payload bytes:
      | key      | value | serialized_payload_json        |
      | checkout | blue  | <input>                        |
      | beta-ui  | true  | "{\"color\":\"green\"}"          |
    When get feature flag payload "checkout" is called without an explicit default
    Then the returned payload should be the language's no-payload value
    When get feature flags and payloads is called
    Then the returned feature flag values should be:
      | key      | value |
      | checkout | blue  |
      | beta-ui  | true  |
    And the payload for "checkout" should be omitted or the language's no-payload value
    And the payload for "beta-ui" should equal the JSON value {"color":"green"}
    And the raw serialized string should not be returned
    And no exception should be thrown

    Examples: Cached client payloads
      | source       | input     |
      | client cache | "{broken" |
      | client cache | ""        |
      | client cache | "   "     |

  @server
  Scenario Outline: Single and bulk evaluated reads isolate malformed payloads consistently
    Given the SDK is initialized with token "test-token"
    And feature flags are supplied through <source> with these serialized payload bytes:
      | key      | value | serialized_payload_json        |
      | checkout | blue  | <input>                        |
      | beta-ui  | true  | "{\"color\":\"green\"}"          |
    When get feature flag payload "checkout" is called without an explicit default
    Then the returned payload should be the language's no-payload value
    When get feature flags and payloads is called
    Then the returned feature flag values should be:
      | key      | value |
      | checkout | blue  |
      | beta-ui  | true  |
    And the payload for "checkout" should be omitted or the language's no-payload value
    And the payload for "beta-ui" should equal the JSON value {"color":"green"}
    And the raw serialized string should not be returned
    And no exception should be thrown

    Examples: Locally and remotely evaluated server payloads
      | source            | input     |
      | local evaluation  | "{broken" |
      | local evaluation  | ""        |
      | local evaluation  | "   "     |
      | remote evaluation | "{broken" |
      | remote evaluation | ""        |
      | remote evaluation | "   "     |

  @both
  Scenario: Valid JSON empty string is preserved in single and bulk results
    Given the SDK is initialized with token "test-token"
    And flag "checkout" has JSON value "blue" with these serialized payload bytes:
      | serialized_payload_json |
      | "\"\""                  |
    When get feature flag payload "checkout" is called
    Then the returned payload should equal the JSON value ""
    When get feature flags and payloads is called
    Then the payload for "checkout" should equal the JSON value ""
