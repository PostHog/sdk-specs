@public @canonical_behavior @acceptance @get_feature_flag_result @both
Feature: Get Feature Flag Result
  Acceptance tests for the canonical get feature flag result behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @both
  Scenario: Structured result includes key enabled variant and payload
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key      | value | payload              |
      | checkout | blue  | {"copy":"new"}    |
    When get feature flag result "checkout" is called
    Then the returned feature flag result should include:
      | field   | value           |
      | key     | checkout        |
      | enabled | true            |
      | variant | blue            |
      | payload | {"copy":"new"} |

  @both
  Scenario: Boolean false flag result is disabled
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key     | value |
      | beta-ui | false |
    When get feature flag result "beta-ui" is called
    Then the returned feature flag result should include:
      | field   | value   |
      | key     | beta-ui |
      | enabled | false   |
    And the returned feature flag result should not include a variant

  @both
  Scenario: Unknown flag returns no structured result
    Given the SDK is initialized with token "test-token"
    And cached feature flags are empty
    When get feature flag result "missing-flag" is called
    Then no feature flag result should be returned

  # serialized_payload_json encodes the serialized input as a JSON string.
  @client
  Scenario Outline: Invalid cached payload does not change the flag result
    Given the SDK is initialized with token "test-token"
    And feature flags are supplied through client cache with these serialized payload bytes:
      | key      | value   | serialized_payload_json |
      | checkout | <value> | <input>                 |
    When get feature flag result "checkout" is called
    Then the returned feature flag result should include:
      | field   | value     |
      | key     | checkout  |
      | enabled | <enabled> |
    And its variant should equal the JSON value <variant> or be absent when null
    And its payload should be absent or the language's no-payload value
    When get feature flag "checkout" is called
    Then the returned flag value should equal the JSON value <value>
    When is feature enabled "checkout" is called
    Then the returned enabled state should be <enabled>
    And no exception should be thrown

    Examples:
      | value  | input     | enabled | variant |
      | "blue" | "{broken" | true    | "blue"  |
      | "blue" | ""        | true    | "blue"  |
      | "blue" | "   "     | true    | "blue"  |
      | false  | "{broken" | false   | null    |
      | false  | ""        | false   | null    |
      | false  | "   "     | false   | null    |

  @server
  Scenario Outline: Invalid evaluated payload does not change the flag result
    Given the SDK is initialized with token "test-token"
    And feature flags are supplied through <source> with these serialized payload bytes:
      | key      | value   | serialized_payload_json |
      | checkout | <value> | <input>                 |
    When get feature flag result "checkout" is called
    Then the returned feature flag result should include:
      | field   | value     |
      | key     | checkout  |
      | enabled | <enabled> |
    And its variant should equal the JSON value <variant> or be absent when null
    And its payload should be absent or the language's no-payload value
    When get feature flag "checkout" is called
    Then the returned flag value should equal the JSON value <value>
    When is feature enabled "checkout" is called
    Then the returned enabled state should be <enabled>
    And no exception should be thrown

    Examples:
      | source            | value  | input     | enabled | variant |
      | local evaluation  | "blue" | "{broken" | true    | "blue"  |
      | local evaluation  | "blue" | ""        | true    | "blue"  |
      | local evaluation  | "blue" | "   "     | true    | "blue"  |
      | local evaluation  | false  | "{broken" | false   | null    |
      | local evaluation  | false  | ""        | false   | null    |
      | local evaluation  | false  | "   "     | false   | null    |
      | remote evaluation | "blue" | "{broken" | true    | "blue"  |
      | remote evaluation | "blue" | ""        | true    | "blue"  |
      | remote evaluation | "blue" | "   "     | true    | "blue"  |
      | remote evaluation | false  | "{broken" | false   | null    |
      | remote evaluation | false  | ""        | false   | null    |
      | remote evaluation | false  | "   "     | false   | null    |
