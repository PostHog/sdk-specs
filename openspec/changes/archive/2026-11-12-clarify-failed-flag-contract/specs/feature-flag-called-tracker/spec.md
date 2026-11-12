## MODIFIED Requirements

### Requirement: Failed direct getter evaluations report evaluation_failed

When a direct single-flag getter has no successfully evaluated value for its context because its detailed remote record is marked `failed: true`, a `$feature_flag_called` event emitted for that read SHALL include `evaluation_failed` in `$feature_flag_error`. A present-but-failed record MUST NOT be classified as `flag_missing` merely because it supplies no value. This per-flag classification SHALL NOT depend on the response-wide `errorsWhileComputingFlags` bit; existing response-level errors remain independently reportable.

For a failed direct read without a successful fallback, `$feature_flag_response` SHALL use the platform's documented missing response sentinel, meaning the null, false, or omitted response field it uses when no value is available. It MUST NOT use a caller default or treat a failed placeholder as an evaluated value. This also applies to failed config version 2 records instead of the ordinary evaluated-value rendering. Their diagnostic config-version and reason metadata SHALL remain governed by the existing attribution rules.

The SDK SHALL preserve its existing dedupe behavior and feature flag event controls. This requirement MUST NOT cause an event when the read's event decision is false. A successfully evaluated value from the source actually used for the read MUST NOT acquire `evaluation_failed` solely because an unused remote record or another key failed. Snapshot missing/unresolved access rules remain governed by `evaluate-flags`.

#### Scenario: A present failed flag is not reported as missing (@both)
- **GIVEN** a fresh SDK instance has no successful fallback for "checkout"
- **AND** remote evaluation returns "checkout" with enabled false and failed true
- **AND** the read's feature flag event decision is true
- **WHEN** get feature flag result "checkout" is called
- **AND** the public flush completes delivery to an isolated mock ingestion service
- **THEN** the received "$feature_flag_called" event for "checkout" reports "evaluation_failed" in "$feature_flag_error"
- **AND** it does not report "flag_missing"
- **AND** "$feature_flag_response" uses the platform's documented missing response sentinel

#### Scenario: Failed flag diagnostics coexist with response-wide errors (@both)
- **GIVEN** a fresh SDK instance has no successful fallback for "checkout"
- **AND** remote evaluation returns "checkout" with failed true and reports errorsWhileComputingFlags true
- **AND** the read's feature flag event decision is true
- **WHEN** get feature flag result "checkout" is called
- **AND** the public flush completes delivery to an isolated mock ingestion service
- **THEN** the received "$feature_flag_called" event for "checkout" reports "evaluation_failed"
- **AND** "$feature_flag_error" also contains "errors_while_computing_flags"

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

#### Scenario: Failed remote fallback reports evaluation_failed after inconclusive local evaluation (@server)
- **GIVEN** local evaluation for "checkout" is inconclusive and remote fallback is enabled
- **AND** the fallback returns "checkout" with enabled false and failed true
- **AND** no successful fallback supplies a value
- **AND** the read's feature flag event decision is true
- **WHEN** get feature flag result "checkout" is called for that evaluation context
- **AND** the public flush completes delivery to an isolated mock ingestion service
- **THEN** the received "$feature_flag_called" event for "checkout" reports "evaluation_failed" in "$feature_flag_error"
- **AND** it does not report "flag_missing"
- **AND** "$feature_flag_response" uses the platform's documented missing response sentinel
