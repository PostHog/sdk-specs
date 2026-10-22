## MODIFIED Requirements

### Requirement: Point-in-time flag values and enablement

The snapshot SHALL retain a stable set of evaluated flag records. Later flag-definition refreshes, remote changes, cache updates, or separate evaluations SHALL NOT change values in an existing snapshot. The snapshot SHALL enumerate the keys it contains; key ordering is unspecified.

The snapshot SHALL retain each record's typed value (boolean, string, number, object or `null`), structured reason and metadata as defined by `typed-flag-values`, and SHALL provide these semantic projections, with naming and result wrappers adapted to the host language:

- enablement: enabled boolean flags and non-empty variants resolve to `true`; disabled flags resolve to `false`; missing flags resolve to `false` by default;
- value: enabled boolean flags resolve to `true`, disabled flags to `false`, multivariate flags to the variant string, and missing flags to the language's nullish sentinel;
- rich result: an SDK MAY return a structured flag object from its value accessor instead of a scalar when that object exposes the same enabled/variant semantics.

The enablement and value projections SHALL use the legacy rendering of the typed value defined by `typed-flag-values`: a string value is a variant, a number or object value is enabled and resolves to `true` (the value itself is available through the payload accessor and the typed number and object accessors), and a `null` value is disabled and resolves to `false`. These projections SHALL NOT return a number or object. The typed accessors in "Snapshot typed accessors" are the projection for typed values.

An SDK MAY let the caller supply a boolean default for missing enablement. When it does, the default SHALL apply only when the key has no record in the snapshot; a present record, including a `false` value and a `null` value rendered as `false`, SHALL win over the default. The typed boolean accessor differs on purpose: it returns the caller default for a `null` value and for a failed record, and returns a present `false` as is.

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

#### Scenario: Number and object values render as enabled
- **GIVEN** a snapshot contains "upload-limit" with the number value 25 and "checkout-config" with the object value `{ "steps": 3 }`
- **WHEN** enablement and value accessors are called for both keys
- **THEN** both are enabled and have value `true`
- **AND** the payload accessor returns 25 for "upload-limit" and `{ "steps": 3 }` for "checkout-config"

#### Scenario: A null value wins over the enablement default but not over the typed default
- **GIVEN** a snapshot contains "new-nav" with value `null` and reason code `no_rule_match`
- **WHEN** enablement is read for "new-nav" with caller default `true`
- **THEN** it returns `false`
- **WHEN** the boolean value accessor is called for "new-nav" with caller default `true`
- **THEN** it returns `true`

## ADDED Requirements

### Requirement: Snapshot typed accessors

The snapshot SHALL expose the typed value and details accessors defined by `typed-flag-values` and SHALL resolve them from the retained records only. A typed read SHALL NOT issue a flag-evaluation request or consult current definitions, caches or the remote endpoint.

Typed accessors are value accessors for access tracking. A typed read SHALL mark its key as accessed, so `onlyAccessed()` keeps that flag, and SHALL route `$feature_flag_called` through the feature-flag-called tracker exactly as `getFlag(...)` does for the same key (see `feature-flag-called-tracker`). This applies when the accessor returns the caller default because of a `null` value, a `false` value read as another type, or a type mismatch. A typed read of a key absent from an original evaluation snapshot SHALL return the caller default with `FLAG_NOT_FOUND` and SHALL report `flag_missing` like any other missing-key access. A typed read on an empty or no-op snapshot SHALL return the caller default with `FLAG_NOT_FOUND` and SHALL NOT emit `$feature_flag_called`.

#### Scenario: Typed read is a snapshot read that counts as access
- **GIVEN** remote evaluation for distinct id "user-123" returns "upload-limit" with the number value 25 and "banner-copy" with the string value "Hello"
- **WHEN** `evaluateFlags("user-123")` is called
- **AND** the number value accessor is called for "upload-limit" with caller default 10
- **THEN** it returns 25
- **AND** exactly one remote feature-flag evaluation request was made in total
- **AND** `onlyAccessed()` returns a snapshot containing "upload-limit" and not "banner-copy"

#### Scenario: Typed read of a missing key on an original snapshot
- **GIVEN** an original evaluation snapshot with a resolvable distinct id does not contain "typo-flag"
- **WHEN** the string details accessor is called for "typo-flag" with caller default "x"
- **THEN** the details value is "x" with error code `FLAG_NOT_FOUND`
- **AND** `$feature_flag_called` metadata identifies "typo-flag" as `flag_missing`

#### Scenario: Typed read on a no-op snapshot is silent
- **GIVEN** `evaluateFlags(...)` returned an empty snapshot because no distinct id could be resolved
- **WHEN** the boolean value accessor is called for "checkout" with caller default true
- **THEN** it returns true
- **AND** no `$feature_flag_called` event is emitted
