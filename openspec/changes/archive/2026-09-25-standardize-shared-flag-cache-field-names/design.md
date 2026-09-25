## Context

External flag-definition providers allow SDKs in different languages to share one definition snapshot. Payload field names must be consistent for readers to consume that snapshot without a language-specific translation.

## Goals / Non-Goals

- Goal: use the flag-definitions endpoint's snake_case field names in shared-cache payloads.
- Non-goals: change provider lifecycle, method names, cache backends, or evaluation semantics.

## Decisions

Require snake_case payload field names, including `flags`, `group_type_mapping`, `cohorts`, `minimal_flag_called_events`, and `property_matching_version`. Existing requirements continue to govern field presence and defaults. Typed representations remain permitted, with the shared representation using these canonical names.

Retain platform-idiomatic provider type names, method names, and return types. These do not determine the stored payload format.

## Validation

Add a specification scenario for an SDK consuming another SDK's shared payload without renaming fields. Validate the delta and synchronized canonical specs using OpenSpec's strict checks.
