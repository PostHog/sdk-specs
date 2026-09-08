## Context

The capture contract needs a consistent serialization policy that distinguishes object members from array elements without breaking existing public input types. Backend object-null removal is planned and still in progress, not universally deployed.

Android already drops null-valued map entries but also drops null list elements, so it does not fully match this target. Python PR #926 proposes top-level omission. SDK implementation and rollout are separate from this specification change.

## Goals / Non-Goals

**Goals:** Omit null/undefined-valued custom object members when serializing events for the wire or disk. Preserve array positions and existing public API acceptance across ordinary, immediate, AI, and exception capture.

**Non-Goals:** SDK/backend implementation, widening currently non-nullable APIs, adding persistence, changing generic storage/feature-flag caches, or changing reserved-field validation and OTLP encoding.

## Decisions

- Define one shared capture requirement and reference it from AI and exception capture.
- Clean object members recursively, including objects inside arrays. Do not compact arrays or discard objects made empty by cleanup. Preserve `false`, `0`, empty strings, and literal strings such as `"null"` and `"undefined"`.
- Preserve null array elements. JavaScript undefined array entries follow normal JSON serialization as null without shifting positions.
- Preserve existing signatures, property value types, and runtime acceptance. Callers must not need casts, filtering, or a different API solely because of this normalization. In-memory events may retain null/undefined until serialization.
- Apply cleanup during serialization for network delivery and disk-backed event queues/caches. Do not change hook timing; the wire payload must still satisfy cleanup after enrichment and before-send processing.
- Treat AI normalization as a specific exception to payload pass-through, not permission for manual-payload redaction, truncation, or media processing.
- Validate disk contents before delivery, then validate the restored event on the wire. An event whose custom properties are all removed must still be delivered if otherwise admissible.

## Risks / Trade-offs

- Existing serialized output changes → require per-SDK compatibility review and rollout without narrowing supported public inputs.
- Backend work is unfinished → document it as planned behavior, not an existing universal guarantee.
- Recursive cleanup can accidentally compact arrays → fixtures include null positions and objects emptied inside arrays.
- Event normalization could affect unrelated caches → limit persistence cleanup to captured events.
- Some SDKs lack nullable inputs or disk queues → condition relevant scenarios on existing support rather than require new APIs or persistence.
