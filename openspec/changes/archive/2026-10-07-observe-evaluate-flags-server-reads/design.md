## Context

The canonical evaluate-flags spec defines reusable server snapshots, silent payload lookups, and lazy access tracking. The existing Gherkin uses private clock/storage/queue fixtures and transport receiver references. Draft2 supports JSON arguments and native outcomes, but its client explicitly rejects receiver references.

Node already provides `evaluateFlags(distinctId, options?)`, `snapshot.isEnabled(key)`, `snapshot.getFlag(key)`, and `snapshot.getFlagPayload(key)`. The public snapshot getters report access through the SDK itself. The evaluation object is not a JSON record.

Inspected sources:
- Node `packages/node/src/client.ts:2270`: evaluation, identity/options resolution, local/remote selection, and native snapshot construction.
- Node `packages/node/src/feature-flag-evaluations.ts:127-161`: native enablement/value/payload getters.
- Node `packages/node/src/__tests__/evaluate-flags.spec.ts`: existing getter, payload, and dedupe unit coverage.
- Harness `v2/flag_steps.py:80-121`, `v2/client.py:167-175`, and Node `compliance/node/v2/binding.mjs:161`: the existing reference-based steps and current boundary.
- Harness `v2/remote_flag_steps.py`: mock-service flag traffic and legacy getter assertions.

## Goals / Non-Goals

**Goals:**
- Black-box coverage of the expanded remote-read matrix against a real Node package in CJS/ESM × capture v0/v1.
- One public evaluation per compound request; ordered public getters on that request's native snapshot.
- Observe exact remote-request counts and caller identity, native getter outcomes, and flushed exposure delivery.
- Preserve every existing authored scenario, including unbound advanced snapshot behavior.

**Non-Goals:**
- Local definitions/fallback, cache/refresh/concurrency behavior, malformed payloads, runtime filters, cross-request snapshot retention, snapshot capture enrichment, standalone compatibility getter coverage, and generic capture coverage.

## Decisions

### Request-scoped compound binding

Add `/evaluate_flags/read`. Its JSON arguments are:

```json
{
  "distinct_id": "snapshot-user",
  "options": {"only_evaluate_locally": false},
  "reads": [
    {"method": "is_enabled", "key": "checkout"},
    {"method": "get_flag", "key": "checkout"},
    {"method": "get_flag_payload", "key": "checkout"}
  ]
}
```

The adapter awaits the public evaluation method once, holds the returned object in a local variable, invokes the listed public getters in order, then releases that local reference when the request completes. Each independent request performs its own evaluation using its own identity/options.

Support `is_enabled`, `get_flag`, `get_flag_payload`, `keys`, `only`, and `only_accessed`. Key enumeration maps to the native public method/property and takes no flag key. Explicit-key filtering calls the SDK's public only(keys) equivalent and executes a nested read list against that returned snapshot. An empty `reads` array means evaluate without accessing values or payloads. SDK configuration, argument spelling, and optional argument presence are translated without manufacturing flag results or events. Node option names map to `groups`, `personProperties`, `groupProperties`, `onlyEvaluateLocally`, `disableGeoip`, and `flagKeys`; preserve nested JSON and false/zero values. Native option omission remains omission. For is_enabled reads, an optional per-read options object maps default_value to the native supported caller-default argument (Node: defaultValue). Omit that getter argument when omitted, and preserve explicit false. The caller-default scenario requires the declared flag_snapshot_enablement_default SDK capability. A missing binding remains an explicit optional-capability gap, not a requirement that every SDK implement defaults. Never synthesize caller-default behavior in the adapter.

The compound binding is an adapter operation, not an SDK return-object schema. Its successful outcome has an ordered collection of getter outcomes:

```json
{
  "kind": "sdk",
  "outcome": {
    "kind": "value",
    "value": {
      "results": [
        {"kind": "value", "value": true},
        {"kind": "value", "value": "control"},
        {"kind": "undefined"}
      ]
    }
  }
}
```

Each element uses the existing outcome kinds, preserving JSON null versus native undefined and strict boolean/number distinctions. Scalar getters retain their native values. A rich getter result can use an explicitly documented projection of its public fields/methods; it is not inferred by truthiness or by serializing private object state. A native evaluation or getter throw follows the existing thrown-outcome path and fails acceptance. Unknown read methods/unsupported parameter mappings remain visible binding gaps. JSON representation failures remain visible fixture gaps.

This operation is sufficient to exercise multiple reads on one snapshot without extending the transport. The legacy `/evaluate_flags` and reference-based snapshot steps retain their existing behavior.

