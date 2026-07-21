## Context

Distributed tracing is live server-side and the SDKs have nothing. Unlike prior specs in this
repo, there is **no shipped SDK implementation to describe** — so every requirement here traces
to one of four verifiable sources, in priority order:

1. **The ingestion service** — `rust/capture-logs` on `posthog/posthog` master (verified by
   reading the source, 2026-07-20): routes in `src/main.rs` (`/v1/traces`, `/i/v1/traces`,
   2 MB `DefaultBodyLimit` from `MAX_REQUEST_BODY_SIZE_BYTES`, default 2097152), handler
   `export_traces_http` and JSON/JSONL parsing in `src/service.rs`, per-span row shaping in
   `src/trace_record.rs`, OTLP/JSON hex-ID fixtures in `tests/traces_test.rs`.
2. **Public standards** — the OpenTelemetry trace data model / OTLP encoding and the W3C Trace
   Context spec. The agreed direction (APM team, 2026-06-11) is "OTel spec without the OTel
   dependency," so where the SDK-facing behavior has no PostHog precedent, OTel semantics are
   the canonical choice.
3. **The shipped logs pipeline** — the `logs` capability spec plus the shipped logs/metrics SDK
   engines, which the APM team named as the template ("just like we did for logs"). Transport,
   encoding-preference, gating, retry, and config-vocabulary requirements deliberately mirror
   `logs` (as amended by `update-logs-transport`).
4. **The logs product's person-join convention** — logs SDKs auto-attach `posthogDistinctId`,
   and the logs product reads it via a configurable attribute key defaulting to
   `posthogDistinctId` (`products/logs/backend/models.py`). Trace↔person/session linking is on
   the tracing roadmap but not yet wired in `products/tracing/`; adopting the same keys now is
   what makes that wiring possible without an SDK change later.

## Goals / Non-Goals

**Goals:**

- Define the canonical, platform-agnostic contract for PostHog-native span capture and export,
  sufficient to implement `add-traces-js` and `add-traces-python` without further design work
  on the pipeline itself.
