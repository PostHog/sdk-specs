## 1. Spec delta

- [x] 1.1 Rename `$feature_flag_variant` to `$feature_flag_variant_key` in the `experiment-exposure`, `feature-flag-called-tracker` and `evaluate-flags` requirements and scenarios
- [x] 1.2 Say in **Experiment exposure properties** why the name ends in `_key`
- [x] 1.3 Point the experiment-exposure applicability section at the harness contract that carries the new name

## 2. Acceptance features

- [x] 2.1 Rename the property in `acceptance/private/experiment-exposure.feature` and `acceptance/private/feature-flag-called-tracker.feature`, and realign the changed tables

## 3. Validation

- [x] 3.1 Run `OPENSPEC_TELEMETRY=0 openspec validate --specs --strict --no-interactive` with openspec 1.4.1
- [x] 3.2 Sync the delta into `openspec/specs/` and archive the change
