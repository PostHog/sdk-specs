## MODIFIED Requirements

### Requirement: Evaluation identity, inputs, and data sources

`evaluateFlags(...)` SHALL resolve a distinct id from the explicit call input or, where the SDK supports request context, from the active request context. It SHALL accept platform-appropriate evaluation inputs for groups, person properties, group properties, local-only evaluation, GeoIP control, and an optional list of flag keys. SDKs that support device-continuity evaluation MAY additionally accept a device id.

The SDK SHALL distinguish the presence of the optional flag-key list from its length. When the list is omitted or null, the call is unscoped and SHALL evaluate all flags available through the SDK's normal evaluation path. When the list is explicitly supplied and empty, the call SHALL return an empty snapshot without consulting an evaluated-result cache, attempting local evaluation, or making a direct remote `/flags` (or equivalent) evaluation request. When the list is non-empty, local evaluation, any direct remote evaluation request, and the resulting snapshot SHALL be scoped to exactly those keys.

The SDK SHALL use a cached evaluated result or attempt local evaluation when its architecture supports either source. When local evaluation does not produce the required set and local-only mode is false, the SDK MAY make at most one direct remote `/flags` (or equivalent) evaluation request for the call.

When local flag definitions are loaded and a non-empty request-time key list includes a key with no local definition, the SDK SHALL treat the requested set as incomplete. If local-only mode is false, the SDK SHALL make one direct remote `/flags` (or equivalent) fallback request using the caller's original requested key scope, including keys that resolved locally, unless the SDK has retained valid missing-key knowledge as described below. This request remains subject to the one-request limit above. A locally resolved value SHALL NOT be overwritten by a remote fallback value for the same key in the resulting snapshot.

An SDK that has a successful local-definition refresh lifecycle SHALL retain negative knowledge for a requested key that is absent from both the loaded local definitions and a clean remote fallback response. A clean response is successful, is not feature-flag quota limited, and reports no errors while computing flags. Retention SHALL use a finite-capacity in-memory store. When adding a new entry at capacity, the SDK MAY evict a previously retained entry; eviction removes knowledge rather than establishing absence, so a later request for the evicted key is eligible to probe again. While knowledge remains retained and valid, the SDK SHALL omit the key without making another fallback request solely for that key. The knowledge SHALL be cleared after every successful local-definition refresh, including a changed response, an unchanged or not-modified response, or a successful shared-cache load, before evaluating a later call. A failed definitions refresh SHALL NOT clear valid knowledge. A remote response SHALL establish negative knowledge only if no successful definitions refresh completed after its request began; implementations SHALL associate an in-flight probe with its definitions generation and discard its omission result when that generation changes. While its knowledge remains retained, this bounds a permanently missing or deleted key to one clean fallback caused solely by that key per definitions-refresh interval while allowing newly created flags to be probed again after definitions are refreshed.

Any current-generation remote response that explicitly returns a previously suppressed key SHALL immediately remove that key's negative knowledge, even when another unresolved key caused the fallback. A clean omission SHALL establish negative knowledge only for unknown missing keys that were assigned to that existence probe when it began. A key whose negative knowledge was already retained when a request began MAY be included in that request to preserve original scope, but an omission from that request SHALL NOT refresh or reinstall its negative knowledge. A failed remote response, a quota-limited response, or a response that reports errors while computing flags SHALL NOT establish negative knowledge. A later evaluation for the same identity and requested scope SHALL remain eligible to make a new direct fallback request, even when a general evaluated-result cache contains the inconclusive response. An SDK without a successful local-definition refresh lifecycle MAY continue probing on each call rather than retain knowledge that it cannot safely invalidate.

Before negative knowledge is established, concurrent evaluations that overlap on the same unknown missing key SHALL coordinate while that key's existence probe is in flight. If the shared probe establishes negative knowledge for the key before an overlapping evaluation stops waiting, and that knowledge is still retained and valid when the evaluation decides whether to fall back, the evaluation SHALL NOT make a duplicate request when it has no other reason to fall back. A clean omission that does not establish negative knowledge, for example because another probe in the same generation returned the key, or knowledge that was cleared before the decision, SHALL NOT suppress the waiter's own fallback. If the response returns the key, its value or payload SHALL NOT be reused for a waiter whose complete evaluation context differs. Evaluation-affecting context includes the distinct id, device id where supported, groups, person properties, group properties, GeoIP control, requested key scope, and any other input sent to remote evaluation. Such a waiter SHALL make its own fallback before producing its snapshot. An evaluated-result cache MAY satisfy a waiter only when its entry is safely reusable for that complete context. Evaluations with disjoint missing-key sets SHALL be able to begin their direct fallbacks independently. When one evaluation's missing-key set contains both a key with an in-flight probe and a different uncoordinated key, it SHALL wait for the overlapping probe to settle, or until it is released early as described below, before deciding whether to make its at-most-one fallback with the caller's original requested scope. That later original-scope request MAY include a settled or suppressed key, but it is not a fallback caused solely by that key.

