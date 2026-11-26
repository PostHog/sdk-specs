## MODIFIED Requirements

### Requirement: Snapshot unresolved flag reporting

A server SDK that loads local flag definitions MAY expose the unresolved flags of a snapshot. It lets a caller detect a flag that exists but has no value, which is otherwise indistinguishable from a flag that does not exist. An SDK that exposes unresolved flags SHALL follow the rules below.

A flag is unresolved when it has a loaded local definition, is inside the requested key scope, local evaluation for it was inconclusive, and the snapshot holds no value for it. When the call is unscoped, every loaded definition is in scope. A definition outside the requested scope that the evaluator inspects only to resolve a dependency is not in scope.

A flag that a remote `/flags` (or equivalent) fallback resolved is not unresolved. A flag that has no value because the fallback failed or did not return it is unresolved. A key with no loaded local definition is never unresolved; it remains a missing flag. An inactive flag resolves to `false` locally and is never unresolved.

The snapshot SHALL expose each unresolved key with a reason (member name and shape per platform convention). The reason SHALL be one of the values below, chosen by what the caller can do about it. The reason describes the flag's own definition and the call that evaluated it, not a dependency's.

- `experience_continuity`: the flag's definition has experience continuity enabled. Local evaluation never resolves it; the fix is to change the flag.
- `unsupported_definition`: the flag's definition uses something the local evaluator does not support, such as a static cohort, an unrecognized operator, a malformed value, a dependency with no loaded definition, or a circular dependency. The fix is to change the flag or upgrade the SDK.
- `missing_context`: the call did not supply a property, group property or device id the flag needs, or supplied it in a form the evaluator cannot use. The fix is to pass it. A missing or unusable group key is a `missing_context` cause only for a flag whose holdout needs it, as the local evaluator spec defines. Otherwise a condition that needs a missing or unusable group key does not match, and the flag is not unresolved for that reason.
- `unresolved_dependency`: a flag the definition depends on has a loaded definition but was unresolved. The dependency's own entry carries its reason when the dependency is in the requested scope.

When more than one cause applies to a flag, the SDK SHALL report the first applicable reason in this order: `experience_continuity`, `unsupported_definition`, `unresolved_dependency`, `missing_context`. An SDK SHALL NOT report a reason this spec does not define. A new cause lands in this spec before an SDK reports it.

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
- **WHEN** snapshot only is called with flag keys "beta-ui" and "checkout"
- **THEN** the filtered snapshot unresolved flags should be empty

#### Scenario Outline: Each inconclusive cause reports its unresolved reason (@unresolved_flags_capable)
- **GIVEN** <definition>
- **AND** the local feature flag definition for "checkout" has experience continuity disabled
- **WHEN** evaluate flags is called for distinct id "user-123" <call> and with local-only evaluation enabled
- **THEN** the snapshot should not contain "checkout"
- **AND** the snapshot unresolved flags should contain "checkout" with reason "<reason>"

  | definition | call | reason |
  | local feature flag definitions include a flag "checkout" matching person property "plan" with operator "exact" and value "pro" | without person property "plan" | missing_context |
  | local feature flag definitions include a device-bucketed flag "checkout" with only person-aggregated conditions | without a device id | missing_context |
  | local feature flag definitions include a flag "checkout" matching person property "plan" with an operator this SDK version does not recognize | with person property "plan" equal to "enterprise" | unsupported_definition |
  | local feature flag definitions include a flag "checkout" matching a static cohort | without person properties | unsupported_definition |
  | local feature flag definitions include a flag "checkout" matching a static cohort and person property "plan" with operator "exact" and value "pro" | without person property "plan" | unsupported_definition |

#### Scenario: A flag blocked by an unresolved dependency reports the dependency (@unresolved_flags_capable)
- **GIVEN** the local feature flag definition for "checkout" has experience continuity enabled
- **AND** local feature flag definitions include a flag "beta-ui" that depends on "checkout" equaling true
- **WHEN** evaluate flags is called for distinct id "user-123" with flag key "beta-ui" and local-only evaluation enabled
- **THEN** the snapshot should not contain "beta-ui"
- **AND** the snapshot unresolved flags should contain "beta-ui" with reason "unresolved_dependency"
- **AND** the snapshot unresolved flags should not contain "checkout"

#### Scenario: A flag that depends on a flag with no loaded definition reports an unsupported definition (@unresolved_flags_capable)
- **GIVEN** no local feature flag definition is loaded for "checkout"
- **AND** local feature flag definitions include a flag "beta-ui" that depends on "checkout" equaling true
- **WHEN** evaluate flags is called for distinct id "user-123" with flag key "beta-ui" and local-only evaluation enabled
- **THEN** the snapshot should not contain "beta-ui"
- **AND** the snapshot unresolved flags should contain "beta-ui" with reason "unsupported_definition"
- **AND** the snapshot unresolved flags should not contain "checkout"

#### Scenario: A flag resolved by remote fallback is not unresolved (@unresolved_flags_capable)
- **GIVEN** the local feature flag definition for "checkout" has experience continuity enabled
- **AND** remote feature flag evaluation for distinct id "user-123" returns:
  | key      | value |
  | checkout | true  |
- **WHEN** evaluate flags is called for distinct id "user-123"
- **THEN** the snapshot should contain "checkout" with value true
- **AND** the snapshot unresolved flags should be empty

#### Scenario Outline: A remote fallback that does not resolve the flag leaves it unresolved (@unresolved_flags_capable)
- **GIVEN** the local feature flag definition for "checkout" has experience continuity enabled
- **AND** <fallback outcome>
- **WHEN** evaluate flags is called for distinct id "user-123"
- **THEN** the snapshot should not contain "checkout"
- **AND** the snapshot unresolved flags should contain "checkout" with reason "experience_continuity"
- **WHEN** snapshot enablement is read for "checkout"
- **THEN** the "$feature_flag_called" event for flag "checkout" should report error "local_evaluation_inconclusive"
- **AND** the "$feature_flag_called" event for flag "checkout" should not report error "flag_missing"

  | fallback outcome |
  | the next remote feature flag evaluation request fails |
  | remote feature flag evaluation for distinct id "user-123" returns no flags |

#### Scenario: A key without a local definition is missing, not unresolved (@unresolved_flags_capable)
- **GIVEN** local feature flag definitions resolve "beta-ui" for distinct id "user-123" as true
- **AND** no local feature flag definition is loaded for "typo-flag"
- **AND** remote feature flag evaluation for distinct id "user-123" returns no flags
- **WHEN** evaluate flags is called for distinct id "user-123" with flag keys:
  | key       |
  | beta-ui   |
  | typo-flag |
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
