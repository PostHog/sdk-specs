## 1. Spec delta

- [x] 1.1 Add the **Caller-supplied event properties take precedence** requirement to `capture`, with client scenarios for an SDK context key and for `$is_identified` / `$process_person_profile`
- [x] 1.2 Modify **Canonical register behavior** in `register` as a full copied-and-edited block, adding the per-event override scenario
- [x] 1.3 Rewrite Behavior step 4 in `capture` with the client precedence order, the SDK-owned keys and the server order
- [x] 1.4 Add the matching scenarios to `acceptance/public/capture.feature` and `acceptance/public/register.feature`

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/capture/spec.md` and `specs/register/spec.md` and archive the change
