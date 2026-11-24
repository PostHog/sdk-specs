## ADDED Requirements

### Requirement: Interaction data buffered before a consent change is never sent

A capture feature that stores interactions and sends them later rather than capturing each one as it
happens — the browser's heatmaps buffer, which holds clicks and mouse moves and sends them on a
timer, and its dead-click and dead-swipe detectors, which hold a click or a touch as a candidate for
seconds before deciding whether to report it — SHALL decide from the consent state at the time of
the interaction, not from the consent state at the time of the send.

The SDK SHALL read the consent state when it stores an interaction and SHALL NOT store one made
while capture is disallowed. Discarding the stored data at send time is not enough on its own: the
data was collected without consent, and a later opt-in makes it deliverable.

On a consent change the SDK SHALL discard what is pending: the buffer, any timer-held interaction
not yet in the buffer, and any deferred report whose interaction happened before the change. This
applies in both directions. An opt-out drops data the visitor no longer consents to; an opt-in that
changes the stored consent state drops data collected before consent, including the interaction with
the consent prompt itself. A repeat opt-in call that does not change the stored state — a consent
manager re-applying stored consent on each page load — discards nothing, in line with
"Consent event is captured once per opt-in transition" in `opt-in`. Where a consent change also
changes the identity the SDK captures under (the browser's cookieless `on_reject` mode), the
discard SHALL happen there too, so buffered interactions never cross from one identity to the next.

This requirement is about data held outside the event queue. Events already enqueued follow the
queue's own rules, and an interaction captured directly is gated at capture time by the canonical
consent-gating behavior above. It is the in-process counterpart of "Deferred crash reports honour
consent at crash time" in `opt-in`, and decides the same way: consent at the time of the recorded
event, not at the time it is sent.

#### Scenario: An interaction buffered while opted out is not sent after opt in
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** a capture feature that buffers interactions and sends them on a timer is enabled
- **AND** analytics capture is opted out
- **WHEN** an interaction occurs
- **AND** opt in is called
- **AND** the feature's send timer fires
- **THEN** no event carrying that interaction should be enqueued

#### Scenario: Interactions buffered before an opt out are discarded
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** a capture feature that buffers interactions and sends them on a timer is enabled
- **AND** analytics capture is opted in
- **WHEN** an interaction occurs
- **AND** opt out is called before the feature's send timer fires
- **AND** opt in is called
- **AND** the feature's send timer fires
- **THEN** no event carrying that interaction should be enqueued

#### Scenario: A deferred report of a pre-change interaction is dropped
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** a capture feature that decides seconds after an interaction whether to report it is enabled
- **AND** analytics capture is opted in
- **WHEN** an interaction occurs
- **AND** opt out is called
- **AND** opt in is called
- **AND** the feature decides to report the interaction
- **THEN** no event carrying that interaction should be enqueued
