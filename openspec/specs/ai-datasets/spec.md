# AI Datasets Specification

## Purpose

Manage reusable evaluation cases and read their immutable history. A dataset revision
pins the item versions used by an experiment; descriptive dataset metadata remains current.

## Applicability

Server SDKs that implement AI dataset management. The reference surface is
`OfflineEvaluations.datasets` and `AsyncOfflineEvaluations.datasets` in Python's
`posthog.ai.evaluations`. Other SDKs can use native names, collections, and async conventions.
The shared client, authentication, tags, and structured error contract is defined in
[Offline Evaluations](../offline-evaluations/spec.md). Dataset operations require a personal
key with `dataset:read` or `dataset:write`, as appropriate, and dataset feature availability.

## Public surface

Names below use Python spelling. IDs are UUIDs or UUID strings. An omitted field is distinct
from an explicit null. Read/mutation results are typed metadata records, not capture-event IDs.

| Operation | Inputs and defaults | Result |
|---|---|---|
| `create` | Required `name`; optional `description`, `metadata`, `tags` | Dataset |
| `get` | `dataset_id` | Dataset |
| `list` | `limit=50`, `offset=0`, optional `search`, `archived=false`, `order_by="-created_at"`, optional `tags`, `tag_match="any"` | Dataset page |
| `update` | `dataset_id`; optional replacement `name`, `description`, `metadata`, `tags` | Dataset |
| `archive`, `restore` | `dataset_id` | Dataset |
| `list_revisions` | `dataset_id`, `limit=50`, `offset=0` | Revision page, newest first |
| `list_items` | `dataset_id`, optional numeric `revision`, `archived=false`, `limit=25`, `offset=0` | Item page |
| `get_item` | Stable `item_id`, optional numeric `revision` | Item version |
| `create_item` | `dataset_id`, required `input`; optional `expected_output`, `source_output`, `metadata`, `client_item_id`, `source_trace_id`, `source_event_id`, `source_timestamp` | Item version |
| `update_item` | `item_id`, required `base_version`; optional `input`, `expected_output`, `metadata` | Item version |
| `archive_item` | `item_id`, required `base_version` | Item version |
| `restore_item` | `item_id`, required `base_version`, optional historical `source_version` | Item version |
| `list_item_versions` | `item_id`, `limit=25`, `offset=0` | Item page, newest first |
| `snapshot` | `dataset_id`, optional numeric `revision` | Snapshot with `dataset`, `revision`, `revision_id` |
| Snapshot `iter_items` | `page_size=25` | Lazy iteration of active item versions at the pinned revision |
| `EvaluationItem.from_dataset_item` | Item version; optional execution `output`, `id`, `case_key`, `trial`, `application_trace_id` | Local evaluation-item declaration |

Dataset records expose `id`, `name`, `description`, `metadata`, `tags`, `archived`,
`current_revision`, `current_revision_id`, `team_id`, and creation/update audit metadata.
Revision records expose `id`, `dataset_id`, `revision`, `team_id`, and creation audit metadata.
Item records expose stable `id`, `dataset_id`, optional `client_item_id`, numeric `version`,
immutable `version_id`, introducing `dataset_revision` and `dataset_revision_id`, `archived`,
`input`, `expected_output`, `source_output`, `metadata`, source trace/event/timestamp fields,
`team_id`, and item/version audit metadata. Returned JSON values are detached local copies.

Pages expose `count`, `results`, and nullable `next_offset`. Limits are positive integers;
offsets are nonnegative integers. Dataset/revision/item-history pages allow at most 100 rows;
item listings and snapshot pages allow at most 25. Dataset ordering accepts `created_at` and
`updated_at`, with an optional `-` prefix. Search covers name, description, and metadata.

## HTTP mapping

All paths are relative to the configured app API host and project:

| Operation | Method and path |
|---|---|
| Create/list dataset | `POST` / `GET /api/projects/{project_id}/datasets/` |
| Get/update dataset | `GET` / `PATCH /api/projects/{project_id}/datasets/{id}/` |
| Archive/restore/revisions | `POST .../{id}/archive/`, `POST .../{id}/restore/`, `GET .../{id}/revisions/` |
| Create/list item | `POST` / `GET /api/projects/{project_id}/dataset_items/` |
| Get/update item | `GET` / `PATCH /api/projects/{project_id}/dataset_items/{id}/` |
| Archive/restore/history | `POST .../{id}/archive/`, `POST .../{id}/restore/`, `GET .../{id}/versions/` |

Item creation/listing sends `dataset` as the parent UUID. Historical reads send the numeric
`revision`. Mutations use JSON bodies; archive/restore of datasets sends an empty object.
Current service quotas are server policy and surface as structured errors; they are not
hard-coded cross-SDK dataset-capacity guarantees.

## Requirements

### Requirement: Dataset management surface and metadata

