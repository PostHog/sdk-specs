## 1. Spec delta

- [x] 1.1 Modify exactly one requirement in `local-feature-flag-evaluator`, **Regular-expression criteria perform safe case-sensitive search**, as a full copied-and-edited block
- [x] 1.2 State that unescaped `^` and `$` anchor to the whole input with no trailing-line-feed exemption
- [x] 1.3 State that a pattern or input outside the portable subset is inconclusive even when the local engine would return a definitive result
- [x] 1.4 Allow deferral in place of the definitive invalid-pattern no-match when the SDK's notion of invalidity differs from the service's
- [x] 1.5 Add the **Engine-divergent regex evaluation defers to the service** and **Portable ASCII regex criteria stay local** scenarios and the strict end-anchor rows
- [x] 1.6 Add the same scenarios to `acceptance/private/local-feature-flag-evaluator.feature`

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/local-feature-flag-evaluator/spec.md` and archive the change
