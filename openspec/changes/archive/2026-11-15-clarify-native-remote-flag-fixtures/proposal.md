## Why

Migrated remote-flag fixtures and the harness generator lag existing canonical contracts: server privacy defaults differ, and failed scalar reads may preserve documented no-result mappings. The capture overview also overstates queued delivery despite its existing synchronous/immediate-mode paragraph.

## What Changes

- Check omitted GeoIP against declared native defaults, retaining explicit true/false checks and legacy undeclared behavior.
- Document that the four existing failed-reader scenarios accept only boolean false or native null/undefined, guarded by an explicit failed record and actual served-v4 traffic. No generated fixture values or expected successful decisions change.
- Clarify the non-normative capture overview table to describe queued mode normally, retaining already documented synchronous/immediate delivery exceptions.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. Existing capture GeoIP and immediate-delivery requirements and get-feature-flag-result failure mappings remain unchanged. This is a fixture/documentation correction, not a new canonical behavior.

## Impact

One migration scenario assertion/title and migration documentation; editorial capture overview text only. Matching harness bindings, generator and tests ship separately. No SDK implementation, suite applicability or release pins change.
