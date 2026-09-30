## ADDED Requirements

### Requirement: Snapshot unresolved flag reporting

A server SDK that loads local flag definitions MAY expose the unresolved flags of a snapshot. It lets a caller detect a flag that exists but has no value, which is otherwise indistinguishable from a flag that does not exist. An SDK that exposes unresolved flags SHALL follow the rules below.

A flag is unresolved when it has a loaded local definition, is inside the requested key scope, local evaluation for it was inconclusive, and the snapshot holds no value for it. When the call is unscoped, every loaded definition is in scope. A definition outside the requested scope that the evaluator inspects only to resolve a dependency is not in scope.

A flag that a remote `/flags` (or equivalent) fallback resolved is not unresolved. A flag that has no value because the fallback failed or did not return it is unresolved. A key with no loaded local definition is never unresolved; it remains a missing flag. An inactive flag resolves to `false` locally and is never unresolved.

The snapshot SHALL expose each unresolved key with a reason (member name and shape per platform convention). The reason SHALL be one of the values below, chosen by what the caller can do about it. The reason describes the flag's own definition and the call that evaluated it, not a dependency's.

- `experience_continuity`: the flag's definition has experience continuity enabled. Local evaluation never resolves it; the fix is to change the flag.
- `unsupported_definition`: the flag's definition uses something the local evaluator does not support, such as a static cohort, an unrecognized operator, a malformed value, or a dependency with no loaded definition. The fix is to change the flag or upgrade the SDK.
- `missing_context`: the call did not supply a property, group key, group property or device id the flag needs, or supplied it in a form the evaluator cannot use. The fix is to pass it.
- `unresolved_dependency`: a flag the definition depends on has a loaded definition but was unresolved. The dependency's own entry carries its reason when the dependency is in the requested scope.

When more than one cause applies to a flag, the SDK SHALL report the reason of the first cause it found during evaluation. An SDK SHALL NOT report a reason this spec does not define. A new cause lands in this spec before an SDK reports it.

An SDK that evaluates flags locally SHOULD log a diagnostic warning, when the platform exposes SDK logging, when loaded definitions include a flag that local evaluation can never resolve, such as one with reason `experience_continuity`. The warning SHALL name the flag and the reason. The SDK SHALL NOT repeat it for the same flag until that flag's definition changes. The warning helps a developer notice the flag early; it does not replace the per-snapshot reporting, which also covers call-side causes.

Unresolved flags SHALL stay absent from the snapshot's flags. Exposing them SHALL NOT change the snapshot's key list, the values returned by the enablement, value and payload accessors, or the flags attached by capture enrichment.

Reading the unresolved flags SHALL use only the snapshot and SHALL NOT issue a flag-evaluation request, mark any flag as accessed for `onlyAccessed()`, or emit `$feature_flag_called`.

Filtered snapshots returned by `only(...)` / `onlyAccessed()` scope capture enrichment and SHALL NOT carry unresolved entries. The in-memory filters SHALL treat an unresolved key as any other key absent from the source snapshot. The original snapshot is the surface for inspecting unresolved flags.

#### Scenario: Local-only evaluation reports an experience continuity flag as unresolved (@unresolved_flags_capable)
- **GIVEN** local feature flag definitions resolve "beta-ui" for distinct id "user-123" as true
- **AND** the local feature flag definition for "checkout" has experience continuity enabled
- **WHEN** evaluate flags is called for distinct id "user-123" with local-only evaluation enabled
- **THEN** the snapshot should contain "beta-ui" with value true
- **AND** the snapshot should not contain "checkout"
- **AND** the snapshot unresolved flags should contain "checkout" with reason "experience_continuity"
- **AND** no remote feature flag evaluation request should have been sent
- **AND** no event named "$feature_flag_called" should be enqueued
- **AND** snapshot only accessed should return no flags

#### Scenario: Loading a definition that local evaluation never resolves logs one warning (@unresolved_flags_capable)
- **GIVEN** SDK logging is enabled
- **AND** the local feature flag definition for "checkout" has experience continuity enabled
- **WHEN** local feature flag definitions are refreshed successfully twice without changes
- **THEN** exactly one warning naming "checkout" and reason "experience_continuity" should be logged
- **AND** no remote feature flag evaluation request should have been sent

#### Scenario: Other inconclusive causes are reported as unresolved (@unresolved_flags_capable)
- **GIVEN** local feature flag definitions include a flag "checkout" matching person property "plan" with operator "exact" and value "pro"
- **AND** the local feature flag definition for "checkout" has experience continuity disabled
- **WHEN** evaluate flags is called for distinct id "user-123" without person property "plan" and with local-only evaluation enabled
- **THEN** the snapshot should not contain "checkout"
- **AND** the snapshot unresolved flags should contain "checkout" with reason "missing_context"

