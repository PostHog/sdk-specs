## MODIFIED Requirements

### Requirement: Evaluation identity, inputs, and data sources

`evaluateFlags(...)` SHALL resolve a distinct id from the explicit call input or, where the SDK supports request context, from the active request context. It SHALL accept platform-appropriate evaluation inputs for groups, person properties, group properties, local-only evaluation, GeoIP control, and an optional list of flag keys. SDKs that support device-continuity evaluation MAY additionally accept a device id.

The SDK SHALL use a cached evaluated result or attempt local evaluation when its architecture supports either source. When local evaluation does not produce the required set and local-only mode is false, the SDK MAY make at most one direct remote `/flags` (or equivalent) evaluation request for the call.

When local flag definitions are loaded and a request-time key list includes a key with no local definition, the SDK SHALL treat the requested set as incomplete. If local-only mode is false, the SDK SHALL make one direct remote `/flags` (or equivalent) fallback request using the caller's original requested key scope, including keys that resolved locally, unless the SDK has retained valid missing-key knowledge as described below. This request remains subject to the one-request limit above. A locally resolved value SHALL NOT be overwritten by a remote fallback value for the same key in the resulting snapshot.

An SDK that has a successful local-definition refresh lifecycle SHALL retain negative knowledge for a requested key that is absent from both the loaded local definitions and a clean remote fallback response. A clean response is successful, is not feature-flag quota limited, and reports no errors while computing flags. Retention SHALL use a finite-capacity in-memory store. When adding a new entry at capacity, the SDK MAY evict a previously retained entry; eviction removes knowledge rather than establishing absence, so a later request for the evicted key is eligible to probe again. While knowledge remains retained and valid, the SDK SHALL omit the key without making another fallback request solely for that key. The knowledge SHALL be cleared after every successful local-definition refresh, including a changed response, an unchanged or not-modified response, or a successful shared-cache load, before evaluating a later call. A failed definitions refresh SHALL NOT clear valid knowledge. A remote response SHALL establish negative knowledge only if no successful definitions refresh completed after its request began; implementations SHALL associate an in-flight probe with its definitions generation and discard its omission result when that generation changes. While its knowledge remains retained, this bounds a permanently missing or deleted key to one clean fallback caused solely by that key per definitions-refresh interval while allowing newly created flags to be probed again after definitions are refreshed.

A failed remote response, a quota-limited response, or a response that reports errors while computing flags SHALL NOT establish negative knowledge. A later evaluation for the same identity and requested scope SHALL remain eligible to make a new direct fallback request, even when a general evaluated-result cache contains the inconclusive response. An SDK without a successful local-definition refresh lifecycle MAY continue probing on each call rather than retain knowledge that it cannot safely invalidate.

Before negative knowledge is established, concurrent evaluations that overlap on the same unknown missing key SHALL coordinate while that key's existence probe is in flight. If the shared probe cleanly omits the key, an overlapping evaluation with no other reason to fall back SHALL NOT make a duplicate request. If the response returns the key, its value or payload SHALL NOT be reused for a waiter whose complete evaluation context differs. Evaluation-affecting context includes the distinct id, device id where supported, groups, person properties, group properties, GeoIP control, requested key scope, and any other input sent to remote evaluation. Such a waiter SHALL make its own fallback before producing its snapshot. An evaluated-result cache MAY satisfy a waiter only when its entry is safely reusable for that complete context. Evaluations with disjoint missing-key sets SHALL be able to begin their direct fallbacks independently. When one evaluation's missing-key set contains both a key with an in-flight probe and a different uncoordinated key, it SHALL wait for the overlapping probe to settle before deciding whether to make its at-most-one fallback with the caller's original requested scope. That later original-scope request MAY include a settled or suppressed key, but it is not a fallback caused solely by that key.

When local-only mode is true, the SDK SHALL NOT make a remote evaluation request; flags that cannot be resolved locally, including requested keys with no local definition, SHALL be absent from the snapshot. When a request-time key list is supplied, any remote evaluation request and the resulting snapshot SHALL be scoped to those keys. An internal local evaluator MAY inspect additional definitions, but values outside the requested set SHALL be dropped before the snapshot is returned.

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

