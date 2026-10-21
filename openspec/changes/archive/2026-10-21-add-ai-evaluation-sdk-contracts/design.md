## Context

This change records the Python evaluation APIs and the backend contracts they use. It adds
three capabilities in one change/PR. SDK implementations remain in their own repositories.

Source baselines inspected on 2026-10-21:

| Source | Revision | Evidence |
|---|---|---|
| Python SDK | [`2936009887d4b23c9eb4156f77e06734e9513e78`](https://github.com/PostHog/posthog-python/tree/2936009887d4b23c9eb4156f77e06734e9513e78/posthog/ai/evaluations) | Public types, sync/async clients, serialization, transport, dataset and scorer management |
| PostHog backend | [`729121d04061edbcfd4792a3a69870740c07aa43`](https://github.com/PostHog/posthog/tree/729121d04061edbcfd4792a3a69870740c07aa43/products/ai_observability/backend) | Dataset services, score definitions/configuration validation, experiment ingestion/lifecycle, permissions and tags |
| Acceptance harness | [`129fbb4d2e3de8e8d6890925141b6c7fa3667528`](https://github.com/PostHog/posthog-sdk-test-harness/blob/129fbb4d2e3de8e8d6890925141b6c7fa3667528/docs/gherkin-steps.md) | Generated step catalogue and v2 discovery registry |

The Python baseline is the pushed dataset feature branch `feat/llma-datasets-sdk-plan`;
the backend baseline is `feat/aio-remaining-offline-evals`. These are source snapshots,
not a claim that every API is released or deployed. The original offline/scorer APIs and
later tag support are also present in Python's main-branch history; datasets are verified
against the feature branch and the corresponding backend. No other SDK is claimed compliant.

## Goals / Non-Goals

**Goals:** Provide API-defining, portable contracts for datasets, scorers, and offline uploads;
preserve version identities and recoverability; make the intended behavior reviewable through
concrete scenarios; keep canonical specs, acceptance scenarios, and archived history together.

**Non-goals:** Implement SDK ports, execute models or evaluators, specify the backend's wider
experiment inspection/export surfaces, add durable job storage, extend the harness, or revise
analytics capture. Do not publish a new conformance score from mocked unit tests.

## Decisions

### Three capability specs with one shared client contract

`ai-datasets`, `ai-scorers`, and `offline-evaluations` remain sibling capabilities. The latter
owns shared client options, auth, error/transport behavior, and tags; the management specs
reference it. This follows the existing Python client composition and avoids a fourth
transport-only capability or divergent copies of the same rules.

Each spec includes the Python operation mapping and relevant wire endpoints, while permitting
native naming and async conventions. It specifies caller-visible results and received traffic,
without prescribing locks, HTTP libraries, private storage, or generated class layouts.

### Preserve the acknowledged error contract

These APIs intentionally raise local validation errors and structured API exceptions, including
async rejection/cancellation. Preserving this behavior was explicitly confirmed for this change
as an exception to the general no-throw acceptance guidance. Errors distinguish rejected,
not-sent, and uncertain persistence; suppressing them would conceal lost acknowledgments and
partial writes. This decision does not change the existing capture/error-hook contracts.

### Separate metadata, definitions, versions, and executions

Dataset metadata and tags remain mutable; item content changes generate immutable versions
and dataset revisions. Scorer metadata and tags remain mutable; configuration changes require
explicit immutable versions. An experiment pins the snapshot revision UUID, each execution
pins its dataset-item version, and each result pins its scorer version. Source trace/output
provenance is distinct from a new execution's output and trace.

### Match the backend while preserving SDK responsibility

The backend owns uniqueness, version creation, concurrency, permissions, atomic per-request
uploads, and score/configuration compatibility. SDK requirements describe transmitting the
right identities and fields, validating supported local inputs and acknowledgments, and
preserving structured server errors. They do not require a second local implementation of
backend score validation or a scorer-discovery request during upload.

Python's upload count and byte limits are recorded because they directly determine client
validation/chunking against the current API. Dataset capacity quotas stay server policy.
Scorer and dataset writes that lack safe replay identity remain non-retrying; safe operations
reuse the prepared request and obey Retry-After.

### Acceptance scenarios describe public behavior and retain execution gaps

One Gherkin scenario corresponds to each scenario in the three specs, grouped by requirement.
They use public operations, returned values/errors, and isolated mock-service traffic.
The harness catalogue at the recorded revision has no management/offline-evaluation steps or
routes. Use descriptive `@server` tags, not `@sdk:server`; do not invent an adapter route or
claim that matching prose is executable. Discovery reports the missing bindings explicitly.

Harness implementation and actual cross-SDK execution are downstream work, not unfinished
tasks in this specification change. A future harness change must bind the operations to real
SDK methods, preserve native errors separately from adapter transport errors, and verify
healthy/defective controlled adapters plus the real Python adapter before adding opt-in tags.

## Requirement evidence

All paths below are relative to the pinned source repositories above. Python evidence covers
both sync and async where the existing test fixtures parameterize those surfaces. Backend
evidence was inspected from source and tests; the backend service suite was not executed here.

| Requirements | Python evidence | Backend evidence |
|---|---|---|
| Dataset surface/metadata; item values/provenance; immutable versions; optimistic concurrency; archive state | `_datasets.py`, `_async_datasets.py`, `_dataset_types.py`, `_dataset_serialization.py`; `test_evaluations_datasets.py` metadata, creation, update, archive/restore, history, conflict cases | `api/datasets.py`, `dataset_service.py`, `dataset_queries.py`; `api/test/test_datasets.py` stale/no-op updates, history and archive/restore cases |
| Dataset create idempotency; pagination; pinned snapshots; partial reads; response identity | Same Python files; `test_evaluations_datasets.py` lost-create acknowledgment, continuation, historical snapshot, partial-read and invalid-response cases | `dataset_service.py` client-item-ID replay/conflicts; `api/datasets.py` pagination and revision-scoped reads |
| Dataset-to-execution conversion; combined pinned run | `_types.py`; `test_dataset_to_execution_copies_payload_and_keeps_trials_independent`, `test_dataset_scorer_experiment_flow_pins_both_versions_and_reuses_execution` | `offline_evaluation_service.py` dataset revision/version ownership and provenance checks |
| Scorer surface, polarity/configuration, metadata, immutable versions, concurrency, non-retrying writes, pagination and responses | `_scorers.py`, `_scorer_types.py`; `test_evaluations_scorers.py` typed configuration, metadata, version, conflict, pagination and response cases | `api/score_definitions.py`, `models/score_definitions.py`, `score_definition_configs.py`, `score_validation.py`; `api/test/test_score_definitions.py` and configuration/score validation tests |
| Acknowledged client; routing/auth; retry safety; uncertainty/errors; closure/cancellation | `_client.py`, `_transport.py`, `_errors.py`; `test_evaluations_transport.py` and `test_evaluations.py` context/cancellation cases | `api/offline_experiments.py`, `api/offline_evaluation_base.py`, `api/offline_experiment_errors.py` and operation scope declarations |
| Stable creation/resumption; immutable declarations; JSON payloads; typed outcomes | `_client.py`, `_types.py`, `_serialization.py`; `test_evaluations.py` creation recovery, JSON restoration, payload and score cases | `api/offline_experiment_serializers.py`, `offline_evaluation_types.py`, `offline_evaluation_fingerprint.py`, `offline_evaluation_service.py` |
| Upload identities/receipts; bounded chunks; partial failure; explicit lifecycle | `_client.py`, `_types.py`; `test_evaluations.py` shared items, count/UTF-8 boundaries, malformed receipts, partial failure and lifecycle cases | `offline_evaluation_service.py` atomic upload, fingerprint checks, accepted counts and explicit closure; `api/offline_experiments.py` receipts |
| Shared tags | `_tags.py`; dataset/scorer/evaluation tag cases | `api/resource_tags.py`, `resource_tags.py`, scorer/dataset metadata and experiment `partial_update` |

Python paths are under `posthog/ai/evaluations/`, with tests under `posthog/test/ai/`.
Backend paths are under `products/ai_observability/backend/`.

## Risks / Trade-offs

- Feature-branch evidence can change before release → pin both source revisions and review
  later behavioral changes as spec deltas; do not describe this snapshot as a release audit.
- Prose acceptance coverage can be mistaken for executable coverage → record discovery
  results, retain missing bindings, and omit integration-selection tags.
- Management API errors differ from capture conventions → make the exception explicit in
  the shared spec and preserve the existing SDK contract.
- Cross-language numeric and omission semantics can drift → require exact score
  representability, distinct booleans/null/omission, and immutable identities in scenarios.

## Validation

- The four focused Python suites (`test_evaluations`, `test_evaluations_datasets`,
  `test_evaluations_scorers`, and `test_evaluations_transport`) passed: **472 tests**.
- OpenSpec change validation passes with the CI-pinned CLI, version 1.4.1.
- All **62 scenarios** parse through the pinned harness and match their spec scenario titles
  and steps exactly: 19 dataset, 12 scorer, and 31 offline-evaluation scenarios, covering
  35 requirements. No scenario carries an integration opt-in tag.
- Harness discovery with `--require-ready` exits **1**: 62 discovered, **0 harness-ready**,
  62 with missing bindings. All remain unexecuted; adapter support is not negotiated.
  This is a recorded harness coverage gap, not a passing SDK conformance result.
- Strict canonical validation passes: **67 specs, 0 failures**. Each new canonical spec
  matches its archived delta, including the API/data/HTTP sections retained at archive time;
  its scenario titles and steps match the acceptance feature. Relative spec links resolve.

## Migration Plan

Apply the acceptance features and capability indexes, validate, then archive/sync all three
specs on this branch. No SDK/backend deployment or data migration occurs in this PR. Further
ports and executable harness support follow the canonical contracts in separate repositories.

## Open Questions

None for this bounded source-derived contract. Harness execution remains an explicit coverage
gap rather than an unresolved product behavior decision.