#### Scenario: A flag resolved by remote fallback is not unresolved (@unresolved_flags_capable)
- **GIVEN** the local feature flag definition for "checkout" has experience continuity enabled
- **AND** remote feature flag evaluation for distinct id "user-123" returns:
  | key      | value |
  | checkout | true  |
- **WHEN** evaluate flags is called for distinct id "user-123"
- **THEN** the snapshot should contain "checkout" with value true
- **AND** the snapshot unresolved flags should be empty

#### Scenario: A failed remote fallback leaves the flag unresolved (@unresolved_flags_capable)
- **GIVEN** the local feature flag definition for "checkout" has experience continuity enabled
- **AND** the next remote feature flag evaluation request fails
- **WHEN** evaluate flags is called for distinct id "user-123"
- **THEN** the snapshot should not contain "checkout"
- **AND** the snapshot unresolved flags should contain "checkout" with reason "experience_continuity"

#### Scenario: A key without a local definition is missing, not unresolved (@unresolved_flags_capable)
- **GIVEN** local feature flag definitions resolve "beta-ui" for distinct id "user-123" as true
- **AND** no local feature flag definition is loaded for "typo-flag"
- **WHEN** evaluate flags is called for distinct id "user-123" with local-only evaluation enabled
- **AND** snapshot enablement is read for "typo-flag"
- **THEN** the snapshot unresolved flags should be empty
- **AND** the "$feature_flag_called" event for flag "typo-flag" should report error "flag_missing"

#### Scenario: A flag outside the requested keys is not unresolved (@unresolved_flags_capable)
- **GIVEN** local feature flag definitions resolve "beta-ui" for distinct id "user-123" as true
- **AND** the local feature flag definition for "checkout" has experience continuity enabled
- **WHEN** evaluate flags is called for distinct id "user-123" with flag keys:
  | key     |
  | beta-ui |
- **THEN** the snapshot should contain "beta-ui" with value true
- **AND** the snapshot unresolved flags should be empty
- **AND** no remote feature flag evaluation request should have been sent

#### Scenario: An inactive flag is resolved as false, not unresolved (@unresolved_flags_capable)
- **GIVEN** the local feature flag definition for "checkout" has experience continuity enabled
- **AND** the local feature flag definition for "checkout" is inactive
- **WHEN** evaluate flags is called for distinct id "user-123" with local-only evaluation enabled
- **THEN** the snapshot should contain "checkout" with value false
- **AND** the snapshot unresolved flags should be empty

## MODIFIED Requirements

### Requirement: Lazy feature-flag access tracking

Creating a `FeatureFlagEvaluations` snapshot SHALL NOT by itself emit `$feature_flag_called`, because evaluation does not prove that application code used a flag. Calling the snapshot's enablement or value accessor SHALL mark that key as accessed and SHALL route `$feature_flag_called` through the SDK's normal feature-flag-called dedupe tracker using the snapshot's canonical value and retained evaluation context.

Repeated enablement/value reads for the same identity, group context, key, and canonical value SHALL follow the existing tracker dedupe contract rather than emit one event per accessor call. On an original evaluation snapshot, reading a key absent from the evaluated set SHALL be treated as an attempted access and, when a distinct id is available, SHALL report the `flag_missing` error through the normal event metadata. Ancillary event metadata and the null/false response sentinel for a missing flag MAY vary by platform.

When the key read on an original evaluation snapshot is absent from the snapshot's flags, has a loaded local definition, and local evaluation for it was inconclusive, an SDK that evaluates flags locally SHOULD report the `local_evaluation_inconclusive` error in place of the `flag_missing` error, whether or not it exposes unresolved flags; an SDK that exposes unresolved flags SHALL. Any other error reported for the same read, such as a response-level error, is unchanged. The returned enablement/value still follows the missing-key contract.

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

#### Scenario: Reading a flag the remote fallback resolved reports no inconclusive error (@unresolved_flags_capable)
- **GIVEN** the local feature flag definition for "checkout" has experience continuity enabled
- **AND** remote feature flag evaluation for distinct id "user-123" returns:
  | key      | value |
  | checkout | true  |
- **WHEN** evaluate flags is called for distinct id "user-123"
- **AND** snapshot enablement is read for "checkout"
- **THEN** the returned enabled value for "checkout" should be true
- **AND** the "$feature_flag_called" event for flag "checkout" should not report error "local_evaluation_inconclusive"
- **AND** the "$feature_flag_called" event for flag "checkout" should not report error "flag_missing"

#### Scenario: Reading an unresolved flag reports an inconclusive local evaluation (@unresolved_flags_capable)
- **GIVEN** the local feature flag definition for "checkout" has experience continuity enabled
- **WHEN** evaluate flags is called for distinct id "user-123" with local-only evaluation enabled
- **AND** snapshot enablement is read for "checkout"
- **THEN** the returned enabled value for "checkout" should be false
- **AND** the "$feature_flag_called" event for flag "checkout" should report error "local_evaluation_inconclusive"
- **AND** the "$feature_flag_called" event for flag "checkout" should not report error "flag_missing"
