## Context

The local evaluator currently has detailed requirements for condition-group selection, presence operators, prefix/suffix operators, unknown operators, rollout percentages, aggregation, and flag dependencies. It does not have one complete property-matching contract. As a result, a reviewer cannot answer a basic question such as “what must `exact` do?” from the canonical spec.

The reference audit used PostHog commit `935b7683660697bdc75c042c4c56828aeb036754`, principally:

- `rust/feature-flags/src/properties/property_models.rs`
- `rust/feature-flags/src/properties/property_matching.rs`
- `rust/feature-flags/src/cohorts/cohort_operations.rs`
- `rust/feature-flags/src/flags/flag_matching_utils.rs`
- `products/feature_flags/backend/api/feature_flag.py`

The SDK parity audit covered Node, Python, Go, Ruby/Rails, PHP, Java server, .NET, and Rust. Elixir has no local definitions evaluator and is excluded. Confirmed drift includes Go's pre-PR-#299 type-strict equality, missing prefix/suffix families in several SDKs, inconsistent null/presence behavior, numeric-versus-lexicographic ordering, invalid negated-regex behavior, and semantic-version normalization.

## Goals / Non-Goals

**Goals:**

- Make the complete local feature-flag criterion/operator inventory discoverable in one capability spec.
- Define operand direction, coercion, list behavior, comparison boundaries, and failure state for every operator family.
- Preserve the local evaluator's three outcomes: match, definitive no-match, and inconclusive/remote fallback.
- Provide shared table-driven acceptance vectors suitable for every server-side SDK local evaluator.
- Make PostHog Go PR #299's intended `exact`/`is_not` behavior directly derivable from the canonical spec.

**Non-Goals:**

- Modify SDK implementations in this change.
- Define event-property querying outside feature-flag evaluation.
- Make Elixir implement local evaluation.
- Change the feature-flag definition API or add team timezone to the local-definition response.
- Document backend-only database loading, regex compilation caches, or evaluator tracing.

## Decisions

### 1. Use the feature-flags service as the semantic reference, then adapt missing context for local evaluation

The Rust feature-flags service and the feature-flag API define the wire operators and remote observable result. The SDK contract follows that behavior where it is portable. The local evaluator differs only where it has partial request-time context: an absent required property is inconclusive rather than proof that the property is absent.

Peer consensus is used to avoid copying incidental backend implementation details. In particular, requirements describe observable comparison results, not Rust error types, parser libraries, caches, or database state.

### 2. Publish one scoped operator inventory

The spec will classify operators by where they are valid:

- ordinary person/group properties: omitted/`exact`, `is_not`, `is_set`, `is_not_set`, contains/multi-contains, prefix/suffix, regex, numeric ordering (including `min`/`max` aliases for `gte`/`lte`), date, and semantic version
- dynamic cohort property leaves only: `between`, `not_between`
- cohort membership only: `in`, `not_in`
- flag dependencies only: `flag_evaluates_to`

Prefix/suffix remain part of the existing SDK contract even though the audited backend direct-write allowlist does not currently emit them. The spec will identify scope instead of implying that every operator is accepted by every flag-authoring surface.

### 3. Make operand direction explicit

For an ordinary criterion, the supplied person/group property is the left operand and the condition value is the right operand: `property operator condition`. A condition-side list for `exact` is an allowlist; it does not redefine arbitrary property arrays as overlapping sets.

An omitted or null operator defaults to `exact`. A value-requiring criterion with no condition value is malformed and locally inconclusive. Unknown operators are also inconclusive for only the affected flag.

### 4. Keep invalid data from becoming a negative match

A missing required key remains inconclusive for positive and negative operators. A present but non-comparable property value is a definitive no-match. A malformed condition value is inconclusive because the local definition cannot be trusted. Named negative operators negate only a valid comparison; they do not turn invalid regexes, invalid numbers, invalid dates, invalid semantic versions, or unavailable context into matches.

Presence operators are the exception because they inspect map membership rather than the value. Existing requirements remain authoritative: explicit JSON null counts as present, while an omitted key in partial local context is inconclusive.

### 5. Define equality using the behavior required by Go PR #299

`exact` and `is_not` compare JSON scalar string representations case-insensitively for ASCII. This makes `"US"` equal `"us"` and numeric `1` equal string `"1"`. A condition-side array matches when any member equals the scalar property under the same comparison. `is_not` is the complement when operands are valid.

The spec does not require byte-identical Unicode case folding across language runtimes; acceptance vectors use ASCII so implementations can use their idiomatic case-insensitive comparison without platform-specific surprises.

### 6. Use strict numeric comparison rather than lexicographic fallback

`gt`, `gte`, `lt`, and `lte` parse JSON numbers and complete numeric strings as finite numbers and compare `property operator condition`. They never fall back to string ordering. `between`/`not_between` are inclusive range criteria for dynamic cohort property leaves only. `min` and `max` normalize to `gte` and `lte`.

This follows the feature-flags service and avoids known SDK disagreement such as comparing `"10"` and `"9"` lexicographically.

### 7. Define safe regex search

