## Context

The backend accepts revision-checked writes to stored resources. Upload receipts contain identities, acceptance times, and outcomes. They do not carry an edit revision. [Backend contract](https://github.com/PostHog/posthog/blob/a0eedd4a6c6e9c10c3c34ceeb432ffa089334ffe/docs/internal/ai-offline-evaluation-reporting.md#updating-and-deleting-offline-evaluation-data)

## Decisions

- Expose two revision reads. The item detail returns the item revision. The result payload endpoint returns its owner's revision even when the payload is unavailable. Callers can chain the integer returned by a PATCH into their next write to that owner.
- Require the caller's revision on every mutation. A lost acknowledgment or a conflicting writer requires a new decision from the caller. Automatically refreshing and retrying would discard the protection provided by the original revision.
- Preserve original upload declarations and outcomes for retained records. This lets callers recover an upload acknowledgment without undoing later corrections. A hard deletion changes replay behavior because the original record no longer exists.
- Keep composite evaluation, cascades, and retention on the server. The SDK sends the caller's fields, lets the server evaluate the pinned scorer rules, and exposes its structured errors.

## Verification

The Python reference includes request-level tests for both clients. Its sync integration smoke test exercised all eight mutations against the backend handlers, including a stale item delete after a score correction. The shared harness currently lacks offline-evaluation management bindings. The public scenarios retain the feature's existing descriptive server tag. [Python implementation and tests](https://github.com/PostHog/posthog-python/pull/1285)
