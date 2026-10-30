## 1. Contract update

- [x] 1.1 Confirm the shipped opt-in replay behavior in posthog-ios, posthog-android, posthog-flutter and posthog-react-native.
- [x] 1.2 Draft the session-rotation and restart-decision requirements and their acceptance scenarios.
- [x] 1.3 Sync the requirements and the narrative notes into the canonical `opt-in` spec.

## 2. Validation and archive

- [x] 2.1 Validate the change and canonical specs strictly; check the diff.
- [x] 2.2 Archive the completed change on this branch.

Validation: reviewed the shipped diffs and PR descriptions for posthog-ios#942 and #959, posthog-android#839, posthog-js#5336 and #5363 (React Native), and posthog-flutter#606, and the opt-in code on each repository's main branch. `openspec validate opt-in --type spec --strict` passes. These are specification checks, not executed SDK conformance tests.
