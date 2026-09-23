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
| `distinct_id` | Optional override. Defaults to the SDK's current distinct id; if a new one is provided, the SDK **updates its persistent state** (becomes the new ambient distinct id). | Optional per-call argument. Explicit id wins; when omitted, use request-scoped analytics identity or generate a fresh UUID. Not persisted. |
| `$anon_distinct_id` | Stamped on the event (the previous distinct id, i.e. the anonymous / device id) so the server can merge profiles. | Not stamped. The server has no concept of the user's anonymous history. |
| Ambient "identified" flag | Set to `true` on success; persisted. Consulted by `capture` (stamps `$is_identified`). | Not held. |
| Duplicate-call suppression | If called with the same distinct id while already identified, the event is suppressed or downgraded to a `$set` event. If called with the same distinct id while still anonymous, the SDK transitions to identified and emits a `$set` instead of suppressing. | No suppression — every call emits `$identify`. |
| Side effects | Reloads feature flags; updates cached person properties; notifies crash-reporting integrations of the context change. | None beyond enqueuing the event. |
| Input validation | Empty distinct id → dropped with log. | An omitted distinct id uses request context or a generated UUID; the call must not throw or reject. |
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
  distinct_id?: string,                   // explicit id, else request context, else generated UUID
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
   - **Same distinct id, still anonymous (`isIdentified` is `false`)** → treat this as the anonymous → identified transition even though the distinct id is unchanged: mark `isIdentified = true` and emit a single `$set` event (not `$identify` — there is no anonymous id to merge, since the caller-supplied id already *is* the persisted anonymous/device id), carrying any supplied `userProperties`/`userPropertiesSetOnce` (or empty `$set`/`$set_once` if none were supplied — the transition itself is the effect being recorded). The person-properties dedup hash is updated only *after* this event is captured, so a stale hash from an earlier no-op call cannot suppress the transition. Feature flags are reloaded only if properties were supplied (the identified-state flag alone is not part of the `/flags` request).
   - **Same distinct id, already identified, but userProperties / userPropertiesSetOnce provided** → emit `$set` (not `$identify`), with the new properties. Feature flags are **not** reloaded (property changes are processed async server-side). A hash check suppresses no-op duplicate calls with the same properties.
   - **Same distinct id, already identified, no properties** → log "already identified", drop.
   - **New distinct id but user is already identified** → in most SDKs, the call is logged and dropped; callers must `reset()` first to identify a different user. (Some SDKs always emit.)
4. **Construct the `$identify` event** with properties:
   - `$anon_distinct_id`: the pre-identify id (the anonymous / device id), **unless** `reuseAnonymousId` is true, in which case it is omitted and the anonymous id is not rotated.
   - `$set`: user properties to set (if provided).
   - `$set_once`: user properties to set only if unset (if provided).
   - Plus all normal capture enrichment (session id, super props, device info, etc.).
5. **Enqueue.** Same queue path as `capture`. Return to the caller immediately.

### Server-side flow

1. **Resolve identity.** Use the explicit `distinct_id` if supplied. If omitted, use the request-scoped analytics distinct id when available (including one extracted from sanitized tracing headers). Otherwise generate a fresh UUID for this event; do not persist it as an ambient identity or use it for feature-flag evaluation.
2. **Build the event.** `event = '$identify'`, root `distinct_id = resolved id`, `$set = caller-provided properties` (or, depending on SDK, `$set = properties` and `$set_once` from a separate option).
3. **Enrich.** Standard server enrichment: `$lib`, `$lib_version`, possibly `$geoip_disable`. If the id was generated, disable person-profile processing unless the caller explicitly supplied `$process_person_profile`: use `properties.$process_person_profile = false` on legacy `/batch/` delivery or `options.process_person_profile = false` on Capture v1 `/i/v1/analytics/events` delivery.
4. **Run `before_send` (if configured)**, same as `capture`.
5. **Submit for delivery.** Use the SDK's normal capture pipeline; a public flush makes the event observable at the receiver regardless of whether this SDK queues or sends immediately.
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

- Read request-scoped analytics identity, if present. Each call is independent; no per-user state is held or persisted by `identify`.

### Cross-SDK lifecycle notes

- **`reset()`** (client) clears the identified state: distinct id is regenerated, `isIdentified` → `false`, super properties and groups are cleared. The next `identify(newId)` call will freshly emit `$identify` with `$anon_distinct_id = <the fresh anonymous id>`.
- **`reuseAnonymousId` config** (when true): the client does **not** rotate the anonymous id on identify, and does not stamp `$anon_distinct_id`. The identified distinct id becomes the device's persistent id. Intended for apps where users are always logged-in (no anonymous phase).
- **`$identify` and `capture` ordering** matters: if a `$capture` event is emitted between two identify calls from different identities without a `reset()`, server-side ordering may mis-attribute events. Clients that change identity should always `reset()` on logout.

