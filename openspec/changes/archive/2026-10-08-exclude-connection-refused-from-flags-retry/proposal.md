## Why

The **Feature flag evaluation retry policy** requirement retries any transport failure that left
the SDK without an HTTP response: "a network error, connection reset/lost, timeout, DNS/socket/TLS
transport failure, or equivalent platform error". Read literally, that covers a refused
connection, but no SDK retries one:

| SDK | Retries a refused connection on `/flags`? | Where |
|---|---|---|
| posthog-js core (browser, node, react-native) | no | `isRetryableFlagsFetchError` returns `code !== 'ECONNREFUSED'` (`packages/core/src/posthog-core-stateless.ts:208-222`, PostHog/posthog-js#3961) |
| posthog-ios | no | `isRetryableFlagsError` retries only `NSURLErrorTimedOut` and `NSURLErrorNetworkConnectionLost` (`PostHog/PostHogApi.swift:478-484`) |
| posthog-android | no | PostHog/posthog-android#828 adds DNS and TLS retry and keeps `ConnectException` fail-fast |

The gap already caused a wrong remediation: the posthog-android compliance row asked for
`ConnectException` to be retried, and PostHog/posthog-android#828 had to back that out.

A refused connection means the destination actively rejected the request. Retrying it after
300ms rarely helps and only delays the flag error.

## What Changes

- The requirement states that a connection refused by the destination (for example
  `ECONNREFUSED` or `java.net.ConnectException`) SHALL NOT be retried and is surfaced as the flag
  error immediately. DNS, TLS, timeout, and connection reset/lost failures still retry.
- New scenario **Flags request does not retry a refused connection**: exactly one feature flag
  request is sent when the first request is refused before any HTTP response.
- The posthog-android compliance row (n22) no longer asks for `ConnectException` retry.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `http-client`: the **Feature flag evaluation retry policy** requirement.

## Impact

Descriptive only. Every SDK listed above already behaves this way, so no SDK has to change.

- **Acceptance adapters**: the new scenario uses the step `the next feature flag request will
  fail with connection refused before any HTTP response`. SDK test harnesses need a binding for it,
  modelled on the existing `transient transport timeout` step.
