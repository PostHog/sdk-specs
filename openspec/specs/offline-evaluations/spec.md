# Offline Evaluations Specification

## Purpose

Upload caller-computed evaluation results into resumable, project-bound experiments with
confirmed acknowledgments. Dataset cases, executions, scorer versions, and results retain
distinct identities. This specification also defines the app API client shared by
[AI Datasets](../ai-datasets/spec.md) and [AI Scorers](../ai-scorers/spec.md).

## Applicability

Server SDKs implementing offline evaluation uploads. Python's reference surface is
`posthog.ai.evaluations`, with `OfflineEvaluations`, `AsyncOfflineEvaluations`, `Experiment`,
`AsyncExperiment`, `EvaluationItem`, and `EvaluationResult`. Other SDKs can adapt names,
collection types, exceptions, and async syntax while preserving observable outcomes.

These are acknowledged management/upload APIs. Validation exceptions and structured API
errors are intentional parts of this contract, including rejected asynchronous calls. This
is an explicit exception to the general acceptance-test no-throw guidance for public SDK methods;
the existing analytics and AI capture contracts are unchanged. Model/evaluator execution,
automatic scoring, backend-only experiment inspection/export APIs, and durable local job
storage are outside this capability.

## Public surface

The client requires positive integer `project_id` and nonempty `secret_key`. Optional
`host` defaults to `https://us.posthog.com`, `timeout` to 15 seconds, and `max_retries` to 3.
It exposes `datasets` and `scorers`, and closes owned HTTP resources through `close` or
`aclose` and the corresponding context-manager protocol.

