## MODIFIED Requirements

### Requirement: Upload identity and idempotent acknowledgments

An upload SHALL accept item declarations or references to items already accepted in the
experiment. Result identity SHALL be the experiment/item/scorer-version combination. While the records are retained, exact
replays SHALL retain stored identities and original acceptance times with `created=false`;
changed content for an existing identity SHALL conflict. Every HTTP upload is atomic at the
backend. The SDK SHALL validate that receipts acknowledge exactly the referenced item set
and submitted result pairs in order, with distinct result UUIDs. Malformed or incomplete
acknowledgments SHALL not be reported as successful persistence.

For a retained result, an exact upload replay SHALL acknowledge its original outcome after an edit. The original declaration remains the replay identity. A retry SHALL NOT overwrite a correction. While an experiment is uploading, re-uploading a hard-deleted result or redeclaring a hard-deleted item SHALL create the missing records. Recreated reported results count as new usage. A recreated item SHALL start at a higher revision than its deleted copy.

#### Scenario: Multiple scorers share one item declaration
- **GIVEN** an isolated offline evaluation client and two results for one item using different scorer versions
- **WHEN** the caller uploads both results together
- **THEN** the received request declares the item once and contains both result pairs
- **AND** the receipt acknowledges the one item and both results in order

#### Scenario: Exact replay is observable without duplication
- **GIVEN** an isolated offline evaluation client and an acknowledged item/result upload
- **WHEN** the caller replays the same declarations in the same experiment
- **THEN** the receipt retains the stored identities and original acceptance times with created false

#### Scenario: Missing acknowledgments remain uncertain
- **GIVEN** an isolated offline evaluation client and an upload of two results
- **WHEN** the mock service responds successfully but acknowledges only one result
- **THEN** the caller receives an invalid-response error with unknown persistence

#### Scenario: An upload retry preserves a score correction
- **GIVEN** an acknowledged reported error with code timeout that was later corrected to ok
- **WHEN** the caller replays the original upload with an ingestion-only key
- **THEN** the receipt returns the original error and code with created false
- **AND** the stored corrected result remains ok

#### Scenario: An uploading experiment can recreate a deleted item
- **GIVEN** a hard-deleted item and its reported result in an uploading experiment
- **WHEN** the caller re-uploads the original item and result declarations
- **THEN** the receipt identifies both as created and the reported result counts as new usage
- **AND** a delayed delete using the previous item's revision receives revision_conflict

### Requirement: Explicit experiment lifecycle

Completion SHALL occur only on an explicit call, require expected counts to match accepted
counts when declared, and return a completed receipt. Counts include all result statuses.
Explicit failure SHALL retain accepted data and omit expected-count checks. Repeating the
same terminal action SHALL be safe. Conflicting terminal actions and uploads that would
create or recreate data after closure SHALL surface conflicts. Exact replays of retained data
remain safe after closure. Explicit corrections and deletes can change retained records after closure.
Operations on one handle SHALL be serialized, including all chunks of a bulk upload; other
handles/processes remain subject to backend concurrency.

#### Scenario: Count mismatch leaves the experiment open
- **GIVEN** an isolated offline evaluation client and an experiment expecting two results with only one accepted
- **WHEN** the caller explicitly completes the experiment
- **THEN** the caller receives a conflict with expected and accepted counts
- **AND** the experiment remains uploading

#### Scenario: Failure is explicit and repeatable
- **GIVEN** an isolated offline evaluation client and a partially uploaded experiment
- **WHEN** the caller explicitly fails the experiment twice
- **THEN** both receipts identify the same failed experiment and its retained accepted counts

#### Scenario: Closed experiments permit exact replay but reject new data
- **GIVEN** an isolated offline evaluation client and a completed experiment with an accepted result
- **WHEN** the caller replays that result and then attempts a new result
- **THEN** the replay is acknowledged without duplication and the new result produces a conflict

#### Scenario: A closed experiment rejects an upload that would recreate a result
- **GIVEN** a completed experiment whose accepted reported result has since been deleted
- **WHEN** the caller replays its original upload
- **THEN** the caller receives HTTP 409 with code experiment_closed and the result stays deleted

### Requirement: Model attribution survives declaration replay and recovery

