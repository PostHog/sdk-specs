# Native local evaluation amendment v1

The checksummed `inputs/local-evaluation-v1.ts` follows capture-amendment-v1 and
flag-semantics-v1 in the effective negotiated identity. The frozen catalog,
180 public routes, their argument/result types and client callbacks are unchanged.
A peer with only the prior two amendments is rejected before fixture allocation.

## Native public reload, not synthetic readiness

For the independently declared SDK feature `feature_flags_local_evaluation_v1`,
`/reload_feature_flags` can invoke the SDK's native public definitions refresh.
This does not change a client's remote evaluation reload into a definitions load.
A host without the relevant genuine public method reports `unsupported_binding`.

Read-only source evidence: `posthog-js/packages/node/src/client.ts:2392–2393`
implements public `reloadFeatureFlags(): Promise<void>` using
`featureFlagsPoller.loadFeatureFlags(true)`. The poller's
`extensions/feature-flags/feature-flags.ts:744–765` can swallow loading errors;
its already-loaded readiness at 771–772 is not evidence of a fresh fetch.
Accordingly each migrated reload explicitly invokes `/reload_feature_flags` and
`/wait_for_local_evaluation_ready`, within one real monotonic 5000ms deadline,
and separately requires a new authenticated definitions HTTP 200 after the
barrier starts. Old readiness, HTTP 304, installed fixture data and cached
snapshots cannot replace that successful fetch. Both modern `/flags/definitions`
and legacy `/api/feature_flag/local_evaluation` paths (with optional trailing
slash) are accepted. Definitions bytes must pass through the native HTTP loader.

Setup maps source `personal_api_key` to `config.secret_key` without supplying
preload, cache, polling or other omitted defaults. The source project token and
personal key are fixture-only placeholders. Local selection depends on public
getter discovery plus the independent local-evaluation feature, not on runtime,
wire API or inferred SDK type. Missing supporting public reload/readiness methods
remain explicit gaps. No client/server type restriction is added to these four
originally untyped source cases.

## Native per-invocation provenance

The optional `flags.evaluation_provenance.v1` capability adds
`evaluation_provenance(call_id)` to the existing bounded flags-state fixture.
The response names the owning fixture, exact call, flag key and concrete native
instrumentation site. A `local` or `remote` conclusive record includes the actual
boolean/string result; `fallback` and `not_evaluated` carry no invented value.

Record the native evaluator's result inside the owning invocation context.
For example, Node's `client.ts:1266–1295` calls
`computeFlagAndPayloadLocally`, then sets `flagWasLocallyEvaluated` from the
actual result. That is a possible observation seam, not an implemented Node
fixture. Public call counters, local-only inputs and absent HTTP are insufficient.
No implicit `/get_feature_flag_result` call or public return metadata is allowed.

The runner requires the exact fixture/call/key/value and local classification
for every getter, plus a conclusive plain public boolean/string and zero remote
evaluation traffic across initialization, reloads and getters. The original
explicit expected-value assertions retain their equality semantics. There are
119 getters and eight reload barriers, not JSON-corpus execution.

Records belong only to their fixture and live invocation IDs. Unknown or foreign
IDs cannot borrow another observation. Missing instrumentation is
`blocked_fixture`; mismatched attribution is a harness failure. Observation is
read-only, bounded by the supplied real deadline and does not evaluate a flag.
Dispose records, context hooks and pending work at fixture close. The observer
shapes are part of the checksummed amendment and therefore negotiated identity.

## Evidence boundary

The sibling harness's `tests/v2_local_parity_host.py` owns a controlled HTTP loader
and the narrow exact/is_not person/group/cohort evaluator required by these four
cases. It is not a real SDK adapter or the broader 358-case canonical evaluator.
The mock serves typed definitions, never expected-result lookup tables. All
native SDK, existing-adapter, packaging and distribution gates remain separate.
