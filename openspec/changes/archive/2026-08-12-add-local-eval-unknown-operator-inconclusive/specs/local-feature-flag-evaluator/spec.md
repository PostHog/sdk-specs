# Local Feature Flag Evaluator Delta: Unrecognized Property-Filter Operators

## ADDED Requirements

### Requirement: Unrecognized property-filter operators degrade to inconclusive

The local evaluator SHALL treat any property-filter operator string it does not recognize as
inconclusive for that flag — deferring to remote evaluation for that flag only — rather than
raising an unhandled error. This includes, for example, a new server-side operator not yet
supported by that SDK's evaluator. This inconclusive signal SHALL NOT disable or interrupt local
evaluation of other flags in the same evaluation pass; only the flag using the unrecognized
operator falls back to remote evaluation.

This mirrors how other inconclusive conditions in this evaluator are scoped (for example a
missing required property), so that one flag definition using an operator ahead of a given
SDK's support does not take down local evaluation project-wide.

#### Scenario: An unrecognized operator defers only that flag to remote evaluation
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** local feature flag definitions include a flag "future-op-flag" matching person
  property "plan" with an operator this SDK version does not recognize
- **WHEN** local feature flag "future-op-flag" is evaluated for a person with property "plan"
  equal to "enterprise"
- **THEN** local evaluation should be inconclusive for "future-op-flag"

#### Scenario: Other flags keep evaluating locally despite one unrecognized operator
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** local feature flag definitions include a flag "future-op-flag" matching person
  property "plan" with an operator this SDK version does not recognize
- **AND** local feature flag definitions include a flag "beta-ui" rolled out to distinct id
  "user-123"
- **WHEN** local feature flag "future-op-flag" is evaluated for distinct id "user-123"
- **AND** local feature flag "beta-ui" is evaluated for distinct id "user-123"
- **THEN** local evaluation should be inconclusive for "future-op-flag"
- **AND** the local evaluation result for "beta-ui" should be true
