## Why

The canonical local feature-flag evaluator spec defines equality and string-search behavior, but it does not define the remaining property-matching criteria. This leaves SDKs free to disagree on observable behavior such as numeric comparison, missing values, invalid regular expressions, dates, semantic-version parsing, and cohorts.

## What Changes

- Extend the merged stringification, equality, and ASCII string-search requirements with multi-contains behavior without replacing their established semantics.
- Define the common operand model for local property matching: the supplied person/group property is compared against the condition value, an omitted or null operator defaults to `exact`, condition-side arrays have explicit semantics, and missing local context has a defined outcome.
- Define platform-neutral behavior for regular-expression search, numeric ordering and ranges, timezone-aware date comparison, semantic-version comparison and ranges, and cohorts.
- Distinguish ordinary property operators from specialized cohort, range, and dependency criteria.
- Define observable aliases, comparison boundaries, and the distinction between definitive no-match and locally inconclusive evaluation.
- Add table-driven private `@server` acceptance scenarios for each matching criterion and its negative form.
- Keep the existing equality, prefix/suffix, presence, unknown-operator, and dependency requirements authoritative.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `local-feature-flag-evaluator`: Add canonical feature-flag condition and property-matching semantics with acceptance vectors.

## Impact

- Documentation and private acceptance coverage in `sdk-specs`.
- Future server-side SDK conformance work across Node, Python, Go, Ruby/Rails, PHP, Java, .NET, and Rust; Elixir currently has no local evaluator.
- No public API or flag-definition wire-format change in this repository. SDKs that currently drift from the canonical matcher may produce different local results when they adopt the contract, while remote evaluation remains the reference fallback.
