## ADDED Requirements

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

When `isIdentifiedId` is true and the bootstrapped `distinctId` differs from the existing local distinct id, the SDK SHALL reconcile the bootstrapped identity against the existing local identity as follows. (An SDK whose identity model structurally cannot merge an anonymous user into an identified one at init MAY instead fall back to the non-overwrite rule above; that is the only permitted deviation.)

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

### Requirement: Bootstrapped feature flags are served before the first flags response

When `bootstrap.featureFlags` is non-empty, the SDK SHALL make those values available to feature-flag reads immediately after setup, before the first `/flags` response. Flag reads (`getFeatureFlag`, `getFeatureFlagPayload`, `isFeatureEnabled`, and equivalents) SHALL return bootstrapped values and paired payloads instead of not-loaded defaults during this window. The SDK SHALL retain a copy of the bootstrapped flag values for reporting on `$feature_flag_called`.

#### Scenario: Bootstrapped payload is served with its flag
- **GIVEN** the SDK is initialized with `bootstrap.featureFlags` `{ "beta-ui": "variant-a" }` and `bootstrap.featureFlagPayloads` `{ "beta-ui": {"color":"blue"} }`
- **WHEN** the flag value and payload for "beta-ui" are read before any `/flags` response
- **THEN** the value is "variant-a"
- **AND** the payload is `{"color":"blue"}`

### Requirement: Loaded flags take precedence over bootstrapped flags

Bootstrapped feature flags SHALL form the base layer only. When the SDK loads flags from `/flags` or applies flags via a direct update, the loaded values SHALL overlay the bootstrapped values for overlapping keys so the freshest values win, while bootstrapped keys not present in the loaded response remain available.

Bootstrap is a first-session concept, applied once when identity is first seeded. When the SDK clears identity (for example via `reset()`), it SHALL drop the retained bootstrap base layer so a subsequent user is never served the previous user's bootstrapped values: after such a reset, bootstrapped-only keys SHALL NOT reappear on later flag loads, and the SDK SHALL NOT re-seed bootstrap for the new identity.

#### Scenario: A loaded flags response overrides the bootstrapped value
- **GIVEN** the SDK is initialized with `bootstrap.featureFlags` `{ "beta-ui": true }`
- **AND** the next `/flags` response returns `{ "beta-ui": false }`
- **WHEN** feature flags finish loading from `/flags`
- **THEN** `getFeatureFlag("beta-ui")` returns `false`

#### Scenario: Bootstrapped-only keys survive a flags load
- **GIVEN** the SDK is initialized with `bootstrap.featureFlags` `{ "beta-ui": true, "legacy": true }`
- **AND** the next `/flags` response returns only `{ "beta-ui": false }`
- **WHEN** feature flags finish loading from `/flags`
- **THEN** `getFeatureFlag("legacy")` still returns `true`

#### Scenario: Bootstrapped flags are not resurrected after reset
- **GIVEN** the SDK was initialized with `bootstrap.featureFlags` `{ "legacy": true }`
- **AND** flags have loaded and then `reset()` was called
- **WHEN** feature flags are reloaded for the new user
- **THEN** `getFeatureFlag("legacy")` does not return the bootstrapped value

### Requirement: Bootstrapped flag reporting on `$feature_flag_called`

When the SDK captures `$feature_flag_called` for a flag that was bootstrapped, it SHALL enrich the event with the bootstrapped context:

- `$feature_flag_bootstrapped_response` — the bootstrapped value for that key, when one was provided.
- `$feature_flag_bootstrapped_payload` — the bootstrapped payload for that key, when one was provided.
- `$used_bootstrap_value` — true when the SDK has not yet received a `/flags` response (so the served value came from bootstrap), otherwise false. The "flags loaded from remote" signal that drives this SHALL be cleared on `reset()`, so it correctly reports true again for a new identity until that identity's first `/flags` response.

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
