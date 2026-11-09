## 1. Spec delta

- [x] 1.1 Add the `quotaLimited` row to the remote-config wire-field table
- [x] 1.2 Add the paragraph on absence, the values the server sends today, and unknown values

## 2. Validation

- [x] 2.1 Run `OPENSPEC_TELEMETRY=0 openspec validate --specs --strict --no-interactive` with openspec 1.6.0
- [x] 2.2 Sync the delta into `specs/remote-config/spec.md` and archive the change
