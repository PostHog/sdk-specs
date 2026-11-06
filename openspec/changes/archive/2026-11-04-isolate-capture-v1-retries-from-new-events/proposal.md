## Why

The capture v1 header rules say a retry keeps `PostHog-Request-Id` and increments `PostHog-Attempt`, but they let a client SDK with a disk queue mint a new request ID and restart at attempt 1 when events captured during a backoff join the resend. Every capture v1 SDK has since settled on the stricter rule: a retry sends exactly the retried events, and newer events wait for their own request. posthog-python 8.0, posthog-go v2 and posthog-rs 1.0 retry inside one send loop, where the retry set only shrinks. posthog-android 4.0 keeps the retried queue files (`PostHogQueue.kt`, `retryFiles`), and posthog-ios 4.0 (PostHog/posthog-ios#1025) and posthog-flutter 6.0 on Windows and Linux (PostHog/posthog-flutter#704) do the same. Nothing in the spec or the harness parity suite pins this, so an SDK that mixes new events into a retry still passes.

## What Changes

- `capture` "Capture v1 request headers": drop the client SDK allowance to reset the request identity when a resend's events change. A retry resends exactly the retried events with the same `PostHog-Request-Id` and `created_at` and the next `PostHog-Attempt`; newer events go in a later request with a new ID and `PostHog-Attempt: 1`.
- Keep the in-memory fallback: when a retried event is no longer in the queue, after an app restart, or after a `413` halving, the client SDK starts a new request at attempt 1.
- Add scenarios for a whole-request retry and a per-event retry with an event captured during the wait, and for the eviction fallback.
- Add the two black-box scenarios to `migration/yaml-parity-v1/capture-analytics-v1-retry.feature`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture`: Capture v1 retries resend only the retried events and keep their request identity.

## Impact

Spec and acceptance coverage only. The rule matches the shipped and in-flight capture v1 SDKs, so no SDK change follows from it. The new parity scenarios use one step the harness does not bind yet (`the analytics capture requests should be, in order:`), so they cannot run until the harness adds it. The server only reads the request ID and attempt number for logs and metrics; skew correction uses `PostHog-Request-Timestamp`, which this change does not touch.
