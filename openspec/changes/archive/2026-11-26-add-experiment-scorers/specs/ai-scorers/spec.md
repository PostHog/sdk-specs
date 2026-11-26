## MODIFIED Requirements

### Requirement: Versioned composite scorer management
For item scorers, the SDK SHALL expose calculation modes `reported` and
`composite`, independent of numeric, boolean, and categorical output kinds.
Create SHALL accept calculation and a composition containing an expression and
1–16 inputs, each with an alias and exact reported scorer-version UUID.
Calculation and kind SHALL remain fixed after creation. Composite version creation
SHALL require the complete composition alongside output config and SHALL retain
the existing optional base-version guard and non-retrying mutation behavior.
Item formula evaluation SHALL remain server-owned. Item formulas accept only reported item scorers as inputs.
Numeric composite config SHALL reject a non-null step.

Scorer and version records SHALL expose calculation and nullable composition as
detached snapshots. Scorer records SHALL additionally expose input_scorers and
dependent_composite_count. Each input SHALL include alias, scorer_version_id,
definition_id, name, kind, version, pinned config, nullable latest_version_id,
and nullable latest_version. Scorer listing SHALL accept calculation and
input_definition_id filters, retaining existing offset and tag behavior.
Missing fields on older reported responses SHALL default to reported, null,
an empty input collection, and zero dependents. Unsupported calculations and
malformed composite metadata SHALL produce invalid-response errors.

#### Scenario: A composite retains an old source version
- **GIVEN** an input scorer with versions 1 and 2
- **WHEN** the caller creates a numeric composite pinned to version 1
- **THEN** its composition and input metadata identify version 1 and its original config
- **AND** latest-version metadata may identify version 2 without changing the pin

#### Scenario: A new composite version has an explicit formula
- **GIVEN** a composite scorer at version 1
- **WHEN** the caller creates a version with config, a complete composition, and base_version 1
- **THEN** one version-creation request carries those fields without automatic replay
- **AND** historical version retrieval retains the old composition

#### Scenario: Dependency listing preserves filters
- **WHEN** the caller lists composites with an input definition UUID, tags, and an offset
- **THEN** the request carries calculation, input_definition_id, tags, and offset together

#### Scenario: Older scorer responses remain readable
- **WHEN** a reported scorer or version response omits composite fields
- **THEN** its calculation is reported and its composition is null
- **AND** a scorer has empty input metadata and zero dependents

### Requirement: Read-scoped formula validation
The SDK SHALL expose validate_composition with required kind and composition and
optional output config and scope. It SHALL POST to
`/api/projects/{project_id}/llm_analytics/score_definitions/validate_composition/`
using llm_analytics:read access, without creating a scorer or version. A valid
response SHALL return true; validation/access failures SHALL retain structured
API errors, and malformed successful responses SHALL not be reported as valid.
Omitted config SHALL remain omitted, permitting syntax/type validation alone.
This read-only operation MAY use the existing safe request retry policy.

The server validates syntax, input access, scope, output type, and literal categorical
outputs. Runtime output values and bounds remain ingestion checks. Formulas are
limited to 1,024 characters; input aliases are unique lowercase identifiers
matching [a-z][a-z0-9_]{0,31}, excluding formula keywords/functions. Every alias
must occur in the expression. Arithmetic, comparisons, membership, boolean
operators, conditionals, number, min, max, and abs are supported by the server.
Boolean inputs retain raw polarity; categorical inputs are lists of keys.
The SDK SHALL NOT evaluate formulas locally or substitute current source versions.

#### Scenario: Formula validation does not save
- **WHEN** the caller validates a formula with an explicit empty output config
- **THEN** one validation request includes the empty config
- **AND** no create or new-version request is sent

#### Scenario: Syntax-only validation preserves omission
- **WHEN** the caller validates a formula without config
- **THEN** the request omits config and a valid response returns true

#### Scenario: Access failures remain observable
- **WHEN** the service denies access to a pinned input during formula validation
- **THEN** the caller receives the structured permission error

## ADDED Requirements

### Requirement: Experiment scorer formula management

The SDK SHALL expose scorer scope `item` or `experiment` on create and
validate_composition. Both operations default to `item`. Listing SHALL support a
scope filter that combines with other filters and pagination. Omitting the filter
allows both scopes. Scope is fixed at creation. Scorer definitions and version
records SHALL expose scope and default to `item` when older responses omit it.

