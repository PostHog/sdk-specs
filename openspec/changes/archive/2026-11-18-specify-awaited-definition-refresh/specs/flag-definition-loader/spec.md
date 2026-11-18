## ADDED Requirements

### Requirement: Awaiting a manual definition refresh

A server SDK MAY expose a manual local-evaluation definition refresh whose completion the caller can observe: an awaited call, a returned promise or future, or a returned error. An SDK that exposes one SHALL complete it only once the refresh has finished and the definitions local evaluation reads are the ones that refresh produced. Scheduling the fetch and returning SHALL NOT count as completion. An SDK MAY keep a separate schedule-and-return refresh surface alongside it, provided the two are distinct named surfaces.

A refresh surface that can report an outcome SHALL report the failure that kept the fetched definitions from being published — an unsuccessful status, a quota-limited definitions response, or a body the SDK cannot decode — and SHALL NOT report success for it. A failed refresh SHALL preserve the loaded definitions, except where this capability's existing quota or auth policy clears them. Reporting a failure SHALL NOT by itself stop the background poll loop or change its schedule.

A refresh that accepts a caller deadline or cancellation SHALL return control when that deadline ends or the caller cancels, and SHALL report that outcome rather than success.

Whether a refresh refuses, reports an error, or is a logged no-op when local evaluation is not configured — no privileged key, or local evaluation disabled — is SDK-specific.

#### Scenario: An awaited refresh completes with the fetched definitions in use
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** the SDK exposes a manual definition refresh with an observable completion
- **AND** local feature flag definitions include flag "beta-ui"
- **AND** the mock server will return flag definitions:
  | key      | active | rollout |
  | beta-ui  | true   | 100     |
  | new-flag | true   | 100     |
- **WHEN** the manual definition refresh completes
- **THEN** local feature flag definitions should include flag "new-flag"
- **AND** the refresh should not report a failure

#### Scenario: A failed refresh reports the failure and keeps the definitions
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** the SDK exposes a manual definition refresh with an observable completion
- **AND** local feature flag definitions include flag "beta-ui"
- **AND** the mock server will fail the next flag definition request with status 500
- **WHEN** the manual definition refresh completes
- **THEN** the refresh should report a failure
- **AND** local feature flag definitions should still include flag "beta-ui"

#### Scenario: A quota-limited refresh reports a failure
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** the SDK exposes a manual definition refresh with an observable completion
- **AND** the mock server will answer the next flag definition request as quota limited
- **WHEN** the manual definition refresh completes
- **THEN** the refresh should report a failure
