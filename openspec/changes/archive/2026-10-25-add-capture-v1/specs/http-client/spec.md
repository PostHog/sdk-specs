## Narrative alignment

When syncing this delta into the canonical `http-client` spec:

- In Purpose and Behavior step 1, add the capture v1 endpoints (`/i/v1/analytics/events`, `/i/v1/ai/events`) next to `/batch` and `/capture`, and say which wire each SDK uses.
- In Behavior step 3, add the capture v1 header set and that the project token travels in `Authorization: Bearer`, not in the body.
- In Behavior step 7, note that on capture v1 a 2xx body carries per-event verdicts the retry layer reads (see `capture`), and that the transport never follows a cross-origin or non-307/308 redirect for capture requests.
- Leave the feature-flag retry requirement unchanged.

## ADDED Requirements

### Requirement: Capture v1 transport

An SDK that delivers events through capture v1 SHALL build the capture URL as `{host}/i/v1/analytics/events` (and `{host}/i/v1/ai/events` for the AI lane), SHALL send the project token only as `Authorization: Bearer <token>`, and SHALL send the header set defined in `capture` (**Capture v1 request headers**) on every attempt.

The SDK MAY compress the body with `gzip`, `deflate`, `br` or `zstd`, offering only the codecs its runtime provides, and SHALL then set `Content-Encoding` to exactly that token. It SHALL NOT use legacy encodings (`gzip-js`, `lz64`, `base64`) or a `?compression=` query parameter on capture v1. If local compression fails, the SDK MAY send the body uncompressed without `Content-Encoding`. Each delivery lane SHALL have its own compression setting; the analytics setting SHALL NOT change AI uploads. The default is the SDK's choice: posthog-python, posthog-go and posthog-rs default to no compression; posthog-node keeps gzip.

For capture requests the transport SHALL follow a redirect only when the status is `307` or `308` and the target has the same origin (scheme, host and port) as the configured host, at most five times, resending the same method, headers and body. Any other redirect, a cross-origin target or a sixth hop is a terminal failure of that request. A caller-supplied HTTP client either keeps its own redirect policy or, where the SDK can intercept its redirects, gets this same rule applied to capture requests; both are compliant.

Legacy capture: the token was sent as `api_key` in the body and most SDKs followed the HTTP library's default redirect policy, which can turn a `POST` into a `GET` or send the body to another host.

#### Scenario: A compressed request declares exactly its encoding (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and compression "gzip" and flush threshold 1
- **WHEN** capture is called with distinct id "user-123" and event "Compressed"
- **AND** pending captures are flushed
- **THEN** a received request header "Content-Encoding" should equal "gzip"
- **AND** the first request body should decompress as gzip into a JSON object with an array "batch"
- **AND** the first request path should not contain "compression="

#### Scenario: An uncompressed request sends no Content-Encoding (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key", flush threshold 1, and compression disabled
- **WHEN** capture is called with distinct id "user-123" and event "Plain"
- **AND** pending captures are flushed
- **THEN** the first request header "Content-Encoding" should be absent
- **AND** the first request body should parse as a JSON object with an array "batch"

#### Scenario: A same-origin 308 is followed with the same body (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the mock answers the first request to "/i/v1/analytics/events" with status 308 and a Location of "/i/v1/analytics/events/" on the same origin
- **WHEN** capture is called with distinct id "user-123" and event "Moved"
- **AND** pending captures are flushed
- **THEN** exactly 2 requests should have been received
- **AND** the second request path should equal "/i/v1/analytics/events/"
- **AND** the second request method should equal "POST"
- **AND** the second request body should equal the first request body
- **AND** the second request should authenticate with bearer token "phc_test_key"

#### Scenario: A cross-origin or non-307/308 redirect is terminal (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the mock answers the first request with status <status> and a Location of "<location>"
- **WHEN** capture is called with distinct id "user-123" and event "Redirected"
- **AND** pending captures are flushed
- **AND** 2000 milliseconds elapse without a public SDK call
- **THEN** exactly 1 request should have been received
- **AND** no request should have been sent to "<location>"
- **AND** the SDK should report the event "Redirected" as not delivered
  Examples:
  | status | location                                           |
  | 301    | /i/v1/analytics/events/                            |
  | 302    | /i/v1/analytics/events/                            |
  | 307    | https://other.example.com/i/v1/analytics/events    |
  | 308    | http://mock.posthog.test:8081/i/v1/analytics/events |

## MODIFIED Requirements

### Requirement: Request body compression and opt-out

A client SDK that compresses outgoing request bodies SHALL use gzip, SHALL apply it by default, and SHALL expose a configuration option that turns compression off for the whole client, except a delivery lane that has its own compression setting (`capture-ai`, **AI lane configuration is scoped to the AI lane**). A client SDK MAY send uncompressed, or use another encoding the server advertises, when gzip is unavailable on the platform or the server's remote configuration does not advertise gzip. A compressed request SHALL declare gzip with the `Content-Encoding: gzip` header where the transport can set it. A browser transport that must keep a CORS-simple request MAY send the gzip body without a declaration and rely on the server detecting gzip bodies, as posthog-js does.

The option MAY be an extensible encoding enum (`compression`, with a gzip default and a "none" member) or a boolean switch, named in the SDK's own style (for example `disable_compression`). New configuration surfaces SHOULD use the enum shape so further encodings can be added without another option. Whichever shape a client SDK ships, the default SHALL leave gzip enabled, so an app that sets nothing keeps the current behavior.

Server SDKs MAY default to no compression, MAY offer other encodings, and MAY expose compression as a positive or negative boolean or as an enum. The rules below apply to every SDK that compresses request bodies.

When compression is turned off, every request the SDK would otherwise have compressed SHALL carry the uncompressed body, plain JSON for JSON endpoints, and SHALL omit any gzip declaration. A browser unload beacon that must avoid a CORS preflight MAY instead send a CORS-simple body without gzip, such as base64 form data. Endpoints the SDK never compressed are unaffected, and so is a delivery lane that has its own compression setting. The set of compressed endpoints is SDK-specific and is not fixed by this requirement.

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
- **WHEN** the SDK sends requests to each endpoint whose body it compresses by default, other than a delivery lane that has its own compression setting
- **THEN** none of those requests should declare gzip
- **AND** each request body should parse as plain JSON

#### Scenario: A server rejection does not silently disable compression (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and compression enabled
- **AND** the mock server will fail the next ingestion request with status 400
- **WHEN** capture is called with event "Save"
- **AND** flush is called
- **AND** capture is called with event "Next"
- **AND** flush is called
- **THEN** the SDK should not resend the "Save" payload uncompressed
- **AND** the ingestion request containing event "Next" should still be compressed with the configured encoding
