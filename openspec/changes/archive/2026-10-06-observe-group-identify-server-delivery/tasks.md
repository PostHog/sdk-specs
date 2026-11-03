## 1. Acceptance scenarios

- [x] 1.1 Replace the server happy-path coverage in the existing group-identify feature with a public-delivery outline for scalar and nested properties, using per-row case labels and `@sdk:server` selection.
- [x] 1.2 Add a no-properties server delivery scenario that checks the event name, explicit distinct ID, group type, and group key.
- [x] 1.3 Give legacy client and invalid-input scenarios their own setup, preserve their applicability and assertions, and correct the supplied `plan` assertion to `$group_set.plan`.

## 2. Validation

- [x] 2.1 Parse the updated feature and compare its scenario inventory with the existing feature, including both Examples rows and preserved legacy scenarios.
- [x] 2.2 Verify server-tag selection includes exactly the three new group-identify executions and preserves existing identify/alias selection.
- [x] 2.3 Run strict OpenSpec validation and address any inconsistencies between the delta and acceptance scenarios.

## 3. Canonical specification and handoff

- [x] 3.1 Sync the completed delta into the canonical group-identify spec and verify the nested-property correction and delivery scenarios are present.
- [x] 3.2 Archive the completed change on the same branch and validate the resulting canonical spec strictly.
- [x] 3.3 Record the harness route and Node adapter work needed to execute the scenarios, with local validation and released-image rollout as separate gates.
