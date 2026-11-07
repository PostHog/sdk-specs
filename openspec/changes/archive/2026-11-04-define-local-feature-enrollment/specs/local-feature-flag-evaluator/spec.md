## ADDED Requirements

### Requirement: Feature enrollment precedes holdouts and release conditions

For an active downloaded flag without experience continuity whose `filters.feature_enrollment` is the boolean `true`, the local evaluator SHALL check the person property `$feature_enrollment/<flag key>` before holdout membership, release-condition filters, rollout percentages, and ordinary variant assignment. Exactly the JSON boolean `true` and the JSON string `"true"` SHALL mean enrolled. Any other present JSON value, including `null`, SHALL mean opted out. The evaluator SHALL return the corresponding boolean immediately rather than continuing through targeting, subject to the group-context support rule below. An inactive flag SHALL resolve to `false` before checking enrollment. An active flag with experience continuity SHALL remain locally inconclusive regardless of whether the enrollment property is supplied.

When the enrollment marker is absent, null, or false, the evaluator SHALL retain ordinary holdout and release-condition behavior. Single-flag, bulk, and flag-dependency evaluation SHALL use the same enrollment semantics. SDKs consuming server-evaluated values do not need a separate local enrollment engine.

#### Scenario Outline: Enrolled people do not need a matching release condition (@server)
- **GIVEN** an active flag "beta-feature" has `feature_enrollment: true` and no matching release condition
- **WHEN** it is evaluated with person property `$feature_enrollment/beta-feature` set to <value>
- **THEN** the flag value should be true without remote evaluation

Examples:
| value  |
| true   |
| "true" |

#### Scenario Outline: Present non-enrolled values override matching targeting (@server)
- **GIVEN** an active flag "beta-feature" has `feature_enrollment: true` and a release condition matching everyone
- **WHEN** it is evaluated with person property `$feature_enrollment/beta-feature` set to <value>
- **THEN** the flag value should be false without remote evaluation

Examples:
| value   |
| false   |
| "false" |
| 1       |
| 0       |
| null    |
| "True"  |
| ""      |
| []      |
| {}      |

#### Scenario Outline: Enrollment takes precedence over a holdout (@server)
- **GIVEN** an active flag "beta-feature" has `feature_enrollment: true` and a 100 percent holdout
- **WHEN** it is evaluated with person property `$feature_enrollment/beta-feature` set to <value>
- **THEN** the flag value should be <value> rather than a holdout variant
- **AND** no remote evaluation should be required

Examples:
| value |
| true  |
| false |

#### Scenario Outline: Inactive enrollment flags remain disabled (@server)
- **GIVEN** an inactive flag "beta-feature" has `feature_enrollment: true`
- **WHEN** it is evaluated with person properties <properties>
- **THEN** the flag value should be false without remote evaluation

Examples:
| properties                                |
| {"$feature_enrollment/beta-feature":true} |
| {}                                        |

#### Scenario Outline: An inactive enrollment marker preserves ordinary targeting (@server)
- **GIVEN** an active flag "beta-feature" has enrollment marker <marker> and a release condition matching everyone
- **WHEN** it is evaluated without an enrollment property
- **THEN** the flag value should be true without remote evaluation

Examples:
| marker  |
| absent  |
| null    |
| false   |

#### Scenario Outline: Bulk and dependency evaluation use enrollment values (@server)
- **GIVEN** active flag "beta-feature" has `feature_enrollment: true`
- **AND** another active flag "dependent" is enabled only when "beta-feature" evaluates to true
- **WHEN** the flags are evaluated in one bulk pass with person property `$feature_enrollment/beta-feature` set to <value>
- **THEN** "beta-feature" and "dependent" should both resolve to <value> without remote evaluation

Examples:
| value |
| true  |
| false |

### Requirement: Unavailable enrollment context remains inconclusive

For an active flag without experience continuity, when `filters.feature_enrollment` is true and the enrollment property is absent from the caller's local person-property context, the evaluator SHALL report inconclusive rather than treating the person as opted out or continuing through holdouts and release conditions. Omitted caller properties do not establish absence from stored person properties. Existing remote fallback SHALL remain eligible; local-only evaluation SHALL make no remote request and SHALL preserve the public API's unresolved-result behavior. For a snapshot API exposing unresolved reasons, missing enrollment context SHALL contribute the `missing_context` cause, and inability to resolve a dependency on that enrollment flag SHALL contribute `unresolved_dependency`. Holdouts and release conditions skipped by the enrollment check SHALL NOT contribute unresolved causes. The existing unresolved-reason precedence SHALL apply only among applicable causes; it SHALL NOT require inspecting skipped targeting to find a higher-priority reason.

