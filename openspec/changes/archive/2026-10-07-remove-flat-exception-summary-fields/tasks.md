## 1. Contract update

- [x] 1.1 Compare the existing flat-field requirement against the standard posthog-js `captureException` event shape.
- [x] 1.2 Update the public capture-exception acceptance scenario to assert primary type/message through `$exception_list`.
- [x] 1.3 Clarify producer metadata ownership for legacy `$exception_type` / `$exception_message` fields.
- [x] 1.4 Sync the change into the canonical specs and acceptance feature.

## 2. Validation and archive

- [x] 2.1 Validate the canonical specs strictly and check the diff.
- [x] 2.2 Archive the completed change on this branch.

Validation: `openspec validate --specs --strict` passed; `git diff --check` passed. These are specification checks, not executed SDK conformance tests.
