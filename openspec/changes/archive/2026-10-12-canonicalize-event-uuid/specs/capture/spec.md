## Narrative alignment

When syncing this delta, note in Behavior step 5 that a caller-supplied `uuid`
is normalized to canonical lowercase hyphenated form, in step 6 that the
normalization is re-applied after the `before_send` hook, and in step 8 that the
uuid returned to the caller is the normalized value that was sent. Add to Error
handling that an unparseable caller-supplied uuid is logged and replaced with a
generated UUIDv7 rather than failing the call. Leave the existing capture
scenarios and unrelated sections unchanged.

## ADDED Requirements

### Requirement: Event uuid is sent in canonical form

The SDK SHALL serialize the event `uuid` in canonical lowercase hyphenated form
(`8-4-4-4-12`, no braces, no `urn:uuid:` prefix). A caller-supplied uuid in
another form the SDK accepts — uppercase, unhyphenated, brace-wrapped, or
`urn:uuid:`-prefixed — SHALL be normalized to that form before the event is
enqueued, and the uuid the capture call returns SHALL be the normalized value
that was sent. The normalization SHALL be applied after the `before_send` hook,
so a uuid the hook sets is normalized too.

A caller-supplied value the SDK cannot parse as a uuid SHALL NOT fail or drop
the capture call: the SDK SHALL replace it with a freshly generated UUIDv7 and
report the discarded value through its logging surface.

Capture v1 keys the per-event `results` map in a 2xx response by the canonical
uuid while parsing the request's uuid leniently, so an event sent under a
non-canonical uuid cannot be correlated with its own verdict: a retryable
verdict is never retried and a drop verdict never reaches the SDK's error
reporting.

#### Scenario: Non-canonical caller uuid is normalized before send (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** capture is called with distinct id "user-123", event "Signed Up", and uuid "0199C3E8-4C7B-7E2E-9F21-2B6D5A1C9E04"
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event uuid should be "0199c3e8-4c7b-7e2e-9f21-2b6d5a1c9e04"
- **AND** the call should return the enqueued event's uuid

#### Scenario: Unparseable caller uuid falls back to a generated uuid (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** capture is called with distinct id "user-123", event "Signed Up", and uuid "not-a-uuid"
- **THEN** the capture call should not throw
- **AND** one event named "Signed Up" should be enqueued
- **AND** the enqueued event uuid should not equal "not-a-uuid"
- **AND** the enqueued event should include an event uuid
- **AND** the call should return the enqueued event's uuid
