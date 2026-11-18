## 1. Define and apply the contract

- [x] 1.1 Compare the contract with PostHog/posthog#138239 and issue #88947.
- [x] 1.2 Modify the presence, equality, enrollment, string-search, multi-contains, and operator-inventory requirements and add the remote-fallback requirement.
- [x] 1.3 Add matching Gherkin scenarios to the local evaluator acceptance feature.
- [x] 1.4 Sync the delta into the canonical spec and archive the change.
- [ ] 1.5 Run `openspec validate --specs --strict` where the CLI is installed.

## 2. Follow-up outside this change

- [ ] 2.1 Add harness steps for the new scenarios: listing known-absent person and group keys for an evaluation, and asserting the `/flags` request body fields. These steps do not exist in the shared harness yet.
- [ ] 2.2 Implement the input and the fallback fields in each local-evaluation SDK repository.
