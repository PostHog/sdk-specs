# HTTP Client Specification

## Purpose

`http-client` is the internal transport layer that turns prepared SDK payloads into HTTP requests to PostHog endpoints.

It is responsible for:

- choosing the correct endpoint (`/batch`, `/capture`, `/flags`, `/decide`, remote-config/local-evaluation endpoints, snapshot/replay endpoints)
- serializing request bodies
- applying headers, timeouts, compression, and authentication
- executing the request through the host platform's HTTP stack
- surfacing success/failure information back to retry, caching, and higher-level components

## Applicability

`both` — both client and server SDKs use an internal HTTP transport, though the specific endpoints and integrations differ.

## Public signature(s)

No single public API.

Canonical internal operations look like:

```ts
sendBatch(events): Result
sendEvent(payload): Result
fetchFlags(context): Result
fetchRemoteConfig(): Result
```

Platform-specific implementations often split these into dedicated methods per endpoint.

## Behavior

1. **Build endpoint URLs from host configuration.**
   - Event ingestion commonly uses `/batch` or `/capture`.
   - Feature flags use `/flags` or `/decide`-family endpoints.
   - Remote config / local evaluation may use asset/API endpoints distinct from the ingestion host.
2. **Construct request bodies.**
   - Serialize event payloads, batched event arrays, flag request bodies, or local-evaluation/authenticated requests as JSON.
3. **Apply SDK headers and metadata.**
   - User-Agent / library identification
   - Content-Type / Accept
   - optional Content-Encoding (gzip)
   - authentication headers for privileged endpoints where required
4. **Apply timeouts and request configuration.**
   - Each endpoint family may use different timeout or cache/revalidation settings.
5. **Execute via platform HTTP stack.**
   - `fetch` in js-core-based SDKs
   - `URLSession` on iOS
   - `OkHttp` on Android
   - `UnityWebRequest` in Unity
   - `requests.Session` in Python
   - `HttpClient` in .NET
6. **Allow wrapper SDKs to delegate transport ownership instead of creating a second HTTP client.** Flutter's Dart layer forwards setup/config to the underlying native SDKs and delegates all runtime transport to those native/browser clients rather than implementing its own request stack.
7. **Translate HTTP failures into SDK-meaningful errors.**
   - Status codes and response bodies are surfaced so retry/caching layers can decide whether to retry, clear caches, or log errors.
   - Some transports parse `Retry-After` headers.
8. **Support endpoint-specific extras.**
   - gzip compression for batched event uploads
   - `$anon_distinct_id` / person/group properties for flag requests
   - conditional fetches / asset-host remapping / authenticated endpoints for config/definitions

## State & lifecycle

### State read

- SDK host / API key / personal API key config
- timeout / compression / custom transport configuration
- current identity/context for flag requests
- optional cached ETag / request metadata for conditional config fetches

### State written

Usually none directly, aside from transient request/response objects. Higher layers persist any returned metadata.

### Lifecycle behavior

- The HTTP client is created during SDK setup and reused by higher-level components.
- Some SDKs keep persistent session/connection pools for reuse across requests.
- Platform shutdown/disposal may close underlying clients or sessions.
- Wrapper SDKs may only bind to an existing transport owner. Flutter Web, for example, attaches to an already-initialized `posthog-js` instance instead of initializing a separate browser HTTP client from Dart.

## Error handling

- HTTP transport should surface status code failures, network errors, and timeouts without crashing application code.
- Non-2xx responses are converted into SDK-specific error types or result objects.
- Malformed URLs, serialization failures, or parsing failures are logged and returned as transport failures.
- Rate-limit metadata such as `Retry-After` is extracted when available.

## Concurrency & ordering guarantees

- The transport itself is typically stateless per request, but may share pooled clients/sessions.
- Ordering is not guaranteed by the transport layer; higher-level queue/batcher components determine submission order.
- Concurrent requests are allowed unless the higher layer intentionally serializes them.

## Interactions

- **retry-queue** uses HTTP failures and status codes to decide retry/backoff behavior.
- **feature-flag-cache** and **reload-feature-flags** depend on flag/decide/remote-config requests made by this layer.
- **persistent-storage** may persist metadata returned by HTTP-backed components (for example cached flags/request ids).
- **consent-gating** may prevent higher layers from calling the transport at all.
- **wrapper setup/config** may act only as a pass-through surface. Flutter serializes host/API/batching/privacy config into platform setup payloads and then relies on native/browser transports to perform the actual requests.

## Requirements

### Requirement: Canonical http-client behavior

