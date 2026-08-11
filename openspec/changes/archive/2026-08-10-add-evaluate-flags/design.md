## Context

The modern server-side feature-flag surface has converged independently across seven shipped SDKs:

- Node: `evaluateFlags(...) -> FeatureFlagEvaluations`
- Python: `evaluate_flags(...) -> FeatureFlagEvaluations`
- Ruby: `evaluate_flags(...) -> FeatureFlagEvaluations`
- PHP: `evaluateFlags(...) -> FeatureFlagEvaluations`
- Go: `EvaluateFlags(...) -> (*FeatureFlagEvaluations, error)`
- .NET: `EvaluateFlagsAsync(...) -> FeatureFlagEvaluations`
- JVM server: `evaluateFlags(...) -> PostHogFeatureFlagEvaluations`

All seven separate **evaluation** from **use**. The entry point resolves one identity/context, attempts local evaluation, optionally performs one direct remote `/flags` fallback, and freezes the resulting values and payloads into a reusable snapshot. Boolean/value accessors read that snapshot synchronously and lazily report `$feature_flag_called`; capture can consume the same snapshot without evaluating again.

The current specs instead describe direct single-flag getters and bulk maps as independent APIs. In particular, `is-feature-enabled` describes a client/server method that may itself perform evaluation on the server. That is not the same operation as `FeatureFlagEvaluations.isEnabled(...)`, which only projects a boolean from an already-created snapshot.

## Goals / Non-Goals

**Goals:**

- Make the evaluate-once/snapshot/read-many model explicit and discoverable.
- Define enough of the entry point, snapshot, access tracking, capture reuse, filtering, and fallback behavior for cross-SDK acceptance testing.
- Explain the relationship to direct `isFeatureEnabled` / `getFeatureFlag` methods without invalidating client-side ambient-cache APIs.
- Select canonical behavior where implementations differ, while preserving legitimate host-language result and error conventions.

**Non-Goals:**

- Re-specifying local rule matching, `/flags` transport/retry behavior, or `$feature_flag_called` dedupe internals already owned by other capabilities.
- Requiring browser/mobile SDKs to add this server-request snapshot API; their ambient identity and cached flag lifecycle is structurally different.
- Standardizing every metadata field retained by a snapshot or emitted on `$feature_flag_called`.
- Requiring one payload representation (`JsonDocument`, decoded JSON, raw JSON string, typed decoder) across languages.
- Removing older single-flag getters, bulk getters, structured-result getters, or capture-time flag-evaluation options. Their formal deprecation and removal timing remain SDK release-policy decisions.

## Decisions

### Treat `evaluate-flags` as a distinct server-side public capability

The capability is not an alias for `is-feature-enabled` or `get-feature-flags-and-payloads`. The entry point performs one evaluation and returns behavior-bearing state; snapshot accessors then provide boolean, value, payload, structured-result, and bulk-enumeration views and can record access. It functionally supersedes the server-side family of separate `isFeatureEnabled`, `getFeatureFlag`, `getFeatureFlagPayload`, `getFeatureFlagResult`, `getAllFlags`, and `getAllFlagsAndPayloads` calls, plus capture-time `sendFeatureFlags` evaluation. Each older use case is a projection or consumer of the same snapshot.

The supersession mapping is functional, not side-effect-preserving. Bulk map APIs remain a data-only compatibility convenience and do not define lazy exposure tracking, access-filtered capture, or reuse of exact decisions. Enumerating snapshot values through `getFlag` records each value as accessed; enumerating only keys or payloads retains their documented silent behavior. Go's legacy `GetFeatureFlagPayload` historically emits an exposure by default, whereas the snapshot payload accessor is intentionally silent like the other modern implementations. These differences are deliberate; callers that specifically require a legacy data-only bulk shape may retain that compatibility method rather than trigger a second evaluation accidentally.

Client-side `isFeatureEnabled(...)` remains governed by its existing cache-read contract. Server SDKs may retain any superseded method for compatibility, but new server code should create one snapshot per incoming request or evaluation context and derive all flag reads and capture enrichment from it.

### Define one logical evaluation with at most one direct remote fallback

An `evaluateFlags` call may use cached evaluated results, cached flag definitions, and local evaluation before remote fallback. If remote evaluation is needed, the SDK must make at most one direct `/flags` evaluation request for that call. Snapshot accessors, snapshot filters, and capture reuse make no additional flag-evaluation request.

The spec does not require identical fallback heuristics. Ruby cannot infer that locally resolved known definitions represent the complete project set without explicit `flagKeys`, while PHP and JVM can skip remote evaluation in more cases. The observable contract is zero or one direct evaluation request, never one request per snapshot accessor.

### Make the snapshot point-in-time and immutable in value, mutable only in access bookkeeping

A snapshot pins values, payloads, evaluation identity/context, and available evaluation metadata. Later definition refreshes, remote changes, or evaluations do not mutate those records. Access tracking may mutate an internal set and dedupe cache; filtered snapshots are value copies/views whose later access bookkeeping does not mutate the parent.

Key enumeration order is intentionally unspecified.

### Standardize semantic accessors, not one host-language object shape

The canonical semantic surface is:

- keys present in the snapshot;
- boolean enablement;
- evaluated value (`true`, `false`, variant, or missing);
- payload (or missing);
- in-memory `only(keys)` and `onlyAccessed()` filtering.

Most SDKs return a scalar from `getFlag`; .NET returns a rich `FeatureFlag` object carrying the same enabled/variant/payload semantics. Both conform if callers can recover the canonical value. Payloads may be parsed JSON, raw JSON strings, host JSON documents, or values exposed through typed decoding helpers.

