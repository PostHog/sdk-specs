## Context

`add-capture-v1` let a client SDK with a durable disk queue start a new request identity when events captured during a backoff joined the resend. That was written while the client ports were still open. All of them now hold the retried queue entries apart and resend only those, the same as the server SDKs, except posthog-android 4.0's synchronous fatal-crash flush.

## Decisions

### A retry resends exactly the retried events

The retry carries the events of a batch that failed as a whole, or the `retry` events of a 2xx `results` map, and nothing newer. It keeps `PostHog-Request-Id` and `created_at` and increments `PostHog-Attempt`. Newer events go in a later request with a new ID and attempt 1. Keeping the two apart is what makes the request ID mean one batch in capture's logs and metrics.

### Retry identity lives in memory

A client SDK keeps the request ID, attempt number and `created_at` next to the queue entries it retries. If one of those entries leaves the queue (capacity eviction, a clear) or the app restarts, the SDK builds its next batch as usual at attempt 1. A synchronous fatal-crash flush may do the same, because delivering the crash before the process exits matters more than keeping one batch per request ID. The cost is only a reset attempt count: capture corrects skew from `PostHog-Request-Timestamp`, not from the request ID or attempt.

### Server and client SDKs satisfy one scenario

A server SDK's flush returns after its retries finish, so an event captured after the flush lands in a later request anyway. A client SDK's flush returns while the retry waits, so the event is queued before the retry goes out. The scenarios use a 5 second `Retry-After` and capture the second event 1 second after the flush returns, so on a client SDK it is queued during the wait even when the adapter's flush waits up to 2 seconds for acknowledgements. Both kinds must produce the same three requests.

## Harness gap

The parity scenarios need one new harness step, `the analytics capture requests should be, in order:`, with columns `events` (JSON list of event names), `posthog-attempt` (integer), `posthog-request-id` and `created_at` (labels: rows with the same label carry the same nonempty value, rows with different labels carry different values). It reads only `/i/v1/analytics/events` requests, and the number of rows is the exact number of those requests. The other steps exist today.
