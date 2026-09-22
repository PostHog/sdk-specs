## MODIFIED Requirements

### Requirement: Malformed serialized payloads return no payload

When a feature flag payload is represented as serialized JSON, the SDK SHALL decode it before exposing it as a payload value. If decoding fails, including for empty or whitespace-only serialized input, the SDK SHALL return the same sentinel used for a known flag with no payload (`null`, `nil`, or `None` as appropriate for the language) and MUST NOT return the raw string or throw to the caller. Parse failures SHALL be logged through SDK diagnostics. This requirement supersedes the earlier “missing/unparsed payloads” wording: an unparsed malformed string is not a permitted public payload result.

These rules SHALL apply consistently to client caches, server local evaluation, and server remote evaluation. SDKs with an explicit caller-supplied default SHALL follow their existing missing-payload default behavior; without such a default, malformed payloads SHALL return no payload.

Valid JSON values SHALL retain their decoded types and values, including `false`, `0`, `null`, arrays, objects, and strings. An empty serialized input is invalid JSON; the serialized JSON string `""` is valid and SHALL return an empty string. SDKs MUST NOT attempt to JSON-decode an already-decoded payload string again.

For JavaScript and TypeScript payload getters, a malformed payload on a known flag SHALL return `null`, not `undefined`. The latter remains reserved for unavailable flag state. In the acceptance scenarios, “the language's no-payload value” means this known-flag/no-payload sentinel. The `@payload_default_capable` scenarios apply only to SDK getters accepting an explicit caller default.

#### Scenario Outline: Malformed serialized payload returns no payload (@both)
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** flag "checkout" has JSON value "blue" with these serialized payload bytes:
  | serialized_payload_json |
  | <input>                 |
- **WHEN** get feature flag payload "checkout" is called without an explicit default
- **THEN** the returned payload should be the language's no-payload value
- **AND** the raw serialized string should not be returned
- **AND** no exception should be thrown

**Examples:**
  | input       |
  | "{broken"   |
  | ""          |
  | "   "       |

#### Scenario Outline: Valid JSON payload values retain their decoded types (@both)
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** flag "checkout" has JSON value "blue" with these serialized payload bytes:
  | serialized_payload_json |
  | <input>                 |
- **WHEN** get feature flag payload "checkout" is called
- **THEN** the returned payload should equal the JSON value <expected>
- **AND** no exception should be thrown

**Examples:**
  | input                       | expected          |
  | "\"hello\""                 | "hello"           |
  | "\"\""                      | ""                |
  | "false"                     | false             |
  | "0"                         | 0                 |
  | "null"                      | null              |
  | "{\"color\":\"green\"}"       | {"color":"green"} |
  | "[1,false]"                 | [1,false]         |

#### Scenario Outline: Already-decoded string is not parsed a second time (@both)
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** flag "checkout" has JSON value "blue" and an already-decoded string payload <payload>
- **WHEN** get feature flag payload "checkout" is called
- **THEN** the returned payload should equal the JSON value <payload>

**Examples:**
  | payload |
  | "hello" |
  | "123"   |
  | "true"  |

#### Scenario Outline: Malformed payload uses the caller default (@payload_default_capable)
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** flag "checkout" has JSON value "blue" with these serialized payload bytes:
  | serialized_payload_json |
  | <input>                 |
- **WHEN** get feature flag payload "checkout" is called with default value "fallback"
- **THEN** the returned payload should equal the JSON value "fallback"
- **AND** the raw serialized string should not be returned
- **AND** no exception should be thrown

**Examples:**
  | input     |
  | "{broken" |
  | ""        |
  | "   "     |
