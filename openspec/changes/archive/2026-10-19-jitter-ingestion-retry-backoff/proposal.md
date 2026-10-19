## Why

The `retry-queue` spec says only that a retryable failure is retried "after an exponential or
linear backoff delay". It says nothing about spreading those delays, so a fleet that fails
together retries together and arrives at the endpoint as one burst each time it recovers.

The `logs` and `traces` specs already state the rule for their lanes — "The SDK SHOULD jitter each
backoff delay, so clients refused together do not return together. The `Retry-After` floor applies
to the jittered delay." The ingestion lane has the same problem and no such requirement, and SDKs
are converging on the same answer without one:

| SDK | Jitter on ingestion retry waits | Where |
|---|---|---|
| posthog-js (browser retry queue) | yes, ±50% of the computed delay | `packages/browser/src/retry-queue.ts` |
| posthog-js (browser-next capture v1) | yes, factor in `[0.5, 1.5]`, clamped to the 30s ceiling, `Retry-After` applied as a floor afterwards | `packages/browser-next/src/capture-v1.ts` (`retryDelay`) |
| posthog-rs | yes, factor in `[0.75, 1.25]`, capped at `retry_max_backoff_ms`, `Retry-After` still the minimum | [posthog-rs#290](https://github.com/PostHog/posthog-rs/pull/290) (merged 2026-10-18) |
| posthog-go | `Backoff` takes a jitter ratio; `DefaultBackoff()` passes `0` | `backoff.go` |
| posthog-python, posthog-node, posthog-ios, posthog-android | no | — |

posthog-rs#290 had to derive the shape itself, including that the jittered wait stays under the
ceiling and that `Retry-After` stays a floor, because the contract does not state them.

## What Changes

- Adds one `retry-queue` requirement, **Ingestion retry backoff is jittered**, stating the rule the
  `logs` and `traces` specs already state for their lanes: jitter SHOULD scale the SDK's own
  computed delay, SHALL stay within the configured ceiling, and SHALL NOT move a retry earlier than
  a `Retry-After` the endpoint sent.
- Says explicitly that jitter replaces neither the schedule nor the ceiling, and that an SDK with
  no usable source of randomness uses the unjittered delay.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `retry-queue`: adds the **Ingestion retry backoff is jittered** requirement.

## Impact

- The requirement is a SHOULD, matching the `logs` and `traces` wording. posthog-js and posthog-rs
  already satisfy it; posthog-go has the mechanism and would only change a default; the remaining
  SDKs are unaffected until they choose to adopt it.
- The base delay schedule is deliberately left alone. Ingestion backoff bases still differ across
  SDKs (posthog-python 1s doubling, posthog-go and posthog-rs 100ms, posthog-js capture v1 3s) and
  settling that is a separate change.
- No acceptance feature scenarios are added; the scenarios here are spec-level only.
