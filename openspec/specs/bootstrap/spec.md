# Bootstrap Specification

## Purpose

`bootstrap` lets a caller seed identity and feature-flag state at SDK setup so the first events carry a known distinct id and feature-flag reads return real values before the first `/flags` response. It is a first-session concept: applied once when identity is first established, overlaid by freshly loaded flags, and dropped on a plain `reset()` — though some SDKs allow a caller to supply a fresh bootstrap explicitly to `reset()` itself, which is applied for the next identity (see the `reset` capability's "Reset MAY accept bootstrap options" requirement).
## Requirements
### Requirement: Bootstrap configuration surface

The SDK SHALL accept an optional `bootstrap` configuration at setup that seeds identity and feature-flag state before any network request completes. The configuration SHALL carry:

- `distinctId` — the distinct id to use before persisted identity is available.
- `isIdentifiedId` — whether `distinctId` already identifies a known person, versus an anonymous id.
- `featureFlags` — a map of flag key to value (boolean or string variant) served until fresh values are fetched.
- `featureFlagPayloads` — a map of flag key to JSON payload, paired with `featureFlags`.

A client SDK that owns session identity MAY additionally accept `sessionID` (see the session bootstrap requirement). When `bootstrap` is absent or empty, setup SHALL proceed with no bootstrap side effects.

This spec refers to the fields as `distinctId` and `isIdentifiedId` for readability only. The names are semantic: each SDK SHALL spell them following its own platform naming conventions rather than a single canonical casing. Shipped SDKs already differ — the browser SDK uses `distinctID` / `isIdentifiedID` while the shared core used by React Native and Node uses `distinctId` / `isIdentifiedId` — and both are conformant. Conformance is judged on the field semantics, not the spelling.

#### Scenario: Bootstrap absent is a no-op
- **WHEN** the SDK is initialized without a `bootstrap` configuration
- **THEN** no bootstrapped identity or feature-flag state is written
- **AND** identity and feature flags follow their normal not-bootstrapped behavior

#### Scenario: Bootstrapped flags are readable immediately after setup
- **GIVEN** the SDK is initialized with `bootstrap.featureFlags` of `{ "beta-ui": true }`
- **WHEN** `getFeatureFlag("beta-ui")` is called before any `/flags` response is received
- **THEN** the call returns `true` from the bootstrapped value rather than a not-loaded default

### Requirement: Bootstrapped identity never overwrites persisted identity

Bootstrapped identity SHALL be applied only when the SDK has no persisted identity for that scope. When a persisted distinct id (for an identified bootstrap) or a persisted anonymous id (for an anonymous bootstrap) already exists, the bootstrapped `distinctId` SHALL be ignored so an existing user is never silently reassigned.

#### Scenario: Bootstrapped identity seeds a fresh install
- **GIVEN** persistent storage has no distinct id
- **WHEN** the SDK is initialized with `bootstrap.distinctId` of "user-123"
- **THEN** the current distinct id becomes "user-123"

#### Scenario: Bootstrapped identity is ignored when identity already persisted
- **GIVEN** persistent storage already holds distinct id "existing-user"
- **WHEN** the SDK is initialized with `bootstrap.distinctId` of "user-123"
- **THEN** the current distinct id remains "existing-user"

### Requirement: Bootstrapped identification state

When `bootstrap.distinctId` is applied to a fresh install, the SDK SHALL record whether the user is identified based on `isIdentifiedId`. When `isIdentifiedId` is true, the SDK SHALL mark the person as identified. When `isIdentifiedId` is false or absent, the SDK SHALL treat `distinctId` as an anonymous id and leave the user in the anonymous state.

For an identified bootstrap, the SDK SHALL seed only the distinct id and identified state; it SHALL NOT adopt the bootstrapped `distinctId` as the device-scoped or anonymous id. The device id SHALL be derived normally (a freshly generated id), so `$device_id` and device-level flag bucketing are never set to the identified person's id. Only an anonymous bootstrap (`isIdentifiedId` false) seeds the anonymous id from `distinctId`.

#### Scenario: Identified bootstrap marks the user identified
- **GIVEN** persistent storage has no distinct id
- **WHEN** the SDK is initialized with `bootstrap.distinctId` "user-123" and `isIdentifiedId` true
- **THEN** the current distinct id is "user-123"
- **AND** the user is in the identified state

#### Scenario: Identified bootstrap does not become the device id
- **GIVEN** persistent storage has no distinct id
- **WHEN** the SDK is initialized with `bootstrap.distinctId` "user-123" and `isIdentifiedId` true
- **THEN** the current distinct id is "user-123"
- **AND** the device id is a freshly generated id, not "user-123"

#### Scenario: Anonymous bootstrap leaves the user anonymous
- **GIVEN** persistent storage has no distinct id
- **WHEN** the SDK is initialized with `bootstrap.distinctId` "anon-abc" and `isIdentifiedId` false
- **THEN** the anonymous id is "anon-abc"
- **AND** the user is in the anonymous state

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

### Requirement: Session bootstrap for cross-context continuation

A client SDK that owns a session id MAY accept a `sessionID` in the bootstrap configuration to continue an existing session across a domain or device. This is an allowed variation applicable to SDKs with a client-side session manager. When supported and provided, `sessionID` SHALL be a valid UUIDv7, the SDK SHALL adopt it as the current session id, and it SHALL derive the session start timestamp from the UUIDv7 timestamp component. When the provided `sessionID` is not a valid UUIDv7, the SDK SHALL log an error and fall back to generating a new session id.

#### Scenario: Valid bootstrapped session id continues the session
- **GIVEN** a client SDK with a session manager
- **WHEN** the SDK is initialized with a `bootstrap.sessionID` that is a valid UUIDv7
- **THEN** the current session id equals the provided value
- **AND** the session start timestamp is derived from the UUIDv7 timestamp

#### Scenario: Invalid bootstrapped session id falls back to a generated id
- **GIVEN** a client SDK with a session manager
- **WHEN** the SDK is initialized with a `bootstrap.sessionID` that is not a valid UUIDv7
- **THEN** an error is logged
- **AND** the SDK generates a new session id

### Requirement: A complete flags response replaces bootstrapped flags

A complete `/flags` response SHALL replace the served feature flags and payloads entirely: bootstrapped keys absent from a complete response SHALL no longer be served, and a bootstrapped payload SHALL NOT be retained alongside a loaded flag value. Only a partial response (a subset of flags was requested) or a response reporting `errorsWhileComputingFlags` SHALL merge into the existing served flags, preserving values that were not recomputed. Before any response, bootstrapped values are served as the snapshot described by the serving requirement.

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

### Requirement: Identified bootstrap upgrades a matching anonymous id

When `isIdentifiedId` is true and the bootstrapped `distinctId` equals the existing local distinct id but the user is not yet marked identified, the SDK SHALL mark the user identified. Because the distinct id is unchanged, the SDK SHALL NOT emit a redundant `$identify` or re-link identities. This applies even when the SDK is opted out of tracking, since only the local identification state changes.

#### Scenario: Matching bootstrap id upgrades an anonymous user to identified
- **GIVEN** the existing local user is anonymous with distinct id "user-123"
- **WHEN** the SDK is initialized with `bootstrap.distinctId` "user-123" and `isIdentifiedId` true
- **THEN** the current distinct id remains "user-123"
- **AND** the user is in the identified state
- **AND** no `$identify` event is emitted

### Requirement: Applying bootstrapped flags fires the flags-loaded callback

When `bootstrap.featureFlags` is applied at setup, the SDK SHALL fire its flags-loaded callback (the same notification/listener invoked when a `/flags` response is processed) with the served bootstrapped flags, before and independently of the first `/flags` response, so a listener waiting on flags is unblocked immediately (matching posthog-js, which fires `onFeatureFlags` when bootstrap is applied in `initialize()`). A later `/flags` response SHALL fire the callback again with the loaded values.

#### Scenario: Bootstrapped flags fire the flags-loaded callback at setup
- **GIVEN** a feature-flag listener is registered at setup
- **AND** the SDK is initialized with `bootstrap.featureFlags` `{ "beta-ui": true }`
- **WHEN** setup completes, before any `/flags` response
- **THEN** the listener is invoked with the served flags including `"beta-ui": true`
- **AND** no `/flags` network request is required for the listener to be invoked

