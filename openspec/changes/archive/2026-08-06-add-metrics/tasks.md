## 1. Verification (grounding checks — every requirement traces to shipped code)

- [x] 1.1 Verify the aggregation engine (folding, series cap, flush serializer, snapshot/reset,
  merge-back, drainWindow, reset, generation guard) in
  `posthog-js/packages/core/src/metrics/index.ts`
- [x] 1.2 Verify the wire helpers (`DEFAULT_HISTOGRAM_BOUNDS`, `seriesKey`, `bucketIndexFor`,
  `msToUnixNano`, resource/envelope builders) in
  `posthog-js/packages/core/src/metrics/metrics-utils.ts`
- [x] 1.3 Verify defaults and config resolution (10000ms flush, 1000 series cap,
  `resourceAttributes`-wins) in `posthog-js/packages/core/src/metrics/{config.ts,types.ts}`
- [x] 1.4 Verify transport + outcome classification (`${host}/i/v1/metrics?token=…`, gzip,
  413→too-large, retryable→retry-later, else fatal) in
  `posthog-js/packages/core/src/posthog-core-stateless.ts` (`_sendMetricsBatch`)
- [x] 1.5 Verify the shared AnyValue encoder (bool-before-int, integral-float→intValue,
  non-finite→proto3 string, null→omit) in `posthog-js/packages/core/src/logs/logs-utils.ts`
  (`toOtlpAnyValue` / `toOtlpKeyValueList`)
- [x] 1.6 Verify the browser host (`METRICS_ENDPOINT = '/i/v1/metrics'`, `?token=`,
  sync `drainWindow`/`sendBeacon` unload path, status-code classification) in
  `posthog-js/packages/browser/src/posthog-metrics.ts`, and the node host (`client.metrics`,
  `this` as `MetricsHost`, shutdown flush) in `posthog-js/packages/node/src/client.ts`
- [x] 1.7 Verify the posthog-python mirror (folding, backoff `2^(n-1)`×interval capped at 64×,
  drop after 8 consecutive failures, fork reset, config hardening, `send=False` discard) in
  `posthog/metrics_capture.py`, and the asserted wire shape in `posthog/test/test_metrics.py`
- [x] 1.8 Confirm the shared-contract intent is documented in code — the
  `posthog/metrics_capture.py` module docstring ("Mirrors the posthog-js core implementation so
  every SDK speaks the same wire shape")
- [x] 1.9 Confirm metrics is absent from posthog-go and posthog-rs (scope statement in the spec)

## 2. Spec delta

- [x] 2.1 Review `specs/metrics/spec.md`: every requirement has ≥1 scenario and every behavioral
  claim matches the verified source above
- [x] 2.2 Every cross-implementation divergence is named on its requirement (not silently
  resolved): retry backoff/drop budget, gzip signalling, opt-out gate, `beforeSend` validation,
  config surface, fork safety
- [x] 2.3 Applicability tags applied (`@both` for the shared contract, `@client` for the
  browser-only unload drain)

## 3. Prose alignment (applied at archive)

- [x] 3.1 Add a Purpose section to `openspec/specs/metrics/spec.md` (logs/traces-style):
  metrics as a separate pipeline (own window, `/i/v1/metrics`, own flush timer), the one-engine +
  host-surfaces + Python-mirror derivation, and the go/rs not-yet-implemented scope
- [x] 3.2 Add the metrics pipeline to the Capabilities list in `openspec/project.md`
- [x] 3.3 Add a Metrics row to the Capabilities table in the top-level `README.md`
  (`product` scope, like Logs and Traces)

## 4. Validation

- [x] 4.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 4.2 Apply + archive to create `specs/metrics/spec.md`

## 5. Downstream follow-up (separate changes, not this one)

- [ ] 5.1 Resolve the retry-backoff divergence with @PostHog/team-client-libraries — either bring
  the JS metrics engine to Python's capped-backoff + 8-failure drop budget, or ratify the
  host-request-layer split explicitly
- [ ] 5.2 `add-metrics-go` / `add-metrics-rs` — implement the contract where metrics does not yet
  exist
- [ ] 5.3 Add metrics to the cross-SDK conformance tracking (golden wire fixtures) once a third
  implementation exists to compare
