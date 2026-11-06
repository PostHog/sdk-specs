## 1. Finalize the contract delta

- [x] 1.1 Check the item-model requirements against the pinned backend sources in `design.md`, including nullable inheritance, identifier validation, unchanged receipts, and legacy fingerprint compatibility.
- [x] 1.2 Confirm both capability deltas cover direct construction and dataset conversion, explicit versus inherited identity, saved declarations, resumed handles, multi-scorer reuse, chunking, and recovery without expanding the SDK read API scope.

## 2. Align public acceptance scenarios

- [x] 2.1 Add the model-attribution and replay scenarios to `acceptance/public/offline-evaluations.feature`, preserving the existing scenarios and public request/response assertions. Include invalid values, boundary/text preservation, legacy replay, content conflicts, and recovery across chunks.
- [x] 2.2 Add the conversion scenarios to `acceptance/public/ai-datasets.feature`, checking distinct execution IDs, retained dataset-version references, caller-supplied models, and absence of model inference from metadata.
- [x] 2.3 Check one-to-one scenario coverage against the deltas. Keep `@server` applicability and the missing-management-bindings note; do not claim real SDK conformance or add integration-selection tags without a working adapter run.

## 3. Validate and synchronize

- [x] 3.1 Run `openspec validate add-offline-evaluation-item-models --strict --no-interactive` and inspect the complete delta for accidental changes to unrelated contracts.
- [x] 3.2 During canonical synchronization, reconcile the offline-evaluations item declaration description and the ai-datasets `EvaluationItem.from_dataset_item` input row with the new optional nullable `model_version`. Retain experiment defaults and the existing receipts and HTTP routes.

## 4. Complete this spec change on the same branch

- [x] 4.1 Sync the deltas and archive with `openspec archive add-offline-evaluation-item-models`, retaining proposal, design, tasks, and deltas under the dated archive directory on this branch. Finish the archive-time checklist in the archived tasks file; SDK implementation is downstream and is not an archive prerequisite.
- [x] 4.2 Run `openspec validate --specs --strict --no-interactive` and `git diff --check`. Verify the canonical specs, acceptance files, and archive agree, that no active directory remains, and that the same eventual PR contains the complete change.
