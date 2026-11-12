## ADDED Requirements

### Requirement: Failed direct getter evaluations report evaluation_failed

When a direct single-flag getter has no successfully evaluated value for its context because its detailed remote record is marked `failed: true`, a `$feature_flag_called` event emitted for that read SHALL include `evaluation_failed` in `$feature_flag_error`. A present-but-failed record MUST NOT be classified as `flag_missing` merely because it supplies no value. This per-flag classification SHALL NOT depend on the response-wide `errorsWhileComputingFlags` bit; existing response-level errors remain independently reportable.

The SDK SHALL preserve its existing unavailable-value response sentinel, dedupe behavior, and feature flag event controls. This requirement MUST NOT cause an event when the read's event decision is false. A successfully evaluated value from the source actually used for the read MUST NOT acquire `evaluation_failed` solely because an unused remote record or another key failed. Snapshot missing/unresolved access rules remain governed by `evaluate-flags`.

#### Scenario: A present failed flag is not reported as missing (@both)
- **GIVEN** a fresh SDK instance has no successful fallback for "checkout"
- **AND** remote evaluation returns "checkout" with enabled false and failed true
- **AND** the read's feature flag event decision is true
- **WHEN** get feature flag result "checkout" is called
- **AND** the public flush completes delivery to an isolated mock ingestion service
- **THEN** the received "$feature_flag_called" event for "checkout" reports "evaluation_failed" in "$feature_flag_error"
- **AND** it does not report "flag_missing"

#### Scenario: Failed flag diagnostics coexist with response-wide errors (@both)
- **GIVEN** a fresh SDK instance has no successful fallback for "checkout"
- **AND** remote evaluation returns "checkout" with failed true and reports errorsWhileComputingFlags true
- **AND** the read's feature flag event decision is true
- **WHEN** get feature flag result "checkout" is called
- **AND** the public flush completes delivery to an isolated mock ingestion service
- **THEN** the received "$feature_flag_called" event for "checkout" reports "evaluation_failed"
- **AND** the SDK's existing response-wide error diagnostics are preserved

#### Scenario: A healthy sibling does not inherit another flag's failure (@both)
- **GIVEN** remote evaluation returns "checkout" with failed true and "beta-ui" with enabled false and failed false
- **AND** the read's feature flag event decision is true
- **WHEN** get feature flag result "beta-ui" is called
- **AND** the public flush completes delivery to an isolated mock ingestion service
- **THEN** the received "$feature_flag_called" event for "beta-ui" reports response false
- **AND** it does not report "evaluation_failed"

#### Scenario: Event suppression also applies to failed direct getter reads (@both)
- **GIVEN** remote evaluation returns "checkout" with failed true and no successful fallback supplies a value
- **AND** the read's feature flag event decision is false
- **WHEN** get feature flag result "checkout" is called
- **AND** the public flush completes for an isolated mock ingestion service
- **THEN** no "$feature_flag_called" event for "checkout" is received
