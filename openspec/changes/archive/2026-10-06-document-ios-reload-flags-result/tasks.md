## 1. Contract update

- [x] 1.1 Confirm the iOS 4.0 signature in posthog-ios #913 and the failure signals other SDKs expose.
- [x] 1.2 Draft the optional completion failure-reporting requirement and two acceptance scenarios.
- [x] 1.3 Sync the requirement, iOS surface variant, and Error handling note into the canonical spec.

## 2. Validation and archive

- [x] 2.1 Validate the change and canonical specs strictly; check the diff.
- [x] 2.2 Archive the completed change on this branch.

Validation: `openspec validate --specs --strict` passed all 64 specifications; the change passed strict validation before archiving. Checked `git diff --check`. These are specification checks, not executed SDK conformance tests.
