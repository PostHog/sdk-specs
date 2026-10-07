## 1. Spec delta

- [x] 1.1 Add the iOS surface variant and its payload shape
- [x] 1.2 Note late-registration delivery and post-commit ordering for iOS in the behavior narrative
- [x] 1.3 Add one scenario: a non-quota failed flag load still invokes the listener, with payload/error assertions scoped to payload-carrying surfaces
- [x] 1.4 Add matching acceptance coverage for the failed-load listener scenario

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Sync the delta into `specs/on-feature-flags/spec.md` and archive the change
