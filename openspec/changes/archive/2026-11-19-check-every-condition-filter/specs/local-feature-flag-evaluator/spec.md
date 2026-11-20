## ADDED Requirements

### Requirement: Every filter in a condition is checked

The property, cohort, and flag-dependency filters within one condition group have no defined order and are combined with logical AND. When a filter is inconclusive from the caller-supplied local context, the evaluator SHALL continue checking that condition's remaining filters rather than stopping at the first inconclusive one.

A filter that definitively does not match SHALL make the whole condition a definitive no-match, even when an earlier filter in the same condition was inconclusive: an ANDed condition cannot match whatever the unresolved filter would have resolved to. The condition SHALL be inconclusive only when at least one filter was inconclusive and no filter definitively failed.

A condition ruled out this way SHALL behave like any other condition mismatch. Evaluation SHALL continue with the next condition group, the inconclusive state of the ruled-out condition SHALL NOT make the flag inconclusive by itself, and the mismatch SHALL NOT trigger `early_exit`. When several filters in a condition are inconclusive, the existing unresolved-reason precedence SHALL select the reported reason. Which unresolvable filter supplies a distinct "requires server evaluation" outcome, where an SDK models one, is SDK-specific.

#### Scenario: A later filter that does not match rules out a condition with missing context (@server)
- **GIVEN** a flag's only condition requires person property "plan" equal to "pro" and person property "region" equal to "US"
- **AND** remote feature flag evaluation is enabled
- **WHEN** the flag is evaluated locally with person property "region" equal to "EU" and no "plan" property
- **THEN** the condition should be a definitive no-match
- **AND** the local evaluation result should be false
- **AND** local evaluation should not be inconclusive

#### Scenario: A condition stays inconclusive when every checkable filter matches (@server)
- **GIVEN** a flag's only condition requires person property "plan" equal to "pro" and person property "region" equal to "US"
- **AND** remote feature flag evaluation is enabled
- **WHEN** the flag is evaluated locally with person property "region" equal to "US" and no "plan" property
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible

#### Scenario: A later condition resolves a flag whose first condition was ruled out (@server)
- **GIVEN** a flag's first condition requires person property "plan" equal to "pro" and person property "region" equal to "US"
- **AND** its second condition is a catch-all with rollout percentage `100.0`
- **WHEN** the flag is evaluated locally with person property "region" equal to "EU" and no "plan" property
- **THEN** the first condition should be a definitive no-match
- **AND** the local evaluation result should be true from the second condition
