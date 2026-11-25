## MODIFIED Requirements

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
