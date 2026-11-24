## ADDED Requirements

### Requirement: A missing flag reports no value

The SDK SHALL report the absence of a value when a read emits `$feature_flag_called` for a flag it
has no record of — no flag with that key in the loaded or cached flags, flags not loaded yet, or a
failed flags request. `$feature_flag_response` SHALL either be absent from the
event's properties or be JSON `null`. The two read the same downstream, and which one an SDK sends
follows from how its serializer treats a null-valued property (see `capture`, "Capture drops
null-valued object properties"), so this spec names no winner between them.

`$feature_flag_response` SHALL NOT be the empty string for a missing flag. The empty string is the
legacy rendering of a flag whose value is an empty variant key, which reads as disabled (see
`get-feature-flag-result`), so sending it for a missing flag makes the two cases indistinguishable
in flag analytics.

Allowed variation: an SDK whose enabled check resolves a missing flag to `false` by construction
(see `is-feature-enabled`, "Allowed variation for the no-default call") MAY report `false` from
that read path, since the event records the value the read resolved. `absent`, `null` and `false`
are the values the shared harness accepts for a missing-flag exposure; `""` is not one of them.

This requirement is about the event property only. What a read *returns* for a missing flag,
including a caller-supplied default, is specified by `get-feature-flag` and `is-feature-enabled`
and does not change here.

#### Scenario: A missing flag reports no value (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | true  |
- **WHEN** get feature flag "missing-flag" is called
- **THEN** one event named "$feature_flag_called" should be enqueued
- **AND** the enqueued event properties should include:
  | property      | value        |
  | $feature_flag | missing-flag |
- **AND** the enqueued event's `$feature_flag_response` is absent or `null`
- **AND** it is not the empty string

#### Scenario: An empty variant key still renders as the empty string (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** cached feature flags are:
  | key     | value |
  | beta-ui | ""    |
- **WHEN** get feature flag "beta-ui" is called
- **THEN** one event named "$feature_flag_called" should be enqueued
- **AND** the enqueued event properties should include:
  | property      | value   |
  | $feature_flag | beta-ui |
- **AND** `$feature_flag_response` is present and is the empty string, which is what distinguishes
  this read from a missing flag

