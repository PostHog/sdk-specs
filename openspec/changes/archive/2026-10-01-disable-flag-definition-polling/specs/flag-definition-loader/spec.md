## ADDED Requirements

### Requirement: Automatic definition polling can be disabled

A server SDK that polls for local-evaluation flag definitions MAY let the caller turn the recurring refresh off while keeping local evaluation. An SDK that offers it SHALL express it as an explicit disabled setting on the polling-interval configuration option, distinct from omitting the option. Omitting the option SHALL keep the SDK's default interval (30 seconds), and an explicit interval SHALL keep polling at that interval.

When polling is disabled, the loader SHALL still perform its initial definition load, SHALL still evaluate flags locally from the loaded definitions, and SHALL NOT schedule a recurring refresh timer or task. Disabling polling SHALL NOT disable local evaluation, clear loaded definitions, or force remote evaluation for flags the definitions can resolve.

The loaded definitions SHALL remain unchanged until the caller refreshes them through the SDK's manual refresh surface (for example `reloadFeatureFlags()`), which SHALL fetch fresh definitions as it does when polling is enabled. Keeping the definitions current is the caller's responsibility while polling is disabled; the SDK SHALL NOT compensate by refreshing on evaluation.

A failed refresh SHALL continue to apply the loader's existing error backoff to subsequent on-demand refreshes, and SHALL NOT schedule a recurring timer that the disabled setting suppressed. Existing rules for preserving prior definitions on failure, for conditional requests, and for quota or auth errors apply unchanged.

This setting SHALL affect only definition polling. Other SDK timers, such as event-flush and request-timeout timers, SHALL be unaffected.

#### Scenario: Omitted polling interval keeps the default
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** no flag definition polling interval is configured
- **WHEN** the SDK clock advances by "30 seconds"
- **THEN** the flag definition loader should request fresh definitions

#### Scenario: Disabled polling still loads definitions once
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** flag definition polling is explicitly disabled
- **AND** the mock server will return flag definitions:
  | key     | active | rollout |
  | beta-ui | true   | 100     |
- **WHEN** the SDK finishes its initial flag definition load
- **THEN** local feature flag definitions should include flag "beta-ui"
- **AND** the flag "beta-ui" should evaluate locally without a remote feature flag evaluation request

#### Scenario: Disabled polling schedules no recurring refresh
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** flag definition polling is explicitly disabled
- **AND** the SDK has finished its initial flag definition load
- **WHEN** the SDK clock advances by "30 minutes"
- **THEN** the flag definition loader should not request fresh definitions
- **AND** no flag definition refresh timer should be pending

#### Scenario: Manual refresh updates definitions while polling is disabled
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** flag definition polling is explicitly disabled
- **AND** local feature flag definitions include flag "beta-ui"
- **AND** the mock server will return flag definitions:
  | key      | active | rollout |
  | beta-ui  | true   | 100     |
  | new-flag | true   | 100     |
- **WHEN** the flag definition loader refreshes
- **THEN** local feature flag definitions should include flag "new-flag"

#### Scenario: A failed manual refresh backs off without starting a timer
- **GIVEN** the SDK is initialized with token "test-token" and local evaluation enabled
- **AND** flag definition polling is explicitly disabled
- **AND** local feature flag definitions include flag "beta-ui"
- **AND** the mock server will fail the next flag definition request with status 503
- **WHEN** the flag definition loader refreshes
- **THEN** local feature flag definitions should still include flag "beta-ui"
- **AND** no flag definition refresh timer should be pending
