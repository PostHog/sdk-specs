## MODIFIED Requirements

### Requirement: Compression

The SDK SHALL gzip the request body by default — protobuf or JSON alike — signaling with
`Content-Encoding: gzip` (preferred) or the `?compression=gzip` / `?compression=gzip-js`
query parameter the server translates into the header. The server additionally sniffs gzip
magic bytes, but the SDK SHALL still signal explicitly wherever the transport can set the header
or query parameter. Where gzip is unavailable — including
send modes that cannot set headers, such as the unload beacon — the SDK SHALL send the raw
body with no `Content-Encoding`. When the application turns compression off through the
client-wide option in `http-client`, the SDK SHALL also send the raw body with no
`Content-Encoding`. There SHALL be no size threshold for compression.

#### Scenario: gzipped batch
- **WHEN** a platform with gzip support flushes
- **THEN** the body is gzipped and sent with `Content-Encoding: gzip`

#### Scenario: gzip unavailable
- **GIVEN** a platform with no gzip primitive
- **WHEN** the SDK flushes
- **THEN** the raw body is sent with no `Content-Encoding` header

#### Scenario: compression turned off
- **GIVEN** the application turned compression off through the `http-client` option
- **WHEN** the SDK flushes
- **THEN** the raw body is sent with no `Content-Encoding` header
