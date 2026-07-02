## Context

The current `http-client` spec applies a bounded retry policy to `/flags` requests, but only when the SDK does not receive an HTTP/API response. Cross-SDK investigation found most SDKs therefore do not retry `502` or `504`, while Python and Elixir already do through their HTTP client retry configuration.

## Goals / Non-Goals

**Goals:**
- Classify HTTP `502` and `504` from `/flags` as transient retryable failures.
- Keep retry behavior bounded by the existing retry budget and exponential backoff.
- Keep non-gateway HTTP status responses terminal for flag evaluation.

**Non-Goals:**
- Changing ingestion retry-queue behavior.
- Retrying every `5xx` response from `/flags`.
- Changing cache preservation or callback behavior after final failure.

## Decisions

- **Retry only `502` and `504` among HTTP statuses.** These statuses commonly represent upstream gateway/proxy timeouts or bad gateway responses and fit the transient-failure intent without broadening retries to every API/server response.
- **Keep `503` terminal.** `503` is deliberately not added so SDKs avoid amplifying service-level throttling or maintenance responses unless a future spec change decides otherwise.
- **Reuse existing budget/backoff.** Gateway-status retries use the same default one retry, `0` disables retries, and 300ms exponential backoff rules as transport retries.

## Risks / Trade-offs

- **Additional `/flags` request volume during gateway incidents** → bounded by the existing retry budget and backoff.
- **SDK divergence during rollout** → acceptance scenarios explicitly name `502` and `504` so SDK maintainers can align implementation and tests.
