## ADDED Requirements

### Requirement: is_set distinguishes null, falsey values, and unavailable context

The local evaluator SHALL match an `is_set` property filter only when the required evaluation property is present with a non-null value. A property explicitly supplied with the platform's JSON null equivalent SHALL produce a definitive non-match for `is_set`.

Boolean false, numeric zero, an empty string, and empty collections SHALL count as set because they are non-null values. Implementations SHALL test null explicitly and SHALL NOT use generic language truthiness to decide whether a property is set.

When the required property is absent from caller-supplied local evaluation context, the evaluator SHALL remain inconclusive and defer to remote evaluation when remote fallback is enabled. Omission from request-time properties does not prove that the property is absent from PostHog's stored person or group properties.

#### Scenario: Explicit null does not match is_set
- **GIVEN** local feature flag "profile-complete" matches person property "plan" with operator "is_set"
- **WHEN** the flag is evaluated locally with person property "plan" explicitly set to null
- **THEN** the local evaluation result should be false
- **AND** the SDK should not require remote fallback solely to interpret the explicit null value

#### Scenario: Falsey non-null values match is_set
- **GIVEN** local feature flags use `is_set` filters for properties supplied as false, zero, an empty string, an empty list, and an empty object
- **WHEN** those flags are evaluated locally
- **THEN** each `is_set` property comparison should match

#### Scenario: Missing property context remains inconclusive
- **GIVEN** local feature flag "profile-complete" matches person property "plan" with operator "is_set"
- **WHEN** the flag is evaluated locally without a "plan" entry in the supplied person properties
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible when enabled