Probe coordination SHALL have the same scope as the SDK's negative-knowledge store: one SDK instance in one operating-system process or runtime node, such as one BEAM node. Within that boundary, evaluations running on different threads, tasks, or lightweight runtime processes SHALL coordinate as described above. The SDK MUST NOT make an evaluation wait for a probe owned by another operating-system process or runtime node, and MUST NOT acquire a lock that spans them for this coordination. Separate operating-system processes or runtime nodes MAY each make their own existence probe for the same key. The bound of one probe per definitions-refresh interval applies per SDK instance, and does not count duplicate requests that were already started, under the release rules below, before negative knowledge was retained.

Waiting for overlapping probes SHALL be bounded by one finite deadline per evaluation that does not depend on any probe's network timeout or retry policy. The deadline starts when the evaluation first coordinates its missing keys and covers every overlapping probe it waits for, including probes for other keys it later finds in flight. When the deadline expires, the waiting evaluation SHALL stop waiting and proceed as if no probe for that key were in flight, subject to the one-request limit, and it MUST NOT continue to be registered as a waiter. If the probe owner ends without completing, or the coordination mechanism itself fails or does not respond, waiting evaluations SHALL be released and proceed the same way. A request made after such a release MAY duplicate the in-flight probe. While a probe is in flight, an evaluation that only waits SHALL NOT block any other key.

When probes for the same key overlap within one definitions generation, positive evidence SHALL win. A clean omission from a probe that was already in flight when another current-generation response returned the key SHALL NOT establish negative knowledge for it. A probe that begins after that positive response MAY establish negative knowledge from its own clean omission, for example after the flag is deleted. The SDK MAY track returned keys in a finite-capacity store. If eviction means the SDK can no longer tell whether a key was returned while a probe was in flight, it SHALL NOT establish negative knowledge from that probe.

After a probe settles without establishing negative knowledge, whether because the key was returned, the response was not clean, or a clean omission could not be retained, the evaluations that waited for it SHALL be able to begin their own fallbacks concurrently. They MUST NOT be made to wait for each other's fallbacks for the settled key. They SHALL still coordinate on any other unknown missing key they have not yet settled.

As an exception, when a probe settles without establishing whether the key exists, because the response was not clean or the request failed, the SDK MAY let one waiting evaluation make a single shared retry probe while the others keep waiting within their existing deadlines. If that retry also does not establish whether the key exists, the remaining waiters SHALL proceed concurrently. The SDK MUST NOT chain further shared retries for the key within the same coordination round.

When local-only mode is true, the SDK SHALL NOT make a remote evaluation request; flags that cannot be resolved locally, including requested keys with no local definition, SHALL be absent from the snapshot. When a non-empty request-time key list is supplied, any remote evaluation request and the resulting snapshot SHALL be scoped to those keys. An internal local evaluator MAY inspect additional definitions, but values outside the requested set SHALL be dropped before the snapshot is returned.

#### Scenario: Omitted key list evaluates all available flags
- **GIVEN** flags "checkout" and "search" are available
- **WHEN** `evaluateFlags(...)` is called with the flag-key list omitted or null
- **THEN** the returned snapshot contains "checkout" and "search"

#### Scenario: Empty key list is a no-op
- **GIVEN** cached, local, and remote evaluation sources could provide flags "checkout" and "search"
- **WHEN** `evaluateFlags(...)` is called with an explicitly empty flag-key list
- **THEN** the returned snapshot contains no flags
- **AND** no cached evaluated result is consulted
- **AND** no local feature-flag evaluation is attempted
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

#### Scenario: Positive remote evidence clears an earlier omission
- **GIVEN** valid missing-key knowledge is retained for "previously-missing"
- **AND** a fallback caused by another unresolved key uses an original scope that also includes "previously-missing"
- **WHEN** the current-generation remote response returns "previously-missing"
- **THEN** its retained negative knowledge is removed immediately
- **AND** a later evaluation does not suppress "previously-missing" using the earlier omission

#### Scenario: Delayed omission cannot overwrite newer positive evidence
- **GIVEN** valid missing-key knowledge is retained for "previously-missing"
- **AND** two fallbacks caused by different unknown keys include "previously-missing" in their original scopes
- **WHEN** one current-generation response returns "previously-missing"
- **AND** a later response from the other request omits "previously-missing"
- **THEN** the positive response removes the retained negative knowledge
- **AND** the later omission does not reinstall it because "previously-missing" did not cause that probe

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
- **AND** the clean remote response omits "deleted-flag" and establishes negative knowledge before any waiting evaluation is released
- **WHEN** multiple evaluations in the same SDK instance concurrently request "deleted-flag"
- **AND** that knowledge is still retained and valid when each waiting evaluation decides whether to fall back
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
- **THEN** it waits for the "missing-a" probe to settle before starting another direct fallback, unless its deadline expires, the probe owner ends, or coordination fails first
- **AND** any fallback it subsequently makes uses the second caller's original requested scope

