## 1. Contract and evidence

- [x] 1.1 Inspect the current handled-state contract and the review discussion in posthog-ruby#336.
- [x] 1.2 Confirm retry and escaping terminal dispositions with real modern and Rails 5.2 Active Job lifecycles in the Ruby SDK worktree.
- [x] 1.3 Define the framework job execution boundary and add consumed-retry and escaping-terminal scenarios while preserving existing scenarios.

## 2. Validation and archive

- [x] 2.1 Validate the delta and sync it into the canonical exception-event-metadata spec.
- [x] 2.2 Run strict canonical spec validation and review the diff for unrelated changes.
- [x] 2.3 Archive the complete change on this branch before opening the PR.
