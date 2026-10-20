## 1. Spec delta

- [x] 1.1 Modify exactly one requirement in `logs`, **Monotonic capture timestamps**, as a full copied-and-edited block
- [x] 1.2 State the precision floor (millisecond or finer) and allow finer platform clocks
- [x] 1.3 Change the bump from +1ns to at least 1 µs, and give the reason (microsecond storage)
- [x] 1.4 Update the same-millisecond scenario and add the sub-millisecond-clock scenario

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/logs/spec.md` and archive the change
