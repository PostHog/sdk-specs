## 1. Spec delta

- [x] 1.1 Split the capture-ai Configuration section into the content-capture flag and the AI lane configuration surface
- [x] 1.2 Add the **AI lane configuration is scoped to the AI lane** requirement with scenarios for lane isolation, the lower-only per-event cap, and invalid values
- [x] 1.3 Adjust the Transport (non-normative) paragraph so it no longer implies the per-event cap is unexposed

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/capture-ai/spec.md` and archive the change
