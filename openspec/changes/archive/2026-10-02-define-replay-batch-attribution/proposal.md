## Why

Replay ingestion combines a request's snapshots into one message using the first snapshot event's session ID and distinct ID. A batch that crosses either boundary silently attributes later snapshots to the wrong session or identity; the existing batching contract does not document this constraint.

## What Changes

- Add a replay-specific requirement to `event-batcher`: every replay request must contain snapshots with the same session ID and distinct ID.
- Preserve the identifiers recorded on each queued snapshot when constructing requests, including after restart and retry.
- Document the ingestion behavior and scenarios for session changes, identity-only changes, persisted snapshots, and homogeneous batches.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `event-batcher`: define replay request attribution boundaries alongside existing batch-size and delivery behavior.

## Impact

Applies to replay-capable client SDKs and native replay transports used by wrappers. This is a canonical specification correction, not a claim that all current SDKs conform. No public API or SDK implementation changes are included; implementations and executable harness bindings remain in their respective repositories.
