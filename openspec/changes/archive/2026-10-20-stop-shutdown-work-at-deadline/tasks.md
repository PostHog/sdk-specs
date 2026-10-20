## 1. Spec delta

- [x] 1.1 Add one requirement to `shutdown`, **Shutdown stops work when its timeout elapses**
- [x] 1.2 State that the timeout bounds the whole drain: no further drain round once it elapses, and a per-attempt budget check as a SHOULD
- [x] 1.3 State that a stopped drain returns normally and is reported once, not once per abandoned request
- [x] 1.4 Add the stopped-at-deadline, unsent-events-kept, and finished-within-timeout scenarios

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and compare against the base branch
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/shutdown/spec.md` and archive the change
