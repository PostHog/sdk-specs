## 1. Spec delta

- [x] 1.1 Add exactly one requirement to `capture-ai`, **AI instrumentation attributes events to the active context**
- [x] 1.2 State the wire keys and that `$ai_session_id` is not the session key
- [x] 1.3 State the precedence order and the already-names-a-user carve-out
- [x] 1.4 State that the live span is never mutated and that stamping never raises
- [x] 1.5 Cover each of the above with a scenario
- [x] 1.6 Note in `Applicability` that the requirement binds SDKs shipping the OTel AI bridge

## 2. Validation

- [x] 2.1 Check the delta against the shipped posthog-js, posthog-python and posthog-go sources
- [x] 2.2 Sync the delta into `specs/capture-ai/spec.md` and archive the change
