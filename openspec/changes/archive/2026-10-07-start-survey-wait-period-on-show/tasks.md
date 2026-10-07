## 1. Spec delta

- [x] 1.1 Add one requirement to `surveys` covering when the device-wide last-seen survey date is written
- [x] 1.2 Keep the per-survey seen key on submit or dismiss, and say the two states are distinct
- [x] 1.3 State that a resumed in-progress survey is subject to the wait period
- [x] 1.4 Require the write to happen under the active-survey lock, and `reset` to clear the date
- [x] 1.5 Add scenarios for the wait period starting on show, the shown survey not being marked seen, and the resumed survey
- [x] 1.6 Update the State written, Lifecycle behavior and Concurrency prose in `specs/surveys/spec.md`

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Sync the delta into `specs/surveys/spec.md` and archive the change
