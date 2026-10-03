## 1. Spec delta

- [x] 1.1 Add the iOS surface variant and its payload shape
- [x] 1.2 Note late-registration delivery and post-commit ordering for iOS in the behavior narrative
- [x] 1.3 Add one scenario: a failed flag load still invokes the listener, with the last known flags

## 2. Validation

- [ ] 2.1 Run `openspec validate --specs --strict` and resolve any errors — CLI not installed in this environment
- [x] 2.2 Sync the delta into `specs/on-feature-flags/spec.md` and archive the change
