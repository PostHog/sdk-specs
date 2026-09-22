## Context

All twelve review threads concern static spec consistency or acceptance scenario coverage. Inspection confirms conflicting cache wording, raw-string snapshot access without validation, understated migration impact, and missing scenarios. No SDK implementation is present here, so runtime reproduction would not validate this patch.

## Goals / Non-Goals

Goals: make malformed payload handling consistent across exposed APIs and use unambiguous, reusable acceptance steps.

Non-goals: change valid snapshot representations, introduce SDK implementation changes, or claim runtime conformance for historical compliance reports.

## Decisions

- Create and archive a follow-up change in the same PR rather than reopening an archived directory.
- Cache failures follow the payload getter contract. Snapshot accessors validate serialized JSON even when returning valid serialized JSON unchanged. This preserves the snapshot spec's explicitly allowed representations while closing malformed-string fallback.
- A malformed payload on a known flag uses the known-flag/no-payload sentinel. JavaScript and TypeScript use `null`, not the unavailable-flag `undefined` sentinel. Existing non-nullable raw-string snapshot signatures can retain their documented empty representation.
- Put client/server tags on scenario outlines. Add a `payload_default_capable` tag for the optional caller-default API.
- Mirror changed Gherkin scenario steps and tables in delta specs, preserving existing requirements and unrelated scenarios.

## Risks / Trade-offs

- Legacy Go getters need a return-type migration for the decoded-value getter contract; record this accurately without imposing it on valid raw snapshot representations.
- Gherkin files describe cross-SDK acceptance contracts, not implemented step definitions in this repository. Validate syntax and fixture JSON, not SDK runtime behavior.

## Validation

Strict OpenSpec validation, Gherkin parsing and example expansion, JSON fixture validation, exact mirrored-step comparison, and final branch review.
