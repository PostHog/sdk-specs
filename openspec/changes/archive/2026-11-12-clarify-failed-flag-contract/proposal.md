## Why

Review of SDK-specs #211 found underspecified default, cache-refresh, combined-bulk and event-error behavior, plus an existing failed-record acceptance row that incorrectly requires every SDK to return scalar false. Clarify those cases without changing the agreed no-decision contract or deciding release compatibility.

## What Changes

- Assert both per-flag and response-wide error strings, define the missing response sentinel on failed-read events, and cover failed remote fallback after inconclusive local evaluation.
- Cover caller defaults, separate false/absent response-wide error-bit cases, and explicitly retain the existing bootstrap refresh policy.
- Apply failed-value filtering and same-context local-pair preservation to combined flags-and-payloads getters.
- Separate the failed acceptance row from successful-value assertions while retaining its config-version, reason, no-rule-identity and no-exposure checks.
- Leave the reviewer's release-policy question unresolved, as requested.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `get-feature-flag-result`: Explicit default, refresh and error-convention cases.
- `get-feature-flags`: Cross-reference the paired bulk API's value filtering.
- `get-feature-flags-and-payloads`: Exclude failed remote values and payloads without overwriting successful local pairs.
- `feature-flag-called-tracker`: Concrete combined-error, missing-sentinel and server-fallback expectations.

## Impact

Specification and fixture changes only. The original change's backend and SDK evidence remains applicable. No SDK implementation, snapshot-policy change, integration opt-in, harness binding, release-policy decision, or dependency pin update is included. Validate the canonical specs, Gherkin structure and fixture consistency separately from SDK runtime conformance.
