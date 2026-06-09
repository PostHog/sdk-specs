# Alias Specification

## Purpose

`alias` links two distinct IDs so PostHog can treat them as belonging to the same person. It is typically used to connect an anonymous / temporary identifier to a newly-known user identifier after signup or login.

The canonical event emitted is **`$create_alias`**.

Unlike `identify`, `alias` does **not** change the SDK's ambient current user. It records a linkage event; it does not switch future captures to a new `distinct_id`.

## Applicability

`both` — client and server SDKs expose aliasing, but the call shape differs.

### Client vs. server semantics

| Concern | Client-side | Server-side |
| --- | --- | --- |
| Source `distinct_id` | Implicit: uses the SDK's current persisted distinct id. | Explicit: caller passes the existing / previous id. |
| Alias target id | Required method argument. | Required method argument / field. |
| Ambient identity mutation | None. Current distinct id remains unchanged. | None. Server SDKs are stateless per call. |
| Person-processing gating | Common on client SDKs; alias is dropped when person processing is disabled (`personProfiles == never`). | Usually no equivalent gate, though some SDKs can be configured into a personless mode. |
| Return value | Usually `void` / `Unit`. | Varies by SDK: UUID, bool, error, `ApiResult`, or `void`. |
| Typical use | Link current anonymous client id to a later known id. | Link a previously-used temporary/session id to a durable user id. |

## Public signatures

### Client-side canonical signature

```ts
alias(alias: string): void
```

The SDK resolves the source `distinct_id` from local state.

### Server-side canonical signature

```ts
alias(
  distinct_id: string,   // the existing / previous id to alias from
  alias: string,         // the new id to alias to
  options?: {
    timestamp?: Date,
    uuid?: string,
    disable_geoip?: boolean,
  },
): string | boolean | void | null
```

### Surface variants

- **posthog-js / browser / react-native / iOS / Android:** `alias(alias)` — only the target alias is passed; the current distinct id is read from local state.
- **flutter:** `alias({ alias }): Future<void>` — wrapper over the same current-distinct-id client alias concept.
- **Node:** `alias({ distinctId, alias, disableGeoip? })` and `aliasImmediate(...)`.
- **Python:** `alias(previous_id, distinct_id, timestamp=None, uuid=None, disable_geoip=None)` — note the second parameter is the new id.
- **Ruby:** `alias(distinct_id:, alias:, timestamp:, properties: ...)`.
- **PHP:** `PostHog::alias(['distinctId' => ..., 'alias' => ...])`.
- **Go:** `client.Enqueue(posthog.Alias{DistinctId, Alias, Timestamp, DisableGeoIP})`.
- **.NET:** `AliasAsync(previousId, newId, cancellationToken)`.

## Behavior

### Client-side flow

1. **Guard.** If the SDK is disabled, opted out, or configured to never process persons, drop the call.
2. **Resolve the source identity.** Read the current ambient `distinct_id` from persisted client state.
3. **Enable person processing.** In SDKs that track this flag, alias marks person processing as enabled for this client context.
4. **Build the event.** Emit an event with:
   - `event = '$create_alias'`
   - top-level `distinct_id = <current distinct id>`
   - `properties.alias = <caller-provided alias>`
   - normal client enrichment such as `$lib`, `$lib_version`, session props, super properties, and `$process_person_profile`
   Some stateless/server-oriented implementations also duplicate the source id into `properties.distinct_id`; audited mobile client helpers do not require that duplication.
5. **Enqueue.** Route the event through the same queue / request pipeline as `capture`.
6. **Do not mutate identity.** The current `distinct_id`, anonymous id, and identified flag remain unchanged. Future `capture(...)` calls continue using the same ambient distinct id until `identify(...)` or `reset()` changes it.

### Server-side flow

1. **Validate inputs.** Both the existing id and the alias target id must be present.
2. **Build the event.** Emit an event with:
   - `event = '$create_alias'`
   - top-level `distinct_id = <existing / previous id>`
   - `properties.alias = <new id>`
   - in most server SDKs, `properties.distinct_id = <existing / previous id>` as well
3. **Enrich.** Add standard server metadata such as `$lib`, `$lib_version`, timestamp, uuid, and optional `$geoip_disable`.
4. **Run `before_send` if supported.** Same hook path as `capture` / `identify`.
5. **Enqueue or send immediately.** Use the SDK's normal event delivery path.
6. **Return.** The return shape is SDK-specific and does not affect semantics.

## State & lifecycle

### Client-side state

`alias` reads:

- current `distinct_id`
- person-processing / opt-out config
- normal event-enrichment state (super properties, groups, session state)

`alias` writes only limited local bookkeeping:

- person-processing enabled flag, in SDKs that persist it
- normal queue state for the new outbound event

It does **not** write:

- a new ambient `distinct_id`
- a new anonymous id
- `isIdentified`

### Server-side state

None. Server alias calls are stateless apart from the shared outbound queue / worker.

### Lifecycle notes

- `alias` is usually followed by `identify` when the caller wants future events to use the new known user id.
- Calling `reset()` after alias clears the client's local identity state, but it does not retract or undo the already-enqueued alias event.
- On clients, alias may be enough to start person processing (`$process_person_profile = true`) even before a later `identify` call.

## Error handling

- Client SDKs generally no-op on disabled, opted-out, or `personProfiles == never` configurations.
- Server SDKs vary on invalid input: some drop / return failure, while others raise validation errors (for example Ruby and Go validators, plus PHP's public wrapper assertions).
- `before_send` returning `null` / `nil` drops the event in SDKs with that hook.
- Alias is fire-and-forget; enqueue / transport failures are typically logged or surfaced only through SDK-specific return values, not as rich synchronous error objects.

## Concurrency & ordering guarantees

- Alias uses the same queueing / synchronization primitives as `capture`.
- Ordering relative to nearby `capture` / `identify` calls is only as strong as the SDK's normal queue ordering guarantees.
- Because alias does not mutate local identity, concurrent captures keep using the pre-existing ambient `distinct_id` unless another call (`identify` / `reset`) changes it.

## Interactions

- **`identify`** — `identify` changes the ambient current user; `alias` only links ids. Many signup flows do both: first alias the anonymous id to the new user id, then identify as that user.
- **`capture`** — alias events travel through the same pipeline as capture, but alias does not alter subsequent capture identity.
- **`reset`** — reset clears local identity state; alias does not.
- **Person-processing controls** — client alias calls can enable person processing for future events.
- **Feature flags** — unlike `identify`, alias does not reload feature flags in the audited client SDKs.

## Requirements

### Requirement: Canonical alias behavior

The SDK SHALL implement the canonical `alias` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Client alias links the current anonymous identity to a known identity (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current distinct id is "anon-123"
- **WHEN** alias is called with alias "user-123"
- **THEN** one event named "$create_alias" should be enqueued
- **AND** the enqueued event distinct id should be "anon-123"
- **AND** the enqueued event properties should include:
  | property    | value    |
  | alias       | user-123 |
  | distinct_id | anon-123 |

#### Scenario: Server alias links explicit previous and new identities (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** alias is called with previous distinct id "anon-123" and distinct id "user-123"
- **THEN** one event named "$create_alias" should be enqueued
- **AND** the enqueued event distinct id should be "anon-123"
- **AND** the enqueued event properties should include:
  | property | value    |
  | alias    | user-123 |

#### Scenario: Alias is dropped when required identities are missing (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** alias is called without a previous distinct id
- **THEN** no event should be enqueued
- **AND** the SDK should record a validation warning
