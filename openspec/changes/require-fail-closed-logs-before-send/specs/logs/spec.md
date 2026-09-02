## MODIFIED Requirements

### Requirement: beforeSend hook

The SDK SHALL support an optional `beforeSend` hook to mutate or drop records before they are
queued, accepting either a single function or an array run left-to-right (each output feeding the
next). Returning `null`, or mutating the body to empty/whitespace, SHALL drop the record.

`beforeSend` is the designated scrubbing point for sensitive record content, and SDK
documentation SHALL present it as such. A log body is free text and its attributes are arbitrary,
so this is the surface on which secrets most often reach the SDK.

A hook that throws SHALL be caught, and the record SHALL be dropped rather than queued with its
pre-hook value: continuing would ship the one record whose scrubber failed, unscrubbed and
indistinguishable from a record no hook was meant to touch. Catching SHALL still guarantee that
the throw does not propagate into the caller's capture call and does not stop later records from
being processed. The SDK SHALL emit a diagnostic naming `beforeSend`, so a hook that throws for
every record is attributable rather than an unexplained gap in the data; that diagnostic MAY
report only the error's type, since a hook's exception message can embed the record body it was
handed. Where a platform's hook signature makes throwing unrepresentable, this requirement is
satisfied without further handling.

This matches the `beforeSpanSend` rule in the traces capability: both hooks are scrubbing points,
so both fail closed.

`beforeSend` SHALL run before the rate cap. (Web MAY omit `beforeSend` today; new SDKs SHALL
implement it.)

#### Scenario: hook drops record
- **WHEN** a `beforeSend` returns `null` for a record
- **THEN** the record is dropped and not enqueued

#### Scenario: throwing hook drops the record
- **GIVEN** a `beforeSend` that throws
- **WHEN** a record is processed
- **THEN** the record is dropped and not enqueued
- **AND** the pre-hook value is not sent in its place

#### Scenario: a throwing hook does not reach the caller
- **GIVEN** a `beforeSend` that throws
- **WHEN** the app calls the logs capture API
- **THEN** the call returns normally, the SDK emits a diagnostic naming `beforeSend`, and a
  subsequent record whose hook does not throw is still enqueued
