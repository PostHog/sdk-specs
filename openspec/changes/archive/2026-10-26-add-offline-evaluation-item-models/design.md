## Context

The branch starts from `sdk-specs` main at `90fa4e372219b3c2607e37a3347c0681e9f070aa`.
PostHog master was fetched on 2026-10-26 and inspected at
[`47fdd2b78cb833f01b4d5e225a6d3b7529831f94`](https://github.com/PostHog/posthog/tree/47fdd2b78cb833f01b4d5e225a6d3b7529831f94).
Item models landed in
[`a9a57fa67da1`, score history breakdowns (#122787)](https://github.com/PostHog/posthog/commit/a9a57fa67da181eaa5067e589ae9f4e6970f6b82).
This is source verification, not a claim about deployment or released SDK support.

| Evidence at the inspected master | Contract established |
|---|---|
| [ItemSubmissionSerializer and identifier field](https://github.com/PostHog/posthog/blob/47fdd2b78cb833f01b4d5e225a6d3b7529831f94/products/ai_observability/backend/api/offline_experiment_serializers.py#L249) | Optional, nullable item `model_version`; strict string, nonempty, at most 255 characters, no whitespace trimming |
| [Submission types](https://github.com/PostHog/posthog/blob/47fdd2b78cb833f01b4d5e225a6d3b7529831f94/products/ai_observability/backend/offline_evaluation_types.py#L33) | Model belongs to an item declaration; results continue to reference item and scorer-version UUIDs |
| [Submission fingerprint](https://github.com/PostHog/posthog/blob/47fdd2b78cb833f01b4d5e225a6d3b7529831f94/products/ai_observability/backend/offline_evaluation_fingerprint.py#L28) and [compatibility test](https://github.com/PostHog/posthog/blob/47fdd2b78cb833f01b4d5e225a6d3b7529831f94/products/ai_observability/backend/test/test_offline_evaluation_fingerprint.py#L55) | Null item models are excluded from the fingerprint to preserve legacy replays; explicit model values change it |
| [Ingestion service](https://github.com/PostHog/posthog/blob/47fdd2b78cb833f01b4d5e225a6d3b7529831f94/products/ai_observability/backend/offline_evaluation_service.py#L400) and [replay test](https://github.com/PostHog/posthog/blob/47fdd2b78cb833f01b4d5e225a6d3b7529831f94/products/ai_observability/backend/test/test_offline_evaluation_service.py#L88) | Stored item model is the declared value; uploads compare fingerprints before accepting existing identities |
| [Read resolution](https://github.com/PostHog/posthog/blob/47fdd2b78cb833f01b4d5e225a6d3b7529831f94/products/ai_observability/backend/offline_evaluation_read_service.py#L119) and [breakdown/read tests](https://github.com/PostHog/posthog/blob/47fdd2b78cb833f01b4d5e225a6d3b7529831f94/products/ai_observability/backend/test/test_offline_evaluation_reads.py#L350) | Item reads and model breakdowns use the item model with experiment fallback |

The existing SDK contracts expose `model_version` only in experiment creation. Item
serialization and dataset conversion therefore need an explicit extension. The existing
upload receipt contains acknowledgments, not model metadata; its shape does not change.

## Goals / Non-Goals

**Goals:** Describe several models within one experiment, preserve experiment defaults and
legacy declarations, and carry explicit item attribution through every public construction,
serialization, upload, and recovery path. Keep sync and async behavior equivalent.

**Non-goals:** Implement SDKs or backend changes, add model/provider lookup or execution,
attribute the evaluator's model, change scorer identity, or add SDK experiment/item reads and
history endpoints. The model here identifies the application execution that produced an
item's output. Backend history semantics are evidence for that attribution only.

## Decisions

### 1. Use the existing wire name at item level

Expose optional nullable `model_version` on `EvaluationItem`, including
`EvaluationItem.from_dataset_item`. Send it beside the item's `id`, `case_key`, and other
declaration fields in `POST /api/projects/{project_id}/ai_observability/offline_experiments/{id}/upload/`.
Keep the experiment creation option as a default. A new `model` object, a provider field, or
payload metadata would not match the backend schema.

For an experiment created with `model_version: "model-a"`, this upload attributes the first
execution to `model-b` and the second to `model-a`. The scorer UUID represents an existing
boolean scorer version in the project:

```json
{
  "items": [
    {
      "id": "11111111-1111-4111-8111-111111111111",
      "case_key": "case-1",
      "model_version": "model-b",
      "payload": {"input": "Example input", "output": "First output"}
    },
    {
      "id": "22222222-2222-4222-8222-222222222222",
      "case_key": "case-1",
      "payload": {"input": "Example input", "output": "Second output"}
    }
  ],
  "results": [
    {
      "item_id": "11111111-1111-4111-8111-111111111111",
      "scorer_version_id": "33333333-3333-4333-8333-333333333333",
      "status": "ok",
      "value": true
    },
    {
      "item_id": "22222222-2222-4222-8222-222222222222",
      "scorer_version_id": "33333333-3333-4333-8333-333333333333",
      "status": "ok",
      "value": false
    }
  ]
}
```

`model_version: null` on the second item has the same inheritance semantics as omission.
The SDK validates a supplied non-null model as a nonempty string of at most 255 characters
and preserves the string without trimming or coercion. Existing identifier validation still
applies; model names are caller-supplied identifiers, not an SDK-maintained registry.

### 2. Resolve inheritance on the backend

| Declared item model | Experiment model | Effective model |
|---|---|---|
| `model-b` | `model-a` or null | `model-b` |
| Omitted or null | `model-a` | `model-a` |
| Omitted or null | Omitted or null | Unknown/null |

An SDK sends the declaration, without filling an inherited value from a creation receipt,
cached handle, dataset metadata, or trace. Resumed handles do not know creation fields and
must remain usable without a read request. Resolving defaults locally would also turn an
inherited declaration into different immutable content.

### 3. Preserve declared identity, including across upgrades

An explicit model is immutable item content. Retrying the same UUID and model is an exact
replay. Changing or removing that model conflicts, as does replacing an inherited value with
an explicit model equal to the experiment default. Equal effective attribution does not
make these declarations identical.

Omitted and null models share the legacy backend fingerprint. Saved declarations without the
new key remain restorable and replayable. SDKs may use their existing optional-field
representation for null/omission, but must not insert a non-null default. Once an upload is
prepared, retries preserve the exact prepared body under the existing retry contract.

Serialization, shared-item deduplication, per-chunk declarations, `failed_chunk`, and
`pending_results` must preserve explicit models. A model contributes to the existing encoded
request byte limit. Changing model attribution requires a new execution UUID; adding another
scorer to an accepted execution continues to use its item UUID without redeclaring a model.

### 4. Extend dataset conversion without changing dataset storage

The caller supplies the model used for each new execution. Conversion copies dataset values
and version references as before, but never derives this execution model from source output,
source traces, or arbitrary metadata. Two models evaluated against the same case produce
distinct execution IDs while preserving the same dataset-item version and case key.

### 5. Keep the specification and acceptance scenarios aligned

Add requirements for model attribution and model-preserving replay to `offline-evaluations`.
Modify the complete dataset-conversion requirement, retaining its existing scenario. During
apply, extend the two existing acceptance feature files with corresponding public behavior
scenarios; retain their `@server` applicability tags and documented missing harness bindings.
Do not add `@sdk:server` or claim integration coverage without a real adapter run.

The canonical public-surface descriptions must also list the new item and conversion input
when the delta is synchronized. No new capability or README capability row is needed.

## Risks / Trade-offs

- **Resolved defaults break old retries** → Keep raw declarations separate from backend read
  projections, and cover an explicit model equal to the experiment default as a conflict.
- **One construction path drops the model** → Cover direct construction, dataset conversion,
  saved restoration, bulk chunks, retries, and recovery with the same field semantics.
- **Older servers reject the new field** → Preserve omission for callers that do not supply a
  model; surface structured server rejection rather than silently dropping explicit attribution.
- **Source tests are mistaken for SDK verification** → Record them as evidence inspected;
  execute SDK conformance only in downstream adapter work.

## Migration Plan

1. Review these planning artifacts on this branch.
2. Apply the spec/acceptance changes, validate them, then sync and archive the change on this
   same branch before merging a PR. Archive history must retain this source baseline.
3. Implement the additive field in SDK repositories independently. Existing item declarations
   and experiment defaults remain compatible with the inspected backend.

No backend migration is required by this repository. If an SDK rollout is reverted, callers
can continue using legacy declarations, but must retain explicit-model saved work for a client
that supports it; stripping the field can conflict with already accepted items.

## Open Questions

None for the specification change. Deployed backend availability and released SDK support
are not prerequisites for archiving the completed spec change.

## Validation and downstream gaps

This is a canonical contract update. The inspected Python SDK snapshot
[`2936009887d4b23c9eb4156f77e06734e9513e78`](https://github.com/PostHog/posthog-python/blob/2936009887d4b23c9eb4156f77e06734e9513e78/posthog/ai/evaluations/_types.py#L89)
does not accept `model_version` in `EvaluationItem.__init__` or `from_dataset_item`.
Its `from_dict` delegates to the constructor, so explicit-model restoration also requires a
separate SDK change. No other SDK was audited or claimed conformant.

Acceptance discovery used the generated step catalogue and runner at harness commit
[`129fbb4d2e3de8e8d6890925141b6c7fa3667528`](https://github.com/PostHog/posthog-sdk-test-harness/blob/129fbb4d2e3de8e8d6890925141b6c7fa3667528/docs/gherkin-steps.md),
the same reference as the original evaluation contract. Discovery parsed 45 offline-evaluation
and 21 dataset scenarios, but both readiness checks exited 1: all 66 scenarios lack harness
bindings at this revision. They remain unexecuted and retain descriptive `@server` tags.
No SDK adapter run or conformance result is claimed. The 14 new offline scenarios and two new
dataset scenarios are matched to the delta by title and steps; inheritance assertions inspect
declared request fields rather than unavailable backend read projections.