The SDK SHALL expose the public surface and records above. Dataset names SHALL be unique
within a project. Creating an empty dataset SHALL return null for both current revision
fields. Metadata updates SHALL replace supplied fields, preserve omitted fields, and leave
revision history unchanged. Empty description, object, or tag list SHALL clear the respective
field. Metadata SHALL be an object, and names SHALL be nonblank strings.

#### Scenario: Metadata changes preserve revision state
- **GIVEN** an isolated dataset client and a dataset with a description, metadata, and no items
- **WHEN** the caller updates only metadata to an empty object
- **THEN** the returned metadata is empty and the description is unchanged
- **AND** both current revision fields remain null

#### Scenario: Duplicate dataset names surface the server rejection
- **GIVEN** an isolated dataset client and an existing dataset named "Regression cases"
- **WHEN** the caller creates another dataset with that name in the same project
- **THEN** the caller receives the server's structured error instead of a successful dataset result

### Requirement: Item values and source provenance

The SDK SHALL preserve JSON types in item content, including false, zero, empty strings,
arrays, and objects. Input SHALL be non-null JSON; expected and source outputs can be null.
Metadata SHALL be an object. Source trace ID and timezone-qualified timestamp SHALL be
supplied together; a source event ID additionally requires that pair. Source provenance,
source output, parent dataset, and client item ID SHALL remain immutable through item updates.

#### Scenario: JSON values retain their types
- **GIVEN** an isolated dataset client and an active dataset
- **WHEN** the caller creates an item with input false, expected output 0, and source output ""
- **THEN** the received request and returned item preserve those three distinct JSON values

#### Scenario: Incomplete provenance fails before a write
- **GIVEN** an isolated dataset client and an active dataset
- **WHEN** the caller creates an item with a source trace ID but no source timestamp
- **THEN** the caller receives a validation error and the mock service receives no request

### Requirement: Stable item identity and immutable versions

The SDK SHALL distinguish stable item UUIDs, immutable item-version UUIDs, numeric item
versions, and dataset revisions. Creating an item SHALL create its first version and a dataset
revision. Changed editable content SHALL create a new item version and dataset revision;
identical content SHALL be a no-op. Omitted update fields SHALL remain unchanged; explicit
null expected output and empty metadata SHALL clear those fields. Historical reads SHALL
retain the version's original content and introducing revision.

#### Scenario: Updating an item preserves its historical version
- **GIVEN** an isolated dataset client and an item at version 1 with an expected output
- **WHEN** the caller updates expected output to null using base version 1
- **THEN** the stable item ID is unchanged and a new version ID is returned
- **AND** reading the original revision returns the original expected output

#### Scenario: Identical content does not create history
- **GIVEN** an isolated dataset client and an item at its current version
- **WHEN** the caller submits the same editable content with that base version
- **THEN** the item version and dataset revision remain unchanged

### Requirement: Optimistic concurrency for item mutations

Item update, archive, and restore SHALL require the observed current `base_version`.
The SDK SHALL surface stale-version conflicts with server details, without refreshing the
version or retrying the write automatically. Restoring historical content SHALL still use
the current base version, not the historical source version, and create a new immutable version.

#### Scenario: A concurrent update is not overwritten
- **GIVEN** an isolated dataset client whose caller observed item version 1, now superseded by version 2
- **WHEN** the caller updates that item using base version 1
- **THEN** the caller receives the conflict with current-version details
- **AND** the mock service receives one write and no automatic refresh or replacement write

#### Scenario: Restore copies history into a new version
- **GIVEN** an isolated dataset client and an archived item currently at version 3
- **WHEN** the caller restores it using base version 3 and source version 1
- **THEN** the returned active version has version 1's content and a new immutable version ID

### Requirement: Dataset and item archive states

Dataset archive/restore SHALL operate separately from item archive/restore. Archived datasets
SHALL remain readable and reject item mutations. Restoring a dataset SHALL preserve individual
item archive states. Item archive and restore SHALL preserve history. Listing with
`archived=false` SHALL select active resources; `archived=true` SHALL select archived resources.

#### Scenario: Restoring a dataset preserves archived items
- **GIVEN** an isolated dataset client and an archived dataset containing an archived item
- **WHEN** the caller restores the dataset and lists active items
- **THEN** that item is absent from the active listing and present in the archived listing

### Requirement: Explicit item-create idempotency

The SDK SHALL automatically retry item creation only when the caller supplied a stable
`client_item_id`. That case-sensitive key is scoped to the dataset. An identical create
against the current active item SHALL return the same item/version; different content or
an archived item with that key SHALL conflict. Other dataset mutations SHALL not retry
automatically, including after a lost acknowledgment.

#### Scenario: A keyed item create can recover a lost acknowledgment
- **GIVEN** an isolated dataset client and a mock service that persists an item create but loses its response
- **WHEN** the caller creates the item using client item ID "case-1" with retries enabled
- **THEN** every attempt uses the same identity and content
- **AND** the successful result identifies the one persisted item and version

