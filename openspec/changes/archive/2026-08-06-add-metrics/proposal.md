## Why

PostHog's SDK metrics pipeline shipped but was never specified. Two implementations are live —
the `@posthog/core` engine in posthog-js (with `posthog-node`, `posthog-browser`, and
`posthog-react-native` as hosts of that one engine) and a deliberate mirror in posthog-python —
yet `openspec/specs/` has no `metrics` entry. Without a canonical contract, the next SDK to add
metrics (posthog-go, posthog-rs) has nothing to converge on, and the two existing
implementations can drift silently on the wire.

This is a **backfill**: unlike `traces`, the behavior already ships in two SDKs, so every
requirement is derived from real code. The posthog-python module is explicit that the shared wire
shape is intentional — its docstring states it "Mirrors the posthog-js core implementation so
every SDK speaks the same wire shape" — which makes a single shared spec the right model rather
than two independent per-language specs.

## What Changes

- **New capability `metrics`:** a platform-agnostic contract for statsd-style application metrics
  (counters, gauges, histograms) captured through the PostHog SDK. It covers the public
  `count`/`gauge`/`histogram`/`flush` API, in-memory pre-aggregation (one OTLP data point per
  series per flush window), delta temporality, series identity/canonicalization, the OTel-default
  histogram bucket bounds, OTLP AnyValue attribute encoding (including the NaN/Infinity proto3
  strings and integral-float→`intValue` rules), the resource/scope envelope, HTTP transport to
  `/i/v1/metrics` (gzip, `?token=`), the flush/serialize model, send-outcome classification and
  window merge-back, retry backoff and the drop budget, the `beforeSend` hook, reset, shutdown
  flush, the browser unload drain, configuration knobs, and the ingestion service's observed
  contract.
- Metrics is a **separate pipeline** from analytics events, session replay, logs, and traces:
  its own in-memory window, its own endpoint, its own flush timer — mirroring how logs and traces
  are modeled.
- **Scope of implementations described:** posthog-js `@posthog/core` (reference) plus its
  browser/node/react-native hosts, and posthog-python (mirror). **Not yet implemented** in
  posthog-go or posthog-rs — stated explicitly so the spec reads as their target, not a claim of
  existing coverage.

## Capabilities

### New Capabilities

- `metrics`: statsd-style pre-aggregating metrics capture and OTLP/HTTP export pipeline.

### Modified Capabilities

_None. The shared OTLP AnyValue attribute-encoding rules are restated in the `metrics` spec
(the metrics engine reuses the logs `toOtlpKeyValueList` encoder in posthog-js) rather than
cross-referenced, since each spec is standalone._

## Divergences carried into the spec (for human decision, not silently resolved)

The two implementations agree on the wire shape but diverge on operational policy. The spec names
a winner where one is clearly canonical and flags the rest as open:

1. **Retry backoff + drop budget (unresolved).** posthog-python re-arms the retry timer with
   capped exponential backoff (`interval * min(2^(failures-1), 64)`) and drops the buffered
   window after 8 consecutive failed flushes. The posthog-js metrics **engine** does neither — it
   re-arms at the base interval and leans on the host request layer (`fetchWithRetry` / browser
   retry queue) for transport backoff, with no engine-level drop budget. The spec states the
   Python policy as canonical and marks the JS gap as the open decision.
2. **gzip signalling.** posthog-python always gzips with a `Content-Encoding: gzip` header; the JS
   core transport does the same but allows a raw-JSON fallback when compression is disabled; the
   browser host signals gzip via a `?compression=` query parameter through the shared request
   layer. Same server outcome, three code paths.
3. **Opt-out gate.** The JS engine gates on `isDisabled || optedOut` from the host; posthog-python
   gates on `client.disabled` and additionally honours a `send=False` test mode. Expected
   client-vs-server difference, noted as an allowed variation.
4. **`beforeSend` return validation.** posthog-python re-validates the returned mapping and
   re-checks the metric type (a hook can change it); the JS engine trusts its typing and truthiness
   check.
5. **Config surface.** camelCase + `flushIntervalMs` (ms) in posthog-js vs snake_case +
   `flush_interval` (seconds) in posthog-python; posthog-python adds runtime config hardening
   because `client.metrics` sits outside the client's no-throw guards.
6. **Fork safety.** posthog-python resets its window on fork (`os.register_at_fork` + a PID
   guard); no equivalent in the JS engine.

## Impact

- `openspec/specs/metrics/spec.md` — created on archive from this change's delta.
- `openspec/project.md` — Capabilities section gains a line for the metrics pipeline.
- `README.md` — Capabilities table gains a Metrics row (`product` scope, like Logs and Traces).
- No SDK code changes; no backend change. The `/i/v1/metrics` endpoint is already shipped and
  serving both SDKs.
- Downstream per-platform port changes (`add-metrics-go`, `add-metrics-rs`, …) would implement the
  contract where metrics does not yet exist.
