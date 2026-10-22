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
| Item/result `to_dict`, `from_dict` | Declaration / saved JSON declaration | Detached JSON / restored declaration |

Experiment options: `id`, `started_at`, nullable `run_source` (`ci`, `local`, `scheduled`),
`expected_item_count`, `expected_result_count`, `suite_key`, `dataset_source`,
`dataset_identifier`, `dataset_revision_identifier`, `dataset_revision_id`,
`application_version`, `model_version`, and `prompt_version`. The name is required and
nonempty, at most 400 characters. Optional textual identifiers are nonempty, at most 255
characters. Expected counts are nullable nonnegative signed 64-bit integers. Omitted ID and
start time are generated once per creation call. A handle exposes its `id`, latest available
`receipt`, and a defensive copy of its original creation `submission`; resumed handles have
no original submission or receipt until an operation supplies one.

An item declaration has an optional/generated UUID `id`; optional `case_key`, `trial`,
`dataset_item_identifier`, `dataset_item_version_identifier`, `dataset_item_version_id`,
and `application_trace_id`; and payload fields `input`, `output`, `expected_output`,
`metadata`. A result references that item and an exact scorer-version UUID, with
`status="ok"` by default; `value`, `error_code`, `evaluator_trace_id`, `evaluated_at`; and
payload fields `reasoning`, `error_message`, `metadata`. `error_code` is at most 128
characters. Textual identifiers follow the nonempty, 255-character rule. Time values must
include a timezone and are normalized to UTC.

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

| Operations | Key/scope |
|---|---|
| Experiment create, upload, complete, fail | Personal or project secret key with `offline_evaluation_ingestion:write` |
| Experiment tag read/update | Personal key with `evaluation:read` / `evaluation:write` |
| Dataset read/write | Personal key with `dataset:read` / `dataset:write` |
| Scorer read/write | Personal key with `llm_analytics:read` / `llm_analytics:write` |

The backend enforces project/resource permissions and applicable feature availability.
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
configured destination.

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
experiment. Result identity SHALL be the experiment/item/scorer-version combination. Exact
replays SHALL retain stored identities and original acceptance times with `created=false`;
changed content for an existing identity SHALL conflict. Every HTTP upload is atomic at the
backend. The SDK SHALL validate that receipts acknowledge exactly the referenced item set
and submitted result pairs in order, with distinct result UUIDs. Malformed or incomplete
acknowledgments SHALL not be reported as successful persistence.

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
same terminal action SHALL be safe; conflicting terminal actions and new data after closure
SHALL surface conflicts. Exact replays of previously accepted data remain safe after closure.
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
