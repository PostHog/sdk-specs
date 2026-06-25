# Shutdown Specification

## Purpose

`shutdown` cleanly stops the SDK and performs final best-effort delivery / teardown work before the process or app instance goes away.

It is the lifecycle-end counterpart to initialization. Typical responsibilities include:

- flushing pending events
- waiting for in-flight async work to finish when supported
- stopping background workers/timers/pollers
- shutting down auxiliary integrations
- releasing internal resources

In some SDKs the public method is named **`close`** or **`Shutdown`** instead of `shutdown`.

## Applicability

`both` — both client and server SDKs may expose an end-of-life teardown API, though the details differ by runtime.

### Client vs. server semantics

| Concern | Client-side | Server-side |
| --- | --- | --- |
| Primary use | App/SDK teardown, backgrounding/quit cleanup, stop replay/integrations. | Process/request teardown, ensure queued events are delivered before exit. |
| Return type | Often `void` on native/mobile SDKs; Promise/async on JS/server SDKs. | Commonly blocking / Promise-based. |
| Resource cleanup | Queues, replay, integrations, reachability/notifiers, storage managers. | Queue drain, worker stop, poller/cache-provider shutdown, error-tracking teardown. |
| Reuse after call | Usually not supported; instance is considered closed. | Usually not supported; create a new client instead. |

## Public signatures

### Canonical signature

```ts
shutdown(timeoutMs?: number): void | Promise<void>
```

### Surface variants

- **posthog-js core / node:** `shutdown(shutdownTimeoutMs?: number): Promise<void>`
- **Python:** `shutdown(): void`
- **iOS:** `close(): void`
- **Android:** `close(): void`
- **Flutter:** `close(): Future<void>`
- **Unity:** `Shutdown(): void`

## Behavior

1. **Stop accepting normal future work.** The instance transitions into a closed/shutting-down state or is otherwise treated as no longer reusable.
2. **Flush pending events.** Attempt to send queued events immediately before tearing down workers/queues.
3. **Wait for in-flight work when supported.**
   - Promise/async implementations may await pending promise queues, active flushes, and outstanding event-preparation work.
   - Native `void` implementations usually fire teardown on their internal queue and do not expose completion to callers.
4. **Stop background workers / timers / pollers.** Shut down batch consumers, flush timers, feature-flag pollers, replay queues, or equivalent background machinery.
5. **Tear down integrations / subsystems.** Depending on SDK, this may include session replay, error tracking, reachability, lifecycle handlers, or custom integrations.
6. **Clear transient tracking state.** Clear in-memory feature-flag-called tracker / dedupe state so it cannot outlive the SDK instance.
7. **Release or reset internal references.** Some SDKs nil out storage/api/config objects, remove API-key registrations, or destroy singleton objects.
8. **Do not expect reuse.** After shutdown/close, callers should treat the instance as dead and create a new SDK instance if needed.

## State & lifecycle

### State read

- pending event queue / in-flight work
- active background workers/timers
- registered integrations / subsystems
- shutdown timeout (where supported)

### State written

- closed/shutdown flags/promises
- stopped worker/timer state
- cleared feature-flag-called tracker state
- cleared internal references / singleton state
- auxiliary subsystem teardown state

### Lifecycle behavior

- `shutdown` is usually called once at the end of the SDK's lifetime.
- Repeated shutdown calls may be deduplicated, warned about, or safely ignored.
- `flush()` is the lighter-weight sibling used when callers want delivery without fully destroying the instance.

## Error handling

- Teardown should not crash application code under normal use.
- Promise-based SDKs may reject on timeout or unrecoverable flush failure, but try to absorb/log ordinary transport errors during the final drain.
- Native/client `close()` / `Shutdown()` methods usually swallow/log teardown errors internally.
- Cache-provider/integration shutdown failures are commonly logged but do not prevent the rest of shutdown from proceeding.

## Concurrency & ordering guarantees

- Shutdown usually serializes with flush/drain operations so only one finalization cycle runs at a time.
- Promise-based implementations often deduplicate concurrent shutdown calls onto a single shared promise.
- Events enqueued after shutdown begins may or may not be included, depending on timing; callers should avoid enqueueing after initiating shutdown.

## Interactions

- **`flush`** — shutdown commonly calls or subsumes flush behavior.
- **retry-queue / event-batcher** — drained/stopped as part of shutdown.
- **feature-flag pollers / cache providers** — stopped or shut down as part of teardown.
- **feature-flag-called tracker** — cleared during teardown so dedupe state does not leak across SDK lifetimes.
- **session replay / error tracking / integrations** — stopped/uninstalled as part of client shutdown.

## Requirements

### Requirement: Canonical shutdown behavior

The SDK SHALL implement the canonical `shutdown` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Shutdown flushes queued events and disables future work (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the mock server will accept the next ingestion request with status 200
- **AND** the event queue contains events:
  | event | distinct_id |
  | Save  | user-123    |
- **WHEN** shutdown is called
- **THEN** the mock server should receive event "Save"
- **AND** the event queue should be empty after a successful flush
- **AND** background workers should be stopped
- **WHEN** capture is called with event "After Shutdown"
- **THEN** no event named "After Shutdown" should be enqueued

#### Scenario: Shutdown is idempotent (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** shutdown is called
- **AND** shutdown is called again
- **THEN** neither call should throw
- **AND** background workers should remain stopped

#### Scenario: Shutdown honors delivery failures without crashing (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the event queue contains events:
  | event | distinct_id |
  | Save  | user-123    |
- **AND** the mock server will fail the next ingestion request with status 503
- **WHEN** shutdown is called
- **THEN** the call should not throw
- **AND** the SDK should record a delivery warning
