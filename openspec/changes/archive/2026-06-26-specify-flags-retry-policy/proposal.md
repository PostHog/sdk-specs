## Why

The SDK specs currently state that feature flag reload failures should not crash and should preserve existing cached flags, but they do not specify the retry policy for `/flags` feature flag evaluation requests. SDKs have diverged on whether to retry HTTP status failures, how many retries to perform by default, and what backoff schedule to use.

Recent cross-SDK alignment established the canonical behavior: retry only transient network/transport/timeout failures, never retry an HTTP/API response status, use one retry by default, allow retries to be disabled, and wait 300ms before the first retry with exponential doubling.

## What Changes

- Add an HTTP-client requirement for `/flags` feature flag evaluation retry policy.
- Specify transient-only retry classification: network, transport, timeout, and equivalent no-HTTP-response failures are retryable.
- Specify that HTTP/API status responses are terminal for flag evaluation, including 408, 429, and 5xx.
- Specify default retry budget of one retry, configurable where the SDK exposes the option, with zero disabling retries.
- Specify bounded exponential backoff: 300ms before the first retry, 600ms before the second, doubling thereafter.
- Specify that retries resend the same flag evaluation context/payload and do not enqueue durable events.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `http-client`: Adds canonical `/flags` feature flag evaluation retry behavior.

## Impact

- Client SDKs that reload ambient feature flags from `/flags`.
- Server SDKs that perform direct feature flag evaluation via `/flags` or equivalent flag-evaluation transport.
- Acceptance tests for feature flag transport retry classification and backoff timing.