Item serialization and restoration SHALL retain an explicitly declared model together with
the original execution UUID and other declaration fields. Detached serialized values SHALL
not mutate the item. Saved declarations predating `model_version` SHALL remain valid inputs
to restoration. The SDK SHALL NOT fill missing or null models with a resolved default during
restoration or replay; those values SHALL retain the backend's legacy item identity.

An explicit model SHALL participate in the original upload declaration. A revision-checked
item update can correct the current model. The backend SHALL acknowledge
an exact replay of the retained declaration with the existing identities, acceptance times, and `created=false`. Changing,
adding, or removing a non-null model by re-uploading a retained item UUID SHALL conflict, including when
the explicit value equals the inherited experiment model. The SDK SHALL surface that server
conflict through the existing structured error contract. A different execution SHALL use a
different item UUID, even if it uses the same dataset case and scorer version.

All scorers for one execution SHALL share the same declared model through the shared item.
Bulk validation SHALL reject conflicting explicit model declarations for one item UUID before
sending any chunk. Chunking SHALL include the original model in every repeated declaration
and account for its encoded size. Prepared retries, `failed_chunk`, and reusable
`pending_results` SHALL preserve model declarations under the existing exact-replay and
partial-failure contracts. Uploading another result by accepted item UUID SHALL require no
model redeclaration or lookup. Sync and async surfaces SHALL preserve these outcomes.

#### Scenario: Saved item models survive reconstruction and detached mutation
- **GIVEN** an evaluation item with model_version "model-b" and two results using different scorer versions
- **WHEN** the caller serializes and restores the declarations, then changes model_version in the saved item dictionary
- **THEN** the original and restored items retain "model-b" and their original execution UUID
- **AND** both restored results still reference that execution item

#### Scenario: Legacy saved declarations retain replay compatibility
- **GIVEN** an accepted item whose saved declaration has no model_version key and whose experiment has model_version "model-a"
- **WHEN** the caller restores and replays that declaration with the same result
- **THEN** the upload does not insert a non-null item model
- **AND** the acknowledgment retains the original identities and acceptance times with created false

#### Scenario: Explicit item models replay without duplication
- **GIVEN** an acknowledged item and result with item model_version "model-b"
- **WHEN** the caller replays the same item and result in the same experiment
- **THEN** the received declaration still contains "model-b"
- **AND** the acknowledgment retains the original identities and acceptance times with created false

#### Scenario: Changing an accepted item's model is a content conflict
- **GIVEN** an acknowledged item with model_version "model-b"
- **WHEN** the caller redeclares the same item UUID with model_version "model-c" or without its explicit model
- **THEN** the backend rejects the changed declaration and the caller receives a structured content_conflict error

#### Scenario: An explicit default is not an inherited declaration
- **GIVEN** an acknowledged item with no explicit model in an experiment with model_version "model-a"
- **WHEN** the caller redeclares the same item UUID with explicit model_version "model-a"
- **THEN** the caller receives a structured content_conflict error despite the equal effective model

#### Scenario: Conflicting models in one bulk call send no partial work
- **GIVEN** two results with distinct scorer versions whose attached declarations use the same item UUID but models "model-b" and "model-c"
- **WHEN** the caller uploads both results as one bulk operation
- **THEN** the caller receives a local validation error and the service receives no upload

#### Scenario: Repeated chunk declarations retain the model through recovery
- **GIVEN** 1001 results for one item declaring model_version "model-b" with distinct scorer versions
- **AND** the service acknowledges the first chunk but loses the second chunk's response
- **WHEN** the caller receives the bulk error and retries its pending results
- **THEN** every chunk declaring the item includes "model-b"
- **AND** failed_chunk retains that model and the retry reproduces the failed chunk's identities and content

#### Scenario: Another scorer can reference an accepted item without its model
- **GIVEN** an accepted evaluation item with model_version "model-b"
- **WHEN** the caller uploads another scorer's result using only that item's UUID
- **THEN** the result references the accepted item without redeclaring or looking up its model

### Requirement: Explicit composite calculation declarations
The SDK SHALL support calculate=true on result declarations and both single and
bulk upload surfaces. A calculation SHALL serialize only item_id, scorer_version_id,
and calculate=true, with no caller-supplied score, non-default status, payload,
error code, evaluator trace, or evaluation time. Omitted/default null optional
arguments MAY be accepted but SHALL NOT be serialized. The ordinary status/value
contract remains unchanged for reported results. Omitted or false calculate
SHALL be omitted on ordinary uploads for compatibility with older backends.

