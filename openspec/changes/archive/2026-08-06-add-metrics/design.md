## Context

Metrics shipped in two SDKs before it was specified, so — unlike `traces` — this spec **describes
shipped behavior**, and every requirement traces to code that runs in production. There are two
verifiable sources, in priority order:

1. **The posthog-js `@posthog/core` engine** — the reference implementation:
   - `packages/core/src/metrics/index.ts` — the `PostHogMetrics` aggregator: `count`/`gauge`/
     `histogram`/`flush`/`drainWindow`/`reset`, folding, the series cap, the flush serializer,
     window snapshot/merge-back, and send-outcome handling.
   - `packages/core/src/metrics/metrics-utils.ts` — `DEFAULT_HISTOGRAM_BOUNDS`, `seriesKey`,
     `bucketIndexFor`, `msToUnixNano`, and the resource/envelope builders.
   - `packages/core/src/metrics/{types.ts,config.ts}` — `MetricsHost`, the resolved-config shape,
     defaults (`flushIntervalMs` 10000, `maxSeriesPerFlush` 1000), and the
     `resourceAttributes`-wins resolution.
   - `packages/core/src/posthog-core-stateless.ts` — `_sendMetricsBatch`: builds
     `${host}/i/v1/metrics?token=…`, gzips, and classifies the send outcome (413→too-large,
     retryable→retry-later, else fatal).
   - `packages/core/src/logs/logs-utils.ts` — `toOtlpKeyValueList` / `toOtlpAnyValue`, the shared
     AnyValue encoder the metrics module reuses (bool-before-int, integral-float→intValue,
     non-finite→proto3 string, null→omit).
   - `packages/types/src/capture-metric.ts` — the shared `Metrics` / `MetricSample` /
     `CaptureMetricOptions` / `BeforeSendMetricFn` types and the OTLP wire types.
   - Host surfaces: `packages/browser/src/posthog-metrics.ts` (`METRICS_ENDPOINT =
     '/i/v1/metrics'`, `?token=`, sync `drainWindow`/`sendBeacon` unload path, browser
     status-code classification), and `packages/node/src/client.ts` (`client.metrics`, `this` as
     the `MetricsHost`, shutdown flush). posthog-react-native hosts the same engine.
2. **posthog-python** — the deliberate mirror:
   - `posthog/metrics_capture.py` (class `PostHogMetrics`), wired via `client.metrics` in
     `posthog/client.py`; the module docstring pins the intent ("Mirrors the posthog-js core
     implementation so every SDK speaks the same wire shape").
   - `posthog/test/test_metrics.py` — asserts the exact wire shape (delta+monotonic sums, gauge
     with no `startTimeUnixNano`, histogram `count`/`bucketCounts` as ints and bounds equal to
     `DEFAULT_HISTOGRAM_BOUNDS`, `intValue`/`boolValue`/`doubleValue` encoding, the endpoint URL,
     series-cap and merge-back behavior, resource-attribute layering, `send=False`, and shutdown
     flush).

## Goals / Non-Goals

**Goals:**

- Capture the shared wire contract once (endpoint, OTLP envelope, delta temporality, bucket
  bounds, AnyValue encoding, series canonicalization) so a third SDK can be built to match.
- Describe the two existing implementations as **one engine with host surfaces plus one mirror**,
  not three-plus independent ports.
- Record operational divergences explicitly for human decision rather than silently picking a
  winner where neither is obviously right.

**Non-Goals:**

- Changing any SDK behavior. This is documentation of what ships.
- Specifying posthog-go / posthog-rs metrics — they have none yet; the spec is their target.
- A cross-SDK conformance/acceptance suite. Per the repo's product-pipeline precedent (`logs`
  and `traces` ship no `acceptance/*.feature` files — those directories cover public/private SDK
  API behavior, not product pipelines), metrics adds none either; a conformance matrix is a
  follow-up once a third implementation exists to compare.

## Decisions

**Capability named `metrics`.** Parallel to `logs` and `traces` (name the signal, match the
endpoint `/i/v1/metrics`).

**One shared spec, per-language exceptions inline.** The posthog-python docstring makes the shared
contract intentional, so the spec states the contract once and notes divergences as exceptions on
the affected requirement, exactly as the repo's product-pipeline specs handle platform variation.

**Divergences surfaced, not resolved (see proposal "Divergences").** The one that matters for
correctness is the **retry backoff + drop budget**: Python bounds a real outage (capped 64×
backoff, drop after 8 consecutive failures ≈ 21 min at 10s); the JS engine re-arms at the base
interval and delegates transport backoff to the host request layer with no engine-level drop. The
spec states Python's policy as canonical and flags the JS gap, because an unbounded engine-level
retry that never drops is the riskier default. This is called out for the client-libraries team,
not silently reconciled.

**AnyValue encoding restated, not cross-referenced.** The metrics engine literally reuses the logs
`toOtlpKeyValueList` encoder in posthog-js, but each spec is standalone, so the rules
(bool-before-int, integral-float→`intValue`, non-finite→proto3 `"NaN"`/`"Infinity"`/`"-Infinity"`,
null→omit, keys stringified) are restated in the metrics spec. Note these encode `intValue` as a
JSON **number** here (both metrics impls), and histogram `count`/`bucketCounts` are JSON numbers
too — pinned by an upstream OTLP deserializer bug (opentelemetry-rust#3328) that silently drops
string-encoded u64s in those fields.

**No per-user context is a requirement, not an omission.** Both implementations deliberately
attach no distinct id / session id to metrics — per-user attributes are the canonical
metrics-cardinality explosion — so the spec makes the absence normative.

**Delivery is at-least-once.** Both implementations retry a window whose response was lost, which
can double-count that window's deltas. The spec states this as an accepted trade-off (loss is
worse than double counting for delta metrics) rather than a bug.

## Risks / Trade-offs

- **The JS engine has no window-level drop budget** → a permanently unreachable endpoint retries
  the same window every interval indefinitely (bounded only by the series cap on memory). Captured
  as the headline divergence; the spec's canonical policy is Python's bounded one.
- **This spec is a backfill of shipping code** → low risk of aspirational invention (the repo's
  main constraint); the residual risk is describing an accidental behavior as canonical, mitigated
  by pinning each requirement to code and, for the wire shape, to `test_metrics.py` assertions.
- **Hand-rolled OTLP can drift between the two SDKs** → the shared-wire intent is documented in
  code and the Python tests assert the exact bytes; a golden-fixture cross-check is the natural
  follow-up when a third SDK lands.

## Open Questions

- **Should the JS metrics engine adopt Python's capped-backoff + 8-failure drop budget, or is the
  host-request-layer split (Node `fetchWithRetry`, browser retry queue) the intended design?** —
  for @PostHog/team-client-libraries. The spec currently names Python's policy canonical and flags
  the JS engine as diverging.
- **gzip signalling** — three code paths reach the same server outcome (header vs `?compression=`
  query param vs raw fallback). Worth converging, or is the browser's preflight-avoiding
  query-param path a permanent platform exception like it is for logs?
