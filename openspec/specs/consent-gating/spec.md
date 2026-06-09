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
   - Flutter adds a wrapper-layer gate here: `disable()` explicitly uninstalls its Dart-side error autocapture integration before delegating to the platform SDK, so consent changes affect wrapper-managed integrations as well as the underlying native/browser capture path.
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
- **exception capture** — often separately gated to avoid collecting crash data while opted out.
- **persistent storage** — browser consent gating may also influence whether persistence itself remains enabled.
- **session replay / integrations** — may be stopped, skipped, or restarted based on consent state.
- **wrapper-managed integrations** — Flutter's error autocapture integration is installed during setup and explicitly uninstalled on `disable()`, so consent gating also controls wrapper-owned exception interception.

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
