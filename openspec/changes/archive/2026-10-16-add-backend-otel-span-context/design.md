# Design

## Context

See proposal.md for the problem. The native traces capability already names the join attributes and freezes context at span start. Request-context integrations need a compatible path for application-owned spans, including spans created before middleware extracts headers.

## Goals / Non-Goals

The bridge reads the same request context used for analytics capture. It does not introduce another identity store, a tracer provider, a trace exporter, or background-job transport. Outgoing HTTP propagation and Rust request-context APIs are separate changes tracked in issue #128.

## Decisions

- Reuse the existing tracing-headers capability because this extends request-context integration, not the native span API.
- Enrich an existing request span after extraction, and use a documented optional processor or platform listener for future children. A start-only processor misses incoming spans that precede middleware.
- Keep setup specific to each platform. SDKs must not replace application-owned tracing infrastructure to make enrichment work.
- Preserve explicit attributes and context snapshots. Do not enrich at export time from whichever request is active then.
- Treat inherited execution context as insufficient after the original scope ends. A scope lifetime marker can prevent detached tasks from leaking stale identity while preserving attributes on spans that started during the request.
- Keep new Gherkin scenarios descriptive until the shared harness has real adapter bindings. Do not add integration selection tags based on local SDK tests alone.

## Risks / Trade-offs

- Middleware order can hide the incoming span. Test a real span started before the PostHog context.
- Runtime context propagation can outlive a request. Test detached work with explicit synchronization, as well as concurrent requests.
- Existing application identity conventions differ. Each SDK must state which keys it respects; do not silently impose the AI processor's contract on general spans.
- SDK APIs and releases will differ. Archive the specification change on this branch, then keep implementation and release progress in issue #128.
