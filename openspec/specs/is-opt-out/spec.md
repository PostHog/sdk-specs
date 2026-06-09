# Is Opt Out Specification

## Purpose

`is-opt-out` reports whether the client SDK currently considers analytics capture **disabled for this installation/runtime context**.

It is the read-only counterpart to `opt-in` / `opt-out`:

- `optOut()` mutates local consent/capture state
- `optIn()` clears that state
- `isOptOut()` (or equivalent) reads the current effective result

This API does **not** emit an event, perform network I/O, or mutate SDK state.

## Applicability

`client` — this is a client-side consent/state getter. Server SDKs are stateless per call and generally do not expose a comparable persisted opt-out-state reader.

## Public signatures

### Canonical client signature

```ts
isOptOut(): boolean | Promise<boolean>
```

### Surface variants

- **iOS:** `isOptOut() -> Bool`
- **Android:** `isOptOut(): Boolean`
- **Flutter:** `isOptOut(): Future<bool>`
- **Unity:** `IsOptedOut: bool` static property
- **browser:** `has_opted_out_capturing(): boolean`

Despite the naming differences, these surfaces answer the same question: should this SDK currently treat capture as opted out / disabled?

## Behavior

1. **Read local consent / opt-out state only.** The getter resolves from already-known local SDK state; it does not fetch from PostHog.
2. **Return the current effective capture-disabled state.**
   - Mobile/native SDKs commonly read a persisted `optOut` boolean from in-memory config or storage-backed state.
   - Browser computes the answer from its consent manager, which can treat cookieless/privacy modes as effectively opted out even when the stored consent state is not a simple boolean.
3. **Fail closed when the SDK is unavailable in many audited implementations.** Several native/wrapper SDKs return `true` when the SDK is disabled, uninitialized, unsupported, or otherwise unavailable, so callers do not mistakenly assume capture is allowed.
4. **Reflect prior `optIn()` / `optOut()` calls.** Once those mutating APIs complete, future reads reflect the new state.
5. **Do not mutate state.** Calling this getter never changes persistence, consent, queues, or integrations.
6. **Do not affect already-enqueued work.** The getter only reports the current state; it does not cancel or resume work by itself.

## State & lifecycle

### State read

- current local opt-out / consent state
- SDK enabled / initialized / supported-platform state
- browser consent-mode configuration where applicable

### State written

None.

### Lifecycle behavior

- The returned value persists across restarts in SDKs where `optOut()` persists its state.
- The value can change after `optIn()` / `optOut()` transitions.
- The value after `reset()` is SDK-specific: in some SDKs reset clears the opt-out state, while others preserve it. This getter simply reports whatever state currently survives that lifecycle.
- Wrapper SDKs may proxy the underlying platform/browser answer rather than owning separate consent state. Flutter delegates `isOptOut()` to the native/browser SDKs.

## Error handling

- This API should not throw in normal operation.
- Many audited native/wrapper implementations return `true` if the SDK is unavailable or the read path fails.
- Browser callers generally receive a synchronous boolean derived from the consent manager.

## Concurrency & ordering guarantees

- Reads are side-effect-free and observe the SDK's current consent state.
- A read performed after `optOut()` completes observes the opted-out state.
- A read performed after `optIn()` completes observes the opted-in state.
- If reads race with consent-state mutations, callers may observe either the pre-transition or post-transition value depending on ordering; no partial state is exposed.

## Interactions

- **`opt-in` / `opt-out`** — these APIs set the state that this getter reports.
- **`capture` / `identify` / `group` / `alias`** — these APIs often consult the same underlying consent state before deciding whether to enqueue work.
- **`reset`** — may or may not clear the underlying opt-out state depending on SDK.
- **consent-gating** — this public getter exposes part of the same internal gating state.
- **session replay / integrations** — higher-level code may use this getter to decide whether replay or other capture-adjacent features should be active.

## Requirements

### Requirement: Canonical is-opt-out behavior

The SDK SHALL implement the canonical `is-opt-out` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Is opt out reports false by default
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** is opt out is called
- **THEN** the returned opt-out value should be false

#### Scenario: Is opt out reports true after opt out
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** opt out is called
- **AND** is opt out is called
- **THEN** the returned opt-out value should be true

#### Scenario: Is opt out is restored from persistent storage
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** persistent storage contains opt-out state "true"
- **WHEN** the SDK is initialized with token "test-token"
- **AND** is opt out is called
- **THEN** the returned opt-out value should be true
