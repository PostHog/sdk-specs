## MODIFIED Requirements

### Requirement: Nested exception relationship source

For a nested exception, `mechanism.source` identifies the runtime relationship through which that entry was reached from its parent. The canonical relationships are `cause`, `context`, `unwrap`, `member`, `suppressed`, and `inner`. A first-party SDK SHALL use the canonical value when its runtime relationship has that meaning. It MAY preserve another stable, non-empty platform relationship only when none of the canonical values applies, and SHALL omit `source` when the relationship is unknown.

`mechanism.source` SHALL NOT identify a framework or capture integration and SHALL NOT contain a source-file path. The outermost exception SHALL omit `mechanism.source`, because it has no parent in the event. A producer MUST NOT label every nested relationship `cause`: aggregate members, suppressed exceptions, implicit context, and multi-error unwrapping retain their distinct relationship.

`$exception_list` is a flattened depth-first, parent-before-child representation of a conceptual exception tree. The outermost exception SHALL have `mechanism.exception_id` equal to integer `0`. Every subsequent entry SHALL have a unique non-negative integer `mechanism.exception_id`, an integer `mechanism.parent_id` referring to an earlier entry, `mechanism.type` equal to `chained`, and `mechanism.source` describing the parent edge. Siblings SHALL retain runtime order when the runtime defines one; otherwise the producer SHALL use a deterministic order based on the runtime's stable iteration representation. Linear chains follow the same representation. Producers SHALL detect cycles and SHALL serialize at most 50 entries. Subject to the aggregate member inspection budget below, truncation SHALL retain the outermost entry and the first 49 nested entries in canonical depth-first order.

Producers SHALL inspect at most 1,000 aggregate members per captured event, using one budget shared across all nested aggregate collections. Each attempted member read SHALL consume one inspection before the member is read, including unreadable members and references skipped as duplicates or cycles. Cause traversal SHALL NOT consume member inspections. Once the budget is exhausted, producers SHALL stop reading aggregate members, including members of later or nested collections. They SHALL finish processing the already-inspected member and its cause chain within the 50-entry output limit. This inspection budget MAY truncate aggregate traversal before 50 entries are emitted. The output limit SHALL still stop traversal earlier when 50 entries have been retained.

#### Scenario: Wrapped cause records its relationship (@both)
- **GIVEN** an outer exception wraps another exception as its cause
- **WHEN** the SDK serializes both exceptions
- **THEN** the outer exception should omit `mechanism.source`
- **AND** the nested exception should have `mechanism.type` equal to `chained`
- **AND** the nested exception should have `mechanism.source` equal to `cause`

#### Scenario: Aggregate member is not mislabeled as a cause (@both)
- **GIVEN** an aggregate exception contains two member exceptions in runtime order
- **WHEN** the SDK serializes the aggregate and members
- **THEN** the aggregate should have `mechanism.exception_id` equal to `0`
- **AND** both members should have `mechanism.parent_id` equal to `0`
- **AND** both members should have `mechanism.type` equal to `chained`
- **AND** both members should have `mechanism.source` equal to `member`
- **AND** the members should retain runtime order

#### Scenario: Nested cause beneath an aggregate member retains its parent (@both)
- **GIVEN** the second member of an aggregate wraps a cause
- **WHEN** the SDK serializes the exception tree
- **THEN** the cause's `mechanism.parent_id` should equal the second member's `mechanism.exception_id`
- **AND** the cause should have `mechanism.type` equal to `chained`
- **AND** the cause should have `mechanism.source` equal to `cause`

#### Scenario: Cycles and oversized trees are bounded deterministically (@both)
- **GIVEN** an exception graph contains a cycle or more than 50 reachable entries
- **WHEN** the SDK serializes the exception tree
- **THEN** no exception object should be serialized more than once
- **AND** `$exception_list` should contain at most 50 entries
- **AND** retained entries should be the earliest entries in canonical depth-first order reached within the aggregate member inspection budget

#### Scenario: Duplicate members consume the inspection budget (@both)
- **GIVEN** an aggregate contains 1,000 references to itself followed by a distinct exception
- **WHEN** the SDK serializes the aggregate
- **THEN** only the outermost aggregate should be emitted
- **AND** the SDK should not read the 1,001st member

#### Scenario: Nested aggregates share the inspection budget (@both)
- **GIVEN** an outer aggregate contains an inner aggregate followed by a distinct sibling
- **AND** the inner aggregate contains 999 references to itself followed by another distinct exception
- **WHEN** the SDK serializes the aggregate tree
- **THEN** only the outer and inner aggregates should be emitted
- **AND** the first outer member and the 999 inner members should exhaust the shared budget
- **AND** neither later distinct exception should be read

#### Scenario: Last inspected member retains its cause (@both)
- **GIVEN** an aggregate contains 999 references to itself followed by a distinct error with a cause
- **WHEN** the SDK serializes the aggregate
- **THEN** the aggregate, distinct error, and its cause should be emitted in that order
- **AND** the cause should retain its parent relationship without consuming another member inspection
