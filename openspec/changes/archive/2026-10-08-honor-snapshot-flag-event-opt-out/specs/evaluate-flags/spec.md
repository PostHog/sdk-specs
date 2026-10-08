## ADDED Requirements

### Requirement: Snapshot feature flag event control

The snapshot's enablement and value accessors, including a value accessor that returns a rich result object, SHALL accept an optional per-read feature flag event option. The option SHALL be named `sendFeatureFlagEvents`, adapted to platform casing (for example `send_feature_flag_events`), and passed in the platform's idiomatic optional-argument form. It has the meaning of the per-call option on the server SDK's single-flag getters: `true` sends `$feature_flag_called` for the read and `false` suppresses it. The payload accessor, key enumeration and in-memory filters SHALL NOT take the option, because they never report `$feature_flag_called`.

For each enablement or value read, the SDK SHALL decide whether to send `$feature_flag_called` in this order, which is the order the single-flag getters use:

1. the per-read option, when the caller supplies it;
2. otherwise the SDK's client-level feature flag event default, when the SDK has one;
3. otherwise `true`.

`evaluateFlags(...)` SHALL NOT take a per-snapshot feature flag event option. One snapshot serves reads that need exposure events and reads that do not, so the choice belongs to each read.

When the decision is `true`, the read follows the lazy access tracking rules unchanged. When the decision is `false`, the read:

- SHALL NOT emit `$feature_flag_called`, including the `flag_missing` event for a key absent from an original snapshot;
- SHALL NOT consult or update the feature-flag-called dedupe tracker, so a later read of the same key whose decision is `true`, on the snapshot or through a single-flag getter, still emits;
- SHALL still mark the key as accessed for `onlyAccessed()`, because access scopes capture enrichment and is separate from exposure reporting.

The option SHALL NOT change the returned value, cause evaluation or network I/O, or change the records the snapshot retains.

#### Scenario: Client-level default off silences snapshot reads (@flag_event_default_capable)
- **GIVEN** the SDK's client-level feature flag event default is disabled
- **AND** remote feature flag evaluation for distinct id "user-123" returns:
  | key      | value |
  | beta-ui  | true  |
  | checkout | blue  |
- **WHEN** evaluate flags is called for distinct id "user-123"
- **AND** snapshot enablement is read for "beta-ui"
- **AND** snapshot value is read for "checkout"
- **THEN** the returned enabled value for "beta-ui" should be true
- **AND** the returned snapshot value for "checkout" should be "blue"
- **AND** no event named "$feature_flag_called" should be enqueued

#### Scenario: Per-read option overrides a disabled client-level default (@flag_event_default_capable)
- **GIVEN** the SDK's client-level feature flag event default is disabled
- **AND** remote feature flag evaluation for distinct id "user-123" returns:
  | key      | value |
  | beta-ui  | true  |
  | checkout | blue  |
- **WHEN** evaluate flags is called for distinct id "user-123"
- **AND** snapshot enablement is read for "beta-ui" with the feature flag event option enabled
- **AND** snapshot value is read for "checkout"
- **THEN** a "$feature_flag_called" event should be enqueued for flag "beta-ui" with value "true"
- **AND** no "$feature_flag_called" event should be enqueued for flag "checkout"

#### Scenario: Per-read option silences one read on a default-on client
- **GIVEN** remote feature flag evaluation for distinct id "user-123" returns:
  | key      | value |
  | beta-ui  | true  |
  | checkout | blue  |
- **WHEN** evaluate flags is called for distinct id "user-123"
- **AND** snapshot enablement is read for "beta-ui" with the feature flag event option disabled
- **AND** snapshot value is read for "checkout"
- **THEN** the returned enabled value for "beta-ui" should be true
- **AND** no "$feature_flag_called" event should be enqueued for flag "beta-ui"
- **AND** a "$feature_flag_called" event should be enqueued for flag "checkout" with value "blue"

#### Scenario: Suppressed read leaves exposure dedupe untouched
- **GIVEN** remote feature flag evaluation for distinct id "user-123" returns:
  | key     | value |
  | beta-ui | true  |
- **WHEN** evaluate flags is called for distinct id "user-123"
- **AND** snapshot enablement is read for "beta-ui" with the feature flag event option disabled
- **THEN** no event named "$feature_flag_called" should be enqueued
- **WHEN** snapshot value is read for "beta-ui"
- **THEN** a "$feature_flag_called" event should be enqueued for flag "beta-ui" with value "true"
- **WHEN** snapshot enablement is read again for "beta-ui"
- **THEN** only one deduped "$feature_flag_called" event should be enqueued for flag "beta-ui" with value "true"

#### Scenario: Suppressed reads still count for only accessed
- **GIVEN** remote feature flag evaluation for distinct id "user-123" returns:
  | key      | value |
  | beta-ui  | true  |
  | checkout | blue  |
  | search   | false |
- **WHEN** evaluate flags is called for distinct id "user-123"
- **AND** snapshot enablement is read for "beta-ui" with the feature flag event option disabled
- **AND** snapshot value is read for "search" with the feature flag event option disabled
- **AND** snapshot only accessed is called
- **THEN** the filtered snapshot should contain flags:
  | key     | value |
  | beta-ui | true  |
  | search  | false |