## Error handling

- **Never throw or reject** to the caller. An omitted server distinct id follows the context/UUID fallback instead of producing a validation error; SDKs that currently raise for this input need correction.
- **Drop silently** on: disabled SDK, opted-out user, invalid client-side distinct id, person-processing disabled, duplicate identified-user call with same properties, `before_send` returning null.
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

The SDK SHALL implement the canonical `identify` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below. Server SDKs MUST resolve an omitted per-call distinct id from request-scoped analytics context when available, otherwise generate a fresh UUID for the event and disable person-profile processing unless the caller explicitly supplied `$process_person_profile`. For legacy `/batch/` delivery, this control MUST be represented by `properties.$process_person_profile = false`; for Capture v1 `/i/v1/analytics/events` delivery, it MUST be represented by `options.process_person_profile = false` with no `$process_person_profile` sentinel left in `properties`. An explicit per-call distinct id MUST take precedence over context. Server `identify` MUST NOT throw or reject to the application when the distinct id is omitted. Generated ids MUST NOT be used for feature-flag evaluation or persisted as ambient user identity.

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

#### Scenario: Identify with a distinct id already matching the anonymous id transitions to identified (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current distinct id is "anon-123"
- **AND** the SDK has not yet identified a user
- **WHEN** identify is called with distinct id "anon-123"
- **THEN** get distinct id should return "anon-123"
- **AND** one event named "$set" should be enqueued
- **AND** no event named "$identify" should be enqueued

#### Scenario: Server identify delivers a profile update for explicit distinct id (@server)
- **GIVEN** an isolated SDK instance and a fresh receiver
- **AND** the SDK is initialized with token "test-token" and flush threshold 20
- **WHEN** identify is called with distinct id "user-123" and properties `{ "email": "user@test.test", "active": false, "score": 0, "note": null }`
- **AND** pending captures are flushed
- **THEN** exactly one capture request contains exactly one `$identify` event
- **AND** the received event's root `distinct_id` equals `user-123`
- **AND** its `$set` equals the supplied JSON object, preserving boolean, numeric and null values

#### Scenario: Server identify delivers nested user properties (@server)
- **GIVEN** an isolated SDK instance and a fresh receiver
- **AND** the SDK is initialized with token "test-token" and flush threshold 20
- **WHEN** identify is called with distinct id "user-456" and properties `{ "preferences": { "theme": "dark" }, "tags": ["beta", "team"] }`
- **AND** pending captures are flushed
- **THEN** exactly one capture request contains exactly one `$identify` event
- **AND** the received event's root `distinct_id` equals `user-456`
- **AND** its `$set` equals the supplied nested JSON object

#### Scenario: Server identify without explicit or contextual identity generates a personless UUID (@server)
- **GIVEN** an isolated server SDK instance with no request-scoped identity and a fresh receiver
- **AND** the SDK is initialized with token "test-token" and flush threshold 20
- **WHEN** identify is called with person properties and no explicit distinct id
- **AND** pending captures are flushed
- **THEN** exactly one capture request contains exactly one `$identify` event
- **AND** the received event's root `distinct_id` is a generated UUID
- **AND** its `$set` equals the supplied person properties
- **AND** the received event has `properties.$process_person_profile` equal to `false` on legacy `/batch/`, or `options.process_person_profile` equal to `false` and no `properties.$process_person_profile` on Capture v1 `/i/v1/analytics/events`
- **AND** the SDK call does not throw or reject

#### Scenario: Server identify uses request-scoped analytics identity before generating one (@server)
- **GIVEN** an isolated server SDK instance with request-scoped analytics distinct id "context-user"
- **WHEN** identify is called without an explicit distinct id
- **AND** pending captures are flushed
- **THEN** the received `$identify` event's root `distinct_id` is "context-user"
- **AND** the SDK call does not throw or reject

#### Scenario: Server identify uses the explicit id before request-scoped analytics identity (@server)
- **GIVEN** an isolated server SDK instance with request-scoped analytics distinct id "context-user"
- **WHEN** identify is called with explicit distinct id "explicit-user"
- **AND** pending captures are flushed
- **THEN** the received `$identify` event's root `distinct_id` is "explicit-user"

#### Scenario: Client identify validates missing distinct id (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** identify is called without a distinct id
- **THEN** identity state should not change
- **AND** no identity event should be enqueued
