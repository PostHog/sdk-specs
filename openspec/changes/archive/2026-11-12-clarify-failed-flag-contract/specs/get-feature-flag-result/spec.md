## MODIFIED Requirements

### Requirement: Failed remote flag details are not evaluated results

When a direct flag getter consumes a detailed `/flags` response, a per-flag `failed: true` marker SHALL mean that the server produced no evaluated value for that key. The SDK MUST NOT convert that record's `enabled: false` placeholder or its variant into a successful structured result. This rule SHALL apply whether the getter uses remote evaluation directly or falls back from local evaluation, and whether `errorsWhileComputingFlags` is true, false, or absent.

If no successful local or otherwise supported fallback supplies a value for the same evaluation context, `get-feature-flag-result` SHALL return the platform's no-result outcome. The SDK MAY return an idiomatic error alongside that outcome where its public API supports one. Scalar and boolean getters that share this evaluation path SHALL retain their documented no-result/default mappings, including a legacy false sentinel; such a sentinel MUST NOT be treated as a successfully evaluated disabled flag.

When no successful fallback supplies a value, `is-feature-enabled` SHALL honor a caller-supplied default under that capability's existing rules. A legacy false no-result sentinel MUST NOT prevent the caller's default from being used.

The independence from `errorsWhileComputingFlags` concerns interpretation of the incoming record, not client cache retention across refreshes. Client SDKs SHALL continue to follow the `bootstrap` requirement "A complete flags response replaces bootstrapped flags": an intentionally partial or response-wide errored response merges successful values into served state, while a complete response without response-wide errors replaces served state. A per-flag failure alone MUST NOT authorize retaining a previously served value. This does not change preservation of successful same-context local decisions within a server bulk evaluation.

An absent `failed` marker or explicit `failed: false` SHALL NOT by itself invalidate a record. In particular, a healthy boolean false SHALL remain a valid disabled result even when another flag caused response-wide evaluation errors. Legacy response formats without per-flag failure markers SHALL retain their existing value interpretation.

#### Scenario: Failed direct remote evaluation returns no structured result (@both)
- **GIVEN** a fresh SDK instance has no successful local or cached fallback for "checkout"
- **AND** the detailed remote response contains "checkout" with enabled false and failed true
- **WHEN** get feature flag result "checkout" consumes that response
- **THEN** no feature flag result is returned
- **AND** no successful disabled result is manufactured from the placeholder

#### Scenario: Failed remote fallback does not turn an inconclusive local result into false (@server)
- **GIVEN** local evaluation for "checkout" is inconclusive
- **AND** remote fallback is enabled
- **AND** the remote response contains "checkout" with enabled false and failed true
- **WHEN** get feature flag result "checkout" is called for that evaluation context
- **THEN** no feature flag result is returned
- **AND** an idiomatic error returned alongside the no-result outcome remains permitted where documented

#### Scenario Outline: Per-flag failure does not depend on the response-wide error bit (@both)
- **GIVEN** a fresh SDK instance has no successful fallback for "checkout"
- **AND** a detailed remote response contains "checkout" with failed true
- **AND** errorsWhileComputingFlags is <error_bit>
- **WHEN** get feature flag result "checkout" consumes that response
- **THEN** no feature flag result is returned

**Examples:**
  | error_bit |
  | false     |
  | absent    |

#### Scenario: A healthy disabled sibling remains a valid result (@both)
- **GIVEN** a detailed remote response reports errorsWhileComputingFlags true
- **AND** "checkout" has enabled false and failed true
- **AND** "beta-ui" has enabled false with its failed marker absent or false
- **WHEN** get feature flag result "beta-ui" consumes that response
- **THEN** a feature flag result with key "beta-ui" and enabled false is returned

#### Scenario Outline: Caller defaults distinguish a failed flag from a healthy false (@both)
- **GIVEN** a fresh SDK instance has no successful local or cached fallback for "checkout"
- **AND** its detailed remote record has enabled false and failed <failed>
- **WHEN** is feature enabled "checkout" is called with default value true
- **THEN** the returned enabled value is <enabled>

**Examples:**
  | failed | enabled |
  | true   | true    |
  | false  | false   |

#### Scenario Outline: Client merge refreshes retain a previously served successful value (@client)
- **GIVEN** a client SDK serves "checkout" as true for the current identity
- **AND** its next detailed response has scope <scope> and errorsWhileComputingFlags <error_bit>
- **AND** that response contains "checkout" with enabled false and failed true
- **WHEN** the response refreshes served flags and get feature flag result "checkout" is called for the same identity
- **THEN** the returned result has enabled true from the previously served value

**Examples:**
  | scope               | error_bit |
  | all flags           | true      |
  | an explicit subset  | false     |

#### Scenario Outline: A complete client refresh does not retain a failed key (@client)
- **GIVEN** a client SDK serves "checkout" as true for the current identity
- **AND** its next detailed response is unscoped and errorsWhileComputingFlags is <error_bit>
- **AND** that response contains "checkout" with enabled false and failed true
- **AND** no independent successful fallback supplies a value
- **WHEN** the response refreshes served flags and get feature flag result "checkout" is called
- **THEN** no feature flag result is returned
- **AND** the previously served true value is not retained

**Examples:**
  | error_bit |
  | false     |
  | absent    |
