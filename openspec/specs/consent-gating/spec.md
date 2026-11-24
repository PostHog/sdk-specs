# Consent Gating Specification

## Purpose

`consent-gating` is the internal decision layer that determines whether the SDK is currently allowed to capture, enqueue, or persist analytics data.

It sits in front of event production and delivery, and is consulted by operations like `capture`, `identify`, `group`, exception capture, and queue submission.

This component is distinct from the public opt-in/opt-out APIs:

- public APIs **change** consent state
- consent gating **reads** that state and decides whether capture is allowed right now

## Applicability

`client` — the audited implementations are client-side capture gates. Server SDKs generally do not maintain a persistent per-user consent state in-process.

## Public signature(s)

No single public API.

Canonical internal checks look like:

```ts
isOptedOut(): boolean
isCapturing(): boolean
shouldEnqueue(eventType): boolean
```

## Behavior

1. **Read current consent / opt-out state.** Determine whether capture is currently allowed based on persisted opt-out state, configuration defaults, and SDK-specific consent rules.
2. **Short-circuit capture when disallowed.** If capture is not allowed, event-producing APIs return early and do not enqueue or send analytics data.
3. **Log or emit a reason when dropped.** Implementations often log a diagnostic message when an event is skipped because the SDK is opted out.
4. **Apply richer consent semantics where supported.** Browser-class SDKs may include tri-state consent, Do Not Track, and cookieless-mode logic instead of a simple boolean gate.
5. **Gate more than events.** Consent gating may also control installation of integrations, persistence, session replay, surveys, or exception capture.
   - Flutter adds a wrapper-layer gate here: `optOut()` explicitly uninstalls its Dart-side error autocapture integration before delegating to the platform SDK, so consent changes affect wrapper-managed integrations as well as the underlying native/browser capture path.
6. **React immediately to consent changes.** Once the opt state changes, future operations use the new gating decision without waiting for network confirmation.

## State & lifecycle

### State read

- persisted opt-out / consent state
- SDK config defaults (for example default opt-in/out)
- browser-only consent modifiers such as DNT or cookieless mode
- runtime booleans such as Unity's in-memory `_optedOut`

### State written

Usually none directly; this component mostly reads state written by `optIn` / `optOut` / consent APIs.

### Lifecycle behavior

- Before the SDK is initialized, many implementations conservatively behave as opted out / disabled.
- After `optOut()`, future event-producing calls are blocked immediately.
- After `optIn()`, future event-producing calls are allowed again immediately.
- Browser consent gating may continue permitting capture in cookieless mode even when the user has explicitly rejected tracking.
- Wrapper SDKs may also expose disabled-state fallbacks on unsupported platforms. For example, Flutter's mobile/native bridge returns `true` from `isOptOut()` when the current platform is unsupported, treating the unavailable SDK as effectively opted out.

## Error handling

- Consent-gating checks should not throw in normal operation.
- If consent state cannot be read, SDKs typically fall back to the safest behavior for that implementation (often treating capture as disabled).
- Event producers should treat a failed gating check as a normal drop path, not as an application error.

## Concurrency & ordering guarantees

- Consent-state reads are synchronized or serialized by the SDK's normal state model.
- A capture call observes either the pre-change or post-change consent state depending on ordering, never a partial transition.
- After a successful opt-state write completes, subsequent capture calls should observe the new gating decision.

## Interactions

- **`opt-in` / `opt-out`** — mutate the state this component reads.
- **`capture` / `identify` / `group` / `alias`** — commonly consult consent gating before any event construction or enqueue.
- **exception capture** — often separately gated to avoid collecting crash data while opted out. A crash recorded by a platform mechanism and reconstructed on a later launch follows the consent state at crash time, per the `opt-in` requirement "Deferred crash reports honour consent at crash time".
- **persistent storage** — browser consent gating may also influence whether persistence itself remains enabled.
- **session replay / integrations** — may be stopped, skipped, or restarted based on consent state.
- **wrapper-managed integrations** — Flutter's error autocapture integration is installed during setup and explicitly uninstalled on `optOut()`, so consent gating also controls wrapper-owned exception interception.

## Requirements

### Requirement: Canonical consent-gating behavior

The SDK SHALL implement the canonical `consent-gating` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Opted out consent blocks capture and persistence writes
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** analytics capture is opted out
- **WHEN** capture is called with event "Blocked"
- **THEN** no event should be enqueued
- **AND** no network request should be sent

#### Scenario: Opted in consent allows capture
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** analytics capture is opted in
- **WHEN** capture is called with event "Allowed"
- **THEN** one event named "Allowed" should be enqueued

#### Scenario: Consent state is restored before early capture calls
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** persistent storage contains opt-out state "true"
- **WHEN** the SDK is initialized with token "test-token"
- **AND** capture is called with event "Early Event"
- **THEN** no event named "Early Event" should be enqueued

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
