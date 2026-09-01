## Context

The merged string-matching baseline defines backend-compatible stringification, released equality boolean gating, Unicode lowercase for equality, and ASCII lowercase for string search. The local evaluator still needs one complete property-matching contract across the remaining operator families, plus explicit boundaries between the direct API's authoring rules, definitions tolerated by the released runtime, and SDK evaluation with partial local context. Those boundaries differ because validation is staged, historical definitions remain observable, and SDKs do not always have the backend's properties, cohort membership, metadata, or regex capabilities.

The refreshed reference audit used PostHog `master` at `55be8f3f6a949ac5588d55e135c5da037a936cd0`, with matcher behavior unchanged from audited commit `4c0b91cff23d71591e7da5336ce151f4cc3db6cb`, principally:

- `rust/feature-flags/src/properties/property_models.rs`
- `rust/feature-flags/src/properties/property_matching.rs`
- `rust/feature-flags/src/properties/relative_date.rs`
- `rust/feature-flags/src/cohorts/cohort_operations.rs`
- `rust/feature-flags/src/flags/flag_matching.rs`
- `rust/feature-flags/src/flags/flag_matching_utils.rs`
- `products/feature_flags/backend/api/filters_schema.py`
- `products/feature_flags/backend/filters_validation.py`
- `products/feature_flags/backend/local_evaluation.py`

The SDK parity audit covered Node, Python, Go, Ruby/Rails, PHP, Java server, .NET, and Rust. Elixir has no local-definitions evaluator and remains excluded.

## Goals / Non-Goals

**Goals:**

- Make the complete local feature-flag operator inventory discoverable in one capability spec.
- Define operand direction, coercion, list behavior, comparison boundaries, and result state for every operator family.
- Preserve three evaluator outcomes: match, definitive no-match, and inconclusive/remote fallback.
- Separate API-authorable definitions from runtime-compatible definitions and partial-context evaluation.
- Provide table-driven acceptance vectors suitable for server-side SDK local evaluators.
- Isolate unsupported definitions and evaluator failures to the affected flag.

**Non-Goals:**

- Modify SDK or backend implementations in this change.
- Define event-property querying outside feature-flag evaluation.
- Make Elixir implement local evaluation.
- Require SDKs to reproduce the feature-flag API's staged validation switch.
- Standardize backend loading internals, cache formats, tracing, or regex compilation caches.

## Decisions

### 1. Keep authoring, runtime compatibility, and partial context separate

The direct API controls what can be newly authored when structural and cross-field enforcement is enabled. The runtime also sees historical, injected, and enforcement-bypassed definitions. SDKs consume those definitions and can additionally lack data needed for a local decision.

The canonical spec therefore states authoring constraints for scope, defines runtime-compatible legacy forms per operator, and uses inconclusive only for the affected flag when local context or capability is insufficient.

### 2. Use the released feature-flags service as the primary semantic reference

Observable matcher behavior follows the released Rust feature-flags service where it is portable. A proposed but unmerged backend change does not replace released behavior in this contract. Safer SDK fallback behavior is allowed only where the spec labels the divergence, especially malformed definitions, missing partial context, resource failures, and cohort negation.

### 3. Publish one scoped operator inventory

The inventory separates:

- ordinary person/group/person-metadata properties
- dynamic-cohort-only ranges
- cohort membership
- flag dependencies
- `min`/`max` aliases that normalize to `gte`/`lte`

Prefix/suffix operators are first-class Rust and direct API operators on the refreshed reference. `person_metadata` remains runtime-compatible but is excluded by the enforced direct API inventory. `between` and `not_between` remain cohort-leaf operators rather than direct flag-property operators.

### 4. Preserve inconclusive state without letting negation invent a match

An omitted key in caller-supplied partial properties is inconclusive for positive and negative operators. A malformed condition is also inconclusive unless a family defines a safe result. A present but uninterpretable property is a definitive no-match.

Named negative operators and cohort leaf `negation` invert only a valid comparison. They never turn missing context, malformed conditions, unsupported syntax, or resource-limit failures into matches.

### 5. Extend the merged exact/is_not baseline without replacing it

The merged baseline records that the released matcher applies compact JSON stringification, then a condition-side boolean gate before ordinary array membership. Boolean-like arrays use aggregate truthiness, including vacuous truth for an empty array. Other condition arrays use ANY membership. Every comparison uses Rust full Unicode lowercase, not ASCII lowercase or Unicode case folding.

This behavior is unusual but observable. The contract records it until the released service changes. Property arrays and objects participate through compact JSON representations. Numeric kind and spelling remain observable where the host JSON model preserves them.

### 6. Use ASCII lowercase for string search

Contains, prefix, suffix, and multi-contains operators stringify operands and lowercase only ASCII `A` through `Z`. Direct authoring requires multi-contains arrays, while the runtime accepts a scalar as one needle. Array members can be any JSON value and are independently stringified.

### 7. Bound regex portability and failures

