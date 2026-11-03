## ADDED Requirements

### Requirement: Group keys are rendered for bucketing like the flags service

A group key reaches the evaluator through an untyped map, so it is not necessarily a string. Before using the selected group key as a bucketing identifier, the evaluator SHALL render it with the same canonical representation the flags service uses for `hashed_identifier`: a JSON string contributes its unquoted contents, and a JSON number contributes its canonical JSON encoding, the same bytes the SDK would send to `/flags` for that key. A numeric group key SHALL therefore bucket identically whether the flag is evaluated locally or remotely. Where the host runtime collapses distinct numeric kinds, the limitation already described by the backend-compatible property-filter stringification requirement applies unchanged.

A group key of any other type SHALL be treated as unresolved context for the conditions that depend on it: the evaluator SHALL return inconclusive for those conditions and remote evaluation SHALL remain eligible when enabled. The evaluator SHALL NOT render such a key with a host-specific spelling, because those spellings do not agree with the service across languages.

An unrenderable group key SHALL NOT crash, panic, or raise out of any caller-facing surface that evaluates flags locally, including single-flag and bulk evaluation and a capture call that evaluates flags as a side effect. It SHALL NOT cause the affected condition to be skipped as a non-match, which would answer the flag locally without a fallback.

#### Scenario: A numeric group key buckets like its decimal form (@server)
- **GIVEN** a group-aggregated flag with a partial rollout percentage
- **AND** group "company" is supplied with the number 42
- **WHEN** the flag is evaluated locally
- **THEN** the bucketing identifier should be "42"
- **AND** the local evaluation result should equal the result for group "company" supplied as the string "42"

#### Scenario: A numeric group key does not crash a capture that evaluates flags (@server)
- **GIVEN** local evaluation is enabled and a group-aggregated flag exists
- **AND** group "company" is supplied with the number 42
- **WHEN** an event is captured with feature flag evaluation enabled
- **THEN** the capture should complete without raising

#### Scenario: An unsupported group key type is inconclusive (@server)
- **GIVEN** a group-aggregated flag whose condition would otherwise match
- **AND** group "company" is supplied with the boolean true
- **WHEN** the flag is evaluated locally
- **THEN** local evaluation should be inconclusive for that condition
- **AND** remote evaluation should remain eligible when enabled
- **AND** the condition should not be skipped as a non-match
