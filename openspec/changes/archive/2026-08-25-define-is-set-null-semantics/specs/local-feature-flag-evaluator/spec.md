## ADDED Requirements

### Requirement: is_set and is_not_set distinguish property presence from unavailable context

The local evaluator SHALL match an `is_set` property filter whenever the required evaluation property key is present. A property explicitly supplied with the platform's JSON null equivalent SHALL match `is_set`, because the key is present.

Boolean false, numeric zero, an empty string, and empty collections SHALL also count as set. Implementations SHALL test property membership and SHALL NOT use generic language truthiness or a non-null check to decide whether a property is set.

When the required property key is absent from caller-supplied local evaluation context, `is_set` SHALL remain inconclusive and defer to remote evaluation when remote fallback is enabled. Omission from request-time properties does not prove that the property is absent from PostHog's stored person or group properties.

The local evaluator SHALL definitively not match an `is_not_set` property filter whenever the required evaluation property key is present, including when its value is null or another falsey value. When the key is absent from caller-supplied local evaluation context, `is_not_set` SHALL remain inconclusive and SHALL NOT match solely because the key was omitted.

Caller-supplied property maps therefore represent present values or unavailable context; they do not currently represent affirmative knowledge that a property is absent. A definitive `is_not_set` match requires property context known to be complete or an explicit known-absence input. Adding such an input requires a separate SDK evaluation option and corresponding `/flags` request contract and is outside this requirement.

#### Scenario: Explicit null matches is_set
- **GIVEN** local feature flag "profile-complete" matches person property "plan" with operator "is_set"
- **WHEN** the flag is evaluated locally with person property "plan" explicitly set to null
- **THEN** the local evaluation result should be true
- **AND** the SDK should not require remote fallback solely to interpret the explicit null value

#### Scenario: Other falsey present values match is_set
- **GIVEN** local feature flags use `is_set` filters for properties supplied as false, zero, an empty string, an empty list, and an empty object
- **WHEN** those flags are evaluated locally
- **THEN** each `is_set` property comparison should match

#### Scenario: Missing property context leaves is_set inconclusive
- **GIVEN** local feature flag "profile-complete" matches person property "plan" with operator "is_set"
- **WHEN** the flag is evaluated locally without a "plan" entry in the supplied person properties
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible when enabled

#### Scenario: Explicit null does not match is_not_set
- **GIVEN** local feature flag "profile-incomplete" matches person property "plan" with operator "is_not_set"
- **WHEN** the flag is evaluated locally with person property "plan" explicitly set to null
- **THEN** the local evaluation result should be false
- **AND** the SDK should not require remote fallback solely to interpret the explicit null value

#### Scenario: Other falsey present values do not match is_not_set
- **GIVEN** local feature flags use `is_not_set` filters for properties supplied as false, zero, an empty string, an empty list, and an empty object
- **WHEN** those flags are evaluated locally
- **THEN** each `is_not_set` property comparison should not match

#### Scenario: Missing property context leaves is_not_set inconclusive
- **GIVEN** local feature flag "profile-incomplete" matches person property "plan" with operator "is_not_set"
- **WHEN** the flag is evaluated locally without a "plan" entry in the supplied person properties
- **THEN** local evaluation should be inconclusive
- **AND** remote evaluation should remain eligible when enabled
