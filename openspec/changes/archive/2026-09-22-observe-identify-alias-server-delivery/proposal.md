## Why

The server identify and alias acceptance scenarios inspect the SDK queue before delivery. A server SDK may flush between an operation and that inspection, even when its eventual event is correct. The observable contract is the event received after public flush: event name, source identity and user properties or alias target.

## What Changes

- Express the server identify and alias outcomes as delivered events following public flush, without fixed-clock, manual-scheduler or queue-snapshot controls.
- Preserve scalar JSON types and nested user properties for identify; verify two distinct alias source/target pairs.
- Keep existing client-state and invalid-input scenarios separately scoped until they have observable equivalents.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `identify`: Specify observable server delivery of `$identify` and typed `$set` properties.
- `alias`: Specify observable server delivery of `$create_alias` with the previous identity and alias target.

## Impact

Updates the canonical server scenarios under `openspec/specs/identify/` and `openspec/specs/alias/`, and the corresponding `acceptance/public/` features. Public SDK method signatures are unchanged.
