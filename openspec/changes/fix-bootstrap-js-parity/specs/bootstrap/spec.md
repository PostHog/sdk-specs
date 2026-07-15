## MODIFIED Requirements

### Requirement: Identity reconciliation for a differing identified bootstrap

When `isIdentifiedId` is true and the bootstrapped `distinctId` differs from the existing local distinct id, the SDK SHALL reconcile the bootstrapped identity against the existing local identity as follows. Reconciliation SHALL persist local identity even when the SDK is opted out of tracking: opt-out suppresses event emission, not the local identity state, so a caller who later opts in retains the bootstrapped identity. (An SDK whose identity model structurally cannot merge an anonymous user into an identified one at init MAY instead fall back to the non-overwrite rule above; that is the only permitted deviation.)

- When the existing local user is anonymous, the SDK SHALL call `identify(distinctId)` so the anonymous user is merged into the identified user, keeping identity consistent for flag evaluation and avoiding duplicate `$feature_flag_called` events.
- When the existing local user is already identified with a different id, the SDK SHALL preserve the existing identity, SHALL NOT switch identities without an explicit `identify`, and SHALL log a warning directing the caller to `reset()` before reinitializing to switch users.

#### Scenario: Identified bootstrap merges an anonymous local user
- **GIVEN** the existing local user is anonymous with distinct id "anon-abc"
- **WHEN** the SDK is initialized with `bootstrap.distinctId` "user-123" and `isIdentifiedId` true
- **THEN** the SDK identifies "user-123", merging the anonymous user into it

#### Scenario: Identified bootstrap preserves a different identified user
- **GIVEN** the existing local user is identified with distinct id "user-existing"
- **WHEN** the SDK is initialized with `bootstrap.distinctId` "user-123" and `isIdentifiedId` true
- **THEN** the current distinct id remains "user-existing"
- **AND** a warning is logged that the existing identity is preserved

#### Scenario: Identified bootstrap reconciles an anonymous user while opted out
- **GIVEN** the SDK is opted out of tracking
- **AND** the existing local user is anonymous with distinct id "anon-abc"
- **WHEN** the SDK is initialized with `bootstrap.distinctId` "user-123" and `isIdentifiedId` true
- **THEN** the local identity is reconciled to "user-123" in the identified state
- **AND** no event is emitted while opted out

### Requirement: Bootstrapped feature flags are served before the first flags response

When `bootstrap.featureFlags` is non-empty, the SDK SHALL apply those values to the served feature-flag state at setup, as an initial snapshot, so flag reads return them before the first `/flags` response. The snapshot SHALL take precedence over any feature-flag values persisted from a previous session (bootstrap wins), and it SHALL be applied whenever `bootstrap.featureFlags` is configured, not only on a fresh install. Flag reads (`getFeatureFlag`, `getFeatureFlagPayload`, `isFeatureEnabled`, and equivalents) SHALL return bootstrapped values and paired payloads during this window. The SDK SHALL retain the configured bootstrapped values for `$feature_flag_called` reporting.

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

### Requirement: Loaded flags take precedence over bootstrapped flags

A complete `/flags` response SHALL replace the served feature flags and payloads entirely: bootstrapped keys absent from a complete response SHALL no longer be served, and a bootstrapped payload SHALL NOT be retained alongside a loaded flag value. Only a partial response (a subset of flags was requested) or a response reporting `errorsWhileComputingFlags` SHALL merge into the existing served flags, preserving values that were not recomputed. Before any response, bootstrapped values are served as the snapshot described in the previous requirement.

The retained bootstrap reporting state is dropped on `reset()` so a subsequent user is never served or reported the previous user's bootstrapped values.

#### Scenario: A complete flags response overrides the bootstrapped value
- **GIVEN** the SDK is initialized with `bootstrap.featureFlags` `{ "beta-ui": true }`
- **AND** the next complete `/flags` response returns `{ "beta-ui": false }`
- **WHEN** feature flags finish loading from `/flags`
- **THEN** `getFeatureFlag("beta-ui")` returns `false`

#### Scenario: A complete flags load drops bootstrapped-only keys
- **GIVEN** the SDK is initialized with `bootstrap.featureFlags` `{ "beta-ui": true, "legacy": true }`
- **AND** the next complete `/flags` response returns only `{ "beta-ui": false }`
- **WHEN** feature flags finish loading from `/flags`
- **THEN** `getFeatureFlag("beta-ui")` returns `false`
- **AND** `getFeatureFlag("legacy")` does not return the bootstrapped value