Enrollment SHALL always use person properties, including when a downloaded definition uses group aggregation. When the evaluator supports retaining person context for that definition, it SHALL evaluate enrollment before requiring a group key or group properties; a missing person enrollment property SHALL contribute `missing_context`. An evaluator whose implementation cannot retain person context for that group-aggregated definition SHALL report inconclusive with the `unsupported_definition` cause rather than interpreting group properties as person enrollment. Existing reason precedence and remote-fallback/local-only rules SHALL still apply. Group aggregation alone SHALL NOT make enrollment unsupported. This does not require accepting group-based flags through the early-access feature creation API.

#### Scenario: Missing enrollment context falls back despite matching targeting (@server)
- **GIVEN** an active flag "beta-feature" has `feature_enrollment: true` and a release condition matching everyone
- **AND** no enrollment property is supplied locally
- **AND** the flags service returns false for the person's stored enrollment
- **WHEN** the public flag getter evaluates "beta-feature" with remote fallback enabled
- **THEN** a remote evaluation request should be made
- **AND** the returned flag value should be false

#### Scenario: Local-only evaluation leaves missing enrollment and its dependency unresolved (@server)
- **GIVEN** an active flag "beta-feature" has `feature_enrollment: true` and a release condition matching everyone
- **AND** another active flag "dependent" requires "beta-feature" to evaluate to true
- **WHEN** a local-only snapshot is evaluated without the enrollment property
- **THEN** neither flag should have a resolved value and no remote evaluation request should be made
- **AND** their unresolved reasons should be `missing_context` and `unresolved_dependency` respectively

#### Scenario Outline: Experience continuity retains precedence over enrollment (@server)
- **GIVEN** an active flag "beta-feature" has `feature_enrollment: true` and experience continuity enabled
- **WHEN** a local-only snapshot is evaluated with person properties <properties>
- **THEN** the flag should remain unresolved with reason `experience_continuity`
- **AND** no remote evaluation request should be made

Examples:
| properties                                 |
| {}                                         |
| {"$feature_enrollment/beta-feature":true}  |
| {"$feature_enrollment/beta-feature":false} |

#### Scenario: Missing enrollment does not inspect unsupported release conditions (@server)
- **GIVEN** an active flag "beta-feature" has `feature_enrollment: true`, experience continuity disabled, and a static-cohort release condition the local evaluator cannot resolve
- **WHEN** a local-only snapshot is evaluated without the enrollment property
- **THEN** the flag should remain unresolved with reason `missing_context`, not `unsupported_definition`
- **AND** no remote evaluation request should be made

#### Scenario Outline: Known enrollment bypasses unsupported release conditions (@server)
- **GIVEN** an active flag "beta-feature" has `feature_enrollment: true`, experience continuity disabled, and a static-cohort release condition the local evaluator cannot resolve
- **WHEN** the flag is evaluated with person property `$feature_enrollment/beta-feature` set to <value>
- **THEN** the flag should resolve to <value> without remote evaluation

Examples:
| value |
| true  |
| false |

#### Scenario: Unsupported group enrollment reports the definition cause (@server)
- **GIVEN** an active group-aggregated flag "beta-feature" has `feature_enrollment: true` and experience continuity disabled
- **AND** this evaluator's implementation cannot retain person context for that group-aggregated definition
- **WHEN** a local-only snapshot is evaluated with person property `$feature_enrollment/beta-feature` set to true
- **THEN** the flag should remain unresolved with reason `unsupported_definition`
- **AND** no remote evaluation request should be made

#### Scenario: Supported group enrollment does not require group context (@server)
- **GIVEN** an active group-aggregated flag "beta-feature" has `feature_enrollment: true` and experience continuity disabled
- **AND** this evaluator supports retaining person context for that definition
- **WHEN** the flag is evaluated without a group key or group properties and with person property `$feature_enrollment/beta-feature` set to true
- **THEN** the flag should resolve to true without remote evaluation

#### Scenario: Supported group enrollment reports missing person context (@server)
- **GIVEN** an active group-aggregated flag "beta-feature" has `feature_enrollment: true` and experience continuity disabled
- **AND** this evaluator supports retaining person context for that definition
- **AND** the matching group's enrollment property is true
- **WHEN** a local-only snapshot is evaluated without the person enrollment property
- **THEN** the flag should remain unresolved with reason `missing_context`
- **AND** no remote evaluation request should be made

#### Scenario: Group enrollment cannot override a person's opt-out (@server)
- **GIVEN** a downloaded group-aggregated definition for "beta-feature" has `feature_enrollment: true`
- **AND** the person property `$feature_enrollment/beta-feature` is false while the matching group's property is true
- **AND** remote evaluation, if needed, returns false for the person
- **WHEN** the public flag getter evaluates the flag with both person and group context
- **THEN** the returned flag value should be false
