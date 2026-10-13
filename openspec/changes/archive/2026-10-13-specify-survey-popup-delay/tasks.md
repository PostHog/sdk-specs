## 1. Spec delta

- [x] 1.1 Add a `Survey popup delay` requirement to `surveys`
- [x] 1.2 State the delay source and the non-positive/missing fallback
- [x] 1.3 Require reserving the survey before the wait, and measuring the wait from the first trigger
- [x] 1.4 State what happens to a pending survey that is dropped before it is shown (no events, not seen)
- [x] 1.5 Require the host UI layer to report back so the reservation is released
- [x] 1.6 Record the browser-only resume-from-activation and bypass behaviors as allowed
- [x] 1.7 Add scenarios for the delayed display, the repeat trigger, the zero/missing delay, and the dropped pending survey

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Sync the delta into `specs/surveys/spec.md` and archive the change
