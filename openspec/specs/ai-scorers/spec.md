# AI Scorers Specification

## Purpose

Manage scorer definitions and their immutable configurations so evaluation results retain
the exact scoring semantics used for a run. Execution of an evaluator is caller-owned.

## Applicability

Server SDKs implementing AI scorer management. Python exposes `OfflineEvaluations.scorers`
and `AsyncOfflineEvaluations.scorers` in `posthog.ai.evaluations`. Native names and async
conventions can vary; observable behavior is shared. The client, authentication, tags, and
structured error contract comes from [Offline Evaluations](../offline-evaluations/spec.md).
Scorer reads/writes require a personal key with `llm_analytics:read` / `llm_analytics:write`.

## Public surface

| Operation | Inputs and defaults | Result |
|---|---|---|
| `create` | Required `name`, `kind`, `config`; optional `description`, `tags` | Scorer with first immutable version |
| `get` | Scorer UUID | Scorer with current immutable version |
| `list` | `limit=100`, `offset=0`; optional `search`, `kind`, `archived`, `order_by`, `tags`; `tag_match="any"` | Scorer page |
| `update` | Scorer UUID; optional `name`, `description`, `archived`, `tags` | Updated scorer metadata |
| `create_version` | Scorer UUID, required `config`; optional `base_version`, `name`, `description` | Scorer with new current version |
| `get_version` | Scorer UUID and exact version UUID | Immutable scorer version |
| `list_versions` | Scorer UUID, `limit=50`, optional `cursor` | Version page, newest first |

Scorer records expose `id`, `name`, `description`, `kind`, `archived`, `tags`,
`current_version`, `current_version_id`, `config`, `team`, `created_at`, `updated_at`, and
nullable `created_by`. Version records expose `id`, `definition_id`, `version`, `kind`,
`config`, `created_at`, and nullable `created_by`. Configurations are detached JSON snapshots.

Scorer pages expose `count`, `results`, `next_offset`, and the server's nullable `next` and
`previous` links. Version pages expose `count`, `results`, and nullable `next_cursor`.
Names are not unique. Search matches names/descriptions; ordering supports `name`, `kind`,
`created_at`, `updated_at`, and `current_version`, each with an optional `-` prefix.
Omitting archive filtering lists active scorers; true selects archived scorers.

## Configuration

| Kind | Configuration and interpretation |
|---|---|
| `boolean` | Optional `true_label`, `false_label`, and nullable `true_is_failure`. True passes when polarity is omitted, null, or false; false passes when `true_is_failure=true`. Labels affect presentation. |
| `numeric` | Optional nullable inclusive `min`, `max`, positive `step`, and `passing_rule`. A rule contains `operator` (`gte` or `lte`) and a finite `threshold` within configured bounds. Without a rule the result is neutral. |
| `categorical` | Required ordered `options`, each with stable `key` and display `label`; optional `selection_mode` (`single` by default, or `multiple`), nullable `min_selections`, `max_selections`, and `passing_rule`. A rule contains `categories`; every returned category must belong to that set to pass. Without a rule the result is neutral. |

Categorical option keys are unique and normalized by the server to lowercase letters,
numbers, underscores, and hyphens. Single selection accepts one category. Multiple-selection
bounds are positive counts no larger than the option count, with minimum no greater than
maximum. Passing categories must be configured option keys. An empty passing set is valid
only for multiple selection and makes every accepted nonempty offline result fail.
Numeric step constrains accepted values relative to `min`, or zero when no minimum is set.
The backend validates configuration and score compatibility; the SDK preserves those rules
and surfaces validation details without fetching configurations before every upload.

## HTTP mapping

The base path is `/api/projects/{project_id}/llm_analytics/score_definitions/` on the app API host.
Create/list use `POST`/`GET` on the base; get/update use `GET`/`PATCH {base}{id}/`.
Version creation uses `POST {base}{id}/new_version/`; version history uses
`GET {base}{id}/versions/`; exact version retrieval uses
`GET {base}{id}/versions/{version_id}/`. Write fields are JSON; listing fields are query
parameters, with version history using an opaque `cursor`.

## Requirements

### Requirement: Scorer management surface and stable identity

The SDK SHALL expose the public surface, records, and configuration types above. Creation
SHALL return an active scorer and its first immutable version. Subsequent operations SHALL
address the scorer by UUID, never infer identity from its nonunique name. Scorer kind SHALL
remain fixed after creation. A caller SHALL be able to retain `current_version_id` for later
evaluation results without further scorer discovery.

#### Scenario: Same-name scorers remain independent
- **GIVEN** an isolated scorer client and two scorers named "Correctness"
- **WHEN** the caller fetches each scorer by its UUID
- **THEN** each response identifies the requested definition and its own current version UUID

### Requirement: Boolean score polarity is versioned configuration

The SDK SHALL preserve boolean configuration, including false, null, omitted fields, and
custom labels. It SHALL not invert stored score values based on labels or polarity.
An evaluation result's `ok` status denotes successful evaluator execution; pass/fail follows
the pinned version's polarity.

#### Scenario: Failure polarity does not invert an uploaded value
- **GIVEN** an isolated scorer client and a boolean scorer version with true_is_failure true
- **WHEN** the caller uploads an ok evaluation result with value true using that version
- **THEN** the received result still has status ok and boolean value true
- **AND** the scorer version still describes true as failure