Declarations SHALL snapshot and restore calculation requests through to_dict
and from_dict with stable item/scorer-version identities. Upload SHALL NOT
discover scorer definitions or evaluate formulas. The backend requires calculation
requests for composites and reported values for reported scorers. New calculations
require an uploading experiment. Exact retries of retained results return their original
outcomes, including after completion, subject to current composite/input access. Calculating
a new composite from an edited input, or replaying that calculation, requires stored-result read access.

#### Scenario: A saved calculation is restored
- **GIVEN** a calculation declaration attached to a reusable evaluation item
- **WHEN** the caller serializes and restores the declaration
- **THEN** the item and scorer-version UUIDs and calculate=true are unchanged
- **AND** the declaration contains no value or result metadata

#### Scenario: A calculation rejects a supplied score
- **WHEN** the caller requests calculate=true with value false
- **THEN** validation fails before any upload

#### Scenario: Ordinary requests retain legacy wire fields
- **WHEN** the caller uploads a reported result with calculate omitted or false
- **THEN** the request omits calculate and retains its ordinary status and value

### Requirement: Calculated outcomes are visible in upload receipts
Result receipts SHALL expose the status and nullable error_code acknowledged at the
original acceptance of a retained result, including on exact retries after a correction. HTTP success SHALL NOT imply a successful calculation.
Missing outcomes on composite acknowledgments SHALL produce invalid-response
errors with unknown persistence and retain recoverable pending work.
Older reported acknowledgments without outcome fields SHALL remain accepted;
Python represents the missing status as None rather than inventing an outcome.
Malformed status/error-code fields SHALL not be accepted as successful receipts.

The server propagates input statuses in the order error, skipped, not_applicable;
input errors use composite_input_error. Formula failures or output values outside
the configured rules use composite_formula_error. Valid reported inputs in such
an accepted request remain saved. Missing inputs instead reject the atomic upload.
All accepted composite outcomes count toward expected_result_count, while derived
results add no uploaded-result billing usage. Omitting a composite means not
requested. Formulas and stored results never recalculate on read or exact retry.
Experiment-level formulas and result inspection APIs remain outside this SDK capability.

#### Scenario: A formula failure is an acknowledged outcome
- **WHEN** the service accepts an upload with composite status error and code composite_formula_error
- **THEN** the receipt exposes that error status and code without requiring a result-read request

#### Scenario: A composite acknowledgment cannot omit the outcome
- **WHEN** the service acknowledges a calculation without status or error_code fields
- **THEN** the SDK reports invalid_response with unknown persistence

#### Scenario: Derived outcomes count toward completion
- **GIVEN** two reported inputs and one accepted composite error for an item
- **WHEN** the experiment is completed with expected_result_count 3
- **THEN** the composite error counts toward completion
- **AND** only the newly accepted reported inputs contribute billing usage

## ADDED Requirements

### Requirement: Revision-checked operations on experiment handles

A newly created or resumed experiment handle SHALL expose the following operations on the project's app API. The paths below are relative to `offline_experiments/{experiment_id}/`. Use the stored item or result UUID from the upload receipt. Sync and async calls SHALL have the same arguments, acknowledgments, and failure semantics.

| Python method | HTTP method and relative path | Returns |
|---|---|---|
| `get_item_revision(item_id)` | GET `items/{item_id}/` | Item revision |
| `get_result_revision(result_id)` | GET `results/{result_id}/payload/` | Result revision, even when its payload is unavailable |
| `update_item(item_id, *, revision, **fields)` | PATCH `items/{item_id}/` | Current item revision |
| `update_result(result_id, *, revision, **fields)` | PATCH `results/{result_id}/` | Current result revision |
| `update_item_payload(item_id, *, revision, payload)` | PATCH `items/{item_id}/payload/` | Current item revision |
| `update_result_payload(result_id, *, revision, payload)` | PATCH `results/{result_id}/payload/` | Current result revision |
| `delete_item(item_id, *, revision)` | DELETE `items/{item_id}/` | No value |
| `delete_result(result_id, *, revision)` | DELETE `results/{result_id}/` | No value |
| `delete_item_payload(item_id, *, revision)` | DELETE `items/{item_id}/payload/` | No value |
| `delete_result_payload(result_id, *, revision)` | DELETE `results/{result_id}/payload/` | No value |