- **AND** the filtered snapshot should not contain "checkout"
- **AND** no event named "$feature_flag_called" should be enqueued

#### Scenario: Missing-key read with the option disabled reports no missing flag
- **GIVEN** remote feature flag evaluation for distinct id "user-123" returns:
  | key     | value |
  | beta-ui | true  |
- **WHEN** evaluate flags is called for distinct id "user-123"
- **AND** snapshot enablement is read for "missing-flag" with the feature flag event option disabled
- **AND** snapshot value is read for "missing-flag" with the feature flag event option disabled
- **THEN** the returned enabled value for "missing-flag" should be false
- **AND** the returned snapshot value for "missing-flag" should be absent
- **AND** no event named "$feature_flag_called" should be enqueued

## MODIFIED Requirements

### Requirement: Server-side snapshot evaluation API

A server SDK SHALL expose a platform-idiomatic `evaluateFlags` / `evaluate_flags` operation that evaluates feature flags for one resolved identity and evaluation context and returns a non-null `FeatureFlagEvaluations` snapshot (name and async/error wrapper per platform convention).

The snapshot is a point-in-time evaluation result, not a renamed boolean check. Calling `evaluateFlags(...)` performs the evaluation; calling `snapshot.isEnabled(key)`, `snapshot.getFlag(key)`, or an equivalent accessor reads the already-created snapshot and SHALL NOT evaluate the flag again or perform network I/O. One snapshot SHALL support any number of flag branches for the same evaluation context.

This capability applies to server SDKs. Client-side `isFeatureEnabled(...)` methods that read ambient cached flag state remain governed by the `is-feature-enabled` capability and are not replaced by this server-request snapshot API.

For server SDKs, the snapshot API supersedes these older call patterns (names vary by platform):

| Older pattern | Snapshot replacement |
| --- | --- |
| `isFeatureEnabled(...)` / `feature_enabled(...)` / `is_feature_enabled(...)` | `evaluateFlags(...).isEnabled(key)` |
| `getFeatureFlag(...)` / `get_feature_flag(...)` | `evaluateFlags(...).getFlag(key)` |
| `getFeatureFlag(key, id, { sendFeatureFlagEvents: x })` and the same per-call option on the other single-flag getters | `evaluateFlags(id).getFlag(key, { sendFeatureFlagEvents: x })`; the option moves to the snapshot read |
| `getFeatureFlagPayload(...)` / `get_feature_flag_payload(...)` | `evaluateFlags(...).getFlagPayload(key)` (a silent payload lookup) |
| `getFeatureFlagResult(...)` / `get_feature_flag_result(...)` | read the value and payload from the same snapshot (or use the platform's rich snapshot result) |
| `getAllFlags(...)` / `get_all_flags(...)` | enumerate snapshot keys and read their values; each value read is tracked as access |
| `getAllFlagsAndPayloads(...)` / `get_all_flags_and_payloads(...)` | enumerate snapshot keys and read values plus payloads; value reads are tracked and payload-only reads are silent |
| `capture(..., sendFeatureFlags: true)` / `send_feature_flags` and equivalents | evaluate once, then pass the snapshot to `capture(..., flags: snapshot)` |

This is a functional migration map. It preserves the caller's control over exposure events, but not every other legacy side effect. A per-call `sendFeatureFlagEvents` value moves to the matching snapshot read, as the snapshot feature flag event control defines, so a migrated call sends the same `$feature_flag_called` events. Snapshot `isEnabled(...)` / `getFlag(...)` calls otherwise report access through `$feature_flag_called`, while key enumeration and payload-only reads are silent. Consequently, folding a data-only bulk map into per-key `getFlag(...)` reads deliberately reports each value used, and migrating Go's historically event-emitting payload getter to snapshot `getFlagPayload(...)` deliberately makes payload-only access silent. Callers that require a legacy data-only bulk shape MAY continue using a retained compatibility method.

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

### Requirement: Lazy feature-flag access tracking

Creating a `FeatureFlagEvaluations` snapshot SHALL NOT by itself emit `$feature_flag_called`, because evaluation does not prove that application code used a flag. Calling the snapshot's enablement or value accessor SHALL mark that key as accessed. Unless the read's feature flag event decision is `false`, it SHALL also route `$feature_flag_called` through the SDK's normal feature-flag-called dedupe tracker using the snapshot's canonical value and retained evaluation context. The snapshot feature flag event control defines that decision and what a read does when it is `false`.

Repeated enablement/value reads for the same identity, group context, key, and canonical value SHALL follow the existing tracker dedupe contract rather than emit one event per accessor call. On an original evaluation snapshot, reading a key absent from the evaluated set SHALL be treated as an attempted access and, when a distinct id is available and the read's feature flag event decision is `true`, SHALL report the `flag_missing` error through the normal event metadata. Ancillary event metadata and the null/false response sentinel for a missing flag MAY vary by platform.

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
