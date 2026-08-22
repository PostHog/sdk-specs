## MODIFIED Requirements

### Requirement: Evaluation identity, inputs, and data sources

`evaluateFlags(...)` SHALL resolve a distinct id from the explicit call input or, where the SDK supports request context, from the active request context. It SHALL accept platform-appropriate evaluation inputs for groups, person properties, group properties, local-only evaluation, GeoIP control, and an optional list of flag keys. SDKs that support device-continuity evaluation MAY additionally accept a device id.

The SDK SHALL distinguish the presence of the optional flag-key list from its length. When the list is omitted or null, the call is unscoped and SHALL evaluate all flags available through the SDK's normal evaluation path. When the list is explicitly supplied and empty, the call SHALL return an empty snapshot and SHALL NOT make a direct remote `/flags` (or equivalent) evaluation request. When the list is non-empty, local evaluation, any direct remote evaluation request, and the resulting snapshot SHALL be scoped to exactly those keys.

The SDK SHALL use a cached evaluated result or attempt local evaluation when its architecture supports either source. When local evaluation does not produce the required set and local-only mode is false, the SDK MAY make at most one direct remote `/flags` (or equivalent) evaluation request for the call.

When local flag definitions are loaded and a non-empty request-time key list includes a key with no local definition, the SDK SHALL treat the requested set as incomplete. If local-only mode is false, the SDK SHALL make one direct remote `/flags` (or equivalent) fallback request using the caller's original requested key scope, including keys that resolved locally, unless the SDK has retained valid missing-key knowledge as described below. This request remains subject to the one-request limit above. A locally resolved value SHALL NOT be overwritten by a remote fallback value for the same key in the resulting snapshot.

An SDK MAY retain negative knowledge for a requested key that is absent from both the loaded local definitions and a successful remote fallback response. While that knowledge remains valid, the SDK MAY omit the key without making another fallback request. The SDK SHALL NOT establish negative knowledge from a failed response, a quota-limited response, or a response that reports errors while computing flags. An SDK that retains negative knowledge SHALL clear it after the next successful local-definition refresh, including a successful unchanged or not-modified refresh, before evaluating a later call. This bounds a permanently missing or deleted key to at most one successful probe per definitions-refresh interval while allowing newly created flags to be probed again after definitions are refreshed.

When local-only mode is true, the SDK SHALL NOT make a remote evaluation request; flags that cannot be resolved locally, including requested keys with no local definition, SHALL be absent from the snapshot. When a non-empty request-time key list is supplied, any remote evaluation request and the resulting snapshot SHALL be scoped to those keys. An internal local evaluator MAY inspect additional definitions, but values outside the requested set SHALL be dropped before the snapshot is returned.

#### Scenario: Omitted key list evaluates all available flags
- **GIVEN** flags "checkout" and "search" are available
- **WHEN** `evaluateFlags(...)` is called with the flag-key list omitted or null
- **THEN** the returned snapshot contains "checkout" and "search"

#### Scenario: Empty key list is a no-op
- **GIVEN** flags "checkout" and "search" are available
- **WHEN** `evaluateFlags(...)` is called with an explicitly empty flag-key list
- **THEN** the returned snapshot contains no flags
- **AND** no direct remote feature-flag evaluation request is made

#### Scenario: Remote fallback fills unresolved flags once
- **GIVEN** local evaluation resolves "local-flag" but cannot resolve "remote-flag"
- **AND** remote evaluation is enabled
- **WHEN** `evaluateFlags(...)` is called
- **THEN** at most one remote feature-flag evaluation request is made
- **AND** the snapshot contains the locally resolved "local-flag" value
- **AND** the snapshot contains the remotely resolved "remote-flag" value when remote evaluation succeeds

#### Scenario: Missing requested local definition triggers scoped remote fallback
- **GIVEN** local flag definitions are loaded and resolve "local-flag"
- **AND** the requested key "missing-local-flag" has no local definition
- **AND** no valid negative knowledge is retained for "missing-local-flag"
- **AND** remote evaluation is enabled
- **WHEN** `evaluateFlags(...)` is called with requested keys `["local-flag", "missing-local-flag"]`
- **THEN** exactly one remote feature-flag evaluation request is made using the original requested key scope
- **AND** the snapshot retains the locally resolved "local-flag" value even if the remote response differs
- **AND** the snapshot contains the remotely resolved "missing-local-flag" value when remote evaluation succeeds

#### Scenario: Optional negative knowledge bounds probes until definitions refresh
- **GIVEN** an SDK retains missing-key knowledge
- **AND** loaded local definitions do not contain requested key "deleted-flag"
- **AND** a successful, non-quota-limited remote fallback response also omits "deleted-flag" and reports no flag-computation errors
- **WHEN** `evaluateFlags(...)` is called again for "deleted-flag" before a successful local-definition refresh
- **THEN** the SDK MAY omit "deleted-flag" without another remote fallback request
- **WHEN** the local definitions are next refreshed successfully, including with an unchanged or not-modified result
- **THEN** the retained missing-key knowledge is cleared
- **AND** the next non-local-only evaluation requesting "deleted-flag" makes one remote fallback request

#### Scenario: Unsuccessful remote responses do not establish missing-key knowledge
- **GIVEN** loaded local definitions do not contain requested key "missing-local-flag"
- **AND** the remote fallback fails, is quota limited, or reports errors while computing flags
- **WHEN** that fallback response is processed
- **THEN** the SDK does not retain negative knowledge for "missing-local-flag" from that response

#### Scenario: Local-only evaluation omits unresolved flags
- **GIVEN** local evaluation resolves "local-flag" but cannot resolve "remote-flag"
- **WHEN** `evaluateFlags(...)` is called with local-only evaluation enabled
- **THEN** no remote feature-flag evaluation request is made
- **AND** the snapshot contains "local-flag"
- **AND** the snapshot does not contain "remote-flag"

#### Scenario: Request-time key filtering scopes evaluation
- **GIVEN** flags "checkout", "new-nav", and "search" are available
- **WHEN** `evaluateFlags(...)` is called with requested keys `["checkout", "search"]`
- **THEN** any remote request is scoped to "checkout" and "search"
- **AND** the returned snapshot contains no keys outside "checkout" and "search"
