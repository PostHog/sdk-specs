## ADDED Requirements

### Requirement: Applying bootstrapped flags fires the flags-loaded callback

When `bootstrap.featureFlags` is applied at setup, the SDK SHALL fire its flags-loaded callback (the same notification/listener invoked when a `/flags` response is processed) with the served bootstrapped flags, before and independently of the first `/flags` response, so a listener waiting on flags is unblocked immediately (matching posthog-js, which fires `onFeatureFlags` when bootstrap is applied in `initialize()`). A later `/flags` response SHALL fire the callback again with the loaded values.

#### Scenario: Bootstrapped flags fire the flags-loaded callback at setup
- **GIVEN** a feature-flag listener is registered at setup
- **AND** the SDK is initialized with `bootstrap.featureFlags` `{ "beta-ui": true }`
- **WHEN** setup completes, before any `/flags` response
- **THEN** the listener is invoked with the served flags including `"beta-ui": true`
- **AND** no `/flags` network request is required for the listener to be invoked
