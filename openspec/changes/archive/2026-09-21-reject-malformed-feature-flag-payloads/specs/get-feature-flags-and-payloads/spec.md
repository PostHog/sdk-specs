## ADDED Requirements

### Requirement: Bulk payload decoding agrees with single-flag APIs

Bulk flags-and-payloads APIs SHALL follow the serialized-payload decoding contract in `get-feature-flag-payload` for each payload independently. Malformed, empty, or whitespace-only serialized payloads SHALL be treated as missing: the affected payload entry SHALL be omitted or contain the language's no-payload value according to the SDK's existing missing-payload map convention, never the raw string. A payload decoding failure MUST NOT discard the associated flag value, healthy sibling payloads, or the combined result. These rules SHALL apply to client caches and server local and remote evaluation paths.

#### Scenario: Bulk results isolate malformed payloads (@both)
- **GIVEN** flag "checkout" has value "blue" and serialized payload `{broken`
- **AND** flag "beta-ui" has value true and serialized payload `{"color":"green"}`
- **WHEN** get feature flags and payloads is called
- **THEN** both flag values are returned unchanged
- **AND** "checkout" has no payload entry or a language-idiomatic no-payload value
- **AND** "beta-ui" has decoded payload `{"color":"green"}`
- **AND** no raw malformed string is returned and no exception is thrown

#### Scenario: Empty serialized payload agrees across single and bulk reads (@both)
- **GIVEN** a known flag has an empty serialized payload
- **WHEN** its payload is read individually and through the bulk flags-and-payloads API
- **THEN** both APIs treat its payload as missing
- **AND** the bulk result retains its evaluated flag value

#### Scenario: Valid JSON empty string is preserved in bulk (@both)
- **GIVEN** a known flag has serialized payload `""`
- **WHEN** its payload is read individually and through the bulk flags-and-payloads API
- **THEN** both APIs return the decoded empty string as its payload
