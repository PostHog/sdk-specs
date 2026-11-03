## MODIFIED Requirements

### Requirement: Compression

The SDK SHALL gzip the JSON body by default and signal it either with a `Content-Encoding: gzip`
header on a gzipped body (preferred) or with a `?compression=gzip-js` / `?compression=gzip` query
parameter that the server translates into `Content-Encoding: gzip`. When gzip is unavailable on the
platform, the SDK SHALL send raw JSON with no `Content-Encoding`. When the application turns
compression off through the client-wide option in `http-client`, the SDK SHALL also send raw JSON
with no `Content-Encoding`. There SHALL be no size threshold for compression.

#### Scenario: gzipped with header
- **WHEN** a platform with gzip support flushes
- **THEN** the body is gzipped and sent with `Content-Encoding: gzip`

#### Scenario: gzip unavailable
- **GIVEN** a platform with no gzip primitive available
- **WHEN** the SDK flushes
- **THEN** it sends raw JSON with no `Content-Encoding` header

#### Scenario: compression turned off
- **GIVEN** the application turned compression off through the `http-client` option
- **WHEN** the SDK flushes
- **THEN** it sends raw JSON with no `Content-Encoding` header
