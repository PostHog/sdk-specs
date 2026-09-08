## Why

The owner has selected omission of null-valued object properties to align SDK output with planned backend removal. That backend work is still in progress; this change does not claim it is already deployed. Null array elements remain valid because removing them would change array positions.

## What Changes

- Supersede the earlier `preserve-null-capture-properties` decision in this PR.
- Drop null-valued custom object properties before sending, recursively through nested objects, including objects inside arrays.
- Preserve null array elements, array order, non-null values, and objects left empty by filtering.
- Apply the same rule to queued, immediate, AI, and exception capture without rejecting an otherwise valid event.
- Update acceptance scenarios to assert the normalized wire payload rather than the original input.
- **BREAKING** for SDKs that currently preserve null-valued object properties. SDK compatibility and rollout work remain separate.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture`: Replace null-property preservation with recursive object-key omission, retaining null array elements.
- `capture-ai`: Apply the revised capture normalization contract on the AI route.
- `capture-exception`: Apply the revised contract to additional custom properties.

## Impact

Specifications and acceptance scenarios only. No SDK or backend implementation changes. The old archive remains as historical context and is superseded by this change. Existing privacy controls, reserved-field validation, and OTLP attribute rules remain unchanged.