Regex operators perform case-sensitive search without implicit anchors. Invalid syntax is false for both polarities. A backend-valid pattern unsupported by an SDK engine, or a runtime resource-limit failure, is inconclusive and isolated to that flag. Portable acceptance uses syntax shared by target engines rather than requiring every SDK to emulate Rust `fancy-regex`.

### 8. Use complete finite binary64 numeric comparison

Numeric ordering and cohort ranges parse complete, untrimmed decimal strings or JSON numbers as IEEE-754 binary64 values. They reject partial parses and non-finite values and never fall back to lexicographic comparison. Binary64 precision loss, underflow, and overflow handling are explicit. Direct authoring can be narrower than runtime compatibility.

### 9. Interpret dates in the effective timezone

Absolute dates use a bounded portable grammar. Naive values use the team timezone when available and UTC otherwise. Relative dates subtract on the effective timezone's local wall clock. DST overlaps choose the earlier instant; gaps are inconclusive. Month/year subtraction is iterative and clamps after each step.

Unix seconds accept finite binary64 fractions. The SDK contract deliberately rejects non-finite timestamps and mathematically normalizes pre-epoch fractions instead of reproducing backend float-to-integer edge bugs.

### 10. Reproduce direct SemVer total ordering and VersionReq ranges

Direct SemVer comparisons use the released normalization order: remove a leading lowercase `v` before trimming, pad omitted components, normalize numeric leading zeros, and parse unsigned 64-bit components. Rust `semver::Version` equality and ordering include build metadata.

Tilde, caret, and wildcard operators use `VersionReq::matches`. Build metadata is ignored for range matching, and prereleases require a comparator prerelease with the same core version. Padding occurs before tilde/caret construction. Wildcard runtime grammar, `x`/`X`, bare `*`, no-token default-caret behavior, and API/runtime parser disagreement are explicit.

### 11. Use three-valued cohort composition

Dynamic cohort groups use true, false, and inconclusive. A conclusive true dominates `OR`; a conclusive false dominates `AND`. The legacy group type `property` aliases `AND`. Empty `OR` is false; empty `AND` is true. Missing/static-without-membership/cyclic cohorts remain inconclusive, while cached static membership is definitive.

Implementations support at least 64 nested levels and fail deeper structures safely without recursion overflow or silent truncation.

### 12. Define dependency payload semantics

Local dependency filter keys are feature-flag keys, not database IDs. `dependency_chain` contains transitive dependencies in topological order, including the immediate dependency and excluding the owning flag. Missing definitions and cycles remain inconclusive even when represented by an empty chain. Inactive referenced definitions resolve as boolean false.

### 13. Isolate decoding and evaluation failures per flag

Unknown operators must be isolated while decoding a raw definition bundle, before a closed enum can reject the entire payload. Matcher or evaluator errors during bulk evaluation similarly affect only their flag. Independent flags continue evaluating locally.

### 14. Use tables as conformance vectors

The canonical spec and private acceptance feature use scenario outlines for operator defaults, result states, equality, Unicode, strings, regex, numeric precision, ranges, dates and DST, SemVer comparison/ranges, cohort composition, and dependency chains. Specialized scenarios cover decode boundaries and flag-local failure isolation.

## Deliberate divergences

| Boundary | Canonical SDK behavior | Released backend or authoring difference |
| --- | --- | --- |
| Missing property in partial context | Inconclusive | Complete backend context can decide absence. |
| Missing or malformed condition | Inconclusive unless explicitly safe | Runtime frequently fails closed; enforced API can reject it. |
| Unknown operator while loading | Only the affected flag is inconclusive | A closed typed bundle can fail whole-payload decoding. |
| Regex resource or dialect failure | Inconclusive | Runtime matcher errors can collapse to false. |
| Non-finite numeric/range operands | Invalid | Runtime accepts some infinities through `f64`. |
| Invalid or non-finite date values | Invalid; `NaN` is never the epoch | Released float conversion has non-finite edge behavior. |
| Pre-epoch fractional seconds | Mathematical Unix-second normalization | Released conversion mishandles some negative fractions. |
| Invalid cohort leaf plus negation | Inconclusive | Backend can collapse the leaf error to false and then negate it. |
| API-invalid but runtime-compatible shape | Evaluate according to the family rule | Enforced API rejects it; enforcement-off or legacy data can still contain it. |

## Risks / Trade-offs

- Existing SDKs will fail some vectors; those failures become explicit parity work rather than reasons to weaken the contract.
- The released equality boolean gate is surprising and may change in the backend. A future released change requires a coordinated spec revision and SDK rollout.
- Exact JSON number spelling cannot be recovered after a host runtime collapses numeric kinds. Such SDKs use safe fallback when available and document deterministic limitations otherwise.
- Regex syntax is not portable across all SDK engines. Unsupported constructs fall back remotely rather than producing false parity.
- Team timezone is not available in every local-definition integration. UTC fallback remains deterministic but can differ from remote evaluation.
- Authoring validation is staged and can change independently. The evaluator contract cannot assume that newly invalid shapes disappear from existing definitions.
