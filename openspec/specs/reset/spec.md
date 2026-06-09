# Reset Specification

## Purpose

`reset` clears the SDK's current user context so subsequent events are emitted under a fresh anonymous identity instead of the previously identified user. It is the logout / account-switch primitive for client SDKs.

`reset` is a **local state mutation**. It does not emit a `$reset` event or any other analytics event. Its only network side effect is that many client SDKs immediately reload feature flags for the now-anonymous context.

## Applicability

`client` — `reset` is a client-side concept. Server SDKs are stateless per call and generally do not expose a comparable API.

## Public signatures

### Canonical client signature

```ts
reset(): void
```

### Surface variants

```ts
// posthog-js core / react-native
reset(propertiesToKeep?: PersistedPropertyKey[]): void
```

- `propertiesToKeep` is an implementation-specific escape hatch allowing selected persisted keys to survive the reset.
- The delivery queue is preserved regardless, so pending events are not discarded.

```ts
// browser
reset(resetDeviceId?: boolean): void
```

- `resetDeviceId` is a browser-specific toggle: when truthy, the browser SDK rotates `$device_id` as well as the anonymous `distinct_id`; when omitted/false, the browser SDK preserves the existing `$device_id` while still creating a fresh anonymous `distinct_id`.

```csharp
// Unity
Task ResetAsync()
```

```dart
// Flutter
Future<void> reset()
```

Unity awaits anonymous-context feature-flag reload before the returned task completes. Flutter wraps the underlying platform reset calls in `Future<void>`. iOS, Android, browser, and React Native expose synchronous `void` methods.

## Behavior

1. **Guard / no-op if unavailable.** Disabled mobile SDKs no-op. JS-core-based SDKs run inside the normal client wrapper and perform only local state mutation.
2. **Clear the current identity.** Remove the persisted `distinct_id` / identified-user marker so future events stop using the previous identified user.
3. **Handle anonymous / device identifiers.**
   - Reset creates a fresh anonymous context for subsequent activity.
   - In the audited js-core/mobile SDKs, implementations may optionally preserve the anonymous id through `reuseAnonymousId`-style configuration or a keep-list escape hatch.
   - The browser SDK instead always rotates the anonymous `distinct_id` and separately decides whether the persisted `$device_id` is preserved via the browser-specific `resetDeviceId` parameter.
4. **Clear user-scoped persisted state.** Implementations clear most state derived from the prior user, including:
   - registered / super properties
   - group memberships
   - cached person properties and group properties used for feature-flag evaluation
   - feature-flag values / payloads / remote-config caches
   - person-processing / identified flags
   - survey / replay / other persisted client caches where the SDK stores them
   - opt-out state in the SDKs audited here
5. **Preserve pending outbound events.** Reset affects future events only. Already-enqueued events remain queued for delivery and are not rewritten to the new anonymous identity.
6. **Rotate session state.** Start a new session (or force the current session id to rotate) so post-reset activity is tracked in a new anonymous session.
7. **Clear feature-flag bookkeeping and reload flags.** Flag-called trackers and related caches are cleared, then feature flags are reloaded for the anonymous context.
8. **Notify local integrations / observers if the SDK has them.** iOS explicitly notifies integrations of the context change after reset. Other SDKs update local managers implicitly via their storage / identity abstractions.

## State & lifecycle

### State cleared by reset

Across the audited client SDKs, `reset` clears or invalidates all persisted state that is logically tied to the current user identity:

- current `distinct_id`
- `isIdentified` / person-mode state
- registered properties / super properties
- stored groups
- cached person-properties hashes used to suppress duplicate `$set` / `$set_once`
- feature-flag caches, payloads, and flag-called tracking
- session state
- opt-out persistence

Client SDKs with extra persisted modules also clear those user-scoped caches during reset (for example remote config, surveys, replay state, and feature-flag person/group-property caches on iOS / React Native / Unity).

### State preserved by reset

- **Outbound event queue / in-flight delivery buffers.** Reset is not a purge operation.
- **Anonymous id when `reuseAnonymousId == true`.**
- **Explicitly-preserved keys** in SDKs that expose `propertiesToKeep`.
- **Platform install/version bookkeeping** in some mobile SDKs.

### Lifecycle effect

After `reset`, the SDK behaves like a fresh anonymous client instance:

- `capture(...)` uses the new anonymous / device id.
- `identify(newUserId)` is again treated as an anonymous → identified transition.
- feature flags are evaluated for the anonymous context until the next `identify` / group mutation.

## Error handling

- `reset` is best-effort local state mutation and should not throw in normal operation.
- Disabled / unavailable SDK instances no-op.
- Failures while reloading feature flags are logged / swallowed by the normal flag-loading machinery.
- Because no event is emitted, transport failures are irrelevant except for the post-reset flag reload.

## Concurrency & ordering guarantees

- `reset` is serialized through the SDK's normal storage / identity locks or single-threaded event loop.
- It only affects **subsequent** events. Events captured before the reset and already placed on the queue may still flush afterward under the old identity.
- Session rotation happens as part of the reset sequence, so events captured after the call observe the new session id.
- Unity is the only audited SDK where callers can await completion of the feature-flag reload; elsewhere the reset call returns before the reload completes.

## Interactions

- **`identify`** — `reset` is the inverse of client-side identify. It clears identified state so the next identify emits a fresh `$identify` transition.
- **`capture`** — subsequent captures use the fresh anonymous identity and new session context.
- **`group` / `groupIdentify`** — stored group membership is cleared, so group context must be re-established after reset.
- **`register` / `unregister`** — registered/super properties are cleared and must be re-registered if still desired.
- **Feature flags** — reset clears cached flag state and reloads flags for the anonymous user.
- **Session replay / surveys / remote config** — implementations that persist these alongside identity clear their user-scoped caches during reset.
- **Consent APIs (`opt_in` / `opt_out`)** — in the audited client SDKs, reset clears persisted opt-out state, so it should not be treated as a privacy-preserving alternative to opt-out.

## Requirements

### Requirement: Canonical reset behavior

The SDK SHALL implement the canonical `reset` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Reset clears identified state and creates a fresh anonymous identity
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current distinct id is "user-123"
- **AND** the current anonymous id is "anon-123"
- **WHEN** reset is called with anonymous id regeneration enabled
- **THEN** get distinct id should not return "user-123"
- **AND** get anonymous id should not return "anon-123"
- **AND** registered groups should be empty

#### Scenario: Reset clears super properties and group context
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** registered properties are:
  | property | value |
  | plan     | pro   |
- **AND** group context contains type "company" and key "company-123"
- **WHEN** reset is called
- **THEN** registered properties should be empty
- **AND** registered groups should be empty

#### Scenario: Reset starts a new session for subsequent events
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current session id is "session-123"
- **WHEN** reset is called
- **AND** get session id is called
- **THEN** the returned session id should not be "session-123"
