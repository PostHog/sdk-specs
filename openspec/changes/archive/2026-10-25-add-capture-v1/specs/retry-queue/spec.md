## Narrative alignment

When syncing this delta into the canonical `retry-queue` spec:

- In Behavior step 5, split the classification by wire. Legacy capture: retryable includes rate limits / `429`. Capture v1: retryable is exactly `404`, `408`, `429`, `500`, `502`, `503`, `504`, network errors and timeouts; `429` comes from a layer in front of capture and carries no `Retry-After` today, so its retries use the normal waits.
- In Behavior step 10 and the "adjusted batch size" State entries, mark batch shrinking on `413` as legacy behavior: on capture v1 `413` is terminal and byte-aware batching keeps requests under the body limit (see `event-batcher`).
- Leave the durable-queue, offline and acknowledgement requirements unchanged; they describe client SDKs with persistent queues and are not changed by capture v1.

## ADDED Requirements

### Requirement: Capture v1 status classification and attempt budget

An SDK that delivers events through capture v1 SHALL retry a capture request only on HTTP `404`, `408`, `429`, `500`, `502`, `503` and `504`, on a network error or timeout before a response is read, and for the `retry` entries of a 2xx `results` map. `404` and `429` are retried like the server errors so that a transient status (a route still rolling out, an edge rate limit) does not drop data; after the last attempt the batch is reported with that status. Every other response SHALL be terminal for the request, including `400`, `401`, `402` (billing limit; no per-event results, so every event in the request is reported lost), `413` and `415`. The SDK SHALL NOT fall back to a legacy endpoint on `404` and SHALL NOT split or halve the batch on `413`. A 2xx whose body is not a readable `results` map is terminal.

Each batch SHALL get at most four attempts by default (three retries), with the retry count configurable within a bounded range. The waits before the second, third and fourth attempts SHALL be 100 ms, 200 ms and 400 ms (100 ms doubling), each multiplied by a random factor in `[0.75, 1.25]`, and never above a 30 second ceiling. A `Retry-After` header SHALL raise the wait to at least its value, clamped to the ceiling, and the jitter SHALL never shorten it. `Retry-After` SHALL be honored on a retryable status and on a 2xx with `retry` entries. After the last attempt, every event still pending SHALL be reported as exhausted through the SDK's error surface. The SDK SHALL NOT keep the events for a later flush; the analytics and AI lanes of a capture v1 server SDK are in-memory queues, not durable queues.

Resends SHALL be SDK attempts, with the header rules in `capture`: the HTTP library's own retry mechanism SHALL be off for capture requests, because a library retry resends the stale `PostHog-Request-Timestamp` and attempt number.

Legacy capture: `429` was retried, several SDKs retried every `5xx`, and some shrank the batch on `413`.

#### Scenario: Retryable statuses are retried with doubling waits (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the mock serves these ordered analytics responses:
  | status   | body                                   |
  | <status> | {"error":"temporary"}                  |
  | <status> | {"error":"temporary"}                  |
  | 200      | {"results":{"*":{"result":"ok"}}}      |
- **WHEN** capture is called with distinct id "user-123" and event "Retry Me"
- **AND** pending captures are flushed
- **THEN** exactly 3 capture request should have been received
- **AND** the first inter-request delay should be at least 75 milliseconds and at most 125 milliseconds
- **AND** the second inter-request delay should be at least 150 milliseconds and at most 250 milliseconds
- **AND** all recorded request attempts should be consecutive integers starting at one
  Examples:
  | status |
  | 404    |
  | 408    |
  | 429    |
  | 500    |
  | 502    |
  | 503    |
  | 504    |

#### Scenario: Terminal statuses are not retried and are reported (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the mock serves these ordered analytics responses:
  | status   | body                                        |
  | <status> | {"error":"<error>"}                         |
  | 200      | {"results":{"*":{"result":"ok"}}}           |
- **WHEN** capture is called with distinct id "user-123" and event "Final"
- **AND** pending captures are flushed
- **AND** 2000 milliseconds elapse without a public SDK call
- **THEN** exactly 1 capture request should have been received
- **AND** the SDK should report the event "Final" as not delivered with status <status>
  Examples:
  | status | error                   |
  | 400    | request_parsing_error   |
  | 401    | invalid_api_token       |
  | 402    | billing_limit_exceeded  |
  | 413    | payload_too_large       |

#### Scenario: Retry-After raises the wait and jitter never lowers it (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the mock serves these ordered analytics responses:
  | status | headers           | body                                   |
  | 503    | Retry-After: 3    | {"error":"service_unavailable"}        |
  | 200    |                   | {"results":{"*":{"result":"ok"}}}      |
- **WHEN** capture is called with distinct id "user-123" and event "Wait"
- **AND** pending captures are flushed
- **THEN** exactly 2 capture request should have been received
- **AND** the first inter-request delay should be at least 3000 milliseconds

#### Scenario: Exhausted retries are reported after the last attempt (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1 and maximum retries 1
- **AND** the mock serves these ordered analytics responses:
  | status | body                                                          |
  | 200    | {"results":{"*":{"result":"retry","details":"not_persisted"}}} |
  | 200    | {"results":{"*":{"result":"retry","details":"not_persisted"}}} |
- **WHEN** capture is called with distinct id "user-123" and event "Never Stored"
- **AND** pending captures are flushed
- **THEN** exactly 2 capture request should have been received
- **AND** the SDK should report the event "Never Stored" as exhausted with details "not_persisted"
- **AND** a later flush should send no further request for "Never Stored"