### Request-local explicit-key filtering

An `only` operation contains `keys` and a nested `reads` list:

```json
{
  "method": "only",
  "keys": ["checkout", "missing"],
  "reads": [
    {"method": "keys"},
    {"method": "get_flag_payload", "key": "checkout"}
  ]
}
```

The adapter invokes the native public filter on the current snapshot and executes those reads against its returned object in the same request. The operation's result is a nested `{"results":[...]}` collection of read outcomes. Subsequent sibling reads still operate on the original parent snapshot. An empty nested list still invokes the filter. An empty keys list is passed to the native filter and must produce an empty child.

This lets one request observe the original, filtered child, and original again through public accessors. The SDK, not the adapter, chooses which keys/values survive. Request-time `options.flag_keys` remains distinct: it scopes evaluation before snapshot creation; `only` filters an already-created snapshot.

The canonical in-memory filtering requirement explicitly defines `only(keys)`, unknown-key dropping/warnings, and silent filtering. Source inspection confirms Node `only`, Python `only`, .NET `Only`, Go `Only`, and Java `only`; this is a representative audit, not runtime coverage of every SDK.

### Request-local accessed-key filtering

An `only_accessed` operation invokes the snapshot's public accessed-key filter and runs its nested read list against the returned object:

```json
{
  "method": "only_accessed",
  "reads": [{"method": "keys"}]
}
```

The same nested-result representation and sibling-parent rules apply as for `only`. Selection comes entirely from the SDK's public filter; the adapter does not maintain its own accessed-key set.

Verify that no value/enablement access yields an empty filtered key set, even after payload reads and enumeration. After real value/enablement reads, only present accessed flags survive, including disabled flags; unknown accessed keys and payload-only keys do not become selected flags. Reads on an explicit-key child must not change the original parent's accessed-key selection. Inspect both selections through public filters/key enumeration, never private state.

The canonical spec requires empty-before-access behavior. Node, Python, and Go sources inspected so far implement that rule. The .NET checkout at 8966a5f returns all flags from `OnlyAccessed()` when none were accessed (`Features/FeatureFlagEvaluations.cs:125`), contrary to the existing canonical requirement. A separate .NET SDK fix is needed before that implementation can earn opt-in for this case; the Node acceptance slice neither weakens the rule nor modifies the .NET repository.

### Safe empty snapshots and supported defaults

Caller-default testing is conditional on the SDK exposing that public option. The Node binding translates:

```json
{"method":"is_enabled","key":"missing","options":{"default_value":true}}
```

Test default omission and explicit false/true. A present disabled flag must return false even with default true; a present enabled boolean/variant must remain enabled with default false. A missing-key default changes the returned enablement, not the canonical missing-value accessor or missing-key tracking metadata. Repeated reads continue to use the SDK's existing canonical-value dedupe.

Missing-identity testing uses a fresh instance without request identity/context and invokes the SDK's native no-identity overload; the adapter preserves omission instead of inventing an ID. Public keys/value/enablement/payload/filter operations are safe and empty/nullish as appropriate. Neither evaluation nor access/flush may send a remote evaluation request or delivered exposure.

Disabled-SDK testing uses the public disabled constructor configuration with explicit identity. The same public snapshot operations remain safe/empty, with no remote evaluation or delivered exposure. The adapter still invokes the SDK; it does not implement its own disabled guard or empty result.

Remote-failure testing uses no local definitions, a controlled HTTP 503 flag response, and public `feature_flags_request_max_retries: 0` configuration (Node: `featureFlagsRequestMaxRetries`). Generic capture `max_retries` is a different option and must not be substituted. The mock must observe the failure, and one initial evaluation attempt is allowed. Evaluation returns its native safe empty snapshot without throwing/rejecting to the caller; public getters/filters must not start another request.

With a valid identity, value/enablement reads on that original failed-evaluation snapshot are attempted missing-key accesses under the existing canonical tracking contract. After explicit flush, require one deduped missing-key exposure, not blanket event silence. Its missing response sentinel and ancillary evaluation-error details can follow the documented platform representation. Payload-only/enumeration/filter reads remain silent.

### Public result shapes and exposure semantics

Read selectors express public semantics, not a requirement that every SDK return Node-shaped scalars. Bindings document the precise public methods/fields used to project a rich result. Enablement, canonical boolean/variant value, payload representation, key identity where available, and native absence are checked without requiring optional evaluation metadata.

