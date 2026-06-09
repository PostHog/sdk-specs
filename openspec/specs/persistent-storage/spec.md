# Persistent Storage Specification

## Purpose

`persistent-storage` is the internal abstraction that lets client SDKs retain identity, consent, feature-flag caches, super properties, groups, sessions, and queued events across app restarts.

It is not a single public API. It is the storage layer underneath methods like `identify`, `reset`, `register`, `reloadFeatureFlags`, and queue flush/retry logic.

## Applicability

`client` — the audited implementations are client-side persistence layers. Server SDKs also have storage concerns, but this spec covers the client-side persistent state layer used for ambient identity and cached SDK state.

## Public signature(s)

No direct public API.

Canonical internal operations look like:

```ts
get(key: string): JsonLike | undefined
set(key: string, value: JsonLike | null): void
remove(key: string): void
clear(except?: string[]): void
```

Many SDKs also split **state storage** and **event-queue storage**:

```ts
saveEvent(id: string, json: string): void
loadEvent(id: string): string | null
listEventIds(): string[]
deleteEvent(id: string): void
```

## Behavior

1. **Namespace SDK state by project / instance.** Storage is scoped to the SDK instance (typically by API key and/or base directory) so separate PostHog clients do not overwrite each other unintentionally.
2. **Persist typed SDK state under stable keys.** Common persisted values across audited SDKs include:
   - `distinct_id`
   - anonymous / device id
   - opt-out state
   - super properties / registered properties
   - groups
   - feature flags and payloads
   - person/group properties for flags
   - session state
   - queued events
3. **Serialize values to storage-safe representations.** Implementations use JSON-ish dictionaries/arrays/primitives or raw text blobs/files depending on platform.
4. **Treat `null` / delete as removal.** Clearing a key removes it from persistence rather than storing a sentinel object.
5. **Support lazy reads.** Higher layers often read from persistence on first access, then cache values in memory until reset or overwrite.
6. **Allow wrapper SDKs to delegate persistence to an underlying platform store.** Flutter's Dart layer forwards stateful operations to the native/browser SDKs rather than implementing its own durable identity/flags/super-properties store.
7. **Survive restarts and crashes.** Stored values are intended to be reusable when the app/process starts again.
8. **Allow full or selective clearing.** Reset flows typically remove most persisted keys while preserving a small allowlist such as queued events or install/version bookkeeping.
9. **Preserve queue durability separately from general state when applicable.** Event queues may be stored in dedicated files/folders so pending events survive process restarts independently of identity resets.
10. **Handle corruption and I/O failures defensively.** Storage errors are logged and swallowed; the SDK falls back to empty/default state rather than throwing to application code.
11. **Support migrations where storage layout changes.** Mature SDKs migrate legacy locations/keys forward when storage formats evolve.

## State & lifecycle

### Typical persisted keys

Across the audited implementations, persistent storage commonly contains:

- identity: distinct id, anonymous id, identified flag
- privacy: opt-out state / consent state
- event enrichment: super properties, groups
- feature flags: cached flags, payloads, request metadata, person/group properties for flags
- runtime state: session ids / timestamps, surveys, replay or remote-config-derived settings
- delivery: queued events

### Initialization

- Storage backends are initialized during SDK setup.
- Some platforms create directories eagerly.
- Values are often loaded lazily on first access rather than all at once.
- Wrapper SDKs may keep only transient in-memory state at their own layer. Flutter stores wrapper-local config and current-screen context in Dart while relying on the underlying native/browser SDKs for persistent identity and cache storage.

### Clearing

- `reset()` clears most user-scoped state.
- Queue/event persistence is often intentionally preserved across reset.
- Dedicated delete/remove operations exist for single-key cleanup.

## Error handling

- Storage read/write failures are logged and treated as recoverable.
- Missing values return `nil` / `undefined` / defaults.
- Corrupt values are ignored, reparsed defensively, or deleted on failure.
- The storage layer should not crash application code during normal SDK use.

## Concurrency & ordering guarantees

- Storage access is synchronized with locks or thread-safe abstractions in native SDKs.
- JS-core-based SDKs rely on serialized access through the single-threaded runtime and the storage abstraction.
- Unity's file storage separates queue-event writes from state files and can wait for pending asynchronous event writes on shutdown.
- Callers should assume atomicity at the key/file level, not across many-key transactions.

## Interactions

- **`identify` / `reset` / `get-distinct-id`** depend on persisted identity keys.
- **`register` / `unregister` / `group`** depend on persisted super-properties and group keys.
- **`reload-feature-flags` / feature-flag getters** depend on persisted cached flags, payloads, and local flag-evaluation properties.
- **event queue / retry logic** depends on durable queued-event storage where implemented.
- **consent gating** depends on persisted opt-out / consent state.
- **wrapper-local state** may live outside durable storage. In Flutter, `_config` and `_currentScreen` are maintained in Dart memory and interact with setup/screen/replay behavior without being part of the underlying persistent store.

## Requirements

### Requirement: Canonical persistent-storage behavior

The SDK SHALL implement the canonical `persistent-storage` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Storage persists and restores identity data
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current anonymous id is "anon-123"
- **WHEN** the SDK is restarted
- **THEN** get anonymous id should return "anon-123"

#### Scenario: Storage persists super properties
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** register is called with properties:
  | property | value |
  | plan     | pro   |
- **AND** the SDK is restarted
- **AND** capture is called with event "Loaded"
- **THEN** the enqueued event property "plan" should equal "pro"

#### Scenario: Storage failures do not crash SDK calls
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** persistent storage writes will fail
- **WHEN** register is called with properties:
  | property | value |
  | plan     | pro   |
- **THEN** the call should not throw
- **AND** the SDK should record a storage warning
