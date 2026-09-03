## Why

Implementing `Retry-After` on the three OTLP export queues in `posthog-js`
([PostHog/posthog-js#4726](https://github.com/PostHog/posthog-js/pull/4726)) surfaced three places
where the canonical contract either says the opposite of what the SDKs do, or says too little to
keep them from diverging. All three are decisions every SDK has to make, so they belong in the
spec rather than in each implementation's judgement.

**1. `Retry-After` is a floor in some SDKs and a replacement in others, and the two specs word it
differently.** The `logs` spec says the canonical backoff is "honoring `Retry-After` when present
**and otherwise** exponential backoff capped at ~30s" — replacement semantics. The `traces` spec
says "retry with exponential backoff capped at ~30s, **honoring `Retry-After` when present**" —
which reads as additive. The shipped SDKs have split accordingly:

| SDK | Rule | Cap on the header |
|---|---|---|
| posthog-rs (`retry::backoff_duration`) | floor | own ceiling, `retry_max_backoff_ms` (default 30s) |
| posthog-python (`capture_v1._backoff`) | floor | own ceiling, `_MAX_BACKOFF_SECONDS` (30s) |
| posthog-go (`client.backoffV1`) | floor | none |
| posthog-ios (`PostHogQueue`) | `max(backoffDelay, retryAfter)` — floor | none |
| posthog-android (`PostHogQueue.calculateDelay`) | `retryAfterSeconds` **replaces** the backoff | none |
| posthog-js (#4726) | floor | a single 5 min constant across all three queues |

Five of the six floor; posthog-android is the lone outlier. On clamping, the two SDKs that do it
share a rule rather than a number — *clamp the header to the ceiling the caller already configured
for its own backoff* — which posthog-rs states outright: "a hostile/buggy server header can't push
a single wait past the ceiling the caller already configured."

Replacement is the weaker rule: a `Retry-After: 1` on a queue that has already backed off to 30s
turns it into a hot loop, which is the opposite of what the header is for. HTTP semantics are "not
before this", which a floor satisfies in both directions.

**2. Three of the six SDKs place no bound on the header at all**, so a misconfigured proxy — the
realistic source of a `429`, since PostHog capture does not emit one — can strand a queue for
hours. The two that do bound it agree on the rule and on the value; posthog-js bounds it too, but
at ten times that value, because its three signals have three different backoff ceilings and it
uses one constant for all of them.

**3. The `traces` spec forbids the overflow mechanism a reviewer has since asked for.**
*Batch assembly and concurrency* names "the reactive 413 path (**not proactive byte measurement**)
as the overflow mechanism". But the server applies `MAX_REQUEST_BODY_SIZE_BYTES` (2 MB) to the body
*after* decompressing it, so a batch measured over that can only ever come back 413 — and the
halving loop then spends a request on each progressively smaller attempt.

This is not a unilateral SDK decision. Reviewing the traces MVP
([PostHog/posthog-js#4579](https://github.com/PostHog/posthog-js/pull/4579)), @jonmcwest measured
the cost and asked for the check by name:

> **Ask: add a client-side size check before the POST.** `_sendOtlpBatch` already serializes the
> payload, and the client knows the ~2MB server cap. Treat a single span whose serialized size
> exceeds the cap as too-large, without a send. That removes every redundant upload and most of the
> halving churn.

He measured a span carrying one multi-MB attribute being uploaded up to 11 times before the halving
loop isolates and drops it, with 35–47 POSTs to drain a full 512-span queue around it, and the
sticky shrink then needing ~480 healthy batches to ramp back up. The spec sentence predates that
request.

Separately, the `traces` *Server-side contract* requirement still describes
[posthog/posthog#75090](https://github.com/PostHog/posthog/pull/75090) as "in flight". It was closed
as stale in August 2026 without merging, and nothing has replaced it.

## What Changes

- **`Retry-After` becomes a floor, explicitly, in both specs.** The SDK SHALL wait the longer of its
  own backoff and the header. This aligns the `logs` wording with the `traces` wording and with the
  five SDKs that already floor; posthog-android's replacement rule becomes a documented deviation
  to migrate.
- **The header gets a bound.** The SDK SHALL clamp the parsed value to a documented maximum. The
  spec fixes the *requirement* to clamp and leaves the value to the SDK. The recommended default is
  the rule posthog-rs and posthog-python already share — clamp to the ceiling the SDK configured for
  its own backoff — but it stays a SHOULD, because an SDK whose signals have different backoff
  ceilings (posthog-js: ~30s for traces, ~64× the flush interval for logs, none for metrics) cannot
  express that as one constant, and a short-lived process (serverless, a mobile background window)
  is served by a tighter bound than a long-running one.
- **Both wire forms are required.** `Retry-After` is delta-seconds *or* an HTTP-date; an SDK that
  parses only the first silently ignores the second. Unparseable values, a date in the past, and
  non-positive deltas SHALL fall back to the SDK's own backoff rather than to zero.
- **Proactive byte measurement becomes permitted** in `traces` — as a complement to the reactive 413
  path, not a replacement for it. The 413 path stays mandatory: a proxy can lower the limit and a
  self-hosted deployment can raise it, so the SDK's constant is never authoritative.
- **The `#75090` reference is corrected** to record that quota enforcement at capture was abandoned,
  and that the realistic source of a `429` is a proxy, CDN or load balancer in front of capture.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `traces`: the **Error handling and retries** requirement (floor semantics, clamp, both wire
  forms), the **Batch assembly and concurrency** requirement (proactive measurement permitted), and
  the **Server-side contract** requirement (the `#75090` sentence).
- `logs`: the **Error handling and retries** requirement, so its `Retry-After` sentence matches
  `traces` instead of reading as replacement.

## Impact

**This is not a breaking change to shipped SDKs; it moves the canonical target ahead of the
implementations.** On merge, three SDKs stop conforming: posthog-android (replaces the backoff
rather than flooring it, and applies no clamp), and posthog-ios and posthog-go (floor correctly but
apply no clamp). None of them changes behavior because this merges, and none needs to land first —
each migrates in its own change, tracked in `tasks.md` §4. Stating the winner where SDKs diverge is
what this repo is for.

- `openspec/specs/traces/spec.md` and `openspec/specs/logs/spec.md` — source of truth, updated via
  this change's delta on archive.
- `metrics` has no spec of its own; posthog-js applies the same policy to its metrics queue.
- **posthog-android** is the one shipped SDK that contradicts the clarified rule (replacement, no
  clamp). Migrating it is a behavior change to its retry timing and belongs in its own change.
- **posthog-ios** and **posthog-go** already floor but apply no clamp; both need one.
- **posthog-rs** and **posthog-python** already implement both halves and need no change.
- **posthog-js** #4726 implements the clarified rule for logs, metrics and traces, and is the origin
  of this proposal. Its 2 MB pre-send check is the proactive measurement this change permits. It
  clamps with a single 5-minute constant rather than per-queue ceilings — conformant, since the
  per-queue rule is a SHOULD, and recorded here so the divergence is visible rather than silent.
- No service change is required. The `retry-queue` and `http-client` capabilities already describe
  `Retry-After` as transport metadata the queue consumes; neither pins the semantics, so neither
  needs a delta.
