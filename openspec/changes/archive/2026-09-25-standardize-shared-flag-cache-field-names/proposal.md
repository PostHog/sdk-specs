## Why

SDKs sharing a flag-definition cache need the same payload field names. The flag-definitions endpoint already provides a common snake_case format that SDKs can store and read across languages.

## What Changes

- Require snake_case field names in shared flag-definition cache payloads, matching the flag-definitions endpoint.
- Keep provider type names, method names, and return types adaptable to language conventions.
- Add a scenario covering one SDK reading a payload written by another SDK without renaming fields.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `flag-definition-loader`: Standardize shared-cache payload field names.

## Impact

The external flag-definition cache contract and its specification scenarios. SDK implementations remain in their respective repositories.
