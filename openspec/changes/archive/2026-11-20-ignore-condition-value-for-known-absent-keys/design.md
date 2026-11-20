## Context and sources

The flags service's property matcher is `rust/feature-flags/src/properties/property_matching.rs` in PostHog/posthog. Known-absent keys come from PostHog/posthog#138239, which removes each listed key from the merged property map before matching (`rust/feature-flags/src/flags/flag_matching.rs`).

## Decisions

1. Match the flags service for local evaluation. With the listed key removed, each operator in `match_property` returns from its missing-value branch before it reads the condition value:
   - `regex` and `not_regex` return `operator == NotRegex` before the pattern is compiled.
   - `gt`, `gte`, `lt`, and `lte` return false before the condition value is parsed as a number.
   - The `semver_*` and `is_date_*` operators return false before the condition value is parsed.
   - `exact`, `is_not`, and the string-search operators return their missing-value result without reading the condition value.

   So for a listed key, an invalid or engine-specific pattern and a malformed numeric, date, or version operand don't change the result.
2. Alternative considered: keep a malformed condition value inconclusive for a listed key, so the flag falls back to `/flags`. That gives the server's answer only when remote fallback is available, and costs a request. Local-only evaluation would leave the flag unresolved. Matching the server's rule locally gives the same answer in both modes.
3. Keep an omitted condition value inconclusive. The server returns no match for every value-requiring operator when the condition value is missing, including `is_not`. The existing spec makes an omitted condition value inconclusive, and falling back is harmless, so this change does not alter that rule.
4. Keep the operator-support check first, as #233 requires. `between` and `not_between` are not affected: no SDK implements them locally, and the server validates their bounds before its missing-value branch.
5. The v2 rules evaluator in the flags service (`evaluate_v2.rs`) rejects an invalid regex before matching. Local evaluators in SDKs evaluate the standard flag definitions, so this change follows the standard matcher. A future local v2 evaluator follows the v2 rules.

## Validation

Acceptance rows cover an invalid regex for both regex operators, a non-numeric `gt` operand, an invalid version, an invalid date, and an omitted condition value on a listed key. A scenario covers a pattern the SDK regex engine doesn't support. `openspec validate --specs --strict` passes, and the delta in this archive matches the canonical spec.

## Risks

A listed key hides a misconfigured condition value, which would otherwise surface as a no-match or a fallback. That is the server's behavior, and the flag gets the same value either way.
