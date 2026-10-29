## ADDED Requirements

### Requirement: Request body compression and opt-out

A client SDK that compresses outgoing request bodies SHALL use gzip, SHALL apply it by default, and SHALL expose a configuration option that turns compression off for the whole client. A compressed request SHALL declare gzip with the `Content-Encoding: gzip` header where the transport can set it. A browser transport that must keep a CORS-simple request MAY send the gzip body without a declaration and rely on the server detecting gzip bodies, as posthog-js does.

The option MAY be an extensible encoding enum (`compression`, with a gzip default and a "none" member) or a boolean switch, named in the SDK's own style (for example `disable_compression`). New configuration surfaces SHOULD use the enum shape so further encodings can be added without another option. Whichever shape a client SDK ships, the default SHALL leave gzip enabled, so an app that sets nothing keeps the current behavior.

Server SDKs MAY default to no compression, MAY offer other encodings, and MAY expose compression as a positive or negative boolean or as an enum. The rules below apply to every SDK that compresses request bodies.

When compression is turned off, every request the SDK would otherwise have compressed SHALL carry an uncompressed body that parses as plain JSON, and SHALL omit any gzip declaration. Endpoints the SDK never compressed are unaffected. The set of compressed endpoints is SDK-specific and is not fixed by this requirement.

A client SDK's opt-out SHALL be reachable through configuration. An SDK that reserves `Content-Encoding` against caller-supplied custom headers SHALL NOT treat overriding that header as the way to disable compression.

When compression fails locally — for example a gzip encoder that throws — the SDK MAY send the uncompressed body instead of dropping the request. The SDK SHALL NOT silently downgrade to an uncompressed body and resend after a server rejects a compressed request; a server rejection is surfaced to the retry layer like any other failure, and opting out stays an explicit application decision.

#### Scenario: Compression is on by default (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and no compression configuration
- **AND** the event queue contains events:
  | event | distinct_id |
  | Save  | user-123    |
- **WHEN** flush is called
- **THEN** the ingestion request body should be gzip-compressed
- **AND** the decompressed request body should contain event "Save"

#### Scenario: Opting out sends a plain JSON body (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and compression turned off
- **AND** the event queue contains events:
  | event | distinct_id |
  | Save  | user-123    |
- **WHEN** flush is called
- **THEN** the ingestion request should not declare gzip
- **AND** the request body should parse as plain JSON containing event "Save"

#### Scenario: Opting out covers every endpoint the SDK compresses (@client)
- **GIVEN** the SDK is initialized with token "test-token" and compression turned off
- **WHEN** the SDK sends requests to each endpoint whose body it compresses by default
- **THEN** none of those requests should declare gzip
- **AND** each request body should parse as plain JSON

#### Scenario: A server rejection does not silently disable compression (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and compression enabled
- **AND** the mock server will fail the next ingestion request with status 400
- **WHEN** capture is called with event "Save"
- **AND** flush is called
- **THEN** the SDK should not resend the same payload uncompressed
- **AND** later ingestion request bodies should still be gzip-compressed
