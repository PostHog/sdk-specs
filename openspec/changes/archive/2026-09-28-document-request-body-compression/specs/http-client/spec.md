## ADDED Requirements

### Requirement: Request body compression and opt-out

An SDK that compresses outgoing request bodies SHALL use gzip, SHALL apply it by default, and SHALL expose a configuration option that turns compression off for the whole client.

The option MAY be an extensible encoding enum (`compression`, with a gzip default and a "none" member) or a boolean disable switch (`disable_compression`, defaulting to false). New configuration surfaces SHOULD use the enum shape so further encodings can be added without another option. Whichever shape an SDK ships, the default SHALL leave gzip enabled, so an app that sets nothing keeps the current behavior.

When compression is turned off, every request the SDK would otherwise have compressed SHALL carry an uncompressed body that parses as plain JSON, and SHALL omit the `Content-Encoding` header. Endpoints the SDK never compressed are unaffected. The set of compressed endpoints is SDK-specific and is not fixed by this requirement.

The opt-out SHALL be reachable through configuration. An SDK that reserves `Content-Encoding` against caller-supplied custom headers SHALL NOT treat overriding that header as the way to disable compression.

When compression fails locally — for example a gzip encoder that throws — the SDK MAY send the uncompressed body instead of dropping the request. The SDK SHALL NOT silently downgrade to an uncompressed body and resend after a server rejects a compressed request; a server rejection is surfaced to the retry layer like any other failure, and opting out stays an explicit application decision.

#### Scenario: Compression is on by default (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and no compression configuration
- **AND** the event queue contains events:
  | event | distinct_id |
  | Save  | user-123    |
- **WHEN** flush is called
- **THEN** the ingestion request should carry the `Content-Encoding` header "gzip"
- **AND** the decompressed request body should contain event "Save"

#### Scenario: Opting out sends a plain JSON body (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and compression turned off
- **AND** the event queue contains events:
  | event | distinct_id |
  | Save  | user-123    |
- **WHEN** flush is called
- **THEN** the ingestion request should omit the `Content-Encoding` header
- **AND** the request body should parse as plain JSON containing event "Save"

#### Scenario: Opting out covers every endpoint the SDK compresses (@both)
- **GIVEN** the SDK is initialized with token "test-token" and compression turned off
- **WHEN** the SDK sends requests to each endpoint whose body it compresses by default
- **THEN** none of those requests should carry a `Content-Encoding` header
- **AND** each request body should parse as plain JSON

#### Scenario: A server rejection does not silently disable compression (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and no compression configuration
- **AND** the mock server will fail the next ingestion request with status 400
- **WHEN** capture is called with event "Save"
- **AND** flush is called
- **THEN** the SDK should not resend the same payload with the `Content-Encoding` header removed
- **AND** later ingestion requests should still carry the `Content-Encoding` header "gzip"
