## Why

The current before-send contract allows an SDK to send an event after a hook throws. If the hook performs privacy filtering or PII redaction, sending the unprocessed or partially processed event can leak sensitive data.

## What Changes

- **BREAKING** Require SDKs to fail closed by dropping an event when any before-send hook throws.
- Require SDKs to log a warning without propagating the hook exception to the caller.
- Stop the remaining hook chain after an exception.
- Add an acceptance assertion that the affected event is not enqueued.
- Align the capture contract with the canonical before-send behavior.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `before-send-hook`: Define hook exceptions as fail-closed event drops.
- `capture`: Replace platform-specific exception fallback behavior with the canonical fail-closed rule.

## Impact

SDKs that currently continue with the original or last successfully transformed event after a hook exception will need to drop that event instead. The private before-send acceptance feature will enforce the behavior across client and server SDKs. No public API signatures or dependencies change.
