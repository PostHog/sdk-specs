## ADDED Requirements

### Requirement: Versioned composite scorer management
The SDK SHALL extend scorer management with calculation modes `reported` and
`composite`, independent of numeric, boolean, and categorical output kinds.
Create SHALL accept calculation and a composition containing an expression and
1–16 inputs, each with an alias and exact reported scorer-version UUID.
Calculation and kind SHALL remain fixed after creation. Composite version creation
SHALL require the complete composition alongside output config and SHALL retain
the existing optional base-version guard and non-retrying mutation behavior.
Formula evaluation SHALL remain server-owned; nested composites are unsupported.
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
optional output config. It SHALL POST to
`/api/projects/{project_id}/llm_analytics/score_definitions/validate_composition/`
using llm_analytics:read access, without creating a scorer or version. A valid
response SHALL return true; validation/access failures SHALL retain structured
API errors, and malformed successful responses SHALL not be reported as valid.
Omitted config SHALL remain omitted, permitting syntax/type validation alone.
This read-only operation MAY use the existing safe request retry policy.

The server validates syntax, input access, output type, and literal categorical
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