A revision SHALL be a nonnegative integer. Zero is valid. The SDK SHALL reject an invalid UUID or revision, including a boolean, before I/O. A revision read SHALL validate the returned owner ID and revision. A missing revision, including on older servers, SHALL surface as `invalid_response`.

Every mutation SHALL require the caller's observed revision. PATCH SHALL send it in the JSON body alongside the changed fields. DELETE SHALL send it as the `revision` query parameter with no request body. PATCH SHALL return the server's revision when it equals or exceeds the submitted revision. If the response revision is lower, the SDK SHALL raise `invalid_response` with unknown persistence. DELETE SHALL require HTTP 204 and return no value (Python `None`). A malformed success acknowledgment SHALL surface as `invalid_response` with unknown persistence.

The SDK SHALL send each mutation once. A stale revision SHALL surface as HTTP 409 `revision_conflict` with rejected persistence. After a lost response the caller SHALL receive an error with unknown persistence. The SDK SHALL NOT refresh the revision or replay a write on the caller's behalf. Revision reads follow the existing bounded retry policy.

Reads require a personal key with `evaluation:read`. Writes require a personal key with `evaluation:write` and evaluation editor access. Reading a result revision, mutating a result or its payload, and deleting an item additionally require `llm_analytics:read` and access to the affected scorers and composite inputs. An ingestion-only key cannot authorize a mutation.

#### Scenario: A result revision can be read without a stored payload
- **GIVEN** a resumed experiment handle and a result whose payload was never provided
- **WHEN** the caller reads the result revision and the payload endpoint returns its ID and revision 0
- **THEN** the caller receives the integer 0

#### Scenario: A stale item delete after a score edit is rejected
- **GIVEN** a caller has read an item revision and another caller has since changed one of its scores
- **WHEN** the caller deletes the item using the older revision
- **THEN** the service receives one DELETE with that revision in the query and an empty body
- **AND** the caller receives HTTP 409 with code revision_conflict and rejected persistence

#### Scenario: A lost mutation response leaves the outcome unknown
- **GIVEN** a resumed experiment handle and a mock service that loses the response to a result update
- **WHEN** the caller submits the update with revision 2 and retries enabled
- **THEN** the service receives one PATCH carrying revision 2
- **AND** the caller receives an error with unknown persistence and the service receives no revision refresh

#### Scenario: An invalid mutation acknowledgment cannot confirm persistence
- **WHEN** the service returns HTTP 202 for an item payload delete
- **THEN** the caller receives invalid_response with unknown persistence

#### Scenario: An update acknowledgment cannot go backwards
- **WHEN** the caller submits revision 3 and the successful PATCH response carries revision 2
- **THEN** the SDK reports invalid_response with unknown persistence and sends no second request

#### Scenario: An ingestion-only key cannot edit an accepted item
- **WHEN** an ingestion-only caller updates an accepted item's trial with its current revision
- **THEN** the caller receives the service's permission error and the trial is preserved

### Requirement: Partial corrections to accepted items and scores

The API SHALL accept corrections during uploading and after completion or failure. Item updates accept one or more of `case_key`, `trial`, `model_version`, and `application_trace_id`. Omission preserves a field and explicit null clears it. Clearing the item model restores the usual experiment-model fallback. Reported result updates accept one or more of `status`, `value`, and `error_code`. The SDK SHALL preserve which fields were supplied and enforce the existing score encoding rules, including the distinction between a boolean and a number. Python exposes these keyword fields as `ItemUpdate` and `ResultUpdate`. Unsupported fields and empty item or result updates SHALL fail before I/O.

The service SHALL validate a partial correction against the stored result and its pinned scorer version. On a status change it clears the score for a non-ok status and clears the error code for a non-error status unless the caller supplies a conflicting value, which is rejected. When a result leaves `error`, the service SHALL also remove any stored `error_message` field from its payload. A change in a reported status or value SHALL recompute dependent composites using their pinned formulas in the same transaction. A direct score edit to a calculated result SHALL be rejected. An unchanged reported outcome SHALL preserve its revision and scoring time. Changing only the error code SHALL advance the result revision while preserving the scoring time and dependent composites.

