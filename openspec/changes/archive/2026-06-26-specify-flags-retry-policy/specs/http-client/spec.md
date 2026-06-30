## ADDED Requirements

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