Representative source audit (read-only; not runtime verification):
- Node at bfd24befe: snapshot `isEnabled` returns bool, `getFlag` returns bool/string/undefined, `getFlagPayload` returns decoded JSON/undefined, and `keys` is a public property. The separate `getFeatureFlagResult` API returns a structured result.
- Python at e61a95b: snapshot `get_flag` returns a scalar or None; separate `FeatureFlagResult` exposes key/enabled/variant/payload/reason and public `get_value()`.
- .NET at 8966a5f: snapshot `GetFlag` returns `FeatureFlag?`, exposing public Key, IsEnabled, VariantKey and Payload; `GetFlagPayload` returns a JsonDocument or null; Keys is public.
- Go at 08549f4: snapshot `GetFlag` returns a scalar or nil, `GetFlagPayload` returns a validated serialized JSON string or empty string, and Keys is a public method. Its separate `FeatureFlagResult` exposes Enabled/Variant/RawPayload and `GetPayloadAs`.

The shared harness must have an explicit binding-declared representation for scalar versus rich values and decoded versus serialized payloads, using existing capability negotiation. Node declares scalar values and decoded JSON payloads. Controlled hosts exercise the supported rich-result and serialized-payload interpretations. Do not guess whether a string is serialized JSON; valid JSON-looking string payloads must remain strings for decoded-JSON getters. A wrong return shape for the binding's declared API is a failure.

Public getter calls on the evaluated snapshot remain the source of truth. A rich result's public projections must not trigger another evaluation, substitute an independent getter, or hide a wrong enabled/variant value. In particular, payload-only selection must call the snapshot's public payload accessor: implementing it as GetFlag(key).Payload would introduce exposure in SDKs where GetFlag records access. Public key enumeration must also stay independent of value getters. Standalone FeatureFlagResult-returning APIs have their own evaluation/tracking timing and stay in a separate capability slice.

Exposure matrix, verified after explicit public flush:
- Evaluation-only, payload-only, key-enumeration, and snapshot-filter requests without value/enablement reads: no exposure.
- Enabled boolean and variant value/enablement reads: one exposure per identity/group/key/canonical response, including repeated mixed reads.
- Disabled flag reads: an exposure with response false.
- Missing-key value/enablement reads with explicit identity: a deduped missing-key exposure identifying flag_missing; its response may follow the documented platform sentinel.
- Independent identities/groups: separate exposures even for the same key/value.
- Missing identity or publicly disabled SDK: no delivered exposure, even after value/enablement access.
- Failed remote evaluation with a valid identity and value/enablement reads: deduped missing-key access exposure; payload/enumeration/filter operations do not add exposure.

Node's inspected snapshot options do not expose the standalone getter's `sendFeatureFlagEvents` switch. The adapter must not implement a synthetic suppression option. Explicit tracking controls, where exposed by another public API, belong to that API's coverage.

### Observable scenarios

Expand the existing evaluate-flags feature:
1. Remote boolean and variant reads, including boolean value reads and repeated mixed variant access. Check ordered results, one remote request, and one flushed exposure per accessed flag with canonical response and caller identity.
2. Disabled, variant, and missing projections, plus exact deduped exposures for those three keys and missing-key error metadata. Do not require one platform's missing response sentinel.
3. Remote evaluation with no reads; public flush delivers no exposure.
4. Repeated nested payload reads, a known flag without payload, and a missing flag; exact documented payload semantics and no exposure.
5. Valid scalar/string payload examples: false, zero, JSON null, an ordinary string, and a JSON-looking string. Preserve type and decoding boundaries; payload reads remain silent.
6. Sequential compound requests for distinct identities/group contexts with the same key/value. Observe independent evaluations and correctly contextualized results/exposures; never reuse the previous request's snapshot. Do not require remote cache invalidation for repeated identical contexts.
7. Evaluation context/options forwarding. Check provided groups/person/group properties and GeoIP choice in received remote traffic, preserve nested false/zero values, and verify retained group context on delivered exposure.
8. Nonempty request-time key scope. Observe the requested wire key list and only those keys through public enumeration; enumeration/payload reads remain silent.
9. Explicitly empty request-time key list. Public enumeration returns no keys; public flush produces no exposure and the mock receives no remote evaluation request. Do not claim private cache/local evaluator observations.
10. Explicit-key filters with a retained key, duplicate retained key, and unknown key; also an empty filter. Inspect child keys/payloads and reread parent keys/payloads. Unknown keys are absent, duplicates do not duplicate keys, the parent remains unchanged, and filtering/enumeration/payload reads add no remote requests or exposure after flush.
11. Read retained enablement/value projections through a filtered child, then through the original parent. Retained child values/payloads and original unfiltered keys remain correct; normal exposure tracking applies to value reads, with shared dedupe across child and parent. Do not require a platform-independent exposure policy for reading excluded child keys.
12. Before value/enablement access, onlyAccessed returns no keys, including after payload reads and key enumeration. Public flush delivers no exposure; filters add no remote requests.
13. After value/enablement reads, onlyAccessed selects present used flags, including a disabled flag, but excludes payload-only and unknown accessed keys. Read a new key through a separate only child and compare child/parent accessed filters through public key enumeration. Parent selection is unchanged; emitted exposure follows the requested value reads, not filtering.
14. Supported caller defaults: omitted/false/true on a missing key, true against a present disabled flag, and false against present enabled/variant flags. Preserve canonical value and deduped exposure independently of the returned default.
15. Missing identity/context: public snapshot reads and filters return safe empty/false/nullish results; explicit flush yields no remote evaluation or exposure.
16. Publicly disabled SDK with explicit identity: the same safe empty results, no remote evaluation, and no delivered exposure after flush.
17. Failed remote evaluation with retries publicly disabled: observe one HTTP 503 attempt, safe empty projections and filters, no accessor-triggered retry, and one flushed deduped missing-key exposure for requested value/enablement access.

