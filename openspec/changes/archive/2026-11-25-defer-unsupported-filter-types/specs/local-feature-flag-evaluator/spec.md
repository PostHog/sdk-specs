## ADDED Requirements

### Requirement: Unsupported property-filter types are inconclusive

The local evaluator SHALL handle a property filter by its `type` field:

| `type` | Local handling |
| --- | --- |
| `person` | Match against caller-supplied person properties. |
| `group` | Match against caller-supplied properties for the filter's group type. |
| `cohort` | Evaluate cohort membership, as the specialized cohort matching requirement defines. |
| `flag` | Evaluate the dependency, as the flag dependency filter requirement defines. |
| field omitted, JSON `null`, or an empty string | Match as a `person` filter, for older definitions that don't set it. |

Any other value, including `person_metadata` and a type the flags service adds after the SDK shipped, SHALL make the filter inconclusive with the `unsupported_definition` cause. The SDK SHALL NOT match such a filter against a caller-supplied person or group property with the same key. The flags service reads a `person_metadata` filter from the persons table, not from person properties, so a caller's `created_at` person property doesn't satisfy a first-seen filter on the server and SHALL NOT satisfy it locally.

The rule applies to flag condition filters and to dynamic-cohort leaves. An unsupported leaf SHALL follow the existing cohort composition rules: it is one inconclusive input to three-valued `AND`/`OR`, and neither leaf `negation` nor an outer `not_in` turns it into a match. Within a flag condition, another filter that is definitively false SHALL still make the condition a no-match.

The SDK SHALL check the filter type before it applies the known-absent table. A known-absent listing SHALL NOT resolve an unsupported filter, even when its key is listed. The unsupported filter SHALL affect only the flags that use it; other flags keep evaluating locally.

#### Scenario Outline: A person_metadata cohort leaf is inconclusive regardless of caller properties (@server)
- **GIVEN** local feature flag "first-seen" requires membership in a dynamic cohort with one leaf of type `person_metadata`, key `created_at`, operator `is_date_after`, and condition value "2025-01-01"
- **WHEN** local feature flag "first-seen" is evaluated <property-context>
- **THEN** local evaluation should be inconclusive for "first-seen"
- **AND** the unresolved reason should be `unsupported_definition`
- **AND** remote evaluation should remain eligible

  | property-context |
  | with person property `created_at` equal to "2026-06-01" |
  | with person property `created_at` equal to "2020-06-01" |
  | without person properties |
  | with person property key `created_at` listed as known absent |

#### Scenario Outline: A person filter on created_at still matches caller properties (@server)
- **GIVEN** local feature flag "created-person-prop" has a condition filter with <type-state> on key `created_at`, operator `is_date_after`, and condition value "2025-01-01"
- **WHEN** local feature flag "created-person-prop" is evaluated with person property `created_at` equal to "2026-06-01"
- **THEN** the local evaluation result should be true

  | type-state |
  | type `person` |
  | the `type` field omitted |
  | a JSON `null` type |
  | an empty-string type |

#### Scenario Outline: Negation does not turn an unsupported cohort leaf into a match (@server)
- **GIVEN** local feature flag "first-seen" requires membership in a dynamic cohort with one `person_metadata` leaf on key `created_at`
- **AND** <negation>
- **WHEN** local feature flag "first-seen" is evaluated with person property `created_at` equal to "2020-06-01"
- **THEN** local evaluation should be inconclusive for "first-seen"
- **AND** the negation should not turn it into a match

  | negation |
  | the leaf sets negation to true |
  | the flag's cohort operator is `not_in` |

#### Scenario: Another cohort leaf can still decide the group (@server)
- **GIVEN** local feature flag "first-seen-pro" requires membership in a dynamic cohort whose `AND` group has a `person_metadata` leaf on key `created_at` and a `person` leaf requiring `plan` to equal "pro"
- **WHEN** local feature flag "first-seen-pro" is evaluated with person property `plan` equal to "free"
- **THEN** the local evaluation result should be false
- **AND** the SDK should not require remote fallback

#### Scenario: An unrecognized filter type in a flag condition defers only that flag (@server)
- **GIVEN** local feature flag "future-type" has a condition filter of type "future_type" on key `plan` with operator `exact` and condition value "pro"
- **AND** local feature flag definitions include a flag "beta-ui" rolled out to distinct id "user-123"
- **WHEN** local feature flag "future-type" is evaluated for distinct id "user-123" with person property `plan` equal to "pro"
- **AND** local feature flag "beta-ui" is evaluated for distinct id "user-123"
- **THEN** local evaluation should be inconclusive for "future-type"
- **AND** the local evaluation result for "beta-ui" should be true

#### Scenario: A definitively false filter decides a condition with an unsupported filter (@server)
- **GIVEN** local feature flag "future-type-plan" has one condition with a filter of type "future_type" on key `region` and a `person` filter requiring `plan` to equal "pro"
- **WHEN** local feature flag "future-type-plan" is evaluated with person property `plan` equal to "free"
- **THEN** the local evaluation result should be false
- **AND** the SDK should not require remote fallback
