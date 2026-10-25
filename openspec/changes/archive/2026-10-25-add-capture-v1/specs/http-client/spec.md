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

For capture requests the transport SHALL follow a redirect only when the status is `307` or `308` and the target has the same origin (scheme, host and port) as the configured host, at most five times, resending the same method, headers and body. Any other redirect, a cross-origin target or a sixth hop is a terminal failure of that request. A caller-supplied HTTP client keeps its own redirect policy.

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
