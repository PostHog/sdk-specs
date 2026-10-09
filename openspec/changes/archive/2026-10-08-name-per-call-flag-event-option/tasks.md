## 1. Contract update

- [x] 1.1 Confirm the per-call option name in each audited client and server SDK, and the names posthog-flutter 6.0 settled on.
- [x] 1.2 Draft the per-call feature-flag-event option requirement and its acceptance scenarios.
- [x] 1.3 Sync the requirement into `get-feature-flag-result` and correct the stale Flutter facts in `feature-flag-called-tracker` and `opt-in`.

## 2. Validation and archive

- [x] 2.1 Validate the change and canonical specs strictly; check the diff.
- [x] 2.2 Archive the completed change on this branch.

Validation: `openspec validate --specs --strict` is unchanged from `main` (33 passed, 31 pre-existing long-requirement warnings); the change passed strict validation before archiving. Checked `git diff --check`. These are specification checks, not executed SDK conformance tests.
