## 1. Contract correction

- [x] 1.1 Confirm the intentional override in posthog-js #1085 and the compatibility concern in #5129.
- [x] 1.2 Draft the mandatory-versus-replaceable scrubbing contract and six acceptance scenarios.
- [x] 1.3 Sync the canonical spec narrative and requirement, preserving unrelated scenarios.
- [x] 1.4 Correct the browser compliance finding and associated roll-up counts.

## 2. Validation and archive

- [x] 2.1 Validate the change and canonical specs strictly; check the diff and compliance counts.
- [x] 2.2 Archive the completed change on this branch after verified agent-driven spec sync.

Validation: `openspec validate --specs --strict` passed all 63 specifications; the change passed strict validation before archiving. Checked exact delta/canonical requirement parity, preservation of existing scenarios, compliance totals (59 rows), and `git diff --check`. These are specification checks, not executed SDK conformance tests.
