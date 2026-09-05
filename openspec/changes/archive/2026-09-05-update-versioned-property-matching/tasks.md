## 1. Reproduce and specify

- [x] 1.1 Record the baseline contract/fixture version-selector gap against the service behavior.
- [x] 1.2 Validate both delta specs strictly and obtain apply authorization for this approved slice.

## 2. Acceptance fixtures

- [x] 2.1 Preserve the legacy equality table with explicit missing-version setup; add missing/1/2 six-row exact and complementary is_not cases, edge cases, normalization, and missing-property cases.
- [x] 2.2 Add person/group/recursive-cohort and dependency propagation, supported API surfaces, and stable in-flight snapshot cases.
- [x] 2.3 Add definition envelope, version-only reload, fresh omission, 304/failure, supported cache round-trip/hydration, and clear-state cases.

## 3. Validate and synchronize

- [x] 3.1 Parse and compile acceptance Gherkin with available tooling and check the six-row/complement coverage.
- [x] 3.2 Validate the change strictly and confirm scope excludes implementation code and compliance assertions.
- [x] 3.3 Archive with the OpenSpec CLI to sync canonical specs, then strictly validate canonical specs and verify delta synchronization.
- [x] 3.4 Verify git diff --check and no staged files; provide contract paths, validation limits, and review handoff.
