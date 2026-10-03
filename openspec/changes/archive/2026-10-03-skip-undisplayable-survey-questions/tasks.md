## 1. Spec delta

- [x] 1.1 Add one requirement to `surveys` covering surveys whose questions the SDK cannot display
- [x] 1.2 Forbid partial display and give the reason (branching and response keys address the full question list)
- [x] 1.3 State that a skipped survey is not marked seen and emits no interaction events
- [x] 1.4 Cover the public renderability check
- [x] 1.5 Add scenarios for the skipped survey and for the unaffected all-displayable case

## 2. Validation

- [ ] 2.1 Run `openspec validate --specs --strict` and resolve any errors — CLI not installed in this environment
- [x] 2.2 Sync the delta into `specs/surveys/spec.md` and archive the change