#### Scenario: An unkeyed item create is not replayed
- **GIVEN** an isolated dataset client and a mock service that loses an item-create response
- **WHEN** the caller creates the item without a client item ID
- **THEN** the caller receives an error with unknown persistence and the service receives one request

### Requirement: Explicit pagination without credential forwarding

The SDK SHALL expose page counts, typed results, and continuation offsets for the operations
above. Continuing a listing SHALL preserve its filters and requested revision. It SHALL
extract only a valid advancing offset from a returned pagination URL, retaining the configured
host and endpoint. An empty page with a continuation or an invalid/nonadvancing continuation
SHALL surface an invalid-response error rather than silently truncating or looping.

#### Scenario: Pagination preserves the original request scope
- **GIVEN** an isolated dataset client and an item page at revision 3 whose next URL names another host and revision 4
- **WHEN** the caller continues the listing using the returned offset
- **THEN** the next request uses the configured host, original dataset, revision 3, and archive filter
- **AND** no credentials are sent to the host in the response URL

#### Scenario: Invalid continuation is observable
- **GIVEN** an isolated dataset client and an empty item page with a continuation
- **WHEN** the caller reads that page
- **THEN** the caller receives an invalid-response error

### Requirement: Revision-pinned snapshots

The SDK SHALL resolve a snapshot's numeric revision and corresponding revision UUID before
iteration, without fetching items. Omitted revision SHALL resolve latest once. Explicit
historical revision SHALL resolve its own UUID even when concurrent writes shift history
pagination. Iteration SHALL fetch active item versions at that exact revision, lazily by page;
repeated iteration SHALL start again at the same revision. The snapshot's dataset metadata is
the metadata observed during resolution, not historical metadata. The owning client SHALL
remain open for subsequent reads.

#### Scenario: Dataset changes do not move a snapshot
- **GIVEN** an isolated dataset client and a snapshot resolved at revision 3
- **WHEN** the dataset advances to revision 4 before the caller iterates the snapshot
- **THEN** all item requests use revision 3
- **AND** iterating again uses revision 3 from the first page

#### Scenario: Historical resolution survives concurrent writes
- **GIVEN** an isolated dataset client resolving historical revision 2 while new revisions shift the history pages
- **WHEN** the first history lookup returns a different revision
- **THEN** the snapshot resolves the UUID belonging to revision 2 from the remaining history

### Requirement: Snapshot failures are distinct from empty datasets

A dataset with no revision or a nonexistent requested revision SHALL produce a caller-visible
error. An existing revision with no active items SHALL produce an empty iteration. A later
page failure SHALL propagate to the caller; yielded earlier items SHALL not imply a complete
read. A subsequent iteration SHALL restart at the same pinned revision.

#### Scenario: Empty history differs from an empty revision
- **GIVEN** an isolated dataset client, a never-populated dataset, and a dataset whose items are all archived
- **WHEN** the caller requests snapshots of both datasets
- **THEN** the never-populated dataset produces an error
- **AND** the other snapshot iterates successfully with no active items

#### Scenario: A partial read remains a failure
- **GIVEN** an isolated dataset client and a snapshot whose first page succeeds and second page fails
- **WHEN** the caller consumes the iteration
- **THEN** the caller receives the first page followed by the structured read error

### Requirement: Validate returned dataset identity and revision scope

The SDK SHALL reject malformed records, inconsistent current-revision references, records
from another project or requested resource, item versions introduced after the requested
revision, and items outside the requested archive filter. Such responses SHALL not become
successful snapshot or item results.

#### Scenario: A newer item cannot enter a pinned read
- **GIVEN** an isolated dataset client requesting active items at revision 3
- **WHEN** the mock service responds with an item introduced at revision 4
- **THEN** the caller receives an invalid-response error instead of that item

### Requirement: Convert dataset cases into independent executions

Conversion SHALL copy input, expected output, and metadata; preserve the stable dataset-item
ID and exact version ID; and generate a fresh execution UUID unless supplied. Default
`case_key` SHALL be the client item ID when present, otherwise the stable item UUID. Execution
output and application trace ID SHALL come from the caller, never from source output or source
trace provenance. Archived items SHALL be rejected. Multiple scorers can reuse one converted
item; independent trials SHALL use independent execution identities. The experiment SHALL
reference the snapshot's revision UUID, which can differ from an item's introducing revision.

#### Scenario: Source data does not become a new execution's output
- **GIVEN** an isolated dataset client and an active case with source output, source trace ID, and client item ID "case-1"
- **WHEN** the caller converts the case twice with different execution outputs and trace IDs
- **THEN** the declarations have different execution IDs and the same case key and dataset-item version ID
- **AND** each declaration contains its caller-supplied output and application trace ID
