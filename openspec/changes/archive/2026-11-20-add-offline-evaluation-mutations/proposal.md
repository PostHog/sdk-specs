## Why

Teams need to correct a reported score or remove a mistaken upload, including after an experiment closes. The SDK contract currently explains how to replay an upload but gives callers no way to distinguish that replay from an intentional edit.

## What Changes

Specify how an experiment handle reads a revision, applies a partial update, and deletes an item, result, or stored payload. Define what callers observe if another writer wins, a response is lost, or a deleted declaration is uploaded again.

## Capabilities

### Modified Capabilities

- `offline-evaluations` gains revision-checked management operations on sync and async experiment handles.

## Impact

The project API implements these operations. The Python SDK supplies the reference method names and return types. [Backend contract](https://github.com/PostHog/posthog/pull/138915) · [Python SDK](https://github.com/PostHog/posthog-python/pull/1285)
