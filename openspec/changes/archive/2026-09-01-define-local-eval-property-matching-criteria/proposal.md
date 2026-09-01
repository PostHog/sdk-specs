## Why

The canonical local feature-flag evaluator spec defines the released equality and string-search baseline, but it does not define condition selection or the complete matching contract used by the remaining feature-flag criteria. This leaves SDKs free to disagree on observable behavior such as numeric comparison, missing values, invalid regular expressions, dates, semantic-version parsing, cohorts, and dependencies.

## What Changes

- Separate definitions accepted by enforced direct API authoring, legacy/injected shapes tolerated by the runtime matcher, and SDK evaluation with partial local context.
- Extend the merged stringification, equality, and ASCII string-search requirements with nested-container and multi-contains behavior without replacing their established semantics.
- Define the common operand model for local property matching: the supplied person/group property is compared against the condition value, an omitted or null operator defaults to `exact`, condition-side arrays have explicit semantics, and missing or null context has a defined outcome.
- Define canonical behavior for the remaining feature-flag property-operator families: portable regular expression search, binary64 numeric ordering, timezone-aware date comparison, semantic-version direct/range parsing, cohorts, and dependencies.
- Distinguish ordinary property operators from specialized criteria: dynamic cohort membership (`in`/`not_in`), cohort-only numeric ranges (`between`/`not_between`), flag dependencies (`flag_evaluates_to`), and condition-leaf negation.
- Define wire aliases, dependency chains, cohort composition, and validation/failure behavior, including malformed filter values, invalid property values, unsupported operators, decode-boundary isolation, and the boundary between a definitive no-match and locally inconclusive evaluation.
- Add table-driven private `@server` acceptance scenarios that serve as shared conformance vectors for each matching criterion, its negative form, and cross-cutting failure isolation.
- Reconcile the existing prefix/suffix, presence, unknown-operator, and dependency requirements with the complete operator contract instead of leaving them as disconnected special cases.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `local-feature-flag-evaluator`: Add the complete canonical feature-flag criterion/property-matching contract and acceptance vectors.

## Impact

- Documentation and private acceptance coverage in `sdk-specs`.
- Future server-side SDK conformance work across Node, Python, Go, Ruby/Rails, PHP, Java, .NET, and Rust; Elixir currently has no local evaluator.
- No public API or flag-definition wire-format change in this repository. SDKs that currently drift from the canonical matcher may produce different local results when they adopt the contract, while remote evaluation remains the reference fallback.
