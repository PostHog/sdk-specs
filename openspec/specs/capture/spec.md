# Capture Specification

## Purpose

`capture` records a single analytics event. It is the primary way PostHog SDKs produce event data. The method accepts an event name plus optional properties and enriches, serializes, and (typically) enqueues the event for eventual delivery to the PostHog ingestion endpoint (`/batch/` or `/capture/` depending on transport).

The canonical method name across official SDKs is **`capture`**. It has no widely-used aliases in PostHog SDKs; unlike some analytics vendors, PostHog does not expose `track` as a primary method.

## Applicability

`both` — every PostHog SDK (client and server) exposes a `capture` method, but with meaningful semantic differences.

### Client vs. server semantics

| Concern | Client-side (browser, ios, android, flutter, unity, react-native) | Server-side (python, node, ruby, php, go, java, dotnet, elixir, rails) |
| --- | --- | --- |
| `distinct_id` | Implicit. The SDK holds the current distinct id (set by `identify` or by an anonymous device id) and attaches it automatically. An optional override may be accepted. | Explicit. Required per-call argument (no ambient user state). |
| Super/registered properties | Supported; merged automatically into every event. | Not generally supported. Python exposes a similar concept via `identify_context`/`set_context_property`, but this is the exception. |
| Auto-properties (`$current_url`, `$screen_name`, `$os`, `$device_id`, etc.) | Auto-collected from the host environment. | Not collected. Only `$lib`, `$lib_version`, and caller-supplied properties are present. |
| Delivery | Typically one-event-per-request (or a small batch) via the browser/OS network stack, subject to `request_batching` settings and page-unload semantics. | Always batched. Events are pushed to an in-memory queue and flushed by a background worker on size/interval thresholds. |
| Ordering | Per-client, roughly FIFO but not guaranteed under page unload or background flush races. | Per-process, FIFO within a single queue flush; across flushes, ordering is best-effort. |
| Return value | Client SDKs typically return a result object (or `undefined` on drop). | Server SDKs typically return the event UUID (or nothing) — they cannot return a fully-materialized event because delivery is asynchronous. |
| Side effects on session state | Refreshes session timers, may update `$session_id`, updates persisted super properties, evaluates campaign/referrer params, runs autocapture hooks. | None. A capture call is a pure enqueue with no per-user bookkeeping. |

Despite these differences, the wire format of the emitted event is **identical** across client and server: the server SDKs produce the same shape of JSON envelope (`{event, distinct_id, properties, timestamp, uuid, ...}`) as client SDKs.

## Public signatures

### Client-side canonical signature

```ts
capture(
  event: string,
  properties?: Record<string, unknown> | null,
  options?: CaptureOptions,
): CaptureResult | undefined
```

Where the options bag may accept (non-exhaustive, varies by SDK):

- `timestamp?: Date` — override event timestamp
- `uuid?: string` — override event uuid
- `$set?: Record<string, unknown>` — merge into person properties
- `$set_once?: Record<string, unknown>` — merge into person properties if unset
- `send_instantly?: boolean` — bypass request batching
- `disable_geoip?: boolean`

Some mobile client SDKs flatten the options into positional/labeled arguments instead of a bag (e.g. iOS, Android — see below).

#### Mobile client variant (iOS, Android, Flutter, Unity)

```kotlin
capture(
  event: String,
  distinctId: String? = null,
  properties: Map<String, Any>? = null,
  userProperties: Map<String, Any>? = null,         // emitted as $set
  userPropertiesSetOnce: Map<String, Any>? = null,  // emitted as $set_once
  groups: Map<String, String>? = null,
  timestamp: Date? = null,
)
```

This shape is the convention for `posthog-android` (Kotlin) and `posthog-ios` (Swift). `userProperties` and `userPropertiesSetOnce` are transformed into `$set` / `$set_once` on the outgoing event payload. The `distinctId` argument is an **override** — if omitted, the SDK's ambient distinct id is used.

### Server-side canonical signature

```ts
capture(
  distinct_id: string,
  event: string,
  properties?: Record<string, unknown>,
  options?: {
    timestamp?: Date,
    uuid?: string,
    groups?: Record<string, string | number>,
    send_feature_flags?: boolean | SendFeatureFlagsOptions,
    disable_geoip?: boolean,
  },
): string | null   // returns the event UUID (or null on drop)
```

Server SDKs vary in surface — Python uses keyword arguments, Go uses a `Capture` struct passed to `Enqueue`, Ruby uses an attribute hash — but the required data is consistent: `distinct_id` and `event` are mandatory; everything else is optional.

