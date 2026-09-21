@public @canonical_behavior @acceptance @get_feature_flag_payload @both
Feature: Get Feature Flag Payload
  Acceptance tests for the canonical get feature flag payload behavior across PostHog SDKs.

  Background:
    Given a fresh SDK acceptance test harness
    And the SDK clock is fixed at "2025-01-01T00:00:00Z"
    And persistent storage is empty
    And the mock PostHog server is reset

  @both
  Scenario: Payload getter returns payload for the matched flag value
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key      | value | payload                |
      | checkout | blue  | {"cta":"Try now"}   |
    When get feature flag payload "checkout" is called
    Then the returned payload should include:
      | field | value   |
      | cta   | Try now |

  @both
  Scenario: Payload getter returns no payload for unknown flags
    Given the SDK is initialized with token "test-token"
    And cached feature flags are empty
    When get feature flag payload "missing-flag" is called
    Then no payload should be returned
    And no exception should be thrown

  @both
  Scenario: Payload lookup does not emit feature flag called by itself
    Given the SDK is initialized with token "test-token"
    And cached feature flags are:
      | key      | value | payload        |
      | checkout | true  | {"enabled":1} |
    When get feature flag payload "checkout" is called
    Then no event named "$feature_flag_called" should be enqueued

  # serialized_payload_json is a JSON string encoding the exact serialized input bytes.
  @both
  Scenario Outline: Malformed serialized payload returns no payload
    Given the SDK is initialized with token "test-token"
    And flag "checkout" has value "blue" with these serialized payload bytes:
      | serialized_payload_json |
      | <input>                 |
    When get feature flag payload "checkout" is called without an explicit default
    Then the returned payload should be the language's no-payload value
    And the raw serialized string should not be returned
    And no exception should be thrown

    Examples:
      | input       |
      | "{broken"   |
      | ""          |
      | "   "       |

  @both
  Scenario Outline: Valid JSON payload values retain their decoded types
    Given the SDK is initialized with token "test-token"
    And flag "checkout" has value "blue" with these serialized payload bytes:
      | serialized_payload_json |
      | <input>                 |
    When get feature flag payload "checkout" is called
    Then the returned payload should equal the JSON value <expected>
    And no exception should be thrown

    Examples:
      | input                       | expected          |
      | "\"hello\""                 | "hello"           |
      | "\"\""                      | ""                |
      | "false"                     | false             |
      | "0"                         | 0                 |
      | "null"                      | null              |
      | "{\"color\":\"green\"}"       | {"color":"green"} |
      | "[1,false]"                 | [1,false]         |

  @both
  Scenario: Already-decoded string is not parsed a second time
    Given the SDK is initialized with token "test-token"
    And flag "checkout" has value "blue" and an already-decoded string payload "hello"
    When get feature flag payload "checkout" is called
    Then the returned payload should equal the JSON value "hello"
