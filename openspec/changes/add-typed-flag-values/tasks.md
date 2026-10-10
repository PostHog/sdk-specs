## 1. Evidence

- [x] 1.1 Read the `/flags?v=3` wire contract and reader fixtures in posthog-sdk-test-harness 1.13.1 (`contracts/feature_flag_rules_v2`), including the OpenFeature mapping and the legacy rendering table.
- [x] 1.2 Compare the reference implementation in posthog-python#1031 and record where it differs.
- [x] 1.3 Survey the shipped OpenFeature providers (Python, Node, web, Elixir) and how they map values, reasons and errors today.
- [x] 1.4 Survey the existing legacy accessors, the `evaluateFlags()` snapshot and the `$feature_flag_called` tracker contracts.

## 2. Settle the decisions

- [ ] 2.1 Settle each decision listed in the PR description and in `design.md` (D1 to D16), and record the outcome in `design.md`.
- [ ] 2.2 Update the spec deltas for every decision that changes.
- [ ] 2.3 Confirm the config version 1 reason mapping with the wire contract owners, or add it to the contract.

## 3. Acceptance and discoverability

- [ ] 3.1 Add `acceptance/public/typed-flag-values.feature` with the typed resolution table, missing, failed and malformed records, older-server records, bootstrap, and the shared `$feature_flag_called` event.
- [ ] 3.2 Add "Typed Flag Values" to the capability index in `README.md`.

## 4. Validation and archive

- [ ] 4.1 Run `openspec validate add-typed-flag-values --strict` and resolve all issues.
- [ ] 4.2 Archive the change so the canonical specs are synced in the same PR, then run `openspec validate --specs --strict`.