An item and its payload share a revision, as do a result and its payload. Adding, changing, or deleting a result on a retained item, including changes to the result payload, SHALL advance the item's revision.

#### Scenario: Correcting a reported score on a completed experiment
- **GIVEN** a completed experiment with a reported boolean result and an accepted dependent composite
- **WHEN** the caller changes the reported result from true to false using its current revision
- **THEN** the PATCH body carries a JSON boolean false and the caller receives the new result revision
- **AND** the service recomputes the dependent composite using its pinned formula

#### Scenario: Correcting an error clears its stored message
- **GIVEN** a reported error with a stored error_message and reasoning
- **WHEN** the caller corrects its status to ok with a valid score at the current revision
- **THEN** the stored result payload no longer contains error_message and retains its reasoning

#### Scenario: Setting the same reported outcome preserves its revision
- **GIVEN** a reported result with value false and revision 5
- **WHEN** the caller sets its value to false at revision 5
- **THEN** the caller receives revision 5 and the score retains its scoring time

### Requirement: Partial payload updates and payload deletion

A payload PATCH SHALL send a `payload` object containing the supplied top-level fields. Item fields are `input`, `output`, `expected_output`, and `metadata`. Result fields are `reasoning`, `error_message`, and `metadata`. Each supplied field replaces its whole value, including an explicit JSON null. Omitted fields SHALL be preserved. The existing payload field types and byte limits apply, including the limit on the final merged payload. Changing item input, output, or expected output keeps the scores and can mark them stale.

The SDK SHALL send an explicitly empty `payload: {}` on both item and result payload updates. Within the original retention window, the service SHALL store `{}` when the owner has never had a payload. If a payload is already stored, the service SHALL preserve its fields. Both writes advance the owner's revision. For a deleted or expired payload, even `{}` SHALL surface HTTP 409 `payload_unavailable`.

A first payload can be added within 30 days of the owner's original acceptance. Edits SHALL preserve that deadline. Deleting a stored payload SHALL remove only the payload and advance the owner's revision. A payload that was never stored, already deleted, or removed by retention cannot be deleted. The service SHALL return HTTP 409 `payload_unavailable` and preserve the revision in those cases. A deleted or expired payload cannot be restored on that record. Its reported score can still be corrected.

#### Scenario: A payload edit distinguishes omission from explicit null
- **GIVEN** a stored item payload with input and output
- **WHEN** the caller updates the payload with only output set to null at the observed item revision
- **THEN** the PATCH body contains that revision and a payload containing only output set to JSON null
- **AND** the stored input is preserved and the caller receives the current item revision

#### Scenario: An empty update can supply the first payload
- **GIVEN** an item with no stored payload inside its original retention window
- **WHEN** the caller updates its payload with an empty object at the current revision
- **THEN** the service receives an explicit empty payload object and stores it
- **AND** the caller receives an advanced item revision

#### Scenario: An empty update preserves an existing payload
- **GIVEN** a result with stored reasoning inside its original retention window
- **WHEN** the caller updates its payload with an empty object at the current revision
- **THEN** the stored reasoning is preserved and the caller receives an advanced result revision

#### Scenario: A deleted result payload stays unavailable
- **GIVEN** a caller has deleted a result payload and read the new result revision
- **WHEN** the caller attempts to write reasoning at that revision
- **THEN** the caller receives HTTP 409 with code payload_unavailable and the result still exists

### Requirement: Hard deletion of experiment items and results

Deleting an item SHALL remove its results and all associated payloads. Deleting a result SHALL remove its payload and dependent composites. Deleting a composite SHALL preserve its inputs. These operations SHALL be available on uploading, completed, and failed experiments. Current summaries reflect the remaining records. Closed experiments SHALL retain their closure time and counts recorded at closure. Edits, recomputations, and deletes SHALL NOT count as new ingestion.

#### Scenario: Deleting a reported input removes its dependent composite
- **GIVEN** an item with two reported inputs and a composite that depends on both
- **WHEN** the caller deletes one reported input at its current revision
- **THEN** the call returns no value and the deleted input, its payload, and the composite are removed
- **AND** the item and the other reported input remain
