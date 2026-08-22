# Evaluate Flags Specification

## Purpose

`evaluate-flags` is the preferred server-side API for evaluating feature flags once for an identity/context and returning a reusable, point-in-time `FeatureFlagEvaluations` snapshot. Snapshot accessors such as `isEnabled(...)` / `is_enabled(...)` and `getFlag(...)` read the frozen result without another evaluation request, lazily report `$feature_flag_called` when a value is actually used, and let `capture(flags: snapshot)` attach the exact decisions used for branching.

This supersedes the older server-side pattern of evaluating through separate boolean, value, payload, structured-result, and bulk getters, or implicitly during capture. It differs from client-side `isFeatureEnabled(...)`, which reads ambient cached flag state. The snapshot API is designed to power all flag reads and event enrichment for one server request/context from the same evaluation.

## Requirements
### Requirement: Server-side snapshot evaluation API

A server SDK SHALL expose a platform-idiomatic `evaluateFlags` / `evaluate_flags` operation that evaluates feature flags for one resolved identity and evaluation context and returns a non-null `FeatureFlagEvaluations` snapshot (name and async/error wrapper per platform convention).

The snapshot is a point-in-time evaluation result, not a renamed boolean check. Calling `evaluateFlags(...)` performs the evaluation; calling `snapshot.isEnabled(key)`, `snapshot.getFlag(key)`, or an equivalent accessor reads the already-created snapshot and SHALL NOT evaluate the flag again or perform network I/O. One snapshot SHALL support any number of flag branches for the same evaluation context.

This capability applies to server SDKs. Client-side `isFeatureEnabled(...)` methods that read ambient cached flag state remain governed by the `is-feature-enabled` capability and are not replaced by this server-request snapshot API.

For server SDKs, the snapshot API supersedes these older call patterns (names vary by platform):

