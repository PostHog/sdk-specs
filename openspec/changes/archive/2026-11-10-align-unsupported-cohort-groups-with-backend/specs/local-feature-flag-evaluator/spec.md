## MODIFIED Requirements

### Requirement: Specialized cohort matching preserves scope and inconclusive state

A criterion with property type `cohort` SHALL use `in` by default when its operator is omitted. `in` SHALL match a definitive referenced membership result; `not_in` SHALL negate only a definitive result. A static cohort with cached local membership is therefore conclusive. A static cohort definition without membership data, a missing dynamic definition, a dependency cycle, or unavailable required context SHALL be inconclusive and MUST NOT be represented as membership false merely to evaluate `not_in`.

Dynamic cohort groups SHALL recursively apply three-valued composition, except for the hard fallback required when an unsupported group type is reached. `OR` returns true when any child is true, false when every child is false, and inconclusive otherwise. `AND` and its legacy wire alias `property` return false when any child is false, true when every child is true, and inconclusive otherwise. An empty `OR` is false; an empty `AND` or `property` group is true.

A leaf's `negation` field SHALL invert only a definitive match/no-match result. It MUST NOT convert an inconclusive or invalid leaf into a match. Unsupported or malformed cohort criteria SHALL remain unresolved locally and MUST NOT throw into application code. An unsupported group type SHALL use the hard fallback described below rather than a composable inconclusive child result. The cohort-only `between` and `not_between` operators SHALL use the numeric-range semantics defined above.

Children SHALL be evaluated in definition order. A supported group SHALL short-circuit when a child decides its result. If evaluation reaches a child group with an unsupported type, such as `XOR`, the evaluator SHALL stop local evaluation immediately and require server evaluation. The failure SHALL propagate through enclosing groups without evaluating later siblings, even if one would otherwise decide the result. A decisive earlier sibling can finish the group before the unsupported group is reached. This hard fallback does not change three-valued composition for missing property context or permit negation to convert the failure into a match.

Implementations SHALL detect cohort cycles and bound recursion. A definition beyond an implementation's safe recursion bound MAY become inconclusive, but MUST NOT be silently truncated or crash application code.

#### Scenario Outline: Cohort membership operators compare definitive membership (@server)
- **GIVEN** a local condition references cohort `42` with operator <operator>
- **AND** cohort `42` has a definitive local membership result <membership>
- **WHEN** the condition is evaluated locally
- **THEN** the criterion match result should be <matches>

  | operator | membership | matches |
  | omitted | true | true |
  | `in` | false | false |
  | `not_in` | true | false |
  | `not_in` | false | true |

#### Scenario Outline: Unavailable membership remains inconclusive for both polarities (@server)
- **GIVEN** a local condition references cohort `42` with operator <operator>
- **AND** cohort membership is unavailable because <reason>
- **WHEN** the condition is evaluated locally
- **THEN** the criterion should be inconclusive
- **AND** remote evaluation should remain eligible

  | operator | reason |
  | `in` | the static cohort has no cached membership |
  | `not_in` | the static cohort has no cached membership |
  | `not_in` | the dynamic cohort definition is missing |
  | `not_in` | the cohort dependency graph contains a cycle |

#### Scenario Outline: Dynamic cohort groups use three-valued composition (@server)
- **GIVEN** a dynamic cohort group combines child results <children> with group type <group-type>
- **AND** any inconclusive child is missing a required person property locally
- **WHEN** the group is evaluated locally
- **THEN** the group result should be <result>

  | group-type | children | result |
  | `OR` | true and inconclusive | true |
  | `OR` | false and inconclusive | inconclusive |
  | `AND` | false and inconclusive | false |
  | `AND` | true and inconclusive | inconclusive |
  | `property` | true and true | true |
  | `OR` | no children | false |
  | `AND` | no children | true |

#### Scenario Outline: Reached unsupported cohort groups stop evaluation before later siblings (@server)
- **GIVEN** a supported dynamic cohort group of type <group-type> has children <children> in definition order
- **AND** the unsupported child is a nested group with type `XOR` and an empty `values` list
- **WHEN** the cohort is evaluated locally
- **THEN** the local result should be <result>
- **AND** requiring server evaluation should leave remote fallback eligible without throwing into application code

  | group-type | children | result |
  | `OR` | unsupported then true | requires server evaluation |
  | `AND` | unsupported then false | requires server evaluation |
  | `OR` | true then unsupported | true |
  | `AND` | false then unsupported | false |

#### Scenario: Negation does not turn an inconclusive cohort leaf into a match (@server)
- **GIVEN** a dynamic cohort contains a negated leaf whose required person property is unavailable locally
- **WHEN** a feature flag depending on that cohort is evaluated locally
- **THEN** the cohort criterion should be inconclusive
- **AND** the negation should not turn it into a match
- **AND** remote evaluation should remain eligible

#### Scenario Outline: Malformed cohort structures are inconclusive (@server)
- **GIVEN** a referenced dynamic cohort contains <malformation>
- **AND** the outer membership operator is `not_in`
- **WHEN** the cohort condition is evaluated locally
- **THEN** the cohort condition should be inconclusive
- **AND** `not_in` should not turn the failure into a match

  | malformation |
  | a known leaf type missing its required key |
  | unknown group type `XOR` |