#### Scenario: A stalled probe does not hold waiting evaluations indefinitely
- **GIVEN** loaded local definitions do not contain requested key "deleted-flag"
- **AND** an existence probe for "deleted-flag" is in flight and does not complete
- **WHEN** a second evaluation requests "deleted-flag"
- **THEN** it waits no longer than the SDK's finite coordination wait
- **AND** it then makes its own direct fallback with its original requested scope
- **AND** it is no longer registered as waiting for the stalled probe

#### Scenario: An abandoned probe releases waiting evaluations
- **GIVEN** an evaluation is waiting for the in-flight existence probe for "deleted-flag"
- **WHEN** the evaluation that owns the probe ends without completing it
- **THEN** the waiting evaluation proceeds without waiting for the coordination wait to expire

#### Scenario: An omission that cannot establish negative knowledge does not suppress a waiter
- **GIVEN** an evaluation is waiting for the in-flight probe for "new-flag"
- **AND** another evaluation's fallback in the same definitions generation already returned "new-flag"
- **AND** a second evaluation is also waiting for that probe
- **WHEN** the in-flight probe completes with a clean omission of "new-flag"
- **THEN** each waiting evaluation makes its own fallback for its complete evaluation context
- **AND** neither waits for the other's fallback

#### Scenario: Negative knowledge cleared before a waiter decides does not suppress it
- **GIVEN** an evaluation is waiting for the in-flight probe for "new-flag"
- **AND** that probe cleanly omits "new-flag" and establishes negative knowledge
- **WHEN** another current-generation response returns "new-flag" before the waiting evaluation decides whether to fall back
- **THEN** the waiting evaluation makes its own fallback for its complete evaluation context

#### Scenario: Waiters of a returned key fall back concurrently
- **GIVEN** evaluations for distinct ids "user-1", "user-2", and "user-3" overlap on unknown key "remote-flag"
- **AND** the shared probe for "user-1" returns "remote-flag"
- **WHEN** the waiting evaluations for "user-2" and "user-3" resume
- **THEN** both direct fallbacks can be in flight at the same time
- **AND** neither waits for the other's response

#### Scenario: One coordination deadline covers every overlapping key
- **GIVEN** an evaluation requests unknown keys "missing-a" and "missing-b"
- **AND** another evaluation's probe for "missing-a" is in flight
- **WHEN** the "missing-a" probe settles and the evaluation then finds a probe for "missing-b" in flight
- **THEN** it waits for "missing-b" only for the time left before its original deadline

#### Scenario: A newer returned key is not hidden by an older omission
- **GIVEN** an existence probe for "new-flag" is in flight
- **AND** a waiting evaluation's deadline expires and it makes its own fallback in the same definitions generation
- **WHEN** the newer fallback returns "new-flag"
- **AND** the older probe later completes with a clean omission of "new-flag"
- **THEN** no negative knowledge is retained for "new-flag"
- **AND** a later evaluation requesting "new-flag" is not suppressed by the older omission

#### Scenario: A probe that starts after a returned key may record its omission
- **GIVEN** a current-generation response returned "retired-flag"
- **AND** no probe for "retired-flag" was in flight at that time
- **WHEN** a later probe for "retired-flag" begins and receives a clean omission
- **THEN** negative knowledge for "retired-flag" may be retained

#### Scenario: An unclean probe allows at most one shared retry
- **GIVEN** several evaluations are waiting for the in-flight probe for "missing-flag"
- **WHEN** that probe completes with a response that reports errors while computing flags
- **THEN** at most one waiting evaluation makes a shared retry probe while the others keep waiting within their deadlines
- **WHEN** the retry also reports errors while computing flags
- **THEN** the remaining waiting evaluations make their own fallbacks concurrently

#### Scenario: Probe coordination does not span processes or nodes
- **GIVEN** two operating-system processes or runtime nodes each run an SDK instance with loaded definitions that do not contain "deleted-flag"
- **AND** neither instance retains negative knowledge for "deleted-flag"
- **WHEN** both instances concurrently evaluate "deleted-flag"
- **THEN** each instance can begin its existence probe without waiting for the other instance's probe
- **AND** within each instance, a waiting evaluation with no other reason to fall back does not make its own request while that instance's negative knowledge for "deleted-flag" is still retained and valid

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