`regex` and `not_regex` perform case-sensitive search, not implicit full-string matching. Anchors in the pattern control anchoring. A syntactically invalid pattern is a definitive no-match for both operators; `not_regex` does not turn an invalid pattern into true. A runtime regex resource-limit failure is inconclusive for the affected flag. Implementations must use their normal regex resource controls and must not expose a matcher panic/exception to application code.

### 8. Normalize dates deterministically

Date criteria compare instants with strict before/after and exact equality. Explicit offsets are honored. Date-only and naive values use the team timezone when it is available in local evaluation context, otherwise UTC. Property values can also use numeric or numeric-string Unix seconds.

Relative condition values use the reference grammar: optional leading `-`, an integer below 10,000, and one lowercase `h`, `d`, `w`, `m`, or `y` unit. Both signed and unsigned forms are lookbacks. Hours/days/weeks are fixed-duration subtraction; months/years use calendar subtraction in the effective timezone. They are anchored to the evaluator's injected/fixed clock.

This is deterministic for SDK acceptance tests while acknowledging that the current local-definition payload does not consistently provide team timezone. A future wire change can supply it without changing operator direction or comparison semantics.

### 9. Use the feature-flags service semantic-version model

Semantic-version operators trim whitespace, accept one lowercase `v` prefix, pad omitted minor/patch components with zero, and normalize leading zeros in numeric components. Standard prerelease precedence applies; build metadata does not affect equality or ordering. Tilde, caret, and wildcard ranges are lower-inclusive and upper-exclusive.

An invalid property version is a definitive no-match. An invalid condition version/range is inconclusive. Shared vectors will cover comparison, normalization, prerelease ordering, and each range family.

### 10. Use tables as conformance vectors

The delta spec and private acceptance feature will use scenario outlines/tables rather than one prose-only scenario per operator. Every wire operator will occur in at least one positive or negative row, and boundary-sensitive families will include both sides of the boundary. Specialized cohort and dependency criteria retain dedicated scenarios because they require evaluation context rather than a scalar matcher call.

### 11. Record deliberate choices where audited engines disagree

| Behavior | Canonical choice | Confirmed divergence |
| --- | --- | --- |
| Missing keys in partial local context | Inconclusive for every operator | The backend can decide negative operators from complete properties; Node currently treats missing `is_not_set` as a match. |
| Exact scalar/list matching | Case-insensitive scalar coercion and condition-list membership | Go before PR #299 is case- and type-sensitive; Rust's special boolean-array path is not generalized membership. |
| Missing condition value for a value-requiring operator | Inconclusive because the local definition is malformed | The backend ordinary matcher currently returns false. |
| Explicit JSON null in string-like matching | Compact JSON scalar text `null` | Several SDKs reject null before comparison or use language-specific text such as an empty string or `<nil>`. |
| Prefix/suffix | Keep the already-canonical SDK operator family | The audited direct feature-flag API allowlist does not emit these operators and several SDKs do not implement them. |
| Multi-contains shape | Require a condition-side array | Rust accepts a scalar as one item at runtime, while API validation and the operator's wire meaning require a list. |
| Invalid regex | False for both polarities; runtime resource-limit failure is inconclusive | Java and the PostHog Rust SDK can negate an invalid pattern to true; the backend reports an execution-limit error. |
| Numeric ordering | Complete finite numeric parse only; no lexicographic fallback | Python, Ruby, PHP, and Java can compare numeric strings lexicographically; Rust does not explicitly reject every non-finite string at runtime. |
| Invalid condition date | Inconclusive, because the local definition is malformed | The backend currently returns false for an unparseable condition date. |
| Naive date timezone | Team timezone when available, deterministic UTC fallback otherwise | Current SDK definition responses do not consistently carry team timezone. |
| Semantic versions | Trim, then remove a lowercase `v`, normalize leading zeros, and use standard prerelease precedence | Current SDKs generally reject leading-zero components and strip prerelease/build suffixes before tuple comparison. Backend Rust normalizes leading zeros and prereleases but removes `v` before trimming, so a combined input such as `" v1.02 "` fails there; the canonical normalization order accepts it. |
| Negated inconclusive cohort leaf | Remains inconclusive | Backend dynamic-cohort handling can collapse a matcher error to false before applying leaf negation. |

## Risks / Trade-offs

- **[Existing SDKs fail the new vectors]** → Treat failures as an explicit parity backlog; do not weaken the canonical contract to match accidental implementation drift.
- **[Canonicalization changes locally evaluated users]** → Keep remote evaluation as the reference fallback and ship future SDK fixes as patch changes with focused release notes where behavior changes.
- **[Date timezone is unavailable locally]** → Use team timezone when supplied and deterministic UTC otherwise; document the remaining remote-parity limit.
- **[Unicode folding differs by runtime]** → Require ASCII case-insensitive vectors and leave stronger Unicode normalization to a separate contract.
- **[Backend and authoring surfaces support different subsets]** → Mark each operator's scope explicitly and do not claim that cohort-only or SDK-extension operators are valid direct-write API inputs.
- **[Negative operators accidentally match malformed input]** → Define negative operators as negation of a valid comparison only and add invalid-input rows.
