## ADDED Requirements

### Requirement: Bulk flag values exclude failed remote decisions

When a bulk flag getter consumes a detailed `/flags` response, it SHALL omit values from records marked `failed: true`, rather than expose their enabled/variant placeholders. A key with no other successfully evaluated value for the same evaluation context SHALL be absent from the returned map or result list. Successfully evaluated siblings, including boolean false, SHALL remain available even when the response reports `errorsWhileComputingFlags`.

When remote fallback supplements local evaluation, a failed remote record MUST NOT overwrite or delete a successful local decision for that key and the same evaluation context. This includes local true, false, and variant-string decisions. Successful remote records SHALL retain the API's existing merge precedence. These rules SHALL also apply when an SDK performs the same bulk local/remote value merge for automatic capture enrichment; this does not require an SDK to add such enrichment.

#### Scenario: Remote-only bulk lookup omits only failed values (@both)
- **GIVEN** a fresh SDK instance has no successful local or cached fallback values
- **AND** a detailed remote response reports errorsWhileComputingFlags true with these records:
  | key        | enabled | variant | failed |
  | checkout   | false   | null    | true   |
  | beta-ui    | true    | null    | false  |
  | disabled   | false   | null    | absent |
  | experiment | true    | blue    | absent |
- **WHEN** the bulk flag getter consumes that response
- **THEN** "checkout" is absent from the returned flags
- **AND** "beta-ui" is present with value true
- **AND** "disabled" is present with value false
- **AND** "experiment" is present with value "blue"

#### Scenario: An all-failed response returns no bulk decisions (@both)
- **GIVEN** a fresh SDK instance has no successful local or cached fallback values
- **AND** every record in its detailed remote response is marked failed true
- **WHEN** the bulk flag getter consumes that response
- **THEN** the returned flag map or result list is empty

#### Scenario: Failed fallback preserves local decisions (@server)
- **GIVEN** local evaluation successfully resolves "enabled-local" to true, "disabled-local" to false, and "variant-local" to "blue" for one evaluation context
- **AND** local evaluation for "checkout" is inconclusive and triggers remote fallback
- **AND** the fallback response marks all four keys failed true with enabled false placeholders
- **WHEN** the bulk flag getter combines the results
- **THEN** "enabled-local" is present with value true
- **AND** "disabled-local" is present with value false
- **AND** "variant-local" is present with value "blue"
- **AND** "checkout" is absent

#### Scenario: Automatic capture enrichment does not attach failed placeholders (@server)
- **GIVEN** the SDK supports automatic bulk flag enrichment during capture and it is enabled
- **AND** local evaluation resolves "beta-ui" to true for the event's evaluation context
- **AND** an inconclusive "checkout" triggers remote fallback
- **AND** the fallback response marks both keys failed true with enabled false placeholders
- **WHEN** a public capture call evaluates and enriches an event for that context
- **AND** the public flush completes delivery to an isolated mock ingestion service
- **THEN** the received event has "$feature/beta-ui" true
- **AND** the received event has no "$feature/checkout" property