Unknown `isEnabled` defaults to `false`. An SDK may additionally accept a caller default, as Python does; a present flag, including disabled `false`, wins over that default. Unknown `getFlag` and payload reads use the language's nullish/empty sentinel.

### Fire exposure events on value use, not snapshot creation or payload-only access

Creating the snapshot does not assert that application code used any flag, so it emits no `$feature_flag_called`. `isEnabled` and `getFlag` mark the key accessed and send through the existing dedupe tracker using the canonical flag value. Repeated boolean/value reads therefore do not multiply exposure events. A missing-key access is still an attempted flag use and should report `flag_missing` when identity is available.

Payload-only reads neither mark the key accessed nor emit an event. Payloads are configuration associated with a decision, not a decision/exposure by themselves.

Implementations differ in ancillary metadata and in the response sentinel attached to an unknown-key event; those remain under the feature-flag-called tracker contract. They also differ when callers branch on a key removed from a capture-oriented filtered snapshot. The spec defines filtered snapshots for event scoping and does not standardize exposure behavior for that misuse.

### Reuse the snapshot for exact, network-free capture enrichment

Passing a snapshot as `flags` to capture attaches its retained values as `$feature/<key>` and includes enabled keys in `$active_feature_flags`, without another evaluation request. This is the primary reason to preserve a point-in-time object rather than return only a transient boolean.

The snapshot wins over deprecated capture-time "send/evaluate feature flags" options when both are supplied, because only the snapshot guarantees the event carries the exact values used for branching. Collision precedence with caller-supplied raw `$feature/*` properties remains part of the capture/property-merging contract rather than this capability.

SDKs do not consistently reject a snapshot whose identity differs from the capture call. The spec documents that snapshots are bound to one evaluation identity/context but does not invent cross-SDK rejection behavior.

### Separate request-time filtering from in-memory filtering

`flagKeys` / `flag_keys` (or a platform equivalent) scopes the remote request and the returned snapshot before access begins. An implementation may still inspect additional cached definitions internally, as the JVM server SDK does, but must drop unrequested values from every result source before returning. `only(keys)` and `onlyAccessed()` filter an existing snapshot for capture and cannot retroactively reduce evaluation work.

Three shipped paths need convergence on returned-snapshot scoping: .NET retains every locally evaluated flag; .NET's evaluated-result cache key omits `FlagKeysToEvaluate`, so an unfiltered cached result may satisfy a filtered call; and Node applies every configured `overrideFeatureFlags` entry after filtering without reapplying `flagKeys`. The canonical rule remains that request-time filtering scopes the returned snapshot regardless of whether a value came from local evaluation, a remote response, an evaluated-result cache, or an override. Otherwise identical calls can expose different keys depending on an invisible result source.

Canonical `onlyAccessed()` is literal and order-dependent: before any boolean/value access it returns an empty snapshot. Node, Python, Ruby, PHP, Go, and JVM already behave this way. .NET's current warning-and-attach-all fallback is another divergence and becomes a conformance gap rather than an allowed variation, because silently attaching all flags contradicts the method name and defeats deliberate event-payload minimization.

### Return a safe snapshot on missing identity or evaluation failure, with idiomatic error reporting

With no explicit or request-context distinct id, the SDK returns an empty/no-op snapshot, performs no `/flags` request, and emits no access events. It may also warn or return an idiomatic error; Go's `(snapshot, error)` is valid, while exception-oriented SDKs should not make ordinary snapshot access unsafe.

Local-only mode omits unresolved flags and performs no remote request. If remote fallback fails after local records were resolved, the snapshot retains those successful records; six of the seven shipped implementations already preserve partial results. The JVM server SDK currently discards its all-or-nothing local pass when one flag is inconclusive and therefore returns empty if the remote fallback also fails; this is a convergence gap. Available response error metadata is pinned so a later attempted access can report it consistently.

## Risks / Trade-offs

- **The new contract exposes request-filtering divergences in Node overrides and .NET local/cache paths, plus .NET's `OnlyAccessed()` divergence** → Require requested-key snapshots across every result source and the literal empty-before-access behavior implemented by the other server SDKs; record those paths as needing convergence rather than making snapshot results source-dependent or weakening payload minimization.
- **The JVM server SDK loses partial local results when remote fallback fails** → Select partial-result preservation implemented by the other six SDKs so a transient remote failure does not discard already-known decisions.
- **.NET does not yet expose GeoIP evaluation control on `AllFeatureFlagsOptions`** → Keep GeoIP control in the canonical input set implemented by the other six SDKs and record .NET as needing an additive option.
- **A hard "one request" statement could accidentally count definition polling or unrelated cache refreshes** → Scope it specifically to direct remote flag-evaluation requests initiated for this call; definition-loader behavior remains in its own capability.
- **Rich .NET values and raw Go/JVM payloads do not match scalar/dynamic SDKs exactly** → Specify semantic projections and missing behavior, not one wire/runtime type.
- **Legacy deprecation state can change by release** → Document the migration relationship and preferred server pattern, but do not require removal dates or warnings.
- **Capture identity mismatch remains possible** → State that the snapshot is bound to one evaluation context and preserve exact values; defer enforcement until shipped SDKs establish a common behavior.

## Migration Plan

This repository change is documentation-only. After archive, server SDK compliance audits can measure existing implementations against the new capability. SDKs that already ship snapshots should cross-link their generated/API docs. Node should reapply request-time key filtering after overrides. .NET should scope local and evaluated-cache results to requested keys, add GeoIP evaluation control, and make `OnlyAccessed()` empty before access. The JVM server SDK should preserve successfully resolved local records when remote fallback fails.

## Open Questions

None.
