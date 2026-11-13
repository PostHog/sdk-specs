## 1. Contract update

- [x] 1.1 Read the posthog-android and posthog-rust changes and confirm the behavior they converge on.
- [x] 1.2 Check the existing `before-send-hook` spec for an invocation-count or ordering rule.
- [x] 1.3 Add the single-invocation requirement and its scenarios.
- [x] 1.4 Sync the change into the canonical spec.

## 2. Validation and archive

- [x] 2.1 Check the diff.
- [x] 2.2 Archive the completed change on this branch.

Validation: diff reviewed; `openspec validate --specs --strict` was not run because the OpenSpec CLI is not installed in this environment. These are specification checks, not executed SDK conformance tests. The new scenarios are not mirrored into `acceptance/private/before-send-hook.feature` because the harness has no steps for hook invocation counts, group merging or minimized flag-called events.
