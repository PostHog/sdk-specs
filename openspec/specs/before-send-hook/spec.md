# Before Send Hook Specification

## Purpose

`before-send-hook` is the internal mutation/filter point that runs **after an event has been assembled** but **before it is enqueued or sent**.

It allows the SDK or caller configuration to:

- inspect the final event payload
- modify event name, properties, timestamp, uuid, or other exposed fields
- drop the event entirely by returning `null` / `nil`

This component is the last application-controlled interception point before delivery.

## Applicability

`both` — audited client and server SDKs expose a before-send-style hook, though the exact event shape and error semantics vary.

## Public signature(s)

No single cross-SDK public API, but the internal hook contract is broadly:

```ts
beforeSend(event): event | null
```

Some SDKs allow multiple hooks:

```ts
beforeSend: BeforeSendFn | BeforeSendFn[]
```

## Behavior

1. **Run after event assembly.** The hook usually sees the event after the SDK has resolved identity, merged properties, added SDK metadata, and attached timestamps/uuids (or a user-facing subset of that final event).
   - Some wrappers expose an earlier approximation instead of the fully-enriched native event. In Flutter, Dart `beforeSend` callbacks only see the user-provided event name/properties before native or browser SDK enrichment adds system fields like `$device_type` or `$session_id`.
2. **Allow mutation.** The hook may return a modified event.
3. **Allow dropping.** Returning `null` / `nil` rejects the event and prevents enqueue/send.
4. **Support hook chaining when configured as an array.** Multiple hooks run in order; each receives the previous hook's output.
5. **Stop the chain when a hook drops the event.** Later hooks are not invoked after a `null` / `nil` return.
6. **Convert between internal and user-facing event shapes where needed.** Some SDKs expose a simplified capture-result-style object to the hook, then map hook mutations back onto the internal message.
7. **Log suspicious or dropped results.** Implementations commonly log when an event is rejected or when the hook returns an event with no properties.
8. **Handle hook exceptions defensively.** Most SDKs catch exceptions from the hook and either continue with the original event or continue with the last good value instead of crashing caller code.

## State & lifecycle

### State read

- configured before-send hook(s)
- fully-assembled event/message

### State written

Usually none directly. The hook returns a transformed event object that higher layers then enqueue/send.

### Lifecycle behavior

- Hooks are configured during SDK setup or configuration mutation.
- They are applied to every eligible event passing through the capture pipeline.
- Eligibility is SDK-specific. For example, Flutter's Dart-layer hooks apply to `capture()`, `screen()`, and `captureException()`, but not to `identify()`, `alias()`, `group()`, `setPersonProperties()`, native-initiated lifecycle/replay events, survey events, or `$feature_flag_called` events.
- Because they run late, they can usually see and modify derived fields like `$set`, `$set_once`, timestamps, flag metadata, and SDK-added properties — except in wrapper-layer implementations like Flutter where the Dart hook runs before native/browser enrichment.

## Error handling

- Hook failures should not crash the application.
- Returning `null` / `nil` is treated as an intentional drop, not an error.
- Exceptions thrown by the hook are logged and handled according to SDK policy:
  - js-core keeps the last good event and continues
  - Ruby falls back to the original event
  - iOS simply uses the hook's returned value and logs if it is `nil`
  - Flutter logs the callback exception and continues with the current event value
  - Node treats `null` as drop and warns on empty properties; hook exceptions are not expected to escape normal event preparation paths

## Concurrency & ordering guarantees

- Hooks run synchronously with event preparation for a single event.
- For a given event, hooks execute in deterministic registration order.
- The hook chain is isolated to that event; it does not batch or reorder events.
- If the hook mutates timestamps/uuids/event names, downstream queueing observes those modified values.

## Interactions

- **capture / identify / alias / group-identify** — many SDKs route these through the hook once the event is assembled, but wrapper SDKs may only hook a subset of public APIs.
- **retry-queue / event-batcher** — only see the hook-transformed event, or nothing if it was dropped.
- **consent-gating** — usually runs earlier; opted-out events are typically blocked before the hook is invoked.
- **feature-flag-called tracking** — hook can mutate or drop these events too if they pass through the same pipeline, though Flutter explicitly excludes Dart-layer hooks from `$feature_flag_called` events.

## Requirements

### Requirement: Canonical before-send-hook behavior

The SDK SHALL implement the canonical `before-send-hook` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Before-send can mutate an assembled event before enqueue
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** before-send adds property "privacy" with value "filtered"
- **WHEN** capture is called with event "Checkout Started"
- **THEN** one event named "Checkout Started" should be enqueued
- **AND** the enqueued event property "privacy" should equal "filtered"

#### Scenario: Before-send can drop an event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** before-send drops events named "Secret Event"
- **WHEN** capture is called with event "Secret Event"
- **THEN** no event named "Secret Event" should be enqueued

#### Scenario: Before-send exceptions do not crash callers
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** before-send throws an exception
- **WHEN** capture is called with event "Safe Event"
- **THEN** the capture call should not throw
- **AND** the SDK should record a before-send warning
