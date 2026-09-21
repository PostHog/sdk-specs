## ADDED Requirements

### Requirement: Payload parse failures preserve flag evaluation results

Structured feature flag results SHALL follow the serialized-payload decoding contract in `get-feature-flag-payload`. A malformed payload SHALL be represented as no payload (a language-idiomatic null value or omitted optional payload field), never as its raw serialized string. The SDK MUST NOT discard an otherwise valid flag result or alter its key, enabled state, variant, or valid metadata because payload decoding failed. Value-only and enabled-state APIs that share this result-construction path SHALL preserve the same evaluated flag value and enabled state without throwing. These rules SHALL apply to cached, locally evaluated, and remotely evaluated results.

#### Scenario: Malformed payload does not discard a multivariate result (@both)
- **GIVEN** flag "checkout" evaluates to variant "blue" with serialized payload `{broken`
- **WHEN** get feature flag result "checkout" is called
- **THEN** the result retains key "checkout", enabled true, and variant "blue"
- **AND** its payload is absent or the language's no-payload value, not the raw string
- **AND** no exception is thrown

#### Scenario: Empty serialized payload does not change flag getters (@both)
- **GIVEN** flag "checkout" evaluates to variant "blue" with an empty serialized payload
- **WHEN** its structured result, flag value, and enabled state are requested
- **THEN** the structured result has no payload
- **AND** the flag value remains "blue" and enabled state remains true
- **AND** no exception is thrown

#### Scenario: Malformed payload does not change a disabled flag (@both)
- **GIVEN** a flag evaluates to boolean false with serialized payload `{broken`
- **WHEN** its structured result, flag value, and enabled state are requested
- **THEN** the structured result remains disabled with no variant and no payload
- **AND** the flag value and enabled state remain false
- **AND** no exception is thrown
