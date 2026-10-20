## Why

The group-identify acceptance scenario checks private queue state and places supplied group properties at the event-property root. SDK implementations and ingestion instead use `properties.$group_set`, so the scenario does not accurately describe the group profile update.

## What Changes

- Correct the canonical group-property nesting assertion to `$group_set`.
- Add server delivery scenarios in the existing group-identify feature, using public calls, flush, and mock-server observations.
- Cover explicit distinct IDs, scalar and nested JSON group properties, and delivery with omitted properties.
- Preserve the existing client-state and invalid-input scenarios.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `group-identify`: Correct the supplied-property assertion and describe server group-profile delivery through observable event output.

## Impact

- `acceptance/public/group-identify.feature` and the canonical group-identify spec.
- A shared harness binding for `/group_identify` and Node's mapping to public `groupIdentify`.
- Controlled-host assertion tests and source-built Node validation in both capture modes and module formats.
- No SDK implementation, public signature, default, or ingestion change. CI rollout requires the reviewed specs and harness to be included in a released image.
