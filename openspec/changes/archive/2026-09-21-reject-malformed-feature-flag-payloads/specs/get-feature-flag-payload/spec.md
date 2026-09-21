## ADDED Requirements

### Requirement: Malformed serialized payloads return no payload

When a feature flag payload is represented as serialized JSON, the SDK SHALL decode it before exposing it as a payload value. If decoding fails, including for empty or whitespace-only serialized input, the SDK SHALL return its language-idiomatic no-payload value (`null`, `nil`, `None`, or `undefined`) and MUST NOT return the raw string or throw to the caller. Parse failures SHALL be logged through SDK diagnostics. This requirement supersedes the earlier “missing/unparsed payloads” wording: an unparsed malformed string is not a permitted public payload result.

These rules SHALL apply consistently to client caches, server local evaluation, and server remote evaluation. SDKs with an explicit caller-supplied default SHALL follow their existing missing-payload default behavior; without such a default, malformed payloads SHALL return no payload.

Valid JSON values SHALL retain their decoded types and values, including `false`, `0`, `null`, arrays, objects, and strings. An empty serialized input is invalid JSON; the serialized JSON string `""` is valid and SHALL return an empty string. SDKs MUST NOT attempt to JSON-decode an already-decoded payload string again.

#### Scenario: Malformed serialized payload returns no payload (@both)
- **GIVEN** flag "checkout" has value "blue" and serialized payload `{broken`
- **WHEN** get feature flag payload "checkout" is called without an explicit default
- **THEN** the returned value is the language's no-payload value
- **AND** the raw string is not returned
- **AND** no exception is thrown

#### Scenario: Empty or whitespace-only serialized payload returns no payload (@both)
- **GIVEN** a known flag has an empty or whitespace-only serialized payload
- **WHEN** its payload is requested without an explicit default
- **THEN** the returned value is the language's no-payload value rather than the input string
- **AND** no exception is thrown

#### Scenario: Valid JSON strings and falsey values remain valid payloads (@both)
- **GIVEN** a known flag has a serialized JSON payload
- **WHEN** the payload is decoded and returned
- **THEN** `"hello"` returns the string "hello" and `""` returns an empty string
- **AND** `false` returns boolean false, `0` returns numeric zero, and `null` returns the language's JSON null equivalent
- **AND** objects and arrays retain their decoded contents

#### Scenario: Already-decoded string is not parsed a second time (@both)
- **GIVEN** a flag's serialized JSON payload `"hello"` has already been decoded into the string "hello"
- **WHEN** its payload is requested
- **THEN** the string "hello" is returned unchanged
