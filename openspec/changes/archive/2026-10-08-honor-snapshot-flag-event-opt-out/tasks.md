## 1. Contract update

- [x] 1.1 Survey the server SDKs' per-call and client-level `$feature_flag_called` controls, and how their snapshot reads handle them today.
- [x] 1.2 Add the snapshot feature flag event control requirement and its scenarios to the `evaluate-flags` delta.
- [x] 1.3 Amend lazy access tracking and the supersession map so they defer to the new control.
- [x] 1.4 Add matching acceptance scenarios to `acceptance/public/evaluate-flags.feature`.

## 2. Validation and archive

- [x] 2.1 Validate the change and canonical specs strictly, parse the Gherkin feature, and check the diff.
- [x] 2.2 Sync the delta into `openspec/specs/evaluate-flags/spec.md` and archive the change on this branch.

Validation: `openspec validate --specs --strict` passes, the change passed strict validation before archiving, the acceptance feature parses as Gherkin, and `git diff --check` is clean. These are specification checks, not executed SDK conformance tests.
