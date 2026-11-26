## 1. Define and apply the contract

- [x] 1.1 Compare dependency evaluation and group filter scoping with the flags service.
- [x] 1.2 Modify the per-condition aggregation and flag-dependency requirements.
- [x] 1.3 Add matching Gherkin scenarios to the local evaluator acceptance feature.
- [x] 1.3b Treat an empty, null, boolean, array or object group key as no key, as `is_usable_group_key` does.
- [x] 1.3a Replace the missing-group-context scenario: no group key resolves `false`, a supplied key without the needed properties stays inconclusive.
- [x] 1.3c Skip group conditions per condition, with no flag-level `false` rule for dependencies or direct evaluation.
- [x] 1.3d Make a holdout above 0% without a usable flag-level group key inconclusive with `missing_context`, and narrow that reason in evaluate-flags.
- [x] 1.3e Add scenarios for a person condition without the flag-level group key, the holdout case, a condition-level aggregation for an index-less group filter, a matching cross-aggregation dependency, and a usable group key. Tag non-string group keys `@json_group_keys_capable`.
- [x] 1.4 Sync the delta into the canonical spec and archive the change.
- [x] 1.5 Run `openspec validate --specs --strict`.

## 2. Follow-up outside this change

- [ ] 2.1 Update local-evaluation SDKs that evaluate a referenced flag with the caller's context, or that skip group known-absent keys for a group filter without an index. posthog-ruby is fixed in PostHog/posthog-ruby#369.
- [ ] 2.2 Update SDKs that return `false` from the flag-level aggregation before checking conditions, and SDKs that resolve a holdout without a usable flag-level group key locally.
- [ ] 2.3 Declare `feature_flags_json_group_keys_v1` in SDK harness adapters that can pass non-string group keys (PostHog/posthog-sdk-test-harness#120).
