## Why

PostHog's distributed tracing product is live: the `capture-logs` ingestion service accepts
OpenTelemetry spans at `POST {host}/i/v1/traces` (protobuf-first OTLP with a JSON fallback, the
same service, auth, and limits as logs), spans land in ClickHouse, and the product shipped to
beta on 2026-07-14. Today the only way to send spans is bring-your-own OpenTelemetry — the docs
explicitly say "you don't need any PostHog-specific packages." The Q3 client-libraries goal is
**first-class tracing in the PostHog SDKs**, starting with JavaScript and Python, following the
direction agreed with the APM team: no OpenTelemetry SDK dependency, but full conformance to the
OTel span model and OTLP wire format — the same play as logs.

No `traces` capability spec exists, so before writing SDK code we need the platform-agnostic
contract: the span API surface, ID and context rules, wire mapping, transport, batching, and the
ingestion service's observed behavior.

## What Changes

- **New capability `traces`:** a platform-agnostic contract for emitting distributed-tracing
  spans from PostHog SDKs. It covers the public span API (start/end, scoped helpers, error
  recording), W3C-conformant trace/span ID generation, active-span parenting and manual
  `traceparent` interop, the OTLP span data model and attribute encoding (shared with logs),
  PostHog auto-context attributes (`posthogDistinctId`, `sessionId`) that make PostHog traces
  joinable to persons and sessions, resource/scope identity, HTTP transport to `/i/v1/traces`
  (Bearer primary, `?token=` fallback; protobuf canonical, JSON fallback — matching the
  `update-logs-transport` decisions), compression, batching and flush, retry semantics, gating,
  configuration knobs, and the verified server-side contract.
- Traces is a **separate pipeline** from analytics events, session replay, and logs: its own
  queue, its own endpoint, its own flush cycle — mirroring how logs is modeled.
- **Not in scope for this change:** automatic instrumentation (HTTP/fetch/framework middleware),
  client-side sampling policy, span links as a public API, and durable on-disk span queues.
  These are deferred deliberately (see design.md) and would arrive as follow-up changes.
- **Explicitly distinct from two neighbors:** the `tracing-headers` capability
  (`X-POSTHOG-*` session/identity header propagation — a different, already-shipped feature that
  shares the word "tracing") and LLM analytics traces (`$ai_trace`/`$ai_span` via
  `/i/v0/ai/otel` — a different product with a different endpoint).

## Capabilities

### New Capabilities

- `traces`: span capture and OTLP/HTTP export pipeline for PostHog distributed tracing.

### Modified Capabilities

_None. (`logs` is untouched; the shared AnyValue attribute-encoding rules are restated in the
`traces` spec rather than cross-referenced, since each spec is standalone.)_

## Impact

- `openspec/specs/traces/spec.md` — created on archive from this change's delta.
- `openspec/project.md` — Capabilities section gains a line for the traces pipeline (prose
  alignment at archive).
- Downstream per-platform port changes (`add-traces-js`, `add-traces-python`, then others)
  implement the contract; JS first, Python second, per the agreed dogfooding order.
- The backend ingestion service (`rust/capture-logs`) is the source of truth for the transport
  and server-contract requirements; no service change is required. The ingestion endpoint is
  documented as subject to change before GA — if it moves, the transport requirement is updated
  through a follow-up change.
