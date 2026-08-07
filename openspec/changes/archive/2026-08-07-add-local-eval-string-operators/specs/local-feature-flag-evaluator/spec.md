# Local Feature Flag Evaluator Delta: String Prefix/Suffix Property Filter Operators

## ADDED Requirements

### Requirement: String prefix/suffix property filter operators

The local evaluator's property-filter matching SHALL support the `starts_with`,
`not_starts_with`, `ends_with`, and `not_ends_with` operators. Matching SHALL stringify both the
property value and the filter value, lowercase them using ASCII case-folding, and compare with a
prefix check (`starts_with`/`not_starts_with`) or suffix check (`ends_with`/`not_ends_with`),
negating the result for the `not_*` variants — the same case-insensitive, stringify-first
approach already used for `icontains`. These operators mirror the corresponding server-side
flags-service operators so that locally-evaluated results agree with remote evaluation.

When the property required for evaluation is absent from the supplied context, matching SHALL be
inconclusive (deferring to remote evaluation), consistent with how other operators handle a
missing property.

#### Scenario: A starts_with filter matches locally (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** local feature flag definitions include a flag "enterprise-ui" matching person property
  "email" with operator "starts_with" and value "admin@"
- **WHEN** local feature flag "enterprise-ui" is evaluated for a person with property "email"
  equal to "Admin@Example.com"
- **THEN** the local evaluation result should be true

#### Scenario: A starts_with filter is inconclusive when the property is missing (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** local feature flag definitions include a flag "enterprise-ui" matching person property
  "email" with operator "starts_with" and value "admin@"
- **WHEN** local feature flag "enterprise-ui" is evaluated for a person with no "email" property
- **THEN** local evaluation should be inconclusive
