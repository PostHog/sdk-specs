## ADDED Requirements

### Requirement: Per-item model attribution with experiment fallback

The SDK SHALL accept optional nullable `model_version` when constructing an evaluation item.
A non-null value SHALL be a nonempty string of at most 255 characters, subject to the existing
textual-identifier validation. The SDK SHALL preserve the supplied string without trimming
or coercion and SHALL reject invalid values before upload I/O.

Uploads SHALL place a supplied model on the item declaration as `items[].model_version`,
alongside its identity and provenance fields. Model attribution SHALL belong to the
application execution represented by the item, not to individual scorer results or the
item payload. Different items in one experiment SHALL support different models while
retaining the existing experiment-level `model_version` as a default.

The backend SHALL use a non-null item model in preference to the experiment model. Omission
or null SHALL inherit the experiment model; when neither supplies a model, attribution SHALL
remain unknown. The SDK SHALL send the declared value without substituting an experiment
default or inferring a model from payloads, dataset metadata, or traces. The same rules SHALL
apply to newly created and resumed experiment handles, without a model-discovery request.

#### Scenario: One experiment contains executions from different models
- **GIVEN** an isolated offline evaluation client and an experiment with model_version "model-a"
- **AND** two evaluation items declaring model_version "model-b" and "model-c"
- **WHEN** the caller uploads results for both items in one request
- **THEN** each received item declaration contains its respective model_version beside its UUID
- **AND** results reference those item UUIDs and scorer versions without a model field
- **AND** no request changes the experiment's model_version

#### Scenario: Omitted and null item models inherit the experiment default
- **GIVEN** an isolated offline evaluation client and an experiment with model_version "model-a"
- **WHEN** the caller uploads one item with an omitted model and another with model_version null
- **THEN** neither received declaration contains a non-null item model
- **AND** the experiment creation request retains model_version "model-a" as the default

#### Scenario: An experiment can have no default model
- **GIVEN** an isolated offline evaluation client and an experiment without a model_version
- **WHEN** the caller uploads an item declaring "model-b" and another without a model
- **THEN** the received first item declares model_version "model-b" and the second contains no non-null model
- **AND** the experiment creation request contains no non-null model

#### Scenario: Invalid item model identifiers fail locally
- **WHEN** the caller constructs an evaluation item with an empty string, a non-string non-null value, or a string longer than 255 characters as model_version
- **THEN** the caller receives a validation error before any upload is sent

#### Scenario: Valid model identifiers retain their exact text
- **GIVEN** evaluation items with a 255-character model identifier and a model identifier containing leading and trailing spaces
- **WHEN** the caller serializes and uploads the items
- **THEN** the received model identifiers exactly match the supplied strings

#### Scenario: A resumed handle needs no experiment model lookup
- **GIVEN** an isolated offline evaluation client and a locally resumed experiment handle
- **WHEN** the caller uploads one item with an explicit model and another without one
- **THEN** the request retains the explicit model and leaves the other model unset
- **AND** no experiment or model read precedes the upload

### Requirement: Model attribution survives declaration replay and recovery

Item serialization and restoration SHALL retain an explicitly declared model together with
the original execution UUID and other declaration fields. Detached serialized values SHALL
not mutate the item. Saved declarations predating `model_version` SHALL remain valid inputs
to restoration. The SDK SHALL NOT fill missing or null models with a resolved default during
restoration or replay; those values SHALL retain the backend's legacy item identity.

An explicit model SHALL participate in immutable item content. The backend SHALL acknowledge
an exact replay with the existing identities, acceptance times, and `created=false`. Changing,
adding, or removing a non-null model for an accepted item UUID SHALL conflict, including when
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
