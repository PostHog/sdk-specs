## MODIFIED Requirements

### Requirement: Experiment holdouts precede release conditions

SDKs that evaluate downloaded flag definitions locally SHALL honor `filters.holdout`, containing an `id` and numeric `exclusion_percentage`. After the inactive-flag check, a held-out identifier SHALL resolve to the string `holdout-<id>` before release-condition properties, rollout percentages, condition variant overrides, or normal multivariate assignment are evaluated. The synthetic holdout variant SHALL NOT need to appear in `filters.multivariate.variants`. An inactive flag SHALL still resolve to `false`.

Absent or null holdout configuration SHALL leave ordinary evaluation unchanged. A holdout object with a missing or null `id` or `exclusion_percentage` SHALL likewise be skipped, continuing ordinary evaluation without constructing a holdout variant. An identifier outside the holdout SHALL continue through ordinary release-condition evaluation. A holdout with both required fields present and non-null SHALL NOT be silently ignored or require remote evaluation solely because it is a holdout when the necessary local context is available. Existing fallback rules for otherwise unsupported features or unavailable context remain applicable. Single-flag, bulk, and dependency evaluation SHALL share these semantics. SDKs consuming server-evaluated values do not need a separate local holdout engine.

#### Scenario: Holdout wins over targeting and variant overrides (@server)
- **GIVEN** an active flag "checkout" has holdout id 727 with exclusion percentage 100
- **AND** its release conditions require an unavailable person property, have rollout percentage 0, and override the variant to "test"
- **AND** its multivariate variants contain only "control" and "test"
- **WHEN** the flag is evaluated locally
- **THEN** the result should be "holdout-727" without evaluating release conditions or requiring remote fallback

#### Scenario: Inactive flag remains disabled (@server)
- **GIVEN** an inactive flag has holdout id 727 with exclusion percentage 100
- **WHEN** the flag is evaluated locally
- **THEN** the result should be false

#### Scenario: No holdout preserves ordinary assignment (@server)
- **GIVEN** an active flag has no holdout configuration and a matching condition selecting "control"
- **WHEN** the flag is evaluated locally
- **THEN** the result should be "control"

#### Scenario: Incomplete holdout preserves ordinary assignment (@server)
- **GIVEN** an active flag has a holdout object with a missing or null `id` or `exclusion_percentage`
- **AND** a matching release condition selects "control"
- **WHEN** the flag is evaluated locally
- **THEN** the result should be "control" rather than a holdout variant

#### Scenario: Bulk and dependency evaluation preserve the holdout value (@server)
- **GIVEN** active flag "checkout" has holdout id 727 with exclusion percentage 100
- **AND** another flag depends on "checkout" equaling "holdout-727"
- **WHEN** the flags are evaluated locally in one bulk pass
- **THEN** "checkout" should resolve to "holdout-727"
- **AND** the dependency comparison should match that string rather than a regular variant
