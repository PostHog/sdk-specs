## Context

The current target omits null-valued object members before sending but does not explicitly protect existing nullable input APIs or cover disk-backed event serialization. The owner clarified that cleanup belongs at serialization boundaries, not in stricter public argument types or validation.

## Goals / Non-Goals

**Goals:** Keep previously supported null/undefined property inputs source-compatible and runtime-compatible. Normalize serialized event data for both network and disk persistence while retaining array positions.

**Non-Goals:** Widening APIs that currently reject null values, adding persistence to SDKs without it, changing generic storage/feature-flag caches, or implementing SDK changes.

## Decisions

- Extend the shared capture requirement rather than duplicate policy in AI and exception specs. Those capture methods already reference it.
- Preserve existing property-map value types, signatures, and runtime acceptance. Existing caller code must not require casts, filtering, or a different API solely because of this normalization.
- Apply cleanup to event serialization for wire transport and disk-backed event queues/caches. In-memory representations may still contain null/undefined. Do not change hook timing; the wire payload must still satisfy cleanup after before-send processing.
- Preserve null array elements. JavaScript undefined array entries serialize as null under ordinary JSON rules; neither case permits array compaction.
- Validate persisted event contents before network delivery so a wire-only implementation does not satisfy the disk scenario accidentally. After restoring the event, check the wire payload again.

## Risks / Trade-offs

- Confusing API acceptance with serialized output → explicitly test previously supported inputs and forbid narrowing public types or rejecting those calls.
- Applying event cleanup to unrelated caches → scope disk normalization to serialized captured events, not general persistent storage semantics.
- Typed/null-restricting SDKs or SDKs without disk queues cannot exercise every scenario → make those scenarios conditional on existing support and require no new public surface or persistence implementation.
