## Context

The Rust `/flags` service already has two deliberate normalization rules in `property_matching.rs`: `exact`/`is_not` use Unicode lowercase, while `icontains`, prefix, and suffix operators use ASCII lowercase. SDKs currently use a mix of ASCII-only comparison, Unicode lowercase, Unicode casefold/equivalence APIs, and type-strict equality. Those APIs agree for ordinary Latin ASCII but diverge for values such as `Ä`, `ß`, and Greek sigma.

The backend also compares canonical `serde_json::Value::to_string()` representations. JSON strings contribute their unquoted contents; other JSON values use compact JSON with sorted object keys and `serde_json` number formatting. Some host runtimes irreversibly collapse distinct JSON number kinds (notably `323` and `323.0`) before local evaluation receives them.

Before either stringification or ordinary array membership, the backend applies a boolean-like gate to the complete `exact`/`is_not` filter value. Its recursive `all()` predicates classify all-boolean-like arrays as aggregate booleans and classify an empty array as truthy by vacuous truth. This behavior is surprising, but this change documents the released `/flags` comparator rather than changing it. [PostHog/posthog#90694](https://github.com/PostHog/posthog/pull/90694) is a draft proposal to replace that behavior later.

## Goals / Non-Goals

**Goals:**

- Make the operator-specific backend behavior explicit and testable.
- Distinguish Unicode lowercase from both ASCII lowercase and Unicode casefold/equivalence.
- Define the backend boolean gate, conditional equality-array semantics, and canonical `serde_json` stringification model.
- State how implementations behave when their host value model has already discarded lexical information.

**Non-Goals:**

- Change `/flags` behavior or analytics/HogQL property-filter semantics.
- Require SDKs to retain raw JSON source text or replace their JSON parser.
- Define new property-filter operators or change missing-property fallback behavior.

## Decisions

### Specify normalization per operator family

After the boolean gate, `exact` and `is_not` normalize each stringified candidate with Rust-compatible full Unicode lowercase and compare the resulting strings. Full lowercase includes contextual final sigma and multi-code-point mappings such as dotted capital I. Search operators normalize only ASCII `A` through `Z`. Generic "ignore case", simple lowercase, casefold, locale-sensitive, accent-insensitive, and collation APIs are not interchangeable with these transforms and therefore do not satisfy the contract unless they demonstrably produce the same results.

Alternative considered: require ASCII folding everywhere. This was rejected because it would make SDK exact matching diverge from the existing backend. Requiring Unicode folding everywhere was rejected for the same reason on contains/prefix/suffix operators and would undo the backend's deliberate performance choice.

### Preserve the backend boolean gate before equality arrays

For `exact`, the backend first classifies the complete filter as boolean-like. Booleans and `true`/`false` strings are boolean-like; an array is boolean-like when every element is recursively boolean-like. Boolean-like filters compare aggregate truthiness, including the backend's vacuously truthy empty array. Only a filter array containing at least one non-boolean-like element reaches ANY membership. `is_not` negates the complete result. Other composite JSON values continue through canonical JSON stringification; this does not redefine the separate `icontains_multi` operators.

### Define stringification at the evaluator boundary

The canonical model follows the backend: strings remain unquoted, while non-string JSON values use `serde_json::Value::to_string()`. Arrays are compact, object keys are recursively sorted, and finite numbers use `serde_json`'s canonical exponent and plain-decimal cutovers. Consequently an integer `323` and a floating-point `323.0` stringify differently when the input representation preserves that distinction.

If a host runtime has already collapsed those values before the evaluator runs, the SDK must not guess the discarded numeric kind. A dedicated inconclusive result is preferred when it can safely preserve remote fallback; otherwise the SDK uses one deterministic representation and documents the limitation. Conformance tests use typed fixtures only where the runtime can represent the distinction.

## Risks / Trade-offs

- [Unicode versions can differ between language runtimes] → Use word-final sigma and dotted-I discriminator vectors that test Rust-compatible full lowercase, while treating unavoidable Unicode database version differences as runtime constraints.
- [A host number model may not preserve `323.0`] → Prefer inconclusive fallback where available; otherwise document the limitation and prohibit invented formatting rather than requiring raw-token parsing.
- [The released boolean gate has counterintuitive empty-array behavior] → Specify the measured behavior for current SDK parity and track the proposed cleanup separately in [PostHog/posthog#90694](https://github.com/PostHog/posthog/pull/90694).
- [Existing SDK behavior changes for rare non-ASCII comparisons] → Ship focused regression tests and compare against the `/flags` matcher vectors.
- [Analytics filters have different semantics] → Scope every requirement explicitly to local feature-flag evaluation and the `/flags` service.