#### Enqueue-style variant (Go, .NET)

Some server SDKs expose a generic `Enqueue(message)` / `Capture(CaptureMessage)` pattern where `capture` is one of several message types (alongside `Identify`, `Alias`, `GroupIdentify`). The validation rules are the same: event and distinct_id are required.

## Behavior

The following steps are the canonical flow for a single capture call. Client and server paths diverge around step 4 (enrichment) and step 7 (delivery); common steps apply to both.

1. **Disabled/opt-out short-circuit.** If the SDK has been disabled (`disabled=true`) or the user/process has opted out (`opt_out=true`), the call returns immediately with no event emitted. Opt-out state is usually persisted client-side and in-memory server-side.
2. **Validate inputs.** Event name must be a non-empty string. On server SDKs, `distinct_id` must also be present and non-empty (Go and .NET enforce this with explicit validation errors; Python and Ruby stringify whatever is passed). On client SDKs, an uninitialized instance short-circuits with a warning.
3. **Resolve `distinct_id`.**
   - Client: use the caller-provided override, else the SDK's current distinct id (set by `identify` or by the anonymous device id generated at first init).
   - Server: use the caller-provided `distinct_id`. If the SDK supports a "context" abstraction (Python), fall back to the context's current distinct id.
4. **Enrich properties.** A new properties dictionary is constructed by merging in this order (later values win):
   1. Caller-supplied `properties`.
   2. SDK environment properties (client-side: `$current_url`, `$host`, `$pathname`, `$browser`, `$os`, `$screen_height`, `$device_type`, etc.; mobile adds `$screen_name`, `$app_version`, `$device_manufacturer`; all: `$lib`, `$lib_version`).
   3. Super/registered properties (client-side only).
   4. Feature flag properties (`$feature/<key>`, `$active_feature_flags`) if `send_feature_flags` is truthy and flags are known locally or can be fetched.
   5. Person-processing hints (`$process_person_profile`, `$is_identified`) based on current identity state.
   6. Session properties (`$session_id`, `$window_id`) on client SDKs that support session replay.
   7. `$groups` if the event was called with group info or the client has registered groups.
