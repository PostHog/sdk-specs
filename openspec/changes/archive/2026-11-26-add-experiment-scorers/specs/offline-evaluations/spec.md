## ADDED Requirements

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
