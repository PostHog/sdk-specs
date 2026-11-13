## 1. Contract and evidence

- [x] 1.1 Read the shipped `trace_propagation_targets` implementation, its matching rule, header generation, and no-overwrite behavior in posthog-js.
- [x] 1.2 Confirm no canonical spec, open change, or open PR already covers `traceparent` injection.
- [x] 1.3 Write the delta requirement and its scenarios, keeping the feature optional and off by default.

## 2. Validation and archive

- [x] 2.1 Sync the delta into the canonical tracing-headers spec and update the capability's header table and configuration surface to match.
- [x] 2.2 Validate the tracing-headers spec strictly.
- [x] 2.3 Review the diff for unrelated changes and archive the complete change on this branch before opening the PR.