Use fresh SDK/receiver isolation and a public flush threshold larger than the small exposure count. Move the feature-wide legacy setup into its existing scenarios, preserving order, applicability, outlines, and capability tags. Add the new setup independently. Legacy `@server` applicability becomes per-scenario where necessary; integration tags are earned only after real SDK verification.

The harness stores only request arguments and returned scalar/JSON outcomes for assertions. SDK getters own enablement, variant selection, payload access, accessed-key tracking, and dedupe. The SDK owns exposure event construction and delivery.

### Validation and submission

Controlled hosts must expose defects in ordered results, scalar/rich public projections, declared payload representations, JSON types, missing-value kinds, identity/group context, request options/key scope, filter membership, accessed-key selection, and parent preservation, payloads, duplicate/missing/mistyped exposures, missing-key metadata, exposure during silent reads, stale cross-request results, and extra evaluation traffic. Native method spies must prove one evaluation, ordered genuine getter/filter calls, correct native parent/child receivers, fresh evaluation per request, argument/omission fidelity, and faithful throws/results. Prove exact forwarding of caller-default arguments, missing identity overloads, disabled configuration, and flag-specific retry configuration. Controlled hosts must fail for defaults overriding present values, invented identities, disabled guards returning fabricated results, failure-to-exercise errors, accessor retries, or incorrect safe-empty exposure. SDK-native integration tests observe public console/logger warnings for unknown filter keys where supported; the shared traffic assertions establish dropping and silence, not warning delivery through the transport.

Build fresh Node tarballs and a consumer from the pinned source; run every new matrix execution before opt-in. After tagging, run the entire acceptance suite in all four configurations. Repeat against a clean committed bundled harness distribution.

Use one fresh, read-only post-implementation reviewer after the parent finishes the scoped work. The parent validates findings and integrates fixes.

## Risks / Trade-offs

- Existing peer implementation may disagree with canonical empty-before-access filtering → preserve the rule and require a separate SDK fix before peer opt-in.
- Compound operations cannot test an earlier snapshot after a later request changes context → keep cross-request snapshot stability and capture reuse in the advanced slice.
- SDK dedupe may be mistaken for adapter dedupe → method spies require every requested getter to execute; controlled traffic tests and real SDK delivery establish the observed outcome.
- A JSON-shaped result can conceal type or missing-value mistakes → compare native outcome kinds and use recursive JSON equality.
- A moment without traffic is not proof of no exposure → use explicit public flush before negative event assertions.
- Controlled hosts do not establish SDK conformance → gate integration tags on the actual installed package and full profile-selected run.
- Local wheel success does not establish hosted/container coverage → record those layers separately; do not advance CI pins as part of this slice.

## Migration Plan

Stack specs `test/evaluate-flags-reads` above #105, harness `feat/evaluate-flags-reads` above #75, and Node `test/node-evaluate-flags-compliance` above #5232. Sync/archive the complete spec change before its PR is ready. Link cross-repository dependencies in the new PRs.

After separately authorized merges/releases, rollout uses actual specs squash-merge SHAs and an immutable published harness digest. Reverting the new scenarios/bindings restores the prior acceptance set without changing production SDK behavior.

## Open Questions

None for this bounded slice.