#### Scenario: A complete flags load replaces the bootstrapped payload
- **GIVEN** the SDK is initialized with `bootstrap.featureFlags` `{ "beta-ui": "variant-a" }` and `bootstrap.featureFlagPayloads` `{ "beta-ui": {"color":"blue"} }`
- **AND** the next complete `/flags` response returns `{ "beta-ui": "variant-b" }` with no payload for "beta-ui"
- **WHEN** feature flags finish loading from `/flags`
- **THEN** `getFeatureFlag("beta-ui")` returns "variant-b"
- **AND** `getFeatureFlagPayload("beta-ui")` does not return `{"color":"blue"}`

#### Scenario: A partial or errored response preserves un-recomputed flags
- **GIVEN** the SDK is initialized with `bootstrap.featureFlags` `{ "beta-ui": true, "legacy": true }`
- **AND** a `/flags` response reporting `errorsWhileComputingFlags` returns only `{ "beta-ui": false }`
- **WHEN** feature flags finish loading from `/flags`
- **THEN** `getFeatureFlag("beta-ui")` returns `false`
- **AND** `getFeatureFlag("legacy")` still returns `true`

#### Scenario: Bootstrapped flags are not resurrected after reset
- **GIVEN** the SDK was initialized with `bootstrap.featureFlags` `{ "legacy": true }`
- **AND** flags have loaded and then `reset()` was called
- **WHEN** feature flags are reloaded for the new user
- **THEN** `getFeatureFlag("legacy")` does not return the bootstrapped value

### Requirement: Bootstrapped flag reporting on `$feature_flag_called`

When the SDK captures `$feature_flag_called` for a flag that was bootstrapped, it SHALL enrich the event with the bootstrapped context:

- `$feature_flag_bootstrapped_response` — the bootstrapped value for that key, when one was provided.
- `$feature_flag_bootstrapped_payload` — the bootstrapped payload for that key, when one was provided.
- `$used_bootstrap_value` — true until the SDK has received a successful `/flags` response, otherwise false. The "flags loaded from remote" signal that drives this SHALL be set after any successful `/flags` response (HTTP 200), including a response that reports `errorsWhileComputingFlags`. It is a global "a remote response has been received" marker, not per-key provenance. It SHALL be cleared on `reset()`, so it correctly reports true again for a new identity until that identity's first `/flags` response.

#### Scenario: Flag call before the first flags response reports bootstrap use
- **GIVEN** the SDK is initialized with `bootstrap.featureFlags` `{ "beta-ui": true }`
- **AND** no `/flags` response has been received
- **WHEN** "beta-ui" is read and `$feature_flag_called` is captured
- **THEN** the event has `$feature_flag_bootstrapped_response` true
- **AND** the event has `$used_bootstrap_value` true

#### Scenario: Flag call after a flags response reports bootstrap not used
- **GIVEN** the SDK was initialized with `bootstrap.featureFlags` `{ "beta-ui": true }`
- **AND** a `/flags` response has been received
- **WHEN** "beta-ui" is read and `$feature_flag_called` is captured
- **THEN** the event has `$used_bootstrap_value` false

#### Scenario: A partial or errored flags response still marks bootstrap not used
- **GIVEN** the SDK is initialized with `bootstrap.featureFlags` `{ "legacy": true }`
- **AND** a `/flags` response reporting `errorsWhileComputingFlags` has been received
- **WHEN** "legacy" is read and `$feature_flag_called` is captured
- **THEN** the event has `$used_bootstrap_value` false

## ADDED Requirements

### Requirement: Identified bootstrap upgrades a matching anonymous id

When `isIdentifiedId` is true and the bootstrapped `distinctId` equals the existing local distinct id but the user is not yet marked identified, the SDK SHALL mark the user identified. Because the distinct id is unchanged, the SDK SHALL NOT emit a redundant `$identify` or re-link identities. This applies even when the SDK is opted out of tracking, since only the local identification state changes.

#### Scenario: Matching bootstrap id upgrades an anonymous user to identified
- **GIVEN** the existing local user is anonymous with distinct id "user-123"
- **WHEN** the SDK is initialized with `bootstrap.distinctId` "user-123" and `isIdentifiedId` true
- **THEN** the current distinct id remains "user-123"
- **AND** the user is in the identified state
- **AND** no `$identify` event is emitted