| Operation | Inputs | Result |
|---|---|---|
| `create_experiment` | Required `name`; optional fields below | Acknowledged experiment handle |
| `resume_experiment` | Existing experiment UUID | Local handle; no read request |
| Experiment `upload_result` | Item declaration or accepted item UUID, exact `scorer_version_id`, result fields below | Upload receipt |
| Experiment `upload_results` | Finite sequence of result declarations | Bulk receipt containing per-request receipts |
| Experiment `complete`, `fail` | No fields | Experiment receipt |
| Experiment `get_tags`, `set_tags` | No fields / replacement tag names | Server-normalized tags |
| Experiment [revision reads, updates, and deletes](#requirement-revision-checked-operations-on-experiment-handles) | Stored item or result UUID, observed revision for writes | Current revision for reads and updates, no value for deletes |
| Item/result `to_dict`, `from_dict` | Declaration / saved JSON declaration | Detached JSON / restored declaration |

Experiment options: `id`, `started_at`, nullable `run_source` (`ci`, `local`, `scheduled`),
`expected_item_count`, `expected_result_count`, `suite_key`, `experiment_scorer_version_id`,
`dataset_source`,
`dataset_identifier`, `dataset_revision_identifier`, `dataset_revision_id`,
`application_version`, `model_version`, and `prompt_version`. The name is required and
nonempty, at most 400 characters. Optional textual identifiers are nonempty, at most 255
characters. Expected counts are nullable nonnegative signed 64-bit integers. Omitted ID and
start time are generated once per creation call. A handle exposes its `id`, latest available
`receipt`, and a defensive copy of its original creation `submission`; resumed handles have
no original submission or receipt until an operation supplies one.

An item declaration has an optional/generated UUID `id`; optional nullable `model_version`;
optional `case_key`, `trial`,
`dataset_item_identifier`, `dataset_item_version_identifier`, `dataset_item_version_id`,
and `application_trace_id`; and payload fields `input`, `output`, `expected_output`,
`metadata`. A result references that item and an exact scorer-version UUID, with
`status="ok"` by default; `value`, `error_code`, `evaluator_trace_id`, `evaluated_at`; and
payload fields `reasoning`, `error_message`, `metadata`. `error_code` is at most 128
characters. Textual identifiers follow the nonempty, 255-character rule. Time values must
include a timezone and are normalized to UTC.

An explicit item `model_version` overrides the experiment default. Omitted or null item
models inherit that default, remaining unknown when neither supplies one. The item model
describes the application execution and is sent alongside the item UUID, outside its payload.

Payload fields can be passed individually or as a `payload` object containing the supported
keys, never both. Payload metadata is an object or null; reasoning/error message is a string
or null. An omitted payload, an empty object, and an object containing explicit nulls differ.

| Result status | Value and error fields |
|---|---|
| `ok` | Requires boolean, finite number, or nonempty list of distinct category keys; no error code or non-null error message |
| `error` | No score; optional error code and error message |
| `skipped`, `not_applicable` | No score, error code, or non-null error message |

Booleans stay distinct from numbers. Numeric scores use finite binary64 values; integer
scores must be exactly representable. Category keys are nonempty strings of at most 128
characters, sent in sorted order with no duplicates. Score compatibility and pass/fail
interpretation belong to the pinned scorer version; the SDK does not discover it at upload.

## Receipts and errors

| Type | Observable fields |
|---|---|
| Experiment receipt | `id`, `status` (`uploading`, `completed`, `failed`), `created`, `started_at`, `created_at`, nullable `finished_at`, expected and accepted item/result counts |
| Item receipt | `id`, `created`, `accepted_at` |
| Result receipt | Server result `id`, `item_id`, `scorer_version_id`, `created`, `accepted_at` |
| Upload receipt | One item acknowledgment per referenced item; result acknowledgments in submitted order |
| Bulk receipt | Ordered `chunks`, each an upload receipt; separate chunks commit independently |
| API error | HTTP `status`, server `code`, `detail`, `attr`, `errors`, complete structured `response`, `retry_after`, and `persistence`; creation failures also expose prepared `submission` |
| Bulk error | API error fields plus acknowledged `completed` chunks, original `failed_index`, reusable `pending_results`, and a defensive copy of the exact `failed_chunk` request |

Persistence is `not_sent` when no request was sent, `rejected` for a definite server rejection,
or `unknown` when a request might have persisted. A failed chunk with unknown persistence
belongs to pending work even if the server might already have committed it.

## HTTP and authentication

The experiment base path is `/api/projects/{project_id}/ai_observability/offline_experiments/`.
Creation uses `POST {base}`; uploads use `POST {base}{id}/upload/` with `items` and `results`
arrays; completion/failure use `POST {base}{id}/complete/` or `fail/` with an empty JSON object.
Tag reads/updates use `GET` / `PATCH {base}{id}/`.

Requests use bearer authentication and JSON on the app API host. Known ingestion hosts
`us.i.posthog.com` and `eu.i.posthog.com` map to their corresponding app hosts;
`app.posthog.com` maps to `us.posthog.com`. Custom hosts and path prefixes are preserved.
Host URLs must be absolute HTTP(S), without credentials, query, or fragment.

Configure a project secret API key or a personal API key. The server enforces a project secret key's scopes in its issuing project. Personal keys also require the user's resource permissions, including evaluation editor access for corrections.

| Operations | Required scopes |
|---|---|
| Experiment create, upload, complete, fail | `offline_evaluation_ingestion:write` |
| Experiment tag read/update | `evaluation:read` / `evaluation:write` |
| [Item, result, and payload operations](#requirement-revision-checked-operations-on-experiment-handles) | `evaluation:read` for revision reads or `evaluation:write` for mutations. Result revision reads, result and result-payload mutations, and item deletes also require `llm_analytics:read`. |
| Dataset read/write | `dataset:read` / `dataset:write` |
| Scorer read/write | `llm_analytics:read` / `llm_analytics:write` |

Dataset exports require a personal API key with `dataset:read`. The backend enforces project/resource permissions and applicable feature availability.
This client is independent of analytics capture configuration, queues, and flush.

## Requirements

### Requirement: Acknowledged project-bound client

The SDK SHALL expose the public surface and data model above. Network operations SHALL
return success only after a valid server acknowledgment, without a background upload queue
or a flush prerequisite. Client options SHALL be validated before I/O: project ID and timeout
must be positive, timeout finite, retry count a nonnegative integer, and secret key nonempty
without whitespace. Sync/async surfaces SHALL preserve the same persistence behavior.

#### Scenario: Success is an acknowledgment
- **GIVEN** an isolated offline evaluation client and a mock service holding an upload response
- **WHEN** the caller uploads a valid result
- **THEN** the call remains pending until the service returns a valid acknowledgment
- **AND** no analytics flush is required for the upload

#### Scenario: Invalid client options do not send requests
- **WHEN** the caller constructs an offline evaluation client with project ID 0
- **THEN** the caller receives a validation error before any request is sent

### Requirement: Authenticated app API routing

The SDK SHALL apply the host mapping and authentication table above, retain project scope,
and surface permission/feature rejections. It SHALL not follow HTTP redirects with the
credential. Returned pagination URLs SHALL supply continuation data only, never replace the
configured destination. The SDK SHALL send the configured personal or project secret key as a bearer token for each operation and surface the service's permission error if its scopes are insufficient.

#### Scenario: One project secret key authenticates management requests
- **GIVEN** a client configured with a project ID and a project secret key with dataset:read, llm_analytics:read, and evaluation:write
- **WHEN** the caller lists datasets, lists scorers, and replaces an experiment's tags
- **THEN** the SDK sends the configured key as a bearer token on all three requests to the configured project

#### Scenario: An ingestion host maps to the management host
- **GIVEN** an isolated offline evaluation client configured with host "https://eu.i.posthog.com" and a test secret key
- **WHEN** the caller creates an experiment
- **THEN** the request targets "https://eu.posthog.com" at the configured project's experiment path with bearer authentication

#### Scenario: Redirects cannot forward the secret
- **GIVEN** an isolated offline evaluation client and a mock service returning a redirect to another host
- **WHEN** the caller performs a management request
- **THEN** the caller receives a structured error and no request is sent to the redirect destination

### Requirement: Stable experiment creation and local resumption

Creation SHALL generate missing UUID and start time once and preserve all prepared fields
through retries. Exact replay SHALL acknowledge the same experiment; changed creation fields
for the same UUID SHALL conflict. A creation failure SHALL expose the prepared submission
for recovery. Resumption SHALL create a local handle to a UUID without fetching or recreating
the experiment; existence and permission checks occur on the next server operation.

#### Scenario: Creation can be replayed after an uncertain response
- **GIVEN** an isolated offline evaluation client with automatic retries disabled and a service that persists creation but loses its response
- **WHEN** the caller retries using the error's prepared submission
- **THEN** the original UUID, start time, and creation fields are reused
- **AND** the receipt identifies the original experiment

#### Scenario: Resume does not discover or create a run
- **GIVEN** an isolated offline evaluation client and an existing experiment UUID
- **WHEN** the caller resumes that UUID
- **THEN** a handle with that UUID is returned and the service receives no request

### Requirement: Immutable execution declarations and exact restoration

Item construction SHALL be local, generate an execution UUID unless supplied, and snapshot
JSON values. The same item SHALL be reusable across scorers; independent executions SHALL
have distinct IDs. `to_dict` SHALL return detached JSON; restoration SHALL preserve the
original ID and reject a missing item ID or mismatched attached item. Saved result declarations
SHALL retain their item reference and scorer version; item declarations are saved separately.

#### Scenario: Saved declarations survive process reconstruction
- **GIVEN** a locally constructed evaluation item and two results using different scorer versions
- **WHEN** the caller serializes and restores the declarations, then mutates the saved JSON objects
- **THEN** the restored declarations retain the original identities and payloads
- **AND** both results still reference the same execution item

### Requirement: Payload omission and JSON fidelity

The SDK SHALL preserve omitted payloads, explicit empty payloads, explicit null fields,
booleans, numeric values, and nested collections. It SHALL reject unsupported payload keys,
mixed payload/individual arguments, non-JSON objects, non-finite numbers, invalid Unicode,
null characters in JSON strings/keys, and nesting beyond 32 container levels. Item payloads
SHALL fit 1 MiB of encoded UTF-8 JSON; result payloads SHALL fit 256 KiB. Validation SHALL
occur before upload, without coercing unsupported objects to strings.

#### Scenario: Missing and null payload values differ
- **WHEN** the caller constructs items with omitted payload, empty payload, and explicit null output
- **THEN** their serialized declarations respectively omit payload, contain an empty payload object, and contain output null

#### Scenario: Invalid payloads fail locally
- **GIVEN** an isolated offline evaluation client
- **WHEN** the caller constructs an item with a non-finite number in its payload
- **THEN** the caller receives a validation error and the service receives no upload

### Requirement: Typed outcomes preserve score meaning

The SDK SHALL enforce the status/value rules above before upload, preserve boolean polarity,
reject integer-to-binary64 precision loss, and retain a pinned scorer-version UUID. It SHALL
not equate `ok` with a passing score or look up a scorer by name/current version during upload.
Server rejection of a value incompatible with the pinned configuration SHALL be exposed.

#### Scenario: A false score is still a successful evaluator outcome
- **GIVEN** an isolated offline evaluation client and an accepted item UUID and scorer-version UUID
- **WHEN** the caller uploads status ok with boolean value false
- **THEN** the received result contains status ok and boolean false with those exact UUIDs
- **AND** no scorer discovery request is sent

#### Scenario: A non-ok outcome cannot carry a score
- **GIVEN** an isolated offline evaluation client
- **WHEN** the caller constructs an error result with numeric value 0
- **THEN** the caller receives a validation error and the service receives no upload

#### Scenario: Numeric score precision cannot be silently lost
- **WHEN** the caller constructs a numeric result with integer value 9007199254740993
- **THEN** the caller receives a validation error instead of a rounded score

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

### Requirement: Bounded and independently replayable upload chunks

Bulk upload SHALL eagerly validate a finite caller-provided sequence before sending any
chunk. Duplicate item/scorer pairs and conflicting declarations for one item UUID SHALL be
rejected. Requests SHALL contain at most 1,000 items, 1,000 results, and 5 MiB of encoded
UTF-8 JSON including envelope overhead. Chunking SHALL preserve result order and include each
available item declaration in every chunk that references it. A single unsendable item/result
pair SHALL fail locally; an empty sequence SHALL return an empty bulk receipt without I/O.
This API has memory proportional to the supplied sequence; callers can submit batches.

#### Scenario: Count boundaries preserve independently replayable declarations
- **GIVEN** an isolated offline evaluation client and 1001 valid results for one declared item using distinct scorer versions
- **WHEN** the caller uploads the sequence
- **THEN** requests preserve result order and each contains at most 1000 results
- **AND** each request includes the shared item declaration

#### Scenario: UTF-8 request size includes the envelope
- **GIVEN** an isolated offline evaluation client and individually valid results whose combined encoded request exceeds 5 MiB
- **WHEN** the caller uploads the sequence
- **THEN** it is split into ordered requests each no larger than 5 MiB including the JSON envelope

#### Scenario: Invalid bulk input sends no partial work
- **GIVEN** an isolated offline evaluation client and a sequence containing a duplicate item/scorer-version pair
- **WHEN** the caller uploads the sequence
- **THEN** the caller receives a validation error and the service receives no upload

### Requirement: Partial bulk failure exposes exact recoverable work

Bulk upload SHALL stop at the first failed acknowledgment and expose completed receipts,
the first original result index in the failed chunk, the exact failed request, and pending
results including that chunk and all subsequent work. Retrying pending results SHALL reuse
the original identities/content. The SDK SHALL neither roll back acknowledged chunks nor
automatically complete/fail the experiment.

#### Scenario: The second chunk fails after the first is acknowledged
- **GIVEN** an isolated offline evaluation client and an upload requiring three chunks
- **WHEN** the first chunk is acknowledged and the second fails after exhausting its permitted retries
- **THEN** the bulk error contains the first receipt and pending results for chunks two and three
- **AND** no third-chunk, complete, or fail request is sent
- **AND** retrying the pending results reproduces the failed chunk's original identities and content

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

### Requirement: Retry only operations with safe identity

Reads, experiment creation/upload/lifecycle, and keyed dataset-item creation SHALL support
bounded retries of transport failures and HTTP 408, 429, 500, 502, 503, and 504. Each retry
SHALL preserve the prepared body and identity. Other management writes SHALL not retry.
Malformed success responses and other HTTP errors SHALL surface without automatic replay.
Backoff SHALL be bounded and honor Retry-After as a minimum; a delay beyond the client's
wait bound SHALL surface to the caller instead of retrying early. Python's wait bound is
30 seconds; its default retry budget allows three additional attempts.

#### Scenario: Retry preserves the exact upload
- **GIVEN** an isolated offline evaluation client and a mock service that loses the first upload response
- **WHEN** the permitted retry succeeds
- **THEN** the retry uses the identical prepared body and experiment identity

#### Scenario: A long Retry-After is not shortened
- **GIVEN** an isolated offline evaluation client with a 30-second retry wait bound
- **WHEN** the mock service returns HTTP 429 with Retry-After 60
- **THEN** the caller receives the structured error with that delay and no early retry is sent

### Requirement: Structured failures preserve uncertainty and protect payloads

Local validation SHALL raise a native argument/type error before I/O. API failures SHALL
expose the fields in Receipts and errors. HTTP 4xx other than 408 SHALL be rejected when no
earlier attempt was uncertain; transport failures, 408, 5xx, malformed successes, and
unconfirmed outcomes SHALL remain unknown. Once an attempt is unknown, a subsequent rejection
SHALL not establish that the operation never persisted. Error messages SHALL omit request
payloads, response content, and credentials; structured details remain explicitly accessible.
Requests on a closed client SHALL fail as not_sent without I/O.

#### Scenario: A rejection after a lost response cannot erase uncertainty
- **GIVEN** an isolated offline evaluation client whose first upload attempt loses its response
- **WHEN** the retry returns a definite rejection
- **THEN** the final error retains unknown persistence and the server's structured rejection details

#### Scenario: Error messages do not expose evaluation content
- **GIVEN** an isolated offline evaluation client and a server rejection containing evaluation payload details
- **WHEN** the caller catches the API error
- **THEN** those details are accessible through structured error fields and absent from its message

### Requirement: Shared resource tags remain mutable metadata

Dataset/scorer tag writes and experiment `set_tags` SHALL replace the full tag set; an empty
list SHALL clear it. Writes SHALL accept at most 100 nonblank names of at most 255 trimmed
characters and preserve caller spelling on the wire. Returned tags SHALL use the server's
trimmed, lowercased, deduplicated, sorted names. Dataset/scorer filters SHALL accept at most
20 names, encoded as a JSON query array, with `any` or `all` matching; an empty filter disables
tag filtering. Tag changes SHALL not create dataset revisions/scorer versions or rewrite the
experiment's original submission. Experiment tags remain editable after closure.

#### Scenario: Experiment tags can change after completion
- **GIVEN** an isolated offline evaluation client and a completed experiment with its saved creation submission
- **WHEN** the caller sets tags to " Regression " and "regression"
- **THEN** the returned tag collection is the single normalized name "regression"
- **AND** the saved submission and completed lifecycle state remain unchanged

### Requirement: Client closure and cancellation do not close experiments

Client/context closure SHALL release connections without completing or failing experiments.
Async cancellation SHALL propagate through the native cancellation mechanism without
follow-up writes or implicit lifecycle changes. Such interruption does not prove a request
was unpersisted; recovery uses the original identities. Creating a resumed handle remains
local even though its next network operation requires an open client.

#### Scenario: Context exit does not finish an experiment
- **GIVEN** an isolated offline evaluation client with an uploading experiment
- **WHEN** the caller exits the client context
- **THEN** the service receives no complete or fail request
- **AND** a subsequent network operation on that closed client fails with persistence not_sent

#### Scenario: Cancellation propagates without cleanup writes
- **GIVEN** an isolated asynchronous offline evaluation client with an upload in flight
- **WHEN** the caller cancels the operation
- **THEN** native cancellation reaches the caller and no retry, complete, or fail request follows

### Requirement: Dataset and scorer versions anchor one reproducible run

An experiment created from a dataset snapshot SHALL carry that snapshot's `revision_id`.
Converted items SHALL retain their exact dataset-item version IDs; results SHALL retain the
selected immutable scorer-version IDs. One execution can have multiple scorer results without
duplicating the execution, even when a dataset or scorer's current version advances later.
The backend SHALL validate that linked item versions are active members of the experiment's
pinned revision and that supplied textual provenance agrees with the linked UUIDs. With a
PostHog revision UUID, it derives `dataset_source="posthog"`, the dataset UUID as
`dataset_identifier`, and the revision UUID as `dataset_revision_identifier` when omitted.
External dataset identifiers remain supported without a PostHog revision or item-version link.

#### Scenario: One pinned dataset execution is scored twice
- **GIVEN** an isolated evaluation client, a dataset snapshot, and two immutable scorer versions
- **WHEN** the caller creates an experiment with the snapshot revision UUID, converts one case, and uploads both scorer results
- **THEN** the experiment request contains the snapshot revision UUID
- **AND** the upload declares one execution with the case's exact item-version UUID and two results with the pinned scorer-version UUIDs
- **AND** the item's introducing revision does not replace the snapshot revision

#### Scenario: An item outside the pinned dataset revision is rejected
- **GIVEN** an isolated evaluation client and an experiment linked to dataset revision 3
- **WHEN** the caller uploads a new item linked to a version introduced only in revision 4
- **THEN** the caller receives the backend's structured validation error and the upload commits no new items or results

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

### Requirement: Composite dependencies remain in one upload request
Ingestion-only uploads MUST supply each composite and every pinned reported input
for that item in the same HTTP request, including exact retries.
Previously stored inputs MAY be resubmitted with their original content.
Using stored inputs without resubmission requires both evaluation:read and
llm_analytics:read in addition to offline_evaluation_ingestion:write.
These scopes allow either key type to use stored inputs.
Current access to the composite and every pinned input is required even on retries.
Missing inputs reject the whole HTTP request; input ordering within it is arbitrary.

Bulk chunking SHALL preserve caller order and keep all supplied results for each
composite-bearing item in one request. Overlapping first-to-last item spans SHALL
be kept together, including intervening results. Ordinary-only submissions retain
the existing independent chunking behavior. Limits remain 1,000 declared items,
1,000 results, and 5 MiB encoded JSON per request. An indivisible group exceeding
a limit SHALL reject the complete bulk call before I/O. Available item declarations
SHALL be included in each request that references them. The SDK SHALL NOT fetch
dependencies to perform grouping or infer credential permissions.

Bulk errors SHALL retain completed receipts, the failed group's first original
index, all pending results, and the exact failed request. Replaying pending work
SHALL preserve the failed request's identities, content, and ordering.

#### Scenario: A count boundary cannot separate a composite from its inputs
- **GIVEN** 999 independent results followed by an input and its calculation for one item
- **WHEN** the caller uploads the sequence
- **THEN** the service receives requests containing 999 results and 2 results
- **AND** receipt order matches caller order

#### Scenario: Interleaved dependencies form one group
- **GIVEN** reported A, calculated B, calculated A, and reported B in that order
- **WHEN** the caller uploads these results
- **THEN** all four results are sent together in their original order

#### Scenario: Oversized groups send no partial work
- **GIVEN** valid early results followed by a composite group larger than a request limit
- **WHEN** the caller uploads the sequence
- **THEN** validation fails before any request is sent

#### Scenario: A failed group can be replayed exactly
- **GIVEN** an acknowledged first chunk and a composite group whose response was lost
- **WHEN** the caller retries the bulk error's pending results
- **THEN** the failed group's request is reproduced exactly with the original result index retained in the error
- **AND** no complete or fail operation is sent automatically

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

Both key types require `evaluation:read` for reads and `evaluation:write` for writes. Personal keys also require evaluation editor access for writes. Reading a result revision, mutating a result or its payload, and deleting an item additionally require `llm_analytics:read` and access to the affected scorers and composite inputs. An ingestion-only key cannot authorize a mutation.

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

### Requirement: Pin an experiment scorer on creation

The SDK SHALL accept a nullable experiment scorer version UUID and send it as
`experiment_scorer_version_id` on experiment creation. Omission SHALL omit the
wire field. An explicit null SHALL be sent as null. Either form allows PostHog
to resolve the default for the run's suite key and environment. An explicit
UUID takes precedence and can also select a version for a run without a suite.
PostHog validates that it identifies an accessible version of an active
experiment scorer. The SDK SHALL surface a rejected selection as a structured
API error and SHALL retain the original selection in its prepared submission
and recovery data.

PostHog pins the selection on the first successful creation. Exact replays
retain the original pin, including when there was no default at creation.
Changing the explicit UUID on replay is a content conflict. The selection
applies to the whole run. Item result uploads continue to reference item
scorer versions. PostHog calculates the score from accepted item results for
completed runs. The ingestion credential and lifecycle receipt contract
also apply to creations that include the explicit override.

#### Scenario: An explicit scorer version survives creation recovery
- **GIVEN** an experiment creation declaration with an explicit scorer version and a different suite default
- **WHEN** the caller retries the prepared creation after losing its response
- **THEN** both requests carry the same experiment UUID and explicit scorer version UUID
- **AND** the acknowledged experiment uses the explicit version

#### Scenario: A suite default is pinned only on first creation
- **GIVEN** a suite default of version 1 and an experiment accepted with the override omitted
- **WHEN** the default moves to version 2 and the caller replays the submission
- **THEN** the original experiment retains version 1
- **AND** a new experiment for the same suite with an explicit null override uses version 2

#### Scenario: A suite default does not backfill an existing run
- **GIVEN** an experiment accepted when its suite had no default
- **WHEN** a default is set and the caller replays the submission
- **THEN** the original experiment still has no pinned experiment scorer

#### Scenario: An item scorer version cannot override an experiment scorer
- **WHEN** the caller creates an experiment with an item scorer version as the override
- **THEN** the caller receives a structured validation error for experiment_scorer_version_id
