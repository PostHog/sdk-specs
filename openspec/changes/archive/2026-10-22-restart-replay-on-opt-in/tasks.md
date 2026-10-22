## 1. Contract update

- [x] 1.1 Confirm the shipped opt-in replay behavior in posthog-ios, posthog-android and posthog-react-native, and confirm what posthog-flutter currently covers.
- [x] 1.2 Draft the session-rotation and restart-decision requirements and their acceptance scenarios.
- [x] 1.3 Sync the requirements and the narrative notes into the canonical `opt-in` spec.

## 2. Validation and archive

- [x] 2.1 Validate the change and canonical specs strictly; check the diff.
- [x] 2.2 Archive the completed change on this branch.

Validation: reviewed the shipped diffs and PR descriptions for posthog-ios#942, posthog-android#839, posthog-js#5336 (React Native) and posthog-flutter#606. `openspec validate opt-in --type spec --strict` passes; the repo-wide `openspec validate --specs --strict` run goes from 31 to 32 passing with no newly failing spec. These are specification checks, not executed SDK conformance tests.