5. **Attach envelope fields.** Assign `timestamp` (caller override or `now()` in ISO 8601 with timezone), `uuid` (caller override or a freshly generated UUIDv7), `distinct_id`, and `event` to the message. Server SDKs additionally stamp `$lib` / `$lib_version` onto properties here if not already present.
6. **Run `before_send` hook.** If the SDK has been configured with a `before_send` callback (Python, Go, posthog-js, .NET), invoke it with the fully-assembled message. The callback may return a modified message, or return `null`/`None` to drop the event. An exception inside the callback is logged and the original message is used (server SDKs) or the event is dropped (varies — follow the SDK's documented platform variation).
7. **Deliver.**
   - **Server (and `posthog-node`, `posthog-js/core` stateless):** push onto an in-memory queue (`max_queue_size` default 10,000). If the queue is full, drop the oldest element and log a warning (posthog-js core; `posthog-python` drops the new element). If queue size ≥ `flush_at` (default 20 client/core, 100 python-server), kick off a background flush. A periodic timer (`flush_interval`, typically 10s client / 10s–30s server) also triggers flushes.
   - **Client (browser):** forward to the request queue (`_requestQueue.enqueue`) unless `send_instantly` is set or batching is disabled, in which case send directly via `_send_retriable_request`. Flushes are opportunistic and aligned with network availability / page lifecycle (e.g. `sendBeacon` on `pagehide`).
8. **Return.** Client SDKs return a `CaptureResult` object containing the event data (or `undefined` if dropped). Server SDKs return the generated UUID string (or `null`/`None` if dropped).

## State & lifecycle

- **Ambient state read** (client only): current distinct id, `$device_id`, `$session_id`/`$window_id`, super properties, registered groups, opt-out flag, person-processing flag.
- **Ambient state written** (client only): session timers (event activity resets session expiry), initial campaign/referrer props on first capture per session, persisted super properties when survey/tour events are captured, `set_once` sent-tracking to avoid re-sending initial props.
- **Server:** no per-user state is read or written. The only shared state touched is the outgoing queue, the global `before_send` callback, and (optionally) the feature flag cache for `send_feature_flags`.
- **Bookkeeping:** `capture` does not persist the event locally beyond the in-flight queue. Once the background flush succeeds, the queue entry is removed. On a failed flush, events return to the front of the queue (see the retry queue spec).

## Error handling

- **Drop silently** on: disabled SDK, opted-out user, empty/invalid event name, invalid distinct id (server), `before_send` returning null, bot user-agent (browser only, when `opt_out_useragent_filter` is false), client-side rate limit (browser only).
- **Log and swallow** internal exceptions (property enrichment failures, feature-flag-fetch errors, before_send exceptions). A failure to enqueue must not surface as an exception to the caller — the contract is that `capture` is fire-and-forget.
- **Return sentinel** (`null`/`None`/`undefined`) when a drop occurs and the SDK's signature lets it express that. Some SDKs (Go, Java) lack a return value and communicate failure only via logging.
- **Never throw** to the caller under normal operation. Capture is latency-sensitive and lives on the hot path of application code; SDKs are expected to absorb all I/O and serialization errors internally.

## Concurrency & ordering

- Capture is **thread-safe / task-safe** in every SDK. Server SDKs protect the queue with a lock (Python `queue.Queue`, Go channel, Ruby Mutex); client SDKs serialize via the single-threaded JS event loop or with an OS-level concurrent queue (iOS `PostHogQueue`, Android executor).
- **Ordering within a queue** is FIFO. Ordering **across flushes** is best-effort — a slow batch can be overtaken by a later one if both are in flight.
- `sync_mode` (Python) / `sendImmediate` (posthog-js core) bypass the queue entirely and deliver synchronously. These are meant for short-lived processes (scripts, serverless) and should not be used in high-throughput paths.
- Client-side `send_instantly: true` bypasses the batcher for a single call but still respects rate limits and the before_send hook.

## Interactions

- **`identify`** — establishes the ambient distinct id (client) and the `$is_identified=true` flag that capture subsequently stamps onto events.
- **`register` / `unregister`** (client) — mutate the super properties that capture merges into every event.
- **`group` / `group_identify`** — populate the `$groups` property that capture attaches to each event.
- **`alias`** — internally dispatches a `capture` call with event name `$create_alias`.
- **Feature flags** — when `send_feature_flags` is enabled, capture calls into the flag evaluator (local or remote) to stamp `$feature/<key>` and `$active_feature_flags` onto the event.
- **Session replay** — on client SDKs that support replay, capture updates session state so that replay snapshots remain attached to the same `$session_id`.
- **Autocapture / pageview / heatmaps** — these features internally call capture with reserved event names (`$autocapture`, `$pageview`, `$pageleave`, `$heatmap`, `$web_vitals`).
- **Exception capture** — `captureException` wraps `capture` with event name `$exception` and a normalized stacktrace property. Calling `capture('$exception', ...)` directly produces a warning in SDKs that ship `captureException` (posthog-js, posthog-python).
- **Before-send hook / privacy filters** — capture is the integration point for drop/mutate hooks; see the before-send hook spec.

## Requirements

### Requirement: Canonical capture behavior

The SDK SHALL implement the canonical `capture` behavior described by this spec. Implementations MAY adapt method names, parameter casing, type syntax, and lifecycle hooks to platform idioms where this spec explicitly allows variation, but MUST preserve the observable outcomes in the scenarios below.

#### Scenario: Client capture enriches an event with ambient context (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** the current distinct id is "user-123"
- **AND** the current session id is "session-123"
- **AND** registered properties are:
  | property | value |
  | plan     | pro   |
- **WHEN** capture is called with event "Signed Up" and properties:
  | property | value |
  | source   | ad    |
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event distinct id should be "user-123"
- **AND** the enqueued event properties should include:
  | property    | value       |
  | source      | ad          |
  | plan        | pro         |
  | $session_id | session-123 |
- **AND** the enqueued event should include a timestamp and uuid

#### Scenario: Server capture requires an explicit distinct id (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** capture is called with distinct id "user-123", event "Signed Up", and properties:
  | property | value |
  | source   | api   |
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event distinct id should be "user-123"
- **AND** the enqueued event properties should include:
  | property | value |
  | source   | api   |
  | $lib     | any   |
- **AND** the enqueued event should include an event uuid

#### Scenario: Capture honors opt-out state (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** analytics capture is opted out
- **WHEN** capture is called with event "Ignored Event"
- **THEN** no event should be enqueued
- **AND** no network request should be sent

#### Scenario: Capture can be modified or dropped by before-send (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** before-send adds property "filtered" with value "yes"
- **WHEN** capture is called with event "Filtered Event"
- **THEN** one event named "Filtered Event" should be enqueued
- **AND** the enqueued event property "filtered" should equal "yes"
- **WHEN** before-send is changed to drop every event
- **AND** capture is called with event "Dropped Event"
- **THEN** no event named "Dropped Event" should be enqueued