#### Scenario: Clean omission bounds probes until definitions refresh
- **GIVEN** the SDK refreshes local flag definitions
- **AND** loaded local definitions do not contain requested key "deleted-flag"
- **AND** a clean remote fallback response also omits "deleted-flag"
- **WHEN** `evaluateFlags(...)` is called again for any identity requesting "deleted-flag" before a successful local-definition refresh
- **THEN** the SDK omits "deleted-flag" without another remote fallback request solely for that key

#### Scenario: Capacity eviction forgets rather than suppresses
- **GIVEN** valid missing-key knowledge for "evicted-flag" is retained
- **AND** adding another clean omission at capacity evicts "evicted-flag"
- **WHEN** a later evaluation requests "evicted-flag"
- **THEN** the evicted knowledge does not suppress a new remote fallback request

#### Scenario: Every successful definitions refresh clears omission knowledge
- **GIVEN** the SDK has retained valid missing-key knowledge for "deleted-flag"
- **WHEN** local definitions are refreshed successfully with changed definitions, an unchanged or not-modified response, or a successful shared-cache load
- **THEN** the retained missing-key knowledge is cleared
- **WHEN** the refreshed definitions still omit "deleted-flag" and no complete cached result applies
- **THEN** the next non-local-only evaluation requesting "deleted-flag" makes one remote fallback request

#### Scenario: Failed definitions refresh preserves omission knowledge
- **GIVEN** the SDK has retained valid missing-key knowledge for "deleted-flag"
- **WHEN** the next local-definition refresh fails
- **THEN** the retained missing-key knowledge remains valid
- **AND** a later evaluation omits "deleted-flag" without another remote fallback request solely for that key

#### Scenario: Refresh invalidates an in-flight probe generation
- **GIVEN** a remote existence probe for "deleted-flag" is in flight
- **WHEN** local definitions refresh successfully before that remote response completes
- **THEN** the old response does not establish negative knowledge in the new definitions generation
- **WHEN** the refreshed definitions still omit "deleted-flag" and no complete cached result applies
- **THEN** a later evaluation requesting "deleted-flag" makes one new remote fallback request

#### Scenario: Unsuccessful remote response permits retry
- **GIVEN** loaded local definitions do not contain requested key "missing-local-flag"
- **AND** the remote fallback fails, is quota limited, or reports errors while computing flags
- **WHEN** `evaluateFlags(...)` is called again for the same identity and requested scope
- **THEN** exactly one new remote fallback request is made
- **AND** a cached inconclusive response does not suppress that request

#### Scenario: Concurrent clean omissions share one existence probe
- **GIVEN** loaded local definitions do not contain requested key "deleted-flag"
- **AND** no valid negative knowledge is retained for "deleted-flag"
- **AND** the clean remote response omits "deleted-flag"
- **WHEN** multiple evaluations concurrently request "deleted-flag"
- **THEN** they make one direct remote existence probe for "deleted-flag"
- **AND** every evaluation omits "deleted-flag" from its snapshot

#### Scenario: Returned key is evaluated for each distinct context
- **GIVEN** concurrent evaluations overlap on unknown key "remote-flag"
- **AND** their complete evaluation contexts differ in any evaluation-affecting input
- **AND** the shared probe returns "remote-flag" for the first context
- **WHEN** the waiting evaluation resumes
- **THEN** it makes its own fallback for its complete evaluation context
- **AND** neither context receives the other context's value or payload

#### Scenario: Unrelated missing keys are not serialized
- **GIVEN** loaded local definitions do not contain requested keys "missing-a" and "missing-b"
- **AND** no valid negative knowledge is retained for either key
- **WHEN** separate evaluations with disjoint missing-key sets concurrently request "missing-a" and "missing-b"
- **THEN** the direct fallback for each key can begin without waiting for the other key's response

#### Scenario: Mixed missing-key scope waits for its overlap
- **GIVEN** an existence probe for "missing-a" is in flight
- **AND** a second evaluation requests both "missing-a" and "missing-b"
- **WHEN** the second evaluation coordinates its missing keys
- **THEN** it waits for the "missing-a" probe to settle before starting another direct fallback
- **AND** any fallback it subsequently makes uses the second caller's original requested scope

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
