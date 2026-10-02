## 1. Contract correction

- [x] 1.1 Confirm the reduction and its ordering in posthog-js #5144 against the merged source.
- [x] 1.2 Draft the required-versus-supporting split and the rate-limiting requirement.
- [x] 1.3 Sync the canonical spec, preserving the mobile divergences and unrelated scenarios.

## 2. Validation and archive

- [x] 2.1 Check the delta and canonical requirements agree and no unrelated scenario moved.
- [x] 2.2 Archive the completed change on this branch.

Validation: checked the delta and canonical requirements for parity, that only the two intended
requirements and the one posthog-js scenario changed, and that the mobile session-key,
hold-reason, trigger, and capture-mode scenarios are untouched. `openspec validate` was not run —
the CLI is not installed in this environment. These are specification checks, not executed SDK
conformance tests.
