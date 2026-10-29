## ADDED Requirements

### Requirement: Replay batches preserve session and identity attribution

Replay-capable client SDKs SHALL construct each replay upload request using snapshot events that have the same `$session_id` and distinct ID. A change to either identifier SHALL create a request boundary, even when the batch-size limit has not been reached. The SDK SHALL use the identifiers stored on each snapshot event, rather than substituting the SDK's current session or identity at upload time. This requirement also applies to snapshots restored from persistent storage and requests rebuilt for retry.

Replay ingestion takes the session ID and distinct ID from the first snapshot event, combines the request's snapshot data into one `$snapshot_items` message, and attributes that message using those identifiers. Later events' identifiers do not create separate messages. Therefore, mixing either sessions or identities in a request loses the attribution of later snapshots.

Existing batch-size limits and retry/drop policies still apply. Separating requests at these boundaries SHALL NOT by itself discard snapshots from either side of the boundary. SDKs MAY use smaller batches or impose additional request boundaries for other replay metadata.

This requirement applies to replay requests, including those sent by underlying native SDKs on behalf of wrappers. Analytics batches do not have this request-level attribution constraint and MAY contain events from different sessions and identities.

#### Scenario: Replay upload separates a session change
- **GIVEN** replay has captured snapshot "A" with session ID "session-a" and distinct ID "person-a"
- **AND** replay then captures snapshot "B" with session ID "session-b" and distinct ID "person-a"
- **WHEN** both snapshots are uploaded successfully
- **THEN** the receiver observes them in separate replay requests
- **AND** snapshot "A" retains session ID "session-a" and distinct ID "person-a"
- **AND** snapshot "B" retains session ID "session-b" and distinct ID "person-a"

#### Scenario: Replay upload separates an identity change within one session
- **GIVEN** replay has captured snapshot "A" with session ID "session-a" and distinct ID "anonymous-a"
- **AND** replay then captures snapshot "B" with session ID "session-a" and distinct ID "person-a"
- **WHEN** both snapshots are uploaded successfully
- **THEN** the receiver observes them in separate replay requests
- **AND** snapshot "A" retains distinct ID "anonymous-a"
- **AND** snapshot "B" retains distinct ID "person-a"
- **AND** both snapshots retain session ID "session-a"

#### Scenario: Restored replay snapshots retain their original attribution
- **GIVEN** persistent storage contains an unsent replay snapshot "A" with session ID "session-a" and distinct ID "person-a"
- **AND** after restart the SDK captures snapshot "B" with session ID "session-b" and distinct ID "person-b"
- **WHEN** both snapshots are uploaded successfully
- **THEN** the receiver observes them in separate replay requests
- **AND** snapshot "A" retains session ID "session-a" and distinct ID "person-a"
- **AND** snapshot "B" retains session ID "session-b" and distinct ID "person-b"

#### Scenario: Replay retry preserves the request boundary
- **GIVEN** a replay request containing snapshot "A" with session ID "session-a" and distinct ID "person-a" receives a retryable failure
- **AND** the SDK subsequently captures snapshot "B" with session ID "session-b" and distinct ID "person-b"
- **WHEN** snapshot "A" is retried and both snapshots are uploaded successfully
- **THEN** every replay request contains snapshot events with a single session ID and distinct ID pair
- **AND** snapshot "A" retains session ID "session-a" and distinct ID "person-a"
- **AND** snapshot "B" retains session ID "session-b" and distinct ID "person-b"

#### Scenario: Compatible replay snapshots can share a request
- **GIVEN** replay has captured snapshots "A" and "B" with the same session ID and distinct ID
- **AND** the snapshots satisfy any other replay request boundaries and size limits
- **WHEN** the SDK constructs a replay upload request
- **THEN** the SDK may include both snapshots in the same request
- **AND** both snapshots retain their recorded session ID and distinct ID
