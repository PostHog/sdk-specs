## Why

PostHog's latest master accepts a model per offline evaluation item, allowing one experiment
to compare executions from several models. The SDK contract currently exposes `model_version`
only on experiment creation, so it cannot describe these executions or preserve their model
attribution when saved and replayed.

## What Changes

- Add optional, nullable `model_version` to evaluation-item declarations and the item objects
  in upload requests. A supplied value overrides the experiment default; omitted or null
  values inherit it.
- Preserve the declared item model through serialization, restoration, shared scorer results,
  chunking, retries, and partial-failure recovery. Do not replace an inherited value with a
  resolved experiment default: explicit model values participate in immutable item identity.
- Allow `EvaluationItem.from_dataset_item` to accept the execution's model independently of
  dataset content and provenance.
- Extend the specification scenarios and their acceptance counterparts for mixed-model runs,
  inheritance, validation, exact replay, and conflicts. Existing experiment-only declarations
  remain valid.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `offline-evaluations`: Item model input, wire placement, validation, inheritance, and
  preservation of immutable declarations across upload and recovery paths.
- `ai-datasets`: Caller-supplied model attribution when converting dataset cases into
  independent evaluation executions.

## Impact

This change affects the two canonical specs and their public acceptance feature files.
SDK implementation remains downstream in the SDK repositories; no backend change is needed
for the inspected API. Backend read responses and model history breakdowns provide evidence
for inheritance semantics, but adding SDK inspection/history APIs is outside this change.

The source baseline and exact request shape are recorded in `design.md`. Applying and
archiving this change must happen on this branch before any spec-change PR merges; this
planning step does not constitute a completed canonical spec change.
