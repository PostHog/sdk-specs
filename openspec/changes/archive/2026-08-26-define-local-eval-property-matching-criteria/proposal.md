## Why

The canonical local feature-flag evaluator spec defines condition selection and a few isolated property operators, but it does not define the complete matching contract used by feature-flag criteria. This leaves SDKs free to disagree on observable behavior such as case sensitivity, string coercion, numeric comparison, missing values, invalid regular expressions, and semantic-version parsing; PostHog Go PR #299 is one concrete example.

## What Changes

- Define the common operand model for local property matching: the supplied person/group property is compared against the condition value, an omitted operator defaults to `exact`, condition-side arrays have explicit membership semantics, and missing or null context has a defined outcome.
- Define canonical behavior for every direct feature-flag property-operator family: equality, presence, contains and multi-contains, prefix/suffix, regular expression, numeric ordering, date comparison, and semantic-version comparison/ranges.
- Distinguish ordinary property operators from specialized criteria: dynamic cohort membership (`in`/`not_in`), cohort-only numeric ranges (`between`/`not_between`), flag dependencies (`flag_evaluates_to`), and condition-leaf negation.
- Define wire aliases and validation/failure behavior, including malformed filter values, invalid property values, unsupported operators, and the boundary between a definitive no-match and locally inconclusive evaluation.
- Add table-driven private `@server` acceptance scenarios that serve as shared conformance vectors for each matching criterion and its negative form.
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
