## Why

A generated server identify identity must not create a person profile. Legacy capture and Capture v1 represent that instruction in different fields; the existing identify requirement names only the legacy field, so the new black-box acceptance case incorrectly rejects conforming Capture v1 delivery.

## What Changes

- Specify the exact personless representation for each received capture format without changing identity precedence or caller overrides.
- Assert the appropriate field against the observed request for both delivery formats.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `identify`: Clarify where the personless instruction appears on legacy and Capture v1 delivery.

## Impact

Canonical identify spec and the server identify acceptance assertion. No SDK production API or delivery behavior changes.