### Requirement: Numeric and categorical configurations retain their meaning

The SDK SHALL transmit supported configuration fields without dropping false, zero, empty
passing sets, or explicit null. It SHALL preserve categorical option order and the server's
normalized configuration in responses. Numeric and categorical rules SHALL retain the
semantics in the Configuration section; invalid configurations SHALL surface validation
errors instead of a fabricated successful version.

#### Scenario: A zero numeric threshold and null bounds survive management
- **GIVEN** an isolated scorer client
- **WHEN** the caller creates a numeric scorer with null bounds and a gte passing threshold of 0
- **THEN** the request preserves the null bounds and zero threshold
- **AND** the returned configuration contains the acknowledged rule

#### Scenario: An empty multiple-selection passing set is preserved
- **GIVEN** an isolated scorer client
- **WHEN** the caller creates a categorical scorer with multiple selection and an empty passing category list
- **THEN** the empty list is transmitted and returned as configuration
- **AND** it is distinct from an omitted or null passing rule

### Requirement: Metadata changes do not rewrite versions

Metadata updates SHALL preserve omitted fields. Explicit null description SHALL clear the
description; `archived=false` SHALL restore the scorer; an empty tag list SHALL clear tags.
These operations SHALL leave the immutable configuration, current version number, and
current version UUID unchanged. Configuration changes SHALL use version creation.

#### Scenario: Restoring and clearing metadata preserves the version
- **GIVEN** an isolated scorer client and an archived scorer with a description and tags
- **WHEN** the caller updates archived to false, description to null, and tags to an empty list
- **THEN** the scorer is active with cleared description and tags
- **AND** its version number, version UUID, and configuration are unchanged

### Requirement: Explicit immutable version creation

Version creation SHALL return the updated scorer with a new immutable version. An identical
configuration SHALL still be allowed to create a new version, for example when evaluator
code changes. Historical version lookup SHALL address the exact version UUID under its
owning scorer. Later metadata/configuration changes SHALL not rewrite a saved version.

#### Scenario: A new version does not alter an existing result's configuration
- **GIVEN** an isolated scorer client and a saved scorer version UUID
- **WHEN** the caller creates a new version with different polarity
- **THEN** the current version UUID changes
- **AND** fetching the saved version returns its original configuration

#### Scenario: Identical configuration can intentionally create a version
- **GIVEN** an isolated scorer client and a scorer with a current configuration
- **WHEN** the caller explicitly creates a version with that same configuration
- **THEN** a new current version number and UUID are returned

### Requirement: Optional scorer concurrency guard

Version creation SHALL support a positive `base_version` to detect concurrent changes.
Omitting it SHALL omit the concurrency guard. A stale guard SHALL surface the server's
conflict and current-version details without an automatic refresh or replacement write.

#### Scenario: A stale version creation remains a conflict
- **GIVEN** an isolated scorer client whose caller observed version 1, now superseded by version 2
- **WHEN** the caller creates a version with base version 1
- **THEN** the caller receives the conflict and current-version details
- **AND** the service receives one write and no automatic refresh or replacement write

### Requirement: Scorer mutations are not automatically replayed

Scorer creation, metadata updates, and version creation SHALL not retry automatically,
including after transport failures, retryable HTTP statuses, or malformed acknowledgments.
Unknown outcomes SHALL remain visible so callers can inspect state before another write.

#### Scenario: A lost version acknowledgment does not create another version
- **GIVEN** an isolated scorer client and a mock service that persists a version but loses its response
- **WHEN** the caller creates that version with client retries enabled
- **THEN** the service receives one version-creation request
- **AND** the caller receives a structured error with unknown persistence

### Requirement: Definition offsets and version cursors remain distinct

Scorer listing SHALL expose offset pagination and preserve search, kind, archive, ordering,
and tag filters when continued. Version listing SHALL use the returned opaque cursor, order
versions newest first, and accept limits from 1 through 100. The SDK SHALL keep the configured
host/endpoint when using continuations; response links SHALL not receive forwarded credentials.

#### Scenario: Scorer listing retains its filters
- **GIVEN** an isolated scorer client and a page of active numeric scorers filtered by tag "regression"
- **WHEN** the caller continues with that page's next offset and the same filters
- **THEN** the request retains kind, archive, and tag filters at the configured scorer endpoint

#### Scenario: Version history continues by cursor
- **GIVEN** an isolated scorer client and a version page with next cursor "next-page"
- **WHEN** the caller requests the next version page
- **THEN** the request sends cursor "next-page" and does not substitute a numeric offset

### Requirement: Returned scorer values are detached and validated

The SDK SHALL return local configuration snapshots so mutation of caller-owned or returned
objects cannot change a previously prepared request or another result. Invalid response
shapes, unsupported scorer kinds, malformed UUIDs, invalid version numbers, and malformed tag
lists SHALL surface structured invalid-response errors. Missing tags in older scorer responses
SHALL be represented as an empty collection.

#### Scenario: A malformed success is not an acknowledgment
- **GIVEN** an isolated scorer client and a mock service returning success with an invalid current version UUID
- **WHEN** the caller creates a scorer
- **THEN** the caller receives an invalid-response error with unknown persistence
- **AND** the service receives no automatic replay
