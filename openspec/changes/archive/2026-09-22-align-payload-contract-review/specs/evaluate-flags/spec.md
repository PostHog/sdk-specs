## MODIFIED Requirements

### Requirement: Snapshot payload access
The snapshot SHALL retain available payloads paired with its evaluated flag records and SHALL expose a payload accessor. Reading a payload SHALL use only the snapshot and SHALL NOT issue a flag-evaluation request, mark the flag as accessed for `onlyAccessed()`, or emit `$feature_flag_called`.

Payload representation MAY follow platform convention: decoded JSON values, a host JSON document, a validated serialized JSON string, or an additional typed decoding helper are all conformant. A missing flag, absent payload, or failed optional typed decode SHALL return the platform's documented empty/nullish result and SHALL NOT make value access unsafe.

Serialized payloads SHALL be validated as JSON before public payload access, including accessors that return serialized strings without a typed decoding helper. Malformed, empty, or whitespace-only serialized JSON SHALL be logged and treated as an absent payload, returning the same documented empty/nullish result used for a known flag with no payload, never the malformed raw string. JavaScript and TypeScript snapshot payload getters SHALL use `null` for this case, not the unavailable-flag `undefined` sentinel. A valid serialized string representation remains permitted; this requirement does not force raw-string snapshot APIs to change their valid-payload return types. Already-decoded strings MUST NOT be decoded again. Payload failure MUST NOT discard the snapshot, the flag's evaluated value, or healthy sibling payloads, and MUST NOT add network or tracking side effects.

#### Scenario: Payload read is a silent snapshot lookup
- **GIVEN** snapshot flag "checkout" has payload `{ "copy": "new" }`
- **WHEN** the payload accessor is called for "checkout"
- **THEN** it returns the stored payload in the platform's documented representation
- **AND** no feature-flag evaluation request is made
- **AND** no `$feature_flag_called` event is emitted
- **AND** "checkout" is not added to the snapshot's accessed-key set

#### Scenario Outline: Snapshot payload reads reject malformed JSON
- **GIVEN** feature flags are supplied through <source> with these serialized payload bytes:
  | key      | value | serialized_payload_json |
  | checkout | blue  | <input>                 |
  | beta-ui  | true  | "{\"color\":\"green\"}"   |
- **WHEN** evaluate flags is called for distinct id "user-123"
- **AND** snapshot payload is read for "checkout"
- **THEN** the returned payload should be the language's no-payload value
- **AND** the raw serialized string should not be returned
- **AND** no exception should be thrown
- **AND** reading the payload should not send a feature flag network request
- **AND** no event named "$feature_flag_called" should be enqueued
- **AND** "checkout" should not be added to the snapshot's accessed-key set
- **AND** the snapshot should retain flag "checkout" with value "blue"
- **AND** the snapshot should retain the valid payload for "beta-ui" in the platform's documented representation

**Examples:**
  | source            | input     |
  | local evaluation  | "{broken" |
  | local evaluation  | ""        |
  | local evaluation  | "   "     |
  | remote evaluation | "{broken" |
  | remote evaluation | ""        |
  | remote evaluation | "   "     |
