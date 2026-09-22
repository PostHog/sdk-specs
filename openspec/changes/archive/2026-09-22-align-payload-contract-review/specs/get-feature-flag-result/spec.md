## MODIFIED Requirements

### Requirement: Payload parse failures preserve flag evaluation results

Structured feature flag results SHALL follow the serialized-payload decoding contract in `get-feature-flag-payload`. A malformed payload SHALL be represented as no payload (a language-idiomatic null value or omitted optional payload field), never as its raw serialized string. The SDK MUST NOT discard an otherwise valid flag result or alter its key, enabled state, variant, or valid metadata because payload decoding failed. Value-only and enabled-state APIs that share this result-construction path SHALL preserve the same evaluated flag value and enabled state without throwing. These rules SHALL apply to cached, locally evaluated, and remotely evaluated results.

#### Scenario Outline: Invalid cached payload does not change the flag result (@client)
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** feature flags are supplied through client cache with these serialized payload bytes:
  | key      | value   | serialized_payload_json |
  | checkout | <value> | <input>                 |
- **WHEN** get feature flag result "checkout" is called
- **THEN** the returned feature flag result should include:
  | field   | value     |
  | key     | checkout  |
  | enabled | <enabled> |
- **AND** its variant should equal the JSON value <variant> or be absent when null
- **AND** its payload should be absent or the language's no-payload value
- **WHEN** get feature flag "checkout" is called
- **THEN** the returned flag value should equal the JSON value <value>
- **WHEN** is feature enabled "checkout" is called
- **THEN** the returned enabled state should be <enabled>
- **AND** no exception should be thrown

**Examples:**
  | value  | input     | enabled | variant |
  | "blue" | "{broken" | true    | "blue"  |
  | "blue" | ""        | true    | "blue"  |
  | "blue" | "   "     | true    | "blue"  |
  | false  | "{broken" | false   | null    |
  | false  | ""        | false   | null    |
  | false  | "   "     | false   | null    |

#### Scenario Outline: Invalid evaluated payload does not change the flag result (@server)
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** feature flags are supplied through <source> with these serialized payload bytes:
  | key      | value   | serialized_payload_json |
  | checkout | <value> | <input>                 |
- **WHEN** get feature flag result "checkout" is called
- **THEN** the returned feature flag result should include:
  | field   | value     |
  | key     | checkout  |
  | enabled | <enabled> |
- **AND** its variant should equal the JSON value <variant> or be absent when null
- **AND** its payload should be absent or the language's no-payload value
- **WHEN** get feature flag "checkout" is called
- **THEN** the returned flag value should equal the JSON value <value>
- **WHEN** is feature enabled "checkout" is called
- **THEN** the returned enabled state should be <enabled>
- **AND** no exception should be thrown

**Examples:**
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
