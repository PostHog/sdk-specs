## MODIFIED Requirements

### Requirement: Bulk payload decoding agrees with single-flag APIs

Bulk flags-and-payloads APIs SHALL follow the serialized-payload decoding contract in `get-feature-flag-payload` for each payload independently. Malformed, empty, or whitespace-only serialized payloads SHALL be treated as missing: the affected payload entry SHALL be omitted or contain the language's no-payload value according to the SDK's existing missing-payload map convention, never the raw string. A payload decoding failure MUST NOT discard the associated flag value, healthy sibling payloads, or the combined result. These rules SHALL apply to client caches and server local and remote evaluation paths.

#### Scenario Outline: Single and bulk cache reads isolate malformed payloads consistently (@client)
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** feature flags are supplied through <source> with these serialized payload bytes:
  | key      | value | serialized_payload_json        |
  | checkout | blue  | <input>                        |
  | beta-ui  | true  | "{\"color\":\"green\"}"          |
- **WHEN** get feature flag payload "checkout" is called without an explicit default
- **THEN** the returned payload should be the language's no-payload value
- **WHEN** get feature flags and payloads is called
- **THEN** the returned feature flag values should be:
  | key      | value |
  | checkout | blue  |
  | beta-ui  | true  |
- **AND** the payload for "checkout" should be omitted or the language's no-payload value
- **AND** the payload for "beta-ui" should equal the JSON value {"color":"green"}
- **AND** the raw serialized string should not be returned
- **AND** no exception should be thrown

**Examples: Cached client payloads**
  | source       | input     |
  | client cache | "{broken" |
  | client cache | ""        |
  | client cache | "   "     |

#### Scenario Outline: Single and bulk evaluated reads isolate malformed payloads consistently (@server)
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** feature flags are supplied through <source> with these serialized payload bytes:
  | key      | value | serialized_payload_json        |
  | checkout | blue  | <input>                        |
  | beta-ui  | true  | "{\"color\":\"green\"}"          |
- **WHEN** get feature flag payload "checkout" is called without an explicit default
- **THEN** the returned payload should be the language's no-payload value
- **WHEN** get feature flags and payloads is called
- **THEN** the returned feature flag values should be:
  | key      | value |
  | checkout | blue  |
  | beta-ui  | true  |
- **AND** the payload for "checkout" should be omitted or the language's no-payload value
- **AND** the payload for "beta-ui" should equal the JSON value {"color":"green"}
- **AND** the raw serialized string should not be returned
- **AND** no exception should be thrown

**Examples: Locally and remotely evaluated server payloads**
  | source            | input     |
  | local evaluation  | "{broken" |
  | local evaluation  | ""        |
  | local evaluation  | "   "     |
  | remote evaluation | "{broken" |
  | remote evaluation | ""        |
  | remote evaluation | "   "     |

#### Scenario: Valid JSON empty string is preserved in single and bulk results (@both)
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** flag "checkout" has JSON value "blue" with these serialized payload bytes:
  | serialized_payload_json |
  | "\"\""                  |
- **WHEN** get feature flag payload "checkout" is called
- **THEN** the returned payload should equal the JSON value ""
- **WHEN** get feature flags and payloads is called
- **THEN** the payload for "checkout" should equal the JSON value ""