An experiment scorer requires the `composite` calculation and supports the
existing numeric, boolean, and categorical output kinds and configurations.
Its inputs may reference accessible reported or composite item scorers.
Each composition input has an alias, a scorer version UUID, and a required
statistic. The SDK SHALL preserve the statistic, any explicit version policy,
and the category key on create, validation, version creation, and reads.
Omitted version policies SHALL remain omitted in formula declarations.

| Input statistic | Source requirements |
|---|---|
| `pass_rate` | Boolean, or numeric or categorical with a passing rule |
| `mean` | Numeric |
| `true_rate` | Boolean, using the raw true count regardless of polarity |
| `category_rate` | Categorical, with a required configured `category` key |

Each statistic is a number in the formula. Rates use successful item counts as
the denominator and range from 0 to 1. The input scorer version UUID anchors the
definition for every policy. `run` (the default) uses the single version with
successful results. Several successful versions under `run` leave the score
unavailable. `exact` selects the supplied version UUID. `combine` pools
successful items across versions, weighting rates and means by successful item
count. If two versions successfully scored the same item, the pooled input is
unavailable. Errors and skips do not count as successful items. PostHog
validates statistic compatibility and computes the score. Item results keep
the existing upload contract and accept only item-scoped versions.

#### Scenario: An experiment formula survives a read and a new version
- **GIVEN** an experiment scorer using category_rate for category correct with version policy combine
- **WHEN** the caller fetches the scorer and creates a version from its returned composition
- **THEN** both version responses retain the scope, statistic, category, and version policy
- **AND** the request preserves the full composition and anchor UUID

#### Scenario: Experiment scope is retained in validation and list requests
- **WHEN** the caller validates an experiment formula and lists experiment scorers by tag and offset
- **THEN** both requests carry experiment scope and the list request retains tag and offset

#### Scenario: Scorer responses without scope remain readable
- **WHEN** a scorer or version response from an older service omits scope
- **THEN** the returned scope is item

### Requirement: Experiment scorer suite defaults

The SDK SHALL accept `apply_to_suite_keys` on scorer create, metadata update,
and version creation. These writes use the existing scorer write scope and
non-retrying mutation behavior. The SDK SHALL keep suite keys distinct from
tags and preserve omitted selections and explicitly empty lists. A suite key
has at most one default per environment. An attempt to assign a suite already
held by another scorer SHALL surface the server's validation error.

On create and metadata update the selection applies to the current version,
unless the caller supplies `suite_version_id` on update. That UUID identifies
an accessible version owned by the scorer and requires an explicit selection.
Selections replace the assignments on the chosen version. They may move a
suite from another version of the same scorer. On version creation, an omitted
selection keeps existing defaults in place. An explicit selection assigns
those suites to the new version and releases deselected suites from the previous
current version. Other historical assignments remain in place unless selected
for reassignment. Archiving releases all defaults across the scorer's versions.

A scorer record's `suite_keys` reflects the current version. A version record's
`suite_keys` reflects that exact version. These are current assignments even on
historical version records. Missing lists SHALL default to empty. Scorer detail
may include `assigned_suite_keys` across all visible versions. The SDK SHALL
distinguish an absent field from a returned empty list.

#### Scenario: Publishing with omitted suite keys preserves the assignment
- **GIVEN** a current experiment scorer version with an assigned suite
- **WHEN** the caller creates a new version with omitted suite keys
- **THEN** the previous version keeps the assignment

#### Scenario: Publishing with an empty selection releases the previous current version's suites
- **GIVEN** a current experiment scorer version with an assigned suite
- **WHEN** the caller creates a new version with an empty selection
- **THEN** the SDK sends an empty list and the assignments on the previous current version are released

#### Scenario: A historical version can own an environment default
- **GIVEN** an experiment scorer with a historical version and an available suite
- **WHEN** the caller updates the scorer with the historical version UUID and that suite
- **THEN** the exact version and scorer detail report the assignment
- **AND** the scorer's current version suite keys exclude it

#### Scenario: A suite default cannot be taken from another scorer
- **GIVEN** a suite assigned to another experiment scorer in the same environment
- **WHEN** the caller attempts to assign it to a different scorer
- **THEN** the caller receives a structured validation error and the assignment is retained

#### Scenario: Archiving clears defaults for all versions
- **GIVEN** suite defaults on current and historical versions of an experiment scorer
- **WHEN** the caller archives the scorer
- **THEN** every version's suite assignments are cleared
