## ADDED Requirements

### Requirement: Analytics requests are bounded by serialized size

An SDK-managed analytics send SHALL be split so that each outgoing request stays within a byte target the SDK keeps below the ingestion deployment's request body limit, in addition to any event-count limit. Ingestion refuses a body over that limit — 2 MiB by default, 10 MiB on PostHog's hosted ingestion — and refuses the whole request, so a batch built from a count alone can be large enough to lose every event in it. The target applies to the bytes the SDK actually sends, so an SDK that compresses MAY measure the compressed body; SDKs that send uncompressed analytics bodies have settled on a ~5 MiB target.

Splitting is not dropping. The SDK SHALL send every event across the resulting requests, in the same order the batcher would otherwise have used, and a split SHALL NOT by itself discard an event from either side of the boundary.

The analytics lane has no per-event size cap. An event whose own serialized size exceeds the target SHALL be sent in a request of its own rather than dropped locally, leaving the decision to ingestion.

Work the batcher already defers to send time stays at send time: a split SHALL NOT move `before_send` / before-send-hook evaluation, serialization, or property stamping earlier than the SDK would otherwise run them.

An explicit single-request API, where the SDK documents that the caller's events are delivered as one request, MAY be exempt. The reactive `413` batch-size reduction described above remains in place as the backstop for a body the SDK's own target did not catch.

#### Scenario: A large flush is split into several requests
- **GIVEN** a queue holding more serialized event bytes than the SDK's request byte target
- **AND** the queue holds fewer events than the event-count limit
- **WHEN** the SDK flushes the queue
- **THEN** it sends more than one analytics request
- **AND** every queued event is sent exactly once
- **AND** the events arrive in the order they were queued

#### Scenario: An event larger than the target is sent alone
- **GIVEN** a queue holding events "small-1", "oversize", and "small-2" in that order
- **AND** "oversize" is on its own larger than the SDK's request byte target
- **WHEN** the SDK flushes the queue
- **THEN** "oversize" is sent in a request containing no other event
- **AND** "small-1" and "small-2" are still sent
- **AND** no event is dropped before the request is made

#### Scenario: The event-count limit still applies
- **GIVEN** a queue holding more events than the event-count limit
- **AND** their total serialized size is below the SDK's request byte target
- **WHEN** the SDK flushes the queue
- **THEN** each request holds at most the event-count limit
