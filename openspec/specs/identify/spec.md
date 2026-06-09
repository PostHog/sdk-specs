# Identify Specification

## Purpose

`identify` associates subsequent events with a specific user by binding a stable `distinct_id` to a person profile, and (optionally) writes user-level properties on that profile.

On client SDKs, `identify` additionally performs **anonymous-to-identified merging**: the previous (anonymous) distinct id is carried in the outgoing `$identify` event as `$anon_distinct_id` so the ingest server can stitch pre-identify events to the now-identified person. This is the mechanism that lets PostHog track a user across their anonymous → signed-up transition.

On server SDKs, `identify` is a stateless record — no anonymous id is inferred, and there is no concept of the "current user" carrying across calls.

The canonical event name emitted is **`$identify`** (with a leading `$`), regardless of SDK.

## Applicability

`both` — client and server SDKs both expose `identify`, but with substantially different semantics.

### Client vs. server semantics

| Concern | Client-side | Server-side |
| --- | --- | --- |
| `distinct_id` | Optional override. Defaults to the SDK's current distinct id; if a new one is provided, the SDK **updates its persistent state** (becomes the new ambient distinct id). | Required per-call argument. Not persisted. |
| `$anon_distinct_id` | Stamped on the event (the previous distinct id, i.e. the anonymous / device id) so the server can merge profiles. | Not stamped. The server has no concept of the user's anonymous history. |
| Ambient "identified" flag | Set to `true` on success; persisted. Consulted by `capture` (stamps `$is_identified`). | Not held. |
| Duplicate-call suppression | If called with the same distinct id while already identified, the event is suppressed or downgraded to a `$set` event. | No suppression — every call emits `$identify`. |
| Side effects | Reloads feature flags; updates cached person properties; notifies crash-reporting integrations of the context change. | None beyond enqueuing the event. |
| Input validation | Empty distinct id → dropped with log. | Empty distinct id → dropped (client SDKs) or raises (Ruby, Go, .NET validators). |
| Return | `void` / `Unit` / `Future<void>` (no meaningful result). | Varies — UUID (Python via `set()`), bool (Ruby, PHP, Go's `Enqueue`), or Unit. Python has **no `identify()` method** — see below. |

Despite these differences, the outgoing wire event is the same shape:

```json
{
  "event": "$identify",
  "distinct_id": "<new id>",
  "properties": {
    "$anon_distinct_id": "<previous id, client-only>",
    "$set": { ... },
    "$set_once": { ... },
    "$lib": "<sdk-id>",
    "$lib_version": "<version>",
    ...
  },
  "timestamp": "...",
  "uuid": "..."
}
```

## Public signatures

### Client-side canonical signature

```ts
identify(
  distinctId?: string,           // optional: override the ambient distinct id
  properties?: Record<string, unknown>,   // merged into $set (for compat); recognizes $set and $set_once keys
  options?: CaptureOptions,
): void
```

Mobile variant (iOS, Android, Flutter, Unity) uses named parameters for clarity:

```kotlin
identify(
  distinctId: String,
  userProperties: Map<String, Any>? = null,        // → $set
  userPropertiesSetOnce: Map<String, Any>? = null, // → $set_once
)
```

Flutter exposes the same conceptual surface through a Dart wrapper that returns a future and uses `userId` as the parameter name:

```dart
identify({
  required String userId,
  Map<String, Object>? userProperties,
  Map<String, Object>? userPropertiesSetOnce,
}): Future<void>
```

### Server-side canonical signature

```ts
identify(
  distinct_id: string,
  properties?: Record<string, unknown>,   // becomes $set on the wire
  options?: {
    timestamp?: Date,
    uuid?: string,
    disable_geoip?: boolean,
  },
): string | boolean | null | void   // varies; varies by SDK
```

#### Server-side surface variants

- **Ruby** (`identify(attrs)`): hash-style message: `{distinct_id:, properties:, timestamp:}`. Emits `$identify` with `$set = properties`.
- **PHP** (`PostHog::identify(['distinctId' => ..., 'properties' => ...])`): array-of-args. Emits `$identify` with `$set`.
- **Go** (`client.Enqueue(posthog.Identify{DistinctId, Properties, Timestamp, DisableGeoIP})`): struct-based. Properties becomes top-level `$set`.
- **Node** (`client.identify({distinctId, properties, disableGeoip})`): object-args.
- **.NET** (`client.Identify(distinctId, personProperties, personPropertiesSetOnce)`): emits `$identify` directly.
- **Python** — **no `identify()` method**. Python exposes `set()` and `set_once()` for user-property updates, and manages ambient distinct id via `identify_context(...)` + `new_context()`. Callers wanting to emit `$identify` must call `capture('$identify', ...)` manually.

## Behavior

### Client-side flow

1. **Guards.** Short-circuit if the SDK is disabled, the user is opted out, or person processing is disallowed (`personProfiles == 'never'`). If the provided `distinctId` is empty or whitespace-only, log and drop.
2. **Resolve distinct ids.** Let `previousDistinctId = current persisted distinct id (or the device/anonymous id)`. Let `newDistinctId = caller-provided value` (if any) `else previousDistinctId`.
3. **Decide the emission path:**
   - **New distinct id, not yet identified** → emit `$identify`. Persist `newDistinctId` as the distinct id, persist `previousDistinctId` as the anonymous id (unless `reuseAnonymousId` is true), mark `isIdentified = true`. Reload feature flags. Notify integrations (crash reporting, surveys) of the context change. Update cached person-properties hash.
   - **Same distinct id, but userProperties / userPropertiesSetOnce provided** → emit `$set` (not `$identify`), with the new properties. Feature flags are **not** reloaded (property changes are processed async server-side). A hash check suppresses no-op duplicate calls with the same properties.
   - **Same distinct id, no properties** → log "already identified", drop.
   - **New distinct id but user is already identified** → in most SDKs, the call is logged and dropped; callers must `reset()` first to identify a different user. (Some SDKs always emit.)
4. **Construct the `$identify` event** with properties:
   - `$anon_distinct_id`: the pre-identify id (the anonymous / device id), **unless** `reuseAnonymousId` is true, in which case it is omitted and the anonymous id is not rotated.
   - `$set`: user properties to set (if provided).
   - `$set_once`: user properties to set only if unset (if provided).
   - Plus all normal capture enrichment (session id, super props, device info, etc.).
5. **Enqueue.** Same queue path as `capture`. Return to the caller immediately.

### Server-side flow

1. **Validate.** `distinct_id` must be present and non-empty. Server SDKs vary between dropping silently (most) and raising (Ruby, Go, .NET via their respective validators).
2. **Build the event.** `event = '$identify'`, `distinct_id = caller-provided`, `$set = caller-provided properties` (or, depending on SDK, `$set = properties` and `$set_once` from a separate option).
3. **Enrich.** Standard server enrichment: `$lib`, `$lib_version`, possibly `$geoip_disable`.
4. **Run `before_send` (if configured)**, same as `capture`.
5. **Enqueue.** Same batching queue as `capture`.
6. **Return.** Varies by SDK (UUID / bool / void).

## State & lifecycle

### Client-side persisted state read/written

- **Read:** current distinct id, anonymous id, `isIdentified` flag, person-properties hash, `reuseAnonymousId` config, super properties.
- **Written on successful identify:**
  - New distinct id → persisted as the ambient distinct id.
  - Previous distinct id → persisted as the anonymous id (unless `reuseAnonymousId`).
  - `isIdentified` flag → `true`.
  - Cached person-properties hash → updated to suppress duplicate `$set` emissions.
  - `PersonMode` → `identified` (posthog-js core).

### Server-side state

- None. Each call is independent; no per-user state is held.

### Cross-SDK lifecycle notes

- **`reset()`** (client) clears the identified state: distinct id is regenerated, `isIdentified` → `false`, super properties and groups are cleared. The next `identify(newId)` call will freshly emit `$identify` with `$anon_distinct_id = <the fresh anonymous id>`.
- **`reuseAnonymousId` config** (when true): the client does **not** rotate the anonymous id on identify, and does not stamp `$anon_distinct_id`. The identified distinct id becomes the device's persistent id. Intended for apps where users are always logged-in (no anonymous phase).
- **`$identify` and `capture` ordering** matters: if a `$capture` event is emitted between two identify calls from different identities without a `reset()`, server-side ordering may mis-attribute events. Clients that change identity should always `reset()` on logout.

## Error handling

- **Never throw** to the caller (except PHP's public façade and Ruby's `check_presence!`, which throw on missing `distinct_id`).
- **Drop silently** on: disabled SDK, opted-out user, empty distinct id, person-processing disabled, duplicate identified-user call with same properties, `before_send` returning null.
- **Log** drops with a descriptive reason in mobile / browser SDKs.

## Concurrency & ordering

- `identify` is thread-safe / task-safe in every SDK. Client SDKs hold an `identifiedLock` (Android) or `NSLock` (iOS) around the state mutation to prevent torn reads with concurrent captures.
- Ordering across `identify → capture` is only FIFO within the same queue flush. A `capture` issued immediately after `identify` may be delivered in the same batch and thus reach the server in order, but across batches, server-side processing may reorder; the `$anon_distinct_id` linkage on the `$identify` event is what guarantees correct attribution even under reordering.

## Interactions

- **`capture`**: after `identify`, every capture event stamps `$is_identified: true` and uses the new distinct id. The `$identify` event itself is delivered via the same capture pipeline.
- **`reset`**: the inverse of identify. Clears identified state and rotates the anonymous id so future events land under a new anonymous profile.
- **`alias`**: for linking a second id to the same person without mutating the ambient distinct id. Typically called during signup to associate a backend user id with an existing client id.
- **`group` / `group_identify`**: group membership is orthogonal to user identity; `$groups` is attached via a separate mechanism (either stamped on every event after `group(...)` or set explicitly on the `$groupidentify` event).
- **Feature flags**: identify triggers a flag reload on the client, because flag evaluation often depends on identified-user properties or cohort membership.
- **Session replay** (client): identify does **not** start a new session; the active session id is preserved across the identify call so the recording spans the anonymous → identified transition.
- **`set` / `set_once`** (where exposed as separate public methods): functionally equivalent to `identify(distinctId, {$set: ...})` or `identify(distinctId, {$set_once: ...})`. Python exposes these as the **only** way to update user properties (no `identify`).

## Requirements

### Requirement: Canonical identify behavior

The SDK SHALL implement the canonical `identify` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Client identify changes the current distinct id and sends identity properties (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current distinct id is "anon-123"
- **WHEN** identify is called with distinct id "user-123" and properties:
  | property | value          |
  | email    | user@test.test |
- **THEN** get distinct id should return "user-123"
- **AND** one event named "$identify" should be enqueued
- **AND** the enqueued event properties should include:
  | property             | value          |
  | distinct_id          | user-123       |
  | $anon_distinct_id    | anon-123       |
  | $set.email           | user@test.test |

#### Scenario: Server identify sends a profile update for explicit distinct id (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** identify is called with distinct id "user-123" and properties:
  | property | value          |
  | email    | user@test.test |
- **THEN** one event named "$identify" should be enqueued
- **AND** the enqueued event distinct id should be "user-123"
- **AND** the enqueued event property "$set.email" should equal "user@test.test"

#### Scenario: Identify validates distinct id (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** identify is called without a distinct id
- **THEN** identity state should not change
- **AND** no identity event should be enqueued
