## 1. Define and apply the contract

- [x] 1.1 Compare dependency evaluation and group filter scoping with the flags service.
- [x] 1.2 Modify the per-condition aggregation and flag-dependency requirements.
- [x] 1.3 Add matching Gherkin scenarios to the local evaluator acceptance feature.
- [x] 1.3b Treat an empty, null, boolean, array or object group key as no key, as `is_usable_group_key` does.
- [x] 1.3a Replace the missing-group-context scenario: no group key resolves `false`, a supplied key without the needed properties stays inconclusive.
- [x] 1.4 Sync the delta into the canonical spec and archive the change.
- [x] 1.5 Run `openspec validate --specs --strict`.

## 2. Follow-up outside this change

- [ ] 2.1 Update local-evaluation SDKs that evaluate a referenced flag with the caller's context, or that skip group known-absent keys for a group filter without an index. posthog-ruby is fixed in PostHog/posthog-ruby#369.
