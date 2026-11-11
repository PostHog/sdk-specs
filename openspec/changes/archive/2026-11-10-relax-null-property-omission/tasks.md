## 1. Spec delta

- [x] 1.1 Make omission optional in **Capture drops null-valued object properties**, state that a kept null is sent as JSON `null` and stored, and make the cleanup rules conditional on omitting
- [x] 1.2 Keep the public API compatibility rule unconditional
- [x] 1.3 Tag every scenario that asserts omission with `@null_property_omission_capable` in `capture`, `capture-ai` and `capture-exception`

## 2. Acceptance features

- [x] 2.1 Tag the omission scenarios in `acceptance/public/capture.feature`, `capture-ai.feature` and `capture-exception.feature`

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict --no-interactive` with openspec 1.4.1
- [x] 3.2 Sync the delta into `openspec/specs/` and archive the change