- Zero OpenTelemetry runtime dependency; full OTLP wire conformance so existing server-side
  tooling (and PostHog's own trace UI) sees no difference from an OTel SDK.
- Make PostHog traces PostHog-shaped from day one: `posthogDistinctId` / `sessionId` span
  attributes so traces join to persons, sessions, and logs.

**Non-Goals (deferred, with reasons):**

- **Auto-instrumentation** (fetch/HTTP/framework middleware): the highest-value follow-up, but
  it is platform-specific and belongs in per-platform port changes once the manual API exists.
  The manual API is the contract auto-instrumentation will sit on.
- **Client-side sampling:** the product is beta, pricing is unsettled, and the server applies
  quota (`traces_mb_ingested`) per project. A sampler API frozen now would be guesswork;
  `beforeSpanSend` plus the queue cap are the v1 pressure valves. Revisit when pricing lands.
- **Span links as public API:** ingestion accepts links into the Kafka row (verified in
  `trace_record.rs`), but the product neither stores a links column nor queries/renders them;
  the wire mapping reserves them without exposing API.
- **Durable span queues:** v1 targets browser JS, Node, and Python server processes, where an
  in-memory queue is the norm (OTel batch processors are in-memory everywhere). Mobile ports
  can propose persistence as a platform deviation if needed — that is where logs' durable queue
  earns its keep, and spans may make a different tradeoff even there.

## Decisions

**Capability named `traces`, not `tracing`.** Parallel to `logs` (both name the signal, not the
activity), matches the endpoint (`/i/v1/traces`), and avoids collision with the existing
`tracing-headers` capability, which is an unrelated shipped feature. The product name in prose
remains "distributed tracing."

**No OTel dependency; OTLP hand-rolled.** Confirmed direction from the APM team (2026-06-11:
"not depending on otel, still using the otel spec"; initial example in posthog-js, Python second
for full dogfooding). Precedent: the logs engine removed its OpenTelemetry dependencies
(posthog-js #3717, #3895) and metrics shipped hand-rolled OTLP in both SDKs (posthog-js #4115,
posthog-python #739). The spec therefore defines the wire shape explicitly rather than saying
"do what OTel does."

**Transport mirrors `update-logs-transport`, not the original logs spec.** The traces handler is
literally the same service and code path family as logs: `Authorization: Bearer` checked first,
`?token=` fallback; protobuf decoded first, JSON (object or JSONL) fallback; gzip sniffed by
magic bytes with the `?compression=` query-param translation layer. Verified directly in
`export_traces_http`. So Bearer + protobuf are canonical from day one, with JSON + `?token=` as
the documented fallbacks (browser SDKs realistically start on JSON).

**Queue overflow drops NEW spans (OTel semantics), diverging from logs' drop-oldest.** Logs
drops oldest-first because a log line is self-contained and the newest lines are the most
diagnostic. A span queue is different: the oldest queued spans are completed parents whose
children may already be exported; dropping them breaks assembled traces retroactively. OTel's
BatchSpanProcessor drops incoming spans when full, keeping already-captured trace structure
intact, and since OTel semantics are our canonical fallback where PostHog has no precedent, the
spec follows it and requires a dropped-span counter warning. This is a deliberate, documented
divergence from the logs template.

**Auto-context is `posthogDistinctId` + `sessionId` (+ platform URL/screen), not the full logs
set.** Same wire keys as logs so the product's configurable join key works unchanged across
signals, snapshot at span start, user attributes win on collision. `feature_flags` (which logs
attaches) is excluded from v1: span volume is multiplicative (every operation, not every log
call) and a flag-key array on every span is weight without a stated product use; a follow-up
change can add it if the tracing product grows flag-aware analysis.

**Errors recorded OTel-style.** Scoped helpers set status `error` and attach an `exception` span
event (`exception.type`, `exception.message`) and then **rethrow the application's exception** —
the SDK-never-throws rule applies to the SDK's own failures, never to swallowing app control
flow. Python already reads active-span context into `$trace_id`/`$span_id` on
`capture_exception` (posthog-python #743); once the SDK owns the active span, that linkage
becomes first-party.

**Timestamps: wall-clock start, monotonic duration.** `startTimeUnixNano` is wall-clock at
`startSpan`; `endTimeUnixNano` is start + a monotonically-measured elapsed time where the
platform has a monotonic clock (`performance.now()`, `time.perf_counter_ns()`), so durations
survive wall-clock jumps. String-encoded nanos on the JSON wire, matching logs and the server's
test fixtures.

**The server's whole-request 400 makes client-side validity the SDK's job.** Verified: one
malformed span (e.g. a timestamp that overflows i64) fails `KafkaTraceRow::new` and 400s the
**entire request**, dropping every span in the batch. The spec therefore requires SDKs to emit
only well-formed spans (valid IDs, in-range timestamps) rather than leaning on server
tolerance, and classifies 400 as non-retriable poison.

**Competitor-informed API alignment (verified against current Sentry v8+ and dd-trace docs,
2026-07-20).** The industry has converged and the spec deliberately matches it: callback-first
scoped API as the recommended form (Sentry `startSpan(cb)`, Datadog `tracer.trace(name, fn)`),
auto error-recording in the callback form, `getActiveSpan`, explicit parent override, OTLP
status codes, and route-template span names (Sentry/OTel convention; Datadog's name/resource
split is the outlier and even its OTel bridge maps away from it). Two competitor features are
adopted into v1 because they are hard to retrofit: `updateName` (a low-cardinality name is
often only knowable after routing resolves — without it our own instrumentation could not
satisfy the cardinality requirement) and a caller-supplied `startTime` (backdating). Names
reserved for future changes, NOT in v1: a `tracePropagationTargets`-style allowlist for
`traceparent` auto-injection (MUST be allowlist-gated when it ships; shape it consistently
with posthog-js's existing `tracing_headers` domain allowlist so the SDK doesn't grow two
divergent allowlists), `sampleRate` + `sampler` for the pricing-era sampling change (Sentry's
two-knob shape, mutually exclusive), and `onlyIfParent` (orphan-noise control). Sentry's
top-level hook is literally `beforeSendSpan`, which independently validates our
`beforeSpanSend` naming against the alternative of reusing logs' nested `beforeSend`.

**Adversarial-review resolutions (implementer-simulation + contradiction-hunt passes,
2026-07-20).** The spec was hardened against two independent hostile reviews; the decisions
they forced, beyond wording fixes:

- **Activation model**: only scoped helpers activate a span; manual `startSpan` returns an
  inactive handle (OTel/Sentry `startInactiveSpan` model). Kills the browser async-context
  ambiguity for manual spans.
- **No context type in v1**: `parent` is a union — span handle or raw `traceparent` string.
  The traceparent string is the serialized context; a third concept adds surface without
  power.
- **`beforeSpanSend` fails closed** (a throwing hook drops the span) — a deliberate,
  documented divergence from logs' fail-open `beforeSend`, forced by designating the hook as
  the PII scrubbing point: a broken scrubber must not leak the unscrubbed record.
- **`maxSpanAgeMs` age eviction** complements `maxLiveSpans`: without it, a span leak
  permanently disables tracing for the process (every later `startSpan` no-ops forever).
  Eviction is a novel mechanism (neither OTel nor logs has one) accepted as the price of the
  live-span bound.
- **Client-side validity is its own requirement** with a concrete sanitize-at-end checklist
  (empty name → `unknown`, unrepresentable timestamps → now, end&lt;start → zero duration),
  because the server 400s a whole batch on one bad span and `startTime` accepts arbitrary
  caller input.
- **Events share the span's clock basis** (monotonic offset from start), so event timestamps
  provably land inside the span window even across wall-clock jumps.
- **Auto-context keys are exempt from the attribute caps** — they are the product's join
  keys; letting user attributes evict them would break the person/session join silently.
- **Further documented divergences from the logs template**: no separate flush-threshold
  knob (`maxExportBatchSize` doubles as depth trigger — OTel batch-processor model);
  full-nanosecond timestamp precision from monotonic sources (vs logs' `ms * 1e6` rule — no
  intra-ms ordering bump needed since waterfalls sort by offset); `app.state` retained on
  mobile (parity with logs after review caught its accidental omission); the 413
  ramp-back-up SHOULD restored to match logs.
- **Wire `flags`**: the low byte carries W3C trace flags with sampled set; OTel's extra OTLP
  flag bits (has-is-remote masks) are allowed but not required — the server stores and
  ignores `flags` today, so byte-exact OTel parity is not load-bearing.

**SDK integration points verified (posthog-js + posthog-python origin/main, 2026-07-21).**
The spec's assumptions about existing SDK machinery were checked against both first-target
repos:

- **Request context exists on both platforms** — Node: `AsyncLocalStorage`-based
  `PostHogContext` with `posthog.getContext()?.distinctId/.sessionId`, fed by
  Express/NestJS middleware reading `x-posthog-distinct-id`/`x-posthog-session-id`; Python:
  `contextvars`-based `posthog/contexts.py` with `get_context_distinct_id()` /
  `get_context_session_id()`, fed by the Django middleware. Caveat for the Python port:
  only Django ships header-reading middleware today — Flask/FastAPI users wire the context
  API themselves, so traces auto-context inherits that coverage boundary.
- **Logs trace correlation is caller-passed only** — no ambient fill exists; the
  "logs SHOULD carry the active span's ids" requirement is new logs-engine work in the JS
  port, not free.
- **Unified flush is aspirational in shipped SDKs** — the logs spec's own "global `flush()`
  includes logs" SHALL is only cleanly true on React Native today (browser drains logs on
  unload/shutdown and has no public `flush()`; Node has no logs pipeline at all). The traces
  requirement matches the canonical target, and each port change inherits the same
  flush-unification work item logs already carries.
- **Engine wiring pattern**: identity/session reach the logs engine via a
  `() => context` constructor callback (`LogSdkContext`), not via `LogsHost` methods — the
  traces engine mirrors the callback approach. Config lands as `traces?: TracesConfig` on
  `PostHogConfig`, exactly parallel to `logs?:`/`metrics?:`.
- **Python exception seam is clean** — `client.py` assembles exception properties as a dict
  spread including `_get_current_otel_span_properties()`; a posthog-native active-span
  source slots in as a sibling spread (decide precedence: native vs foreign OTel span).
- **Gzip raw-fallback is real and lands on React Native** — `isGzipSupported()`
  feature-detects `CompressionStream`; the send path already omits `Content-Encoding` and
  sends raw when unavailable, matching the spec's allowance.

## Risks / Trade-offs

- **The ingestion endpoint may move before GA** (the docs say so explicitly) → transport is
  isolated in a single requirement so a move is a one-requirement follow-up change; SDK ports
  ship the feature as explicitly pre-GA/opt-in config.
- **One malformed span 400s the whole batch server-side, silently losing every span in it** →
  the spec makes client-side validity a SHALL (well-formed IDs, in-range timestamps) and
  classifies 400 as non-retriable poison so the queue never wedges; residual loss surfaces via
  the dropped-span warning.
- **No durable queue in v1: a crash or closed tab loses queued spans** → bounded exposure via
  the flush interval and the web beacon-on-unload trigger; accepted for v1 (matches OTel
  processors everywhere) and revisitable per platform in port changes.
- **Browser has no reliable async context, so active-span parenting can mis-nest across
  awaits** → the limitation is a documented allowed variation, and the explicit `parent`
  option is the escape hatch.
- **Hand-rolled OTLP can drift from the OTel spec over time** → mirror the logs approach of
  golden wire-format fixtures in each SDK (as posthog-js did for logs) and lean on the
  server's own test fixtures as the reference encoding.
- **This spec precedes any shipped SDK implementation, unlike the repo norm of describing
  shipped behavior** → every requirement is pinned to the verified server contract, public
  standards, or the shipped logs/metrics template (see Context), and the Open Questions below
  go to the APM team on the spec PR before archive.

## Resolved by research (2026-07-20, evidence noted; no team input needed)

- **Operations aggregation is (service_name, span name).** Verified: the flat operations
  rollup is `GROUP BY service_name, name`
  (`products/tracing/backend/aggregation_query_runner.py:278`); the tree view groups on the
  parent/child name edge. The spec's low-cardinality-name requirement is therefore load-bearing,
  not stylistic.
- **No prior posthog-js tracing prototype exists on GitHub.** Exhaustive search of posthog-js
  branches/PRs/commits, Jon's PRs across the org, and PostHog example repos found nothing —
  every "tracing"/"span" hit is LLM analytics or `tracing_headers`. The "initial example" was
  never PR'd; treat the SDK work as greenfield (worth one Slack aside asking Jon if he still
  has local code, but nothing blocks on it).
- **Empty `service.name` renders as a literal blank today.** Nothing anywhere maps empty →
  `unknown_service` or renders a placeholder: ingestion stores `""`
  (`rust/capture-logs/src/trace_record.rs` via `extract_string_from_resource`), the
  operations table renders the raw value, and the facet rail just filters empty strings out
  of selections. The spec's `unknown_service` default therefore strictly improves the UI
  (visible label instead of a blank cell) with no server change needed.
- **Quota drops happen after a 200, with no signal.** Over-quota spans are accepted by
  capture and dropped in the downstream Kafka consumer (`TracesIngestionConsumer` →
  `filterQuotaLimitedMessages`, Redis set `@posthog/quota-limits/traces_mb_ingested`); the
  capture-side `TokenDropper` is a static env-var list (`DROP_EVENTS_BY_TOKEN`), not dynamic
  quota. The spec's server contract now states a 200 is not proof of ingestion. Billing
  plumbing shipped in quotahog#39.
- **Span links are dead weight today.** Accepted at ingest into the Kafka row, but nothing in
  the product stores a links column, queries, or renders them. Reserving them at wire level
  with no v1 API is the right call; nothing on the visible roadmap needs them.
- **Endpoint is de-facto stable.** No PR or issue anywhere proposes moving `/i/v1/traces`; it
  is wired into prod ingress charts for US/EU, documented across seven language guides and
  the beta blog post, and the product went beta on 2026-07-14. The docs' "endpoint may change
  before GA" caveat appears stale. Treat as stable; a courtesy confirm rides along on the PR.

## Open Questions

The genuinely-open items for the APM team, raised on the spec PR or a Slack thread linking to
it (#team-apm / @jonmcwest, @frankh), resolved before archive:

- **Join-key spelling — one or both?** For logs, Jon ruled (Slack, 2026-06-02) that the
  product should read **both** `posthogDistinctId` and `posthog_distinct_id`, with docs
  steering to a recommended spelling; the logs config default is still `posthogDistinctId`
  and the traces product has no person-link config of its own yet.
  **Recommendation: emit `posthogDistinctId` only.** Emitting both duplicates bytes on every
  span under per-MB billing; the product side reads both spellings and its key is per-team
  configurable, so a later org-wide rename is a config/docs change while an SDK emit change
  is a slow multi-platform migration. One camelCase key also matches logs SDKs today.
- **Rate cap:** logs has a client-side tumbling-window cap; v1 traces relies on the queue cap
  only. **Recommendation: no client rate cap for traces, ever — sampling instead.** A
  tumbling-window cap drops random spans mid-trace, producing partial waterfalls that mislead
  more than they save; the trace-shaped volume control is head-based, parent-consistent
  sampling (whole traces kept or dropped), deferred to the pricing conversation.
  `maxQueueSize`, `maxLiveSpans`, and `beforeSpanSend` are the v1 pressure valves.
- **Capture-side quota signal:** quota is currently a silent post-200 drop.
  **Recommendation: no SDK change either way; if a capture-side signal lands before GA, shape
  it as 429 + `Retry-After`.** The spec's retry table already honors that combination with
  bounded retries, so every conformant SDK would gain backoff with zero SDK releases.
- **Remote config:** will remote config eventually gate tracing?
  **Recommendation: the manual `startSpan` API is never remote-gated (parity with
  `captureLog`); reserve a remote key for future auto-instrumentation only**, mirroring how
  `logs.captureConsoleLogs` gates console autocapture. Agreeing the key shape now costs
  nothing in v1 and avoids a breaking change when instrumentation ships.
- **Server-side span limits:** the service currently has no per-span cap.
  **Recommendation: client caps stay at OTel's 128/128 as primary enforcement; if the server
  adds limits, truncate-and-annotate (like its timestamp clamping) rather than reject** — a
  per-span reject would create a second whole-request-400 failure mode.
- **Courtesy confirms:** `/i/v1/traces` stability (research says stable; the docs caveat
  looks stale — consider removing it), and that rendering `unknown_service` for unnamed
  services is acceptable to the UI (today those rows render blank).
