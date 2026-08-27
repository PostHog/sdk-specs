## 1. Verify the Canonical Matching Contract

- [x] 1.1 Reconcile the operator inventory and scope against the feature-flag API allowlist, Rust `OperatorType`, ordinary property dispatch, cohort dispatch, and dependency dispatch at reference commit `935b7683660697bdc75c042c4c56828aeb036754`.
- [x] 1.2 Verify the `exact`/`is_not` coercion, case-folding, and condition-list vectors against PostHog Go PR #299 and the Node, Python, Ruby/Rails, PHP, Java, .NET, and Rust local evaluators.
- [x] 1.3 Verify the proposed missing/null, invalid regex, strict numeric, date/timezone, semantic-version, range, and cohort-negation outcomes against focused backend and SDK tests; record any deliberate canonical choice where implementations disagree.

## 2. Add Complete Private Acceptance Coverage

- [x] 2.1 Add `@server` scenario outlines for operator defaults/result states, `exact`/`is_not`, contains/multi-contains, prefix/suffix, and regex criteria to `acceptance/private/local-feature-flag-evaluator.feature`.
- [x] 2.2 Add `@server` scenario outlines for numeric ordering and cohort-only ranges, date comparisons with a fixed clock, and all semantic-version comparison/range operators.
- [x] 2.3 Add specialized cohort-membership and negated-inconclusive scenarios, preserving the existing presence and flag-dependency scenarios rather than duplicating or contradicting them.
- [x] 2.4 Check programmatically that every operator and alias in the canonical inventory appears in either the new acceptance vectors or an existing dedicated scenario.

## 3. Review and Archive

- [x] 3.1 Review the delta and acceptance vectors for consistent operand direction (`property operator condition`), positive/negative boundaries, direct-versus-cohort-only scope, and definitive-false versus inconclusive outcomes.
- [x] 3.2 Run strict OpenSpec validation for the change and the full spec set, parse/check the edited Gherkin feature, and run `git diff --check`.
- [x] 3.3 Complete a fresh read-only review against the reference implementation and PR #299, address concrete findings, then archive `define-local-eval-property-matching-criteria` into the canonical `local-feature-flag-evaluator` spec.
