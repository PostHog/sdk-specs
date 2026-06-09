# Screen Specification

## Purpose

`screen` records a **screen-view event** for the current client-side user/session.

It is the mobile/native-oriented equivalent of explicitly telling PostHog that the user has viewed a named screen or route. The API wraps that view as a normal analytics event, typically named `$screen`, with the viewed screen name attached in properties.

## Applicability

`client` — this is a client-side event-capture API. Server SDKs generally do not model ambient app screens/routes and therefore do not expose a comparable screen-view primitive.

## Public signatures

### Canonical client signature

```ts
screen(
  name: string,
  properties?: Record<string, JsonValue>,
  options?: CaptureOptions,
): void | Promise<void>
```

### Surface variants

- **react-native:** `screen(name, properties?, options?) => Promise<void>`
- **iOS:** `screen(_ screenTitle: String, properties: [String: Any]? = nil) -> Void`
- **Android:** `screen(screenTitle: String, properties: Map<String, Any>? = null) -> Void`
- **Unity:** `Screen(string screenName, Dictionary<string, object> properties = null) -> Void`

The event name is not caller-configurable in the audited SDKs; these surfaces emit a `$screen` event.

## Behavior

1. **Guard / no-op if unavailable.** Disabled, uninitialized, or opted-out SDK instances do nothing.
2. **Accept a screen name and optional event properties.** The screen name is required by the public API shape in the audited SDKs.
3. **Inject the canonical screen-name property.** The SDK adds `$screen_name = <name>` to the event properties.
   - In the canonical shape, the explicit `name` argument wins over any conflicting caller-supplied `$screen_name` property.
4. **Send a `$screen` analytics event through the normal capture pipeline.** The event then receives the SDK's usual enrichment and delivery behavior, such as ambient `distinct_id`, super properties, groups, session identifiers, timestamps, queueing, and transport.
5. **Return immediately or via an async handle.** Most audited SDKs are fire-and-forget; React Native returns a `Promise<void>` because its screen helper awaits initialization and then delegates to async capture.
6. **Do not change identity or feature-flag state.** This API is an event capture primitive, not an identity or flag-management call.

## State & lifecycle

### State read

- SDK enabled / initialization state
- opt-out / consent state where enforced by the SDK
- current ambient distinct id / anonymous id
- current session state
- registered/super properties and ambient groups

### State written

- queued `$screen` event payload
- normal capture-pipeline side effects such as event-queue mutation

### Lifecycle behavior

- Each call produces a new screen-view event attempt.
- The API does not canonically persist the screen name as long-lived SDK identity/context state.
- Standard capture-pipeline retries, batching, flush behavior, and shutdown behavior apply after the event is enqueued.

## Error handling

- This API should not throw in normal operation.
- Disabled or opted-out clients no-op.
- Invalid/unsendable events are handled by the SDK's normal capture/event-building pipeline.
- Transport failures occur after enqueue/capture handoff and follow the SDK's normal retry/drop behavior.

## Concurrency & ordering guarantees

- `screen(...)` participates in the same ordering guarantees as ordinary `capture(...)` calls in each SDK.
- If multiple screen events are emitted in sequence, they are queued/sent in call order subject to the SDK's normal batching and async scheduling.
- Concurrent calls may be serialized by the underlying event queue or capture pipeline; no special screen-specific ordering semantics are added.

## Interactions

- **`capture`** — `screen(...)` is a specialized wrapper over the normal event-capture path.
- **Event batcher / retry queue** — queued `$screen` events are delivered through the same batching/retry infrastructure as other events.
- **Session manager** — normal capture-pipeline session enrichment may attach the current session id to the screen event.
- **Session replay integrations** — some SDKs feed screen names into replay-specific state in addition to emitting `$screen`; those behaviors are platform-specific extensions outside the canonical event-only model.

## Requirements

### Requirement: Canonical screen behavior

The SDK SHALL implement the canonical `screen` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Screen records a screen view event
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** screen is called with name "Home" and properties:
  | property | value |
  | tab      | main  |
- **THEN** one event named "$screen" should be enqueued
- **AND** the enqueued event properties should include:
  | property     | value |
  | $screen_name | Home  |
  | tab          | main  |

#### Scenario: Screen updates current screen context
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** screen is called with name "Settings"
- **THEN** current screen context should be "Settings"

#### Scenario: Screen respects opt-out state
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** analytics capture is opted out
- **WHEN** screen is called with name "Home"
- **THEN** no event named "$screen" should be enqueued
