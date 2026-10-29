## 1. Spec delta

- [x] 1.1 Modify **Session, queue, hold-reason, trigger, and mode keys** in `session-replay-debug-properties` so the debug keys follow capture's merge order, replacing the debug-values-win scenario
- [x] 1.2 Update the posthog-ios reference and covering test to 4.0

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/session-replay-debug-properties/spec.md` and archive the change