The SDK SHALL implement the canonical `http-client` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: HTTP client sends ingestion requests with authentication and JSON payload
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and host "https://mock.posthog.test"
- **AND** the event queue contains events:
  | event | distinct_id |
  | Save  | user-123    |
- **WHEN** flush is called
- **THEN** the mock server should receive a request to an ingestion endpoint
- **AND** the request should include token "test-token"
- **AND** the request body should contain event "Save"

#### Scenario: HTTP client treats successful status codes as delivered
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the mock server will accept the next ingestion request with status 200
- **AND** the event queue contains events:
  | event | distinct_id |
  | Save  | user-123    |
- **WHEN** flush is called
- **THEN** the event queue should be empty after a successful flush

#### Scenario: HTTP client reports retryable failures without throwing to capture callers
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the mock server will fail the next ingestion request with status 503
- **WHEN** capture is called with event "Retry Me"
- **AND** flush is called
- **THEN** the call should not throw
- **AND** the event named "Retry Me" should remain queued for retry

### Requirement: Feature flag evaluation retry policy

The SDK SHALL apply a bounded, endpoint-specific retry policy to feature flag evaluation requests sent to `/flags` or an equivalent flag-evaluation endpoint. This policy is separate from the durable ingestion retry queue and applies to both client-side flag reloads and server-side direct flag evaluation when they use the remote flags endpoint.

A flag evaluation request SHALL retry only when the SDK did not receive an HTTP/API response because request execution failed with a transient transport condition, such as a network error, connection reset/lost, timeout, DNS/socket/TLS transport failure, or equivalent platform error. SDKs MAY also treat response-body read failures before a valid flags response is available as transport failures. SDKs SHALL NOT retry serialization/programming errors that occur before a valid request can be sent.

A flag evaluation request SHALL NOT retry any HTTP/API status response from the flags endpoint. This includes `408 Request Timeout`, `429 Too Many Requests`, every `5xx` response, and all other non-2xx statuses. Those responses SHALL be surfaced to the feature-flag caller/cache layer according to the SDK's normal flag error behavior without issuing another flags request for the same evaluation.

The default retry budget SHALL be one retry after the initial attempt (two total attempts). SDKs that expose a flag-request retry configuration SHALL interpret `0` retries as disabled and SHALL bound any configured retry count so the SDK never retries indefinitely.

Retries SHALL use exponential backoff starting at 300ms before the first retry, then 600ms before the second retry, doubling for each later retry. SDKs MAY cap the delay to an implementation-defined maximum to preserve bounded behavior. The retry SHALL resend the same flag evaluation endpoint, request body, and evaluation context as the failed attempt; it SHALL NOT enqueue a durable event or change feature-flag called tracking by itself.

#### Scenario: Flags request retries one transient transport failure by default (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current distinct id is "user-123"
- **AND** the next feature flag request will fail with a transient transport timeout before any HTTP response
- **AND** the following feature flag request will return feature flags:
  | key     | value |
  | beta-ui | true  |
- **WHEN** feature flags are loaded from the remote flags endpoint
- **THEN** exactly 2 feature flag requests should be sent
- **AND** the first retry should not be sent before 300ms have elapsed
- **AND** cached feature flags should include:
  | key     | value |
  | beta-ui | true  |

#### Scenario: Flags request does not retry HTTP status errors (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **AND** the next feature flag request will fail with HTTP status 503
- **WHEN** feature flags are loaded from the remote flags endpoint
- **THEN** exactly 1 feature flag request should be sent
- **AND** cached feature flags should still include:
  | key     | value |
  | beta-ui | true  |
- **AND** the call should not throw in normal client reload operation

#### Scenario: Zero configured flag retries disables retry (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and feature flag request max retries 0
- **AND** the next feature flag request will fail with a transient transport timeout before any HTTP response
- **WHEN** feature flags are loaded from the remote flags endpoint
- **THEN** exactly 1 feature flag request should be sent

#### Scenario: Configured flag retries use 300ms exponential backoff (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and feature flag request max retries 2
- **AND** the next 2 feature flag requests will fail with transient transport timeouts before any HTTP response
- **AND** the following feature flag request will return feature flags:
  | key     | value |
  | beta-ui | true  |
- **WHEN** feature flags are loaded from the remote flags endpoint
- **THEN** exactly 3 feature flag requests should be sent
- **AND** the first retry should not be sent before 300ms have elapsed
- **AND** the second retry should not be sent before 600ms have elapsed after the first retry
- **AND** cached feature flags should include:
  | key     | value |
  | beta-ui | true  |
