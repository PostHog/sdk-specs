## 1. Spec delta

- [x] 1.1 Add **Values the record did not supply are reported as config version 1** to `feature-flag-called-tracker`
- [x] 1.2 Name the new cases in **Config version 2 attribution on `$feature_flag_called`**, and scope its `$feature_flag_response` rule to values the record supplied
- [x] 1.3 Name the new cases in the `experiment-exposure` trigger

## 2. Acceptance features

- [x] 2.1 Add a match-value scenario and a stale-cache scenario outline to `acceptance/private/feature-flag-called-tracker.feature`

## 3. Validation

- [x] 3.1 Run `OPENSPEC_TELEMETRY=0 openspec validate --specs --strict --no-interactive` with openspec 1.4.1
- [x] 3.2 Sync the delta into `openspec/specs/` and archive the change
