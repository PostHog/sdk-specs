## ADDED Requirements

### Requirement: Cached payload decoding rejects malformed JSON

Cached payload reads SHALL follow the serialized-payload decoding and known-flag/no-payload sentinel contract in `get-feature-flag-payload`. Invalid JSON, including empty and whitespace-only serialized input, MUST NOT be exposed as a raw payload string. The SDK SHALL log parse failures and treat the affected payload as absent without changing its flag value or healthy sibling payloads. This replaces the Error handling allowance to return invalid payload JSON as the raw value. Valid already-decoded strings MUST NOT be decoded again. Internal caches MAY retain serialized representations, provided exposed payload reads honor this contract.

#### Scenario Outline: Cached malformed payload is treated as absent (@client)
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** feature flags are supplied through client cache with these serialized payload bytes:
  | key      | value | serialized_payload_json |
  | checkout | blue  | <input>                 |
- **WHEN** get feature flag payload "checkout" is called without an explicit default
- **THEN** the returned payload should be the language's no-payload value
- **AND** the raw serialized string should not be returned
- **AND** no exception should be thrown
- **AND** no feature flag network request should be sent

**Examples:**
  | input     |
  | "{broken" |
  | ""        |
  | "   "     |
