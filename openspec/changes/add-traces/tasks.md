## 1. Verification (grounding checks before this change is approved)

- [x] 1.1 Verify the ingestion routes, auth order, body limit, and decode order by reading
  `rust/capture-logs/src/{main.rs,service.rs}` on `posthog/posthog` master
- [x] 1.2 Verify per-span shaping (ID zeroing, timestamp clamp + `$originalTimestamp`,
  attribute stringification, scope flattening, `service.name` extraction, whole-request 400)
  in `rust/capture-logs/src/trace_record.rs`
- [x] 1.3 Verify OTLP/JSON hex-ID + string-nano encoding via `rust/capture-logs/tests/traces_test.rs`
- [x] 1.4 Verify the logs person-join key convention (`posthogDistinctId`, configurable) in
  `products/logs/backend/models.py`
- [x] 1.5 Empirical smoke test against production (2026-07-20): Bearer/JSON, gzip, `?token=`
  all 200; missing token 401; **invalid token 200** (finding folded into the server-contract
  requirement); trace rendered correctly in the project 2 waterfall UI
- [ ] 1.6 When opening the spec PR, put the design.md Open Questions (with their
  recommendations) to #team-apm — on the PR or in a Slack thread linking to it

## 2. Spec delta

- [x] 2.1 Review the `specs/traces/spec.md` delta: every requirement has ≥1 scenario, and every
  server-behavior claim matches the verified source above
- [x] 2.2 Adversarial review pass (implementer-simulation + contradiction hunt, 2026-07-20):
  15 ambiguities and 13 findings resolved — see design.md "Adversarial-review resolutions"
- [x] 2.3 Review deferred scope (auto-instrumentation, sampling, span links API, `feature_flags`
  auto-context) is stated in the proposal as future changes, not silently missing
- [x] 2.4 Canonicality review pass (2026-07-21): repo-convention conformance (requirements
  split to sibling-spec length, design-notes pointers inlined, scenario style normalized) and
  all-platform coverage (mobile background flush trigger, explicit-context variation for Go,
  sync/async helper overloads for Kotlin/Swift, error-value platforms, in-memory-on-mobile
  deviation documented, continuous-clock rule)

## 3. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [ ] 3.1 Add a Purpose section to `openspec/specs/traces/spec.md` (logs-style, 2-3
  paragraphs): traces as a separate pipeline (own queue, `/i/v1/traces`, own flush), distinct
  from `tracing-headers` and LLM analytics, plus derivation provenance ("derived from the
  Rust `capture-logs` ingestion service, verified empirically against production 2026-07-20,
  and the logs pipeline as template — spec precedes the first SDK implementation")
- [ ] 3.2 Add the traces pipeline to the Capabilities list in `openspec/project.md`
- [ ] 3.3 Add a Traces row to the Capabilities table in the top-level `README.md`
  (`product` scope, like Logs)

## 4. Validation

- [ ] 4.1 Run `openspec validate --strict` and resolve any errors
- [ ] 4.2 Run `/opsx:apply` then `/opsx:archive` to create `specs/traces/spec.md`

## 5. Downstream follow-up (separate changes, not this one)

- [ ] 5.1 `add-traces-js` — implement in posthog-js (shared core engine + browser/node
  hosts), the agreed first platform. Known prerequisites from integration verification:
  `traces?: TracesConfig` on `PostHogConfig`; engine takes a `() => context` callback like
  `LogSdkContext` (not `LogsHost` methods); ambient trace-id fill for `captureLog` is new
  logs-engine work; browser needs a public traces flush path (no public `flush()` exists);
  first golden wire fixture = the 2026-07-20 smoke-test payload
- [ ] 5.2 `add-traces-python` — implement in posthog-python for full dogfooding, second.
  Known prerequisites: auto-context reads `posthog/contexts.py`
  (`get_context_distinct_id`/`get_context_session_id`; header middleware is Django-only
  today); wire the native active span into the `client.py` exception-property spread
  alongside `_get_current_otel_span_properties()` (decide native-vs-OTel precedence)
- [ ] 5.3 Propose auto-instrumentation and `traceparent` auto-injection per platform once the
  manual API ships
- [ ] 5.4 Revisit sampling and a client-side rate cap when tracing pricing lands
- [ ] 5.5 Add traces to the cross-SDK conformance tracking (README conformance-matrix TODO /
  `acceptance/` features) once two implementations exist to compare
