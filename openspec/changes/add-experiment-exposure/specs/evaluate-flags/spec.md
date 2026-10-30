## ADDED Requirements

### Requirement: Snapshot reads report experiment exposure

The snapshot SHALL retain, with each evaluated record, the evaluation details that `experiment-exposure` and the config version 2 attribution on `$feature_flag_called` need: the config version, the reason code, the rule ID, the rule type, the variant key, whether the record failed, and whether local evaluation produced it. Like the snapshot's values, these details SHALL NOT change after the snapshot is created.

A snapshot enablement or value read, or a typed read where the SDK has one, whose feature flag event decision is `true` SHALL apply the `experiment-exposure` rules to the details retained for that key, in the same step that reports `$feature_flag_called` under "Lazy feature-flag access tracking". The exposure therefore reports the assignment that the snapshot's evaluation produced, even when flag definitions or remote results changed after it. A read whose decision is `false` emits neither event, as "Snapshot feature flag event control" and `experiment-exposure` define.

Creating a snapshot, enumerating its keys, filtering it with `only(...)` or `onlyAccessed()`, reading a payload, and passing the snapshot to `capture(...)` SHALL NOT emit `$experiment_exposure`.

#### Scenario: Evaluation emits no experiment exposure until a flag is read
- **GIVEN** remote evaluation for distinct id "user-123" returns "checkout-flow" as a complete config version 2 experiment split with value true, rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
- **WHEN** `evaluateFlags("user-123")` is called and no accessor is called
- **THEN** no `$experiment_exposure` event is emitted
- **WHEN** `isEnabled("checkout-flow")` is then called on the snapshot
- **THEN** one `$feature_flag_called` and one `$experiment_exposure` event are emitted for "checkout-flow" with `$feature_flag_variant` "test"

#### Scenario: The exposure reports the snapshot's assignment
- **GIVEN** a snapshot for distinct id "user-123" retains "checkout-flow" as a split with rule id "3f6b1c2e-7a4d-4b8e-9c21-5d0e8f7a6b13" and variant key "test"
- **AND** a later definitions refresh would assign "user-123" variant key "control"
- **WHEN** `getFlag("checkout-flow")` is called on the original snapshot
- **THEN** the `$experiment_exposure` event has `$feature_flag_variant` "test"
- **AND** the read makes no feature-flag evaluation request

#### Scenario: Capture with a snapshot emits no exposure
- **GIVEN** a snapshot for distinct id "user-123" retains "checkout-flow" as a complete config version 2 experiment split with variant key "test"
- **AND** no accessor has been called on the snapshot
- **WHEN** an event is captured with the snapshot
- **THEN** the captured event has `$feature/checkout-flow` set from the snapshot
- **AND** no `$feature_flag_called` and no `$experiment_exposure` event is emitted
