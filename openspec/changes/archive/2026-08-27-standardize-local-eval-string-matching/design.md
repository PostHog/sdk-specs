## Context

The Rust `/flags` service already has two deliberate normalization rules in `property_matching.rs`: `exact`/`is_not` use Unicode lowercase, while `icontains`, prefix, and suffix operators use ASCII lowercase. SDKs currently use a mix of ASCII-only comparison, Unicode lowercase, Unicode casefold/equivalence APIs, and type-strict equality. Those APIs agree for ordinary Latin ASCII but diverge for values such as `Ä`, `ß`, and Greek sigma.

The backend also compares string representations. JSON strings contribute their unquoted contents; other JSON values use their JSON lexical representation. Some host runtimes irreversibly collapse JSON numeric spellings (notably `323` and `323.0`) before local evaluation receives them.

## Goals / Non-Goals

**Goals:**

- Make the operator-specific backend behavior explicit and testable.
- Distinguish Unicode lowercase from both ASCII lowercase and Unicode casefold/equivalence.
- Define equality array semantics and the backend JSON lexical stringification model.
- State how implementations behave when their host value model has already discarded lexical information.

**Non-Goals:**

- Change `/flags` behavior or analytics/HogQL property-filter semantics.
- Require SDKs to retain raw JSON source text or replace their JSON parser.
- Define new property-filter operators or change missing-property fallback behavior.

## Decisions

### Specify normalization per operator family

`exact` and `is_not` normalize each stringified candidate with Unicode lowercase and compare the resulting strings. Search operators normalize only ASCII `A` through `Z`. Generic "ignore case", casefold, locale-sensitive, accent-insensitive, and collation APIs are not interchangeable with these transforms and therefore do not satisfy the contract unless they demonstrably produce the same results.

Alternative considered: require ASCII folding everywhere. This was rejected because it would make SDK exact matching diverge from the existing backend. Requiring Unicode folding everywhere was rejected for the same reason on contains/prefix/suffix operators and would undo the backend's deliberate performance choice.

### Treat equality arrays as a matcher construct

For `exact`, a filter array is an ANY list: each element is independently stringified, lowercased, and compared with the property. `is_not` negates that aggregate, producing NONE semantics. Other composite JSON values continue through ordinary JSON stringification; this does not redefine the separate `icontains_multi` operators.

### Define stringification at the evaluator boundary

The canonical model follows the backend: strings remain unquoted, while non-string JSON values use their JSON lexical form. Consequently an integer `323` and a float token `323.0` stringify differently when the input representation preserves that distinction.

If a host runtime has already collapsed those tokens into one value before the evaluator runs, the SDK must stringify the value it actually received deterministically and must not guess discarded source text. Conformance tests should use typed or lexical fixtures only where the runtime can represent the distinction.

## Risks / Trade-offs

- [Unicode versions can differ between language runtimes] → Use discriminator vectors that test the required transformation category, while treating unavoidable Unicode database version differences as runtime constraints.
- [A host number model may not preserve `323.0`] → Document the limitation and prohibit invented formatting rather than requiring raw-token parsing.
- [Existing SDK behavior changes for rare non-ASCII comparisons] → Ship focused regression tests and compare against the `/flags` matcher vectors.
- [Analytics filters have different semantics] → Scope every requirement explicitly to local feature-flag evaluation and the `/flags` service.
