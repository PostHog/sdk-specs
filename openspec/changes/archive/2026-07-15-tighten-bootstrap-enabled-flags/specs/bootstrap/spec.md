## MODIFIED Requirements

### Requirement: Bootstrapped feature flags are served before the first flags response

When `bootstrap.featureFlags` is non-empty, the SDK SHALL apply those values to the served feature-flag state at setup, as an initial snapshot, so flag reads return them before the first `/flags` response. Only enabled bootstrap flags are served: a value SHALL be served when it is boolean `true` or a non-empty variant string, and a `false` or empty value SHALL be dropped (matching posthog-js `!!value`). Payloads SHALL be kept only for served (enabled) flags. The snapshot SHALL take precedence over any feature-flag values persisted from a previous session (bootstrap wins), and it SHALL be applied whenever `bootstrap.featureFlags` is configured, not only on a fresh install. Flag reads (`getFeatureFlag`, `getFeatureFlagPayload`, `isFeatureEnabled`, and equivalents) SHALL return the served bootstrapped values and paired payloads during this window. The SDK SHALL retain the served bootstrapped values for `$feature_flag_called` reporting.

#### Scenario: Bootstrapped payload is served with its flag
- **GIVEN** the SDK is initialized with `bootstrap.featureFlags` `{ "beta-ui": "variant-a" }` and `bootstrap.featureFlagPayloads` `{ "beta-ui": {"color":"blue"} }`
- **WHEN** the flag value and payload for "beta-ui" are read before any `/flags` response
- **THEN** the value is "variant-a"
- **AND** the payload is `{"color":"blue"}`

#### Scenario: Bootstrap snapshot takes precedence over persisted flags
- **GIVEN** feature-flag state persisted from a previous session has `{ "checkout": false }`
- **AND** the SDK is initialized with `bootstrap.featureFlags` `{ "checkout": true }`
- **WHEN** `getFeatureFlag("checkout")` is called before any `/flags` response
- **THEN** the call returns `true` from the bootstrapped value

#### Scenario: A disabled bootstrap flag and its payload are not served
- **GIVEN** the SDK is initialized with `bootstrap.featureFlags` `{ "enabled": true, "disabled": false }` and `bootstrap.featureFlagPayloads` `{ "disabled": {"k":"v"} }`
- **WHEN** the flags are read before any `/flags` response
- **THEN** `getFeatureFlag("enabled")` returns `true`
- **AND** `getFeatureFlag("disabled")` does not return a value
- **AND** `getFeatureFlagPayload("disabled")` does not return a value
