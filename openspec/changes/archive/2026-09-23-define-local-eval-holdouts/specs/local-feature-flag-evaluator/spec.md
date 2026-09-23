## ADDED Requirements

### Requirement: Experiment holdouts precede release conditions

SDKs that evaluate downloaded flag definitions locally SHALL honor `filters.holdout`, containing an `id` and numeric `exclusion_percentage`. After the inactive-flag check, a held-out identifier SHALL resolve to the string `holdout-<id>` before release-condition properties, rollout percentages, condition variant overrides, or normal multivariate assignment are evaluated. The synthetic holdout variant SHALL NOT need to appear in `filters.multivariate.variants`. An inactive flag SHALL still resolve to `false`.

Absent or null holdout configuration SHALL leave ordinary evaluation unchanged. An identifier outside the holdout SHALL continue through ordinary release-condition evaluation. Holdout configuration alone SHALL NOT require remote evaluation when the necessary local context is available, and SHALL NOT be silently ignored. Existing fallback rules for otherwise unsupported features or unavailable context remain applicable. Single-flag, bulk, and dependency evaluation SHALL share these semantics. SDKs consuming server-evaluated values do not need a separate local holdout engine.

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

#### Scenario: Bulk and dependency evaluation preserve the holdout value (@server)
- **GIVEN** active flag "checkout" has holdout id 727 with exclusion percentage 100
- **AND** another flag depends on "checkout" equaling "holdout-727"
- **WHEN** the flags are evaluated locally in one bulk pass
- **THEN** "checkout" should resolve to "holdout-727"
- **AND** the dependency comparison should match that string rather than a regular variant

### Requirement: Holdout membership uses backend-compatible bucketing

The evaluator SHALL clamp `exclusion_percentage` to the inclusive range 0–100 without truncating fractional percentages. A clamped value of 100 SHALL include every identifier without computing a hash. Otherwise membership SHALL use the inclusive comparison `hash <= percentage / 100`.

The hash SHALL be computed from the UTF-8 bytes of `holdout-<bucketing_value>` with no additional separator or salt: take the first 15 hexadecimal digits of the SHA-1 digest, interpret them as an unsigned integer, and divide by `0xFFFFFFFFFFFFFFF`. Neither the flag key nor holdout id participates in this hash. In particular, the ordinary dot-separated flag hash SHALL NOT be reused unchanged. The inclusive rule also applies at zero: an exact zero hash matches; a positive hash does not.

Holdouts SHALL use the flag-level bucketing identity: the person bucketing identifier (distinct id by default, or the required device id for device-bucketed flags), or the group key for flag-level group aggregation. Per-condition aggregation SHALL NOT change holdout membership. Missing required identity SHALL follow existing inconclusive/fallback rules rather than substituting an unrelated identity.

#### Scenario: Partial membership matches the server rather than the dot-separated hash (@server)
- **GIVEN** an active flag has holdout id 727 with exclusion percentage 20 and otherwise selects "control"
- **WHEN** it is evaluated with person bucketing value "user-1"
- **THEN** the holdout hash should be approximately 0.17805599206573022
- **AND** the result should be "holdout-727"
- **WHEN** it is evaluated with person bucketing value "user-5"
- **THEN** the holdout hash should be approximately 0.6563813925994418
- **AND** the result should be "control"

#### Scenario: Percentage boundaries are inclusive and clamped (@server)
- **GIVEN** a holdout membership calculation with hash 0.125
- **WHEN** the exclusion percentage is 12.5
- **THEN** the identifier should be held out
- **WHEN** the exclusion percentage is 12.4, 0, or -10
- **THEN** the identifier should not be held out
- **WHEN** the exclusion percentage is 100 or 150
- **THEN** the identifier should be held out without computing a hash

#### Scenario: Flag-level group identity determines membership (@server)
- **GIVEN** an active group-aggregated flag has holdout id 727 with exclusion percentage 20
- **AND** its flag-level group key is "user-1" and the person's distinct id is "user-5"
- **WHEN** the flag is evaluated locally
- **THEN** the result should be "holdout-727" using the group key

#### Scenario: Device identity determines membership for device-bucketed flags (@server)
- **GIVEN** an active person flag uses device-id bucketing and holdout id 727 with exclusion percentage 20
- **AND** the device id is "user-1" and the distinct id is "user-5"
- **WHEN** the flag is evaluated locally
- **THEN** the result should be "holdout-727" using the device id
