## Context

The owner revised the null policy after the initial preservation proposal was archived on this unmerged PR. Backend removal is planned and still in progress. The new target distinguishes object members from array elements, rather than treating all JSON nulls alike.

Android already drops null-valued map entries, although its current serializer also drops null list elements and therefore does not fully match this target. Python PR #926 proposes top-level omission. Neither is evidence that recursive object-key omission with array-position preservation is already uniform across SDKs.

## Goals / Non-Goals

**Goals:** Omit null-valued custom object members before transmission for all capture variants, while preserving null array elements. Give each contract an explicit input and expected wire output.

**Non-Goals:** SDK/backend implementation, rollout timing, changing required or reserved-field validation, null exception inputs, or OTLP attribute encoding.

## Decisions

- Remove null-valued object members recursively, including members of objects contained in arrays. Top-level-only filtering would leave the same kind of null-valued property in nested payloads.
- Preserve array length, ordering, and explicit null elements. For example `["1", null, 2]` is sent unchanged. Objects within arrays are cleaned without removing their array slots, and objects made empty by cleanup remain `{}`.
- Do not reject the event when a property is null, and do not drop an event merely because all custom properties were removed. Preserve `false`, `0`, empty strings, empty arrays/objects, and the literal string `"null"`.
- Make the invariant hold after enrichment and `before_send`, including null-valued members introduced by a hook. Existing privacy drops/mutations remain effective; cleanup never restores data removed by a hook.
- Apply the shared rule to AI capture as a specific normalization exception to its payload pass-through promise. It is not permission to add redaction, truncation, or media processing to manual AI capture.
- Replace the earlier preservation requirements through a new archived delta. Retain the original archive as historical evidence, explicitly marked superseded, rather than rewriting git history.

## Risks / Trade-offs

- Changing SDKs that preserve object nulls changes their wire payloads → SDK-specific compatibility review and rollout remain separate.
- Backend normalization is not fully deployed → document it as the planned target, not existing universal behavior.
- Recursive cleanup could accidentally compact arrays or discard empty objects → acceptance fixtures include both positional nulls and objects emptied inside arrays.

## Migration Plan

Revise the three capture requirements and acceptance scenarios, validate the delta and Gherkin examples, then sync and archive on the existing PR branch. No SDK conformance is asserted by these specification-only checks.
