## MODIFIED Requirements

### Requirement: Condition groups are selected as ordered alternatives

For feature-flag definitions that contain condition groups, the local evaluator SHALL evaluate the groups in their definition order. All property, cohort, and flag-dependency filters within one group SHALL be combined with logical AND. The groups themselves SHALL be alternatives: a group that does not match SHALL NOT prevent evaluation of the next group. A group with no filters SHALL proceed directly to its rollout gate.

After every filter in a group matches, the evaluator SHALL apply that group's `rollout_percentage`, defaulting an absent percentage to `100.0`. The first group whose filters match and whose rollout includes the effective bucketing identifier SHALL determine the flag value. The evaluator MUST NOT reorder groups to prioritize condition-level variant overrides.

For a matching multivariate condition, a condition-level `variant` SHALL be used only when it names one of the flag's defined variants. If the override is absent or invalid, the evaluator SHALL select a variant with the normal deterministic variant hash. A matching non-multivariate condition SHALL return `true`.

The flag-level `early_exit` selector SHALL default to `false`. When it is `true`, `early_exit` SHALL trigger only when every filter in the current group matched but that group's rollout excluded the effective bucketing identifier. Triggering `early_exit` SHALL stop condition evaluation: no later group SHALL be evaluated. If no earlier group was inconclusive, the evaluator SHALL return `false`, with no variant or payload. If an earlier group was inconclusive, the flag SHALL remain inconclusive rather than return `false`, so remote evaluation stays eligible. A property, cohort, or dependency mismatch SHALL continue to the next group and SHALL NOT trigger `early_exit`. A locally inconclusive group SHALL also not itself trigger `early_exit`; the evaluator SHALL continue so another independently evaluable group can match. If no later group matches and at least one group was inconclusive, the flag SHALL remain inconclusive even when other groups definitively do not match.

#### Scenario: The first matching condition wins without variant-priority sorting (@server)
- **GIVEN** a multivariate flag has a first condition that matches person property "plan" equal to "pro" with no variant override
- **AND** the same flag has a later catch-all condition overriding the variant to "test"
- **AND** the evaluated distinct id hashes to variant "control" under normal variant assignment
- **WHEN** the flag is evaluated locally for a person whose "plan" is "pro"
- **THEN** the local evaluation result should be "control"
- **AND** the later "test" override should not reorder or replace the first matching condition

#### Scenario: Filters are ANDed within a condition and conditions are ORed (@server)
- **GIVEN** a flag's first condition requires person property "plan" equal to "pro" and person property "region" equal to "us"
- **AND** its second condition requires only person property "plan" equal to "pro"
- **WHEN** the flag is evaluated locally with person properties "plan" equal to "pro" and "region" equal to "eu"
- **THEN** the first condition should not match
- **AND** the local evaluation result should be true from the second condition

#### Scenario: Early exit stops after a targeted rollout exclusion (@server)
- **GIVEN** a flag has `early_exit` enabled
- **AND** its first condition matches person property "plan" equal to "pro" with rollout percentage `0.0`
- **AND** its second condition is a catch-all with rollout percentage `100.0`
- **WHEN** the flag is evaluated locally with person property "plan" equal to "pro"
- **THEN** the local evaluation result should be false
- **AND** the result should not include a variant or payload
- **AND** the second condition should not be evaluated as a match

#### Scenario: Disabled early exit allows a later condition to match (@server)
- **GIVEN** a flag omits `early_exit` or sets it to false
- **AND** its first condition matches person property "plan" equal to "pro" with rollout percentage `0.0`
- **AND** its second condition is a catch-all with rollout percentage `100.0`
- **WHEN** the flag is evaluated locally with person property "plan" equal to "pro"
- **THEN** the local evaluation result should be true from the second condition

#### Scenario: Early exit does not stop after a property mismatch (@server)
- **GIVEN** a flag has `early_exit` enabled
- **AND** its first condition requires person property "plan" equal to "enterprise" with rollout percentage `0.0`
- **AND** its second condition is a catch-all with rollout percentage `100.0`
- **WHEN** the flag is evaluated locally with person property "plan" equal to "pro"
- **THEN** the first condition should be treated as a property mismatch rather than a rollout exclusion
- **AND** the local evaluation result should be true from the second condition

#### Scenario: Early exit does not stop after an inconclusive condition (@server)
- **GIVEN** a flag has `early_exit` enabled
- **AND** its first group-aggregated condition has an available group key but missing required group properties and rollout percentage `0.0`
- **AND** its second person-aggregated condition matches person property "plan" equal to "pro" with rollout percentage `100.0`
- **WHEN** the flag is evaluated locally with person property "plan" equal to "pro"
- **THEN** the first condition should remain inconclusive and should not trigger `early_exit`
- **AND** the local evaluation result should be true from the second condition

#### Scenario: Early exit after an inconclusive condition stops evaluation and stays inconclusive (@server)
- **GIVEN** a flag has `early_exit` enabled
- **AND** its first condition requires person property "plan" equal to "pro" with rollout percentage `0.0`
- **AND** its second condition matches person property "region" equal to "US" with rollout percentage `0.0`
- **AND** its third condition is a catch-all with rollout percentage `100.0`
- **WHEN** the flag is evaluated locally with person property "region" equal to "US" and no "plan" property
- **THEN** the first condition should remain inconclusive
- **AND** the second condition should trigger `early_exit`
- **AND** the third condition should not be evaluated as a match
- **AND** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible

#### Scenario: Inconclusive state is preserved when no later condition matches (@server)
- **GIVEN** a flag's first condition cannot be resolved from the supplied local context
- **AND** every later condition definitively does not match
- **WHEN** the flag is evaluated locally
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible

#### Scenario: A valid condition variant override wins (@server)
- **GIVEN** a multivariate flag defines variants "control" and "test"
- **AND** its first matching condition specifies variant override "test"
- **AND** the evaluated distinct id hashes to variant "control" under normal variant assignment
- **WHEN** the flag is evaluated locally
- **THEN** the local evaluation result should be "test"

#### Scenario: An invalid condition variant override falls back to deterministic assignment (@server)
- **GIVEN** a multivariate flag defines variants "control" and "test"
- **AND** its first matching condition specifies variant override "unknown"
- **AND** the evaluated distinct id hashes to variant "control" under normal variant assignment
- **WHEN** the flag is evaluated locally
- **THEN** the local evaluation result should be "control"