| Older pattern | Snapshot replacement |
| --- | --- |
| `isFeatureEnabled(...)` / `feature_enabled(...)` / `is_feature_enabled(...)` | `evaluateFlags(...).isEnabled(key)` |
| `getFeatureFlag(...)` / `get_feature_flag(...)` | `evaluateFlags(...).getFlag(key)` |
| `getFeatureFlagPayload(...)` / `get_feature_flag_payload(...)` | `evaluateFlags(...).getFlagPayload(key)` (a silent payload lookup) |
| `getFeatureFlagResult(...)` / `get_feature_flag_result(...)` | read the value and payload from the same snapshot (or use the platform's rich snapshot result) |
| `getAllFlags(...)` / `get_all_flags(...)` | enumerate snapshot keys and read their values; each value read is tracked as access |
| `getAllFlagsAndPayloads(...)` / `get_all_flags_and_payloads(...)` | enumerate snapshot keys and read values plus payloads; value reads are tracked and payload-only reads are silent |
| `capture(..., sendFeatureFlags: true)` / `send_feature_flags` and equivalents | evaluate once, then pass the snapshot to `capture(..., flags: snapshot)` |

This is a functional migration map, not a promise to preserve every legacy side effect. Snapshot `isEnabled(...)` / `getFlag(...)` calls report access through `$feature_flag_called`, while key enumeration and payload-only reads are silent. Consequently, folding a data-only bulk map into per-key `getFlag(...)` reads deliberately reports each value used, and migrating Go's historically event-emitting payload getter to snapshot `getFlagPayload(...)` deliberately makes payload-only access silent. Callers that require a legacy data-only bulk shape MAY continue using a retained compatibility method.

Server SDKs MAY retain any of these APIs for compatibility, and formal deprecation status MAY vary by SDK and release policy. Documentation SHALL present `evaluateFlags(...)` as the preferred server composition when flag reads or event enrichment share one identity/evaluation context.

#### Scenario: One evaluation powers multiple flag branches
- **GIVEN** remote evaluation for distinct id "user-123" returns flags "checkout" and "new-nav"
- **WHEN** `evaluateFlags("user-123")` is called
- **AND** `isEnabled("checkout")`, `getFlag("new-nav")`, and `isEnabled("checkout")` are called on the returned snapshot
- **THEN** exactly one direct remote feature-flag evaluation request is made
- **AND** the three snapshot accessor calls make no feature-flag evaluation requests

#### Scenario: Snapshot boolean access is not a direct evaluation call
- **GIVEN** a `FeatureFlagEvaluations` snapshot has already been returned
- **WHEN** `isEnabled("checkout")` is called on that snapshot
- **THEN** the boolean is derived only from the value frozen into that snapshot
- **AND** no current flag definition, evaluated-result cache, or remote endpoint is consulted

### Requirement: Evaluation identity, inputs, and data sources

`evaluateFlags(...)` SHALL resolve a distinct id from the explicit call input or, where the SDK supports request context, from the active request context. It SHALL accept platform-appropriate evaluation inputs for groups, person properties, group properties, local-only evaluation, GeoIP control, and an optional list of flag keys. SDKs that support device-continuity evaluation MAY additionally accept a device id.

The SDK SHALL use a cached evaluated result or attempt local evaluation when its architecture supports either source. When local evaluation does not produce the required set and local-only mode is false, the SDK MAY make at most one direct remote `/flags` (or equivalent) evaluation request for the call.

When local flag definitions are loaded and a request-time key list includes a key with no local definition, the SDK SHALL treat the requested set as incomplete. If local-only mode is false, the SDK SHALL make one direct remote `/flags` (or equivalent) fallback request using the caller's original requested key scope, including keys that resolved locally, unless the SDK has retained valid missing-key knowledge as described below. This request remains subject to the one-request limit above. A locally resolved value SHALL NOT be overwritten by a remote fallback value for the same key in the resulting snapshot.

An SDK that has a successful local-definition refresh lifecycle SHALL retain negative knowledge for a requested key that is absent from both the loaded local definitions and a clean remote fallback response. A clean response is successful, is not feature-flag quota limited, and reports no errors while computing flags. Retention SHALL use a finite-capacity in-memory store. When adding a new entry at capacity, the SDK MAY evict a previously retained entry; eviction removes knowledge rather than establishing absence, so a later request for the evicted key is eligible to probe again. While knowledge remains retained and valid, the SDK SHALL omit the key without making another fallback request solely for that key. The knowledge SHALL be cleared after every successful local-definition refresh, including a changed response, an unchanged or not-modified response, or a successful shared-cache load, before evaluating a later call. A failed definitions refresh SHALL NOT clear valid knowledge. A remote response SHALL establish negative knowledge only if no successful definitions refresh completed after its request began; implementations SHALL associate an in-flight probe with its definitions generation and discard its omission result when that generation changes. While its knowledge remains retained, this bounds a permanently missing or deleted key to one clean fallback caused solely by that key per definitions-refresh interval while allowing newly created flags to be probed again after definitions are refreshed.

A failed remote response, a quota-limited response, or a response that reports errors while computing flags SHALL NOT establish negative knowledge. A later evaluation for the same identity and requested scope SHALL remain eligible to make a new direct fallback request, even when a general evaluated-result cache contains the inconclusive response. An SDK without a successful local-definition refresh lifecycle MAY continue probing on each call rather than retain knowledge that it cannot safely invalidate.

Before negative knowledge is established, concurrent evaluations that overlap on the same unknown missing key SHALL coordinate while that key's existence probe is in flight. If the shared probe cleanly omits the key, an overlapping evaluation with no other reason to fall back SHALL NOT make a duplicate request. If the response returns the key, its identity-specific value SHALL NOT be reused for a waiting evaluation with a different distinct id, groups, person properties, or group properties; that waiter SHALL make its own fallback before producing its snapshot. An evaluated-result cache MAY satisfy a waiter only when its complete evaluation context is safely reusable. Evaluations with disjoint missing-key sets SHALL be able to begin their direct fallbacks independently. When one evaluation's missing-key set contains both a key with an in-flight probe and a different uncoordinated key, it SHALL wait for the overlapping probe to settle before deciding whether to make its at-most-one fallback with the caller's original requested scope. That later original-scope request MAY include a settled or suppressed key, but it is not a fallback caused solely by that key.

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
- **GIVEN** concurrent evaluations for different identities overlap on unknown key "remote-flag"
- **AND** the shared probe returns "remote-flag" for the first identity
- **WHEN** the waiting evaluation resumes
- **THEN** it makes its own fallback for its distinct evaluation context
- **AND** neither identity receives the other identity's value or payload

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

### Requirement: Point-in-time flag values and enablement

The snapshot SHALL retain a stable set of evaluated flag records. Later flag-definition refreshes, remote changes, cache updates, or separate evaluations SHALL NOT change values in an existing snapshot. The snapshot SHALL enumerate the keys it contains; key ordering is unspecified.

The snapshot SHALL provide these semantic projections, with naming and result wrappers adapted to the host language:

- enablement: enabled boolean flags and non-empty variants resolve to `true`; disabled flags resolve to `false`; missing flags resolve to `false` by default;
- value: enabled boolean flags resolve to `true`, disabled flags to `false`, multivariate flags to the variant string, and missing flags to the language's nullish sentinel;
- rich result: an SDK MAY return a structured flag object from its value accessor instead of a scalar when that object exposes the same enabled/variant semantics.

An SDK MAY let the caller supply a boolean default for missing enablement. When it does, the default SHALL apply only when the key has no value in the snapshot; a present value, including `false`, SHALL win over the default.

The snapshot SHALL retain the evaluation identity/context and available evaluation metadata needed for later access tracking and capture enrichment. Public metadata fields MAY vary by platform.

#### Scenario: Snapshot accessors project boolean and variant values
- **GIVEN** a snapshot contains boolean-enabled flag "a", boolean-disabled flag "b", and variant flag "c" with variant "blue"
- **WHEN** enablement and value accessors are called for those keys
- **THEN** "a" is enabled and has value `true`
- **AND** "b" is disabled and has value `false`
- **AND** "c" is enabled and exposes variant "blue"

#### Scenario: Missing snapshot value is distinct from disabled value
- **GIVEN** a snapshot contains disabled flag "known" and does not contain "missing"
- **WHEN** the value accessor is called for both keys
- **THEN** "known" returns `false`
- **AND** "missing" returns the platform's nullish missing value
- **AND** enablement for "missing" returns `false` unless a supported caller default overrides the missing case

#### Scenario: Existing snapshot does not change after another evaluation
- **GIVEN** a snapshot contains "checkout" with value `true`
- **AND** a later definition or remote response changes "checkout" to `false`
- **WHEN** "checkout" is read from the original snapshot
- **THEN** the original snapshot still returns `true`

### Requirement: Snapshot payload access

The snapshot SHALL retain available payloads paired with its evaluated flag records and SHALL expose a payload accessor. Reading a payload SHALL use only the snapshot and SHALL NOT issue a flag-evaluation request, mark the flag as accessed for `onlyAccessed()`, or emit `$feature_flag_called`.

Payload representation MAY follow platform convention: decoded JSON values, a host JSON document, a raw JSON string, or an additional typed decoding helper are all conformant. A missing flag, absent payload, or failed optional typed decode SHALL return the platform's documented empty/nullish result and SHALL NOT make value access unsafe.

#### Scenario: Payload read is a silent snapshot lookup
- **GIVEN** snapshot flag "checkout" has payload `{ "copy": "new" }`
- **WHEN** the payload accessor is called for "checkout"
- **THEN** it returns the stored payload in the platform's documented representation
- **AND** no feature-flag evaluation request is made
- **AND** no `$feature_flag_called` event is emitted
- **AND** "checkout" is not added to the snapshot's accessed-key set

### Requirement: Lazy feature-flag access tracking

Creating a `FeatureFlagEvaluations` snapshot SHALL NOT by itself emit `$feature_flag_called`, because evaluation does not prove that application code used a flag. Calling the snapshot's enablement or value accessor SHALL mark that key as accessed and SHALL route `$feature_flag_called` through the SDK's normal feature-flag-called dedupe tracker using the snapshot's canonical value and retained evaluation context.

Repeated enablement/value reads for the same identity, group context, key, and canonical value SHALL follow the existing tracker dedupe contract rather than emit one event per accessor call. On an original evaluation snapshot, reading a key absent from the evaluated set SHALL be treated as an attempted access and, when a distinct id is available, SHALL report the `flag_missing` error through the normal event metadata. Ancillary event metadata and the null/false response sentinel for a missing flag MAY vary by platform.

Filtered snapshots returned by `only(...)` / `onlyAccessed()` are intended to scope capture enrichment rather than support further branching. When a key was present in the original evaluation but excluded from a filtered snapshot, the SDK MAY suppress a missing-key event instead of reporting `flag_missing`; the excluded key is not evidence that the flag was absent from the evaluation.

#### Scenario: Evaluation emits no exposure until a flag is used
- **WHEN** `evaluateFlags(...)` returns a snapshot and no value accessor is called
- **THEN** no `$feature_flag_called` event is emitted
- **WHEN** `isEnabled("checkout")` is then called on the snapshot
- **THEN** one deduped `$feature_flag_called` attempt is made for "checkout" using the snapshot's value and evaluation context

#### Scenario: Boolean and value access share exposure dedupe
- **GIVEN** snapshot flag "checkout" has variant "blue"
- **WHEN** `isEnabled("checkout")`, `getFlag("checkout")`, and `isEnabled("checkout")` are called
- **THEN** exposure tracking uses canonical response "blue" for each access
- **AND** the normal feature-flag-called tracker deduplicates the repeated accesses

#### Scenario: Missing-key access on an original snapshot reports a missing flag
- **GIVEN** an original evaluation snapshot with a resolvable distinct id does not contain "typo-flag"
- **WHEN** the enablement or value accessor is called for "typo-flag"
- **THEN** the returned enablement/value follows the missing-key contract
- **AND** `$feature_flag_called` metadata identifies "typo-flag" as `flag_missing`

### Requirement: Reuse snapshot for capture enrichment

The server SDK SHALL allow a `FeatureFlagEvaluations` snapshot to be supplied to `capture(...)` (field name and call shape per platform convention). Capture SHALL attach the exact values retained in that snapshot as `$feature/<key>` properties without evaluating flags again. Enabled keys SHALL be represented in `$active_feature_flags`; an SDK MAY omit that property when no retained flag is enabled.

By default, capture SHALL attach all flags retained by the supplied snapshot. A caller MAY pass a filtered snapshot to attach a deliberate subset. When the SDK also retains a deprecated capture-time option that fetches feature flags, the supplied snapshot SHALL take precedence so capture does not discard the exact values on which the application branched or make another evaluation request.

#### Scenario: Capture uses the exact snapshot decision without reevaluation
- **GIVEN** a snapshot contains "checkout" with variant "blue" and "new-nav" with value `false`
- **AND** application code branches on that snapshot
- **AND** a later remote evaluation would return different values
- **WHEN** an event is captured with the snapshot
- **THEN** the event has `$feature/checkout` equal to "blue"
- **AND** the event has `$feature/new-nav` equal to `false`
- **AND** `$active_feature_flags` contains "checkout" and not "new-nav"
- **AND** capture makes no feature-flag evaluation request

### Requirement: In-memory snapshot filtering

The snapshot SHALL support an in-memory explicit-key filter (`only(keys)` or equivalent) and an accessed-key filter (`onlyAccessed()` or equivalent). These filters SHALL NOT perform evaluation or network I/O and SHALL return filtered snapshots suitable for capture.

The explicit-key filter SHALL retain only requested keys present in the source snapshot. Unknown requested keys SHALL be dropped and SHALL produce a diagnostic warning when the platform exposes SDK logging.

The accessed-key filter SHALL retain only present flags whose enablement or value accessor was called before filtering. Payload-only reads SHALL NOT count. Calling the accessed-key filter before any value/enablement access SHALL return an empty snapshot; this order-dependent behavior SHALL NOT silently fall back to all flags. A filtered snapshot's subsequent access bookkeeping SHALL NOT mutate the parent snapshot's accessed-key set.

Request-time key filtering and in-memory filtering are distinct: request-time filtering reduces evaluation/server work before snapshot creation, while these filters only reduce what an existing snapshot later exposes to capture.

#### Scenario: Accessed filter before branching is empty
- **GIVEN** a snapshot contains flags "a" and "b"
- **WHEN** `onlyAccessed()` is called before either flag's enablement or value is read
- **THEN** the returned filtered snapshot contains no flags

#### Scenario: Accessed filter contains only value-accessed flags
- **GIVEN** a snapshot contains flags "a", "b", and "c"
- **WHEN** enablement is read for "a"
- **AND** value is read for "c"
- **AND** only the payload is read for "b"
- **THEN** `onlyAccessed()` returns a snapshot containing "a" and "c"
- **AND** it does not contain "b"

#### Scenario: Explicit in-memory filter does not reduce completed evaluation work
- **GIVEN** a completed snapshot contains flags "a", "b", and "c"
- **WHEN** `only(["a", "missing"])` is called
- **THEN** the filtered snapshot contains only "a"
- **AND** "missing" is dropped with a diagnostic when logging is available
- **AND** no evaluation or network request occurs

### Requirement: Safe empty and partial snapshots

When neither an explicit nor request-context distinct id can be resolved, `evaluateFlags(...)` SHALL return an empty/no-op snapshot, SHALL NOT make a remote feature-flag evaluation request, and SHALL NOT emit `$feature_flag_called` when accessors are called on that snapshot. The SDK MAY additionally warn or return an idiomatic error alongside the snapshot.

A disabled SDK SHALL return an empty/no-op snapshot. If local or remote evaluation fails after one or more flag records were successfully resolved, the SDK SHALL retain those records in the returned snapshot; if no record was resolved, it SHALL return an empty snapshot. The host language MAY surface an idiomatic error alongside that partial or empty result. Accessing any returned snapshot SHALL remain safe. Local-only and remote failures SHALL NOT cause an accessor to initiate a new evaluation.

#### Scenario: Missing identity returns a no-op snapshot
- **GIVEN** no explicit distinct id is supplied
- **AND** request context has no distinct id
- **WHEN** `evaluateFlags(...)` is called
- **THEN** the returned snapshot is empty
- **AND** no remote feature-flag evaluation request is made
- **AND** reading a key from the snapshot emits no `$feature_flag_called` event

#### Scenario: Remote failure preserves local results
- **GIVEN** local evaluation resolves "local-flag"
- **AND** the remote fallback fails
- **WHEN** `evaluateFlags(...)` returns normally or alongside an idiomatic error
- **THEN** any returned snapshot retains "local-flag"
- **AND** reading that snapshot does not retry remote evaluation

