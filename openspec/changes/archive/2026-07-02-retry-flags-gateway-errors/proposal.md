## Why

The `/flags` retry policy already covers transient transport failures, but it currently treats every HTTP status response as terminal. Gateway/proxy failures such as `502 Bad Gateway` and `504 Gateway Timeout` are transient in practice and should receive the same bounded retry treatment as no-response transport failures.

## What Changes

- Treat HTTP `502` and `504` responses from `/flags` or equivalent flag-evaluation endpoints as retryable transient failures.
- Keep all other HTTP/API status responses terminal for flag evaluation, including `408`, `429`, `500`, `503`, and other non-2xx statuses.
- Add acceptance coverage that verifies `502` and `504` retry once by default and update the non-retry scenario to cover non-transient HTTP status errors.
- Preserve the existing retry budget, disabling behavior, exponential backoff, and same-request retry requirements.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `http-client`: Update the feature flag evaluation retry policy to include transient HTTP gateway statuses `502` and `504`.

## Impact

- Client SDKs that reload ambient feature flags from `/flags`.
- Server SDKs that perform direct feature flag evaluation via `/flags` or an equivalent flag-evaluation endpoint.
- Acceptance tests for feature flag transport retry classification.
