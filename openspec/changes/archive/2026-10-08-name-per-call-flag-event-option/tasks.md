## 1. Contract update

- [x] 1.1 Confirm the per-call option name in each audited client and server SDK, and the names the unreleased posthog-flutter 6.0 settles on.
- [x] 1.2 Draft the per-call feature-flag-event option requirement and its acceptance scenarios.
- [x] 1.3 Sync the requirement into `get-feature-flag-result` and state the Flutter facts (released 5.x vs unreleased 6.0) in `feature-flag-called-tracker` and `opt-in`.

## 2. Validation and archive

- [x] 2.1 Validate the change and canonical specs strictly; check the diff.
- [x] 2.2 Archive the completed change on this branch.

Validation: `openspec validate --specs --strict` reports 64 passed, 0 failed; the change passed strict validation before archiving. Checked `git diff --check`. These are specification checks, not executed SDK conformance tests.
