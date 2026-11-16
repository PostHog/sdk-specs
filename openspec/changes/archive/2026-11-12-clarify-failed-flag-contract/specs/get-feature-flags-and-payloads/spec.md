## ADDED Requirements

### Requirement: Combined bulk reads exclude failed remote values and payloads

The values returned by `get-feature-flags-and-payloads` SHALL follow "Bulk flag values exclude failed remote decisions" in `get-feature-flags`. A failed remote record MUST NOT contribute its enabled/variant placeholder or associated remote payload to the result. When no successful value for that key and the same evaluation context is available, the key SHALL be absent from both returned maps.

When a successful local value and payload were resolved for the same key and evaluation context, a failed remote fallback MUST NOT overwrite or remove either. Healthy sibling values and payloads SHALL remain available, including valid boolean false values. This requirement does not change successful-record merge precedence or require an SDK to add a combined bulk API it does not expose.

#### Scenario: Combined remote-only lookup omits a failed record and its payload (@both)
- **GIVEN** a fresh SDK instance has no successful local or cached fallback
- **AND** a detailed response contains "checkout" with enabled false, failed true, and payload {"copy":"placeholder"}
- **AND** the response contains healthy "beta-ui" with value true and payload {"color":"green"}, and healthy "disabled" with value false
- **WHEN** get feature flags and payloads consumes that response
- **THEN** the returned values contain "beta-ui" true and "disabled" false
- **AND** the returned payloads contain "beta-ui" with {"color":"green"}
- **AND** neither map contains "checkout"

#### Scenario: Failed combined fallback preserves the successful local pair (@server)
- **GIVEN** local evaluation resolves "beta-ui" to variant "blue" and payload {"copy":"local"} for one evaluation context
- **AND** inconclusive local evaluation for "checkout" triggers remote fallback
- **AND** the fallback marks both keys failed true with enabled false placeholders and payload {"copy":"remote"}
- **WHEN** get feature flags and payloads combines those results
- **THEN** the returned values retain "beta-ui" with value "blue"
- **AND** the returned payloads retain "beta-ui" with {"copy":"local"}
- **AND** neither map contains "checkout"
