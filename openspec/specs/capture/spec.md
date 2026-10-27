# Capture Specification

## Purpose

`capture` records a single analytics event. It is the primary way PostHog SDKs produce event data. The method accepts an event name plus optional properties and enriches, serializes, and (typically) enqueues the event for eventual delivery to the PostHog ingestion endpoint. Legacy capture delivers to `/batch/` or `/capture/`; capture v1 delivers to `/i/v1/analytics/events`, with AI events on `/i/v1/ai/events` (see `capture-ai`). The server SDKs move to capture v1 in posthog-python 8.0, posthog-go v2, posthog-rs 1.0 and posthog-node 6.0.

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
   - **Client:**
     1. Properties the SDK sets itself, such as SDK environment and feature flag properties, `$groups` from registered groups (the event's group wins per group type), `$is_identified` and `$process_person_profile`.
     2. Super/registered properties.
     3. Caller-supplied `properties`. These win over everything above, and `before_send` (step 6) can change the result (see **Caller-supplied event properties take precedence**).
   - **Server, capture v1:** the call's `properties` and `options` win. The ambient request context, then the SDK-level default properties and options, then the values the SDK adds itself (`$is_server`, `$geoip_disable` from the client setting, system context, the `$feature/<key>` and `$active_feature_flags` properties derived from a flags snapshot or `send_feature_flags`, `$release_id`, and `$trace_id` with `$span_id` where the SDK derives them) fill only the keys the layers above left unset. `$groups` comes from the `groups` option, merged key by key over a `$groups` property. See **Server SDKs build every event in one layer order**.
   - **Server, legacy capture:** request-context properties, then caller-supplied `properties`, then SDK-stamped properties. Server SDKs on legacy capture stamp `$lib` and `$lib_version` over the caller's values, and posthog-python 7.x, posthog-go 1.x, dotnet (`SuperProperties`) and elixir (`global_properties`) apply their SDK-level default properties after the caller's properties too.
5. **Attach envelope fields.** Assign `timestamp` (caller override or `now()`, serialized in ISO 8601 and normalized to its equivalent UTC instant regardless of the input's original timezone/offset, preserving sub-second precision when the input carries it), `uuid` (caller override or a freshly generated UUIDv7; server SDKs normalize it to canonical lowercase hyphenated form), `distinct_id`, and `event` to the message. Server SDKs on legacy capture additionally stamp `$lib` / `$lib_version` onto properties here if not already present. On capture v1 the SDK never writes `$lib` or `$lib_version` into `properties`; the server derives them from the `PostHog-Sdk-Info` request header (see **Library identity comes from the request header**).
6. **Run `before_send` hook.** If the SDK has been configured with a `before_send` callback (Python, Go, posthog-js, .NET), invoke it with the fully-assembled message. The callback may return a modified message, or return `null`/`None` to drop the event. If the callback throws, log a warning, stop the hook chain, and drop the event. Never enqueue the original or partially processed message after a hook failure. Server SDKs re-normalize the message `uuid` after the hook returns, because the hook may have replaced it with another accepted form. On capture v1 the legacy option properties are hoisted into `options` after the hook returns (see **Per-event options replace the legacy option properties**).
7. **Deliver.**
   - **Server (and `posthog-node`, `posthog-js/core` stateless):** push onto an in-memory queue (`max_queue_size` default 10,000). If the queue is full, drop the oldest element and log a warning (posthog-js core; `posthog-python` drops the new element). If queue size ≥ `flush_at` (default 20 client/core, 100 python-server), kick off a background flush. A periodic timer (`flush_interval`, typically 10s client / 10s–30s server) also triggers flushes. On capture v1 the SDK keeps one queue, flush cycle and retry state per delivery lane (analytics and AI), so a slow or failing AI lane never delays or resends analytics events.
   - **Client (browser):** forward to the request queue (`_requestQueue.enqueue`) unless `send_instantly` is set or batching is disabled, in which case send directly via `_send_retriable_request`. Flushes are opportunistic and aligned with network availability / page lifecycle (e.g. `sendBeacon` on `pagehide`).
8. **Return.** Client SDKs return a `CaptureResult` object containing the event data (or `undefined` if dropped). Server SDKs return the UUID string that was sent — the normalized, canonical form (or `null`/`None` if dropped).

## State & lifecycle

- **Ambient state read** (client only): current distinct id, `$device_id`, `$session_id`/`$window_id`, super properties, registered groups, opt-out flag, person-processing flag.
- **Ambient state written** (client only): session timers (event activity resets session expiry), initial campaign/referrer props on first capture per session, persisted super properties when survey/tour events are captured, `set_once` sent-tracking to avoid re-sending initial props.
- **Server:** no per-user state is read or written. The only shared state touched is the outgoing queue, the global `before_send` callback, and (optionally) the feature flag cache for `send_feature_flags`.
- **Bookkeeping:** `capture` does not persist the event locally beyond the in-flight queue. Once the background flush succeeds, the queue entry is removed. On a failed flush, events return to the front of the queue (see the retry queue spec).

## Error handling

- **Drop silently** on: disabled SDK, opted-out user, empty/invalid event name, invalid distinct id (server SDKs on legacy capture; on capture v1 an empty or whitespace-only distinct id is treated as missing, giving a personless event with a generated id or the SDK's existing error, and the event is never sent without a `distinct_id`), `before_send` returning null, bot user-agent (browser only, when `opt_out_useragent_filter` is false), client-side rate limit (browser only).
- **Log and drop** when `before_send` throws. The SDK must not enqueue a fallback event because the failed hook may have been responsible for removing sensitive data.
- **Log and swallow** other internal exceptions such as property enrichment or feature-flag-fetch failures. A failure to enqueue must not surface as an exception to the caller — the contract is that `capture` is fire-and-forget.
- **Return sentinel** (`null`/`None`/`undefined`) when a drop occurs and the SDK's signature lets it express that. Some SDKs (Go, Java) lack a return value and communicate failure only via logging.
- **Log and replace** (server SDKs) a caller-supplied `uuid` that cannot be parsed as a uuid, substituting a freshly generated UUIDv7. An unusable uuid override must not cost the caller the event.
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

#### Scenario: Capture drops an immediately delivered event when before-send throws (@both)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **AND** capture is configured for immediate delivery
- **AND** before-send throws an exception
- **WHEN** capture is called with event "Sensitive Event"
- **THEN** the capture call should not throw
- **AND** no event named "Sensitive Event" should be enqueued
- **AND** no network request should be sent
- **AND** the SDK should record a before-send warning

### Requirement: Capture drops null-valued object properties

The SDK SHALL omit custom event object properties whose values are explicit nulls (for example Python `None`, JavaScript `null`, or Swift `NSNull()`) or `undefined` where supported by the runtime, when serializing events for wire delivery or disk-backed event queues/caches. A null/undefined-valued property SHALL NOT cause an otherwise valid, previously supported capture call to be rejected. The SDK MUST NOT serialize that object member as JSON `null` or convert its value to the string `"null"` or `"undefined"`.

This is a serialization rule, not a public API restriction. If an SDK's public capture API already accepts null/undefined property values, it SHALL continue accepting them with the same signatures and property value types. Implementations MUST NOT narrow those types, introduce null/undefined input validation errors for previously supported values, or require callers to pre-filter properties to comply. The rule does not require widening APIs that do not currently accept those values. In-memory event representations MAY retain them until serialization. This compatibility rule also applies to the AI and exception capture methods that inherit this requirement.

This cleanup SHALL apply recursively to nested objects, including objects inside arrays. Null array elements SHALL remain JSON `null` at their original indices; cleanup MUST NOT compact or reorder arrays. JavaScript undefined array entries SHALL follow normal JSON serialization as null array elements without changing their positions. Other values, including `false`, `0`, empty strings, the literal strings `"null"` and `"undefined"`, and empty objects/arrays, SHALL remain unchanged by this cleanup. Objects made empty by removing null/undefined-valued members SHALL remain `{}`, including when they occupy an array slot. If all custom properties are removed, the SDK SHALL still send an otherwise admissible event with its normal SDK metadata.

The same rule SHALL apply to queued and immediate/synchronous capture. The wire payload SHALL satisfy it after enrichment and `before_send` processing, including for null/undefined-valued custom object members introduced by a hook. Each disk serialization of a captured event SHALL apply the same object-member cleanup to the event being written; cleanup only at network send time is insufficient for SDKs that persist events. This does not require adding disk persistence or changing hook timing. Events restored from disk SHALL also satisfy the wire serialization rule. Missing custom keys MUST NOT be synthesized. Caller-configured privacy filtering and event drops remain authoritative; cleanup MUST NOT restore removed data.

This requirement concerns custom event property values, not a missing/null properties container, required envelope fields, or reserved fields with their own type/validation contracts. It does not change those field-specific rules, unrelated persistent-storage/cache semantics, or the OTLP attribute rules for logs and traces.

#### Scenario: Queued capture drops null-valued properties and preserves array positions (@both)
- **GIVEN** an initialized SDK with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Nullable Properties" and custom properties represented by JSON `{"test":null,"nested":{"drop":null},"items":["1",null,2,{"drop":null},[null]],"empty":"","zero":0,"enabled":false,"literal":"null","emptyArray":[]}`
- **AND** the SDK is flushed
- **THEN** one event named "Nullable Properties" should be received
- **AND** its custom properties should equal JSON `{"nested":{},"items":["1",null,2,{},[null]],"empty":"","zero":0,"enabled":false,"literal":"null","emptyArray":[]}`
- **AND** the absent custom property "missing" should remain absent

#### Scenario: Immediate capture drops null-valued properties and preserves array positions (@both)
- **GIVEN** an initialized SDK supporting immediate delivery with a valid distinct id and no property-changing hooks or filters
- **AND** capture is configured for immediate delivery
- **WHEN** capture is called with event "Nullable Properties" and custom properties represented by JSON `{"test":null,"nested":{"drop":null},"items":["1",null,2,{"drop":null},[null]]}`
- **AND** the immediate send completes
- **THEN** one event named "Nullable Properties" should be received
- **AND** its custom properties should equal JSON `{"nested":{},"items":["1",null,2,{},[null]]}`

#### Scenario: All-null custom properties do not drop the event (@both)
- **GIVEN** an initialized SDK with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Only Null Properties" and custom properties represented by JSON `{"test":null}`
- **AND** the SDK is flushed
- **THEN** one event named "Only Null Properties" should be received
- **AND** its custom properties should equal JSON `{}`
- **AND** it should retain its normal SDK metadata

#### Scenario: Null object properties introduced by before-send are omitted (@both)
- **GIVEN** an initialized SDK supporting before-send with a valid distinct id
- **AND** before-send adds custom properties represented by JSON `{"hookNull":null,"hookItems":[null,{"drop":null}]}`
- **WHEN** capture is called with event "Hook Properties" and no custom properties
- **AND** the SDK is flushed
- **THEN** one event named "Hook Properties" should be received
- **AND** its custom properties should equal JSON `{"hookItems":[null,{}]}`

#### Scenario: JavaScript null and undefined object properties are omitted (@both)
- **GIVEN** an initialized JavaScript SDK with a valid distinct id and no property-changing hooks or filters
- **WHEN** capture is called with event "Null And Undefined" and JavaScript properties `{ test: null, missing: undefined, items: ["1", null, 2] }`
- **AND** the SDK is flushed
- **THEN** one event named "Null And Undefined" should be received
- **AND** its custom properties should equal JSON `{"items":["1",null,2]}`

#### Scenario: Existing nullable capture inputs remain supported (@both)
- **GIVEN** the SDK's existing public capture API accepts null or undefined property values
- **AND** an existing caller supplies those values using the supported public property types
- **WHEN** the SDK adopts the serialization cleanup rule
- **THEN** the same caller code should remain accepted by the public API, including compilation/type-checking where enforced
- **AND** capture should not reject the call or require caller-side filtering solely because of those values
- **AND** serializing the captured event should omit null/undefined-valued object members while preserving array positions

#### Scenario: Disk-backed event serialization omits null object properties (@both)
- **GIVEN** an initialized SDK with disk-backed event persistence, a valid distinct id, and no property-changing hooks or filters
- **AND** network delivery is paused
- **WHEN** capture is called with event "Persisted Properties" and custom properties represented by JSON `{"test":null,"nested":{"drop":null},"items":["1",null,2,{"drop":null}]}`
- **AND** the SDK serializes the queued event to disk
- **THEN** the persisted event's decoded custom properties should equal JSON `{"nested":{},"items":["1",null,2,{}]}`
- **AND** no network request should have been sent
- **WHEN** the persisted event is restored and delivered
- **THEN** the received event's custom properties should equal JSON `{"nested":{},"items":["1",null,2,{}]}`

#### Scenario: JavaScript disk serialization omits undefined object members without compacting arrays (@both)
- **GIVEN** an initialized JavaScript SDK with disk-backed event persistence, a valid distinct id, and no property-changing hooks or filters
- **AND** network delivery is paused
- **WHEN** capture is called with event "Persisted Undefined" and JavaScript properties `{ test: null, missing: undefined, nested: { missing: undefined }, items: ["1", undefined, null, 2], literal: "undefined" }`
- **AND** the SDK serializes the queued event to disk
- **THEN** the persisted event's decoded custom properties should equal JSON `{"nested":{},"items":["1",null,null,2],"literal":"undefined"}`
- **AND** no network request should have been sent
- **WHEN** the persisted event is restored and delivered
- **THEN** the received event's custom properties should equal JSON `{"nested":{},"items":["1",null,null,2],"literal":"undefined"}`

### Requirement: Environment-sourced release identifier

A server SDK that can read its process environment SHALL resolve a release identifier from the `POSTHOG_RELEASE_ID` environment variable and report it as the `$release_id` event property.

The SDK SHALL read the variable once, while the client is constructed, and reuse that value for the client's lifetime. The raw value SHALL be trimmed of surrounding whitespace, and a missing, empty, or whitespace-only value SHALL count as unset. When the value is unset, the SDK SHALL omit `$release_id` rather than sending an empty string.

When the value is set, the SDK SHALL stamp `$release_id` on the shared event path that its public event-producing methods pass through, so ordinary captures, exception captures, person-property events (`$identify`, or `$set`/`$set_once` on SDKs without `identify`), `alias`, and `group_identify` events all carry it. Low-level passthrough APIs that deliberately bypass that shared path are outside this requirement.

The environment value SHALL act as a default, not an override: an explicit `$release_id` supplied in the call's properties, in super/registered properties, or in an ambient request context SHALL win. The SDK SHALL stamp `$release_id` before `before_send` runs, so a hook can inspect, replace, or remove it. The SDK SHALL NOT copy the value into `$set`, `$set_once`, or `$group_set`, because a release identifier is event context rather than a person or group property.

`$release_id` is a static, low-cardinality runtime identity property in the sense of the `feature-flag-called-tracker` minimal-event allowlist, so a minimized `$feature_flag_called` event SHALL retain it when the SDK stamped it.

#### Scenario: Release id from the environment lands on an ordinary event (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to "rel-abc123" before the client is constructed
- **WHEN** capture is called with event "Save"
- **THEN** the enqueued "Save" event should have property "$release_id" equal to "rel-abc123"

#### Scenario: An empty environment value is treated as unset (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to the empty string before the client is constructed
- **WHEN** capture is called with event "Save"
- **THEN** the enqueued "Save" event should omit "$release_id"

#### Scenario: A whitespace-only environment value is treated as unset (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to a value containing only spaces before the client is constructed
- **WHEN** capture is called with event "Save"
- **THEN** the enqueued "Save" event should omit "$release_id"

#### Scenario: Surrounding whitespace is trimmed (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to " rel-abc123 " before the client is constructed
- **WHEN** capture is called with event "Save"
- **THEN** the enqueued "Save" event should have property "$release_id" equal to "rel-abc123"

#### Scenario: Every shared-path event type carries the release id (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to "rel-abc123" before the client is constructed
- **WHEN** the SDK produces an event of type "<event>"
- **THEN** the enqueued event should have property "$release_id" equal to "rel-abc123"
  Examples:
  | event          |
  | $exception     |
  | $create_alias  |
  | $groupidentify |

#### Scenario: The person-properties event carries the release id (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to "rel-abc123" before the client is constructed
- **WHEN** the SDK sets person properties for distinct id "user-1" with "plan" equal to "pro"
- **THEN** the enqueued person-properties event ("$identify", or "$set" on SDKs without `identify`) should have property "$release_id" equal to "rel-abc123"

#### Scenario: An explicit release id wins over the environment (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to "rel-from-env" before the client is constructed
- **WHEN** capture is called with event "Save" and property "$release_id" equal to "rel-explicit"
- **THEN** the enqueued "Save" event should have property "$release_id" equal to "rel-explicit"

#### Scenario: An ambient context release id wins over the environment (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to "rel-from-env" before the client is constructed
- **AND** the SDK's ambient context (registered properties where supported, otherwise the request context) carries "$release_id" equal to "rel-context"
- **WHEN** capture is called with event "Save"
- **THEN** the enqueued "Save" event should have property "$release_id" equal to "rel-context"

#### Scenario: before_send can remove the release id (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to "rel-abc123" before the client is constructed
- **AND** a before_send hook that deletes "$release_id" from the event properties
- **WHEN** capture is called with event "Save"
- **THEN** the delivered "Save" event should omit "$release_id"

#### Scenario: The release id stays out of person properties (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to "rel-abc123" before the client is constructed
- **WHEN** the SDK sets person properties for distinct id "user-1" with "plan" equal to "pro"
- **THEN** the enqueued event properties should have "$release_id" equal to "rel-abc123"
- **AND** "$set" and "$set_once" should omit "$release_id"

#### Scenario: The release id stays out of group properties (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to "rel-abc123" before the client is constructed
- **WHEN** group identify is called for group type "company" and key "id:5" with "name" equal to "Acme"
- **THEN** the enqueued "$groupidentify" event should have property "$release_id" equal to "rel-abc123"
- **AND** "$group_set" should omit "$release_id"

#### Scenario: A minimized flag-called event keeps the release id (@server)
- **GIVEN** `POSTHOG_RELEASE_ID` is set to "rel-abc123" before the client is constructed
- **AND** the server reports the minimal flag-called event gate for flag "beta-ui" with experiment linkage exactly `false`
- **WHEN** get feature flag "beta-ui" is called
- **THEN** the enqueued "$feature_flag_called" event should be minimized per the allowlist
- **AND** it should have property "$release_id" equal to "rel-abc123"

### Requirement: Caller-supplied event properties take precedence

On client SDKs, an event's properties SHALL be merged in this order, each layer overwriting the one before:

1. Properties the SDK sets itself.
2. Registered (super) properties.
3. The properties the caller passes on the event.

`before_send` (Behavior step 6) then runs over the assembled message and can change any of them.

A registered or caller value for a key the SDK sets itself changes that event only. It SHALL NOT change the SDK's own state: a later event without that key carries the SDK's value again, and a caller `$process_person_profile` does not turn person processing on or off for the SDK.

The project token is request routing, not an event property. Where an SDK carries it on the event (posthog-js stamps `token` on every event and takes the batch `api_key` from it), the SDK SHALL set the configured token on every event, and a registered or caller `token` SHALL NOT replace it.

A group the caller passes for the event SHALL win over a registered group of the same type.

This requirement does not apply to server SDKs. Server SDKs that deliver through capture v1 follow **Server SDKs build every event in one layer order**: the call's values win, and `$lib` and `$lib_version` come from the request header. Server SDKs still on legacy capture set `$lib` and `$lib_version` after the caller's properties, and python 7.x, go 1.x, dotnet and elixir apply their SDK-level default properties after the caller's properties as well.

#### Scenario: Caller property overrides an SDK context property (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** capture is called with event "Signed Up" and properties:
  | property | value      |
  | $lib     | custom-lib |
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event properties should include:
  | property | value      |
  | $lib     | custom-lib |

#### Scenario: Registered property overrides an SDK-set property (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and person profiles mode "never"
- **AND** registered properties are:
  | property       | value |
  | $is_identified | true  |
- **WHEN** capture is called with event "Signed Up"
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event properties should include:
  | property       | value |
  | $is_identified | true  |

#### Scenario: Caller property overrides an SDK-set property (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and person profiles mode "never"
- **WHEN** capture is called with event "Signed Up" and properties:
  | property                | value |
  | $process_person_profile | true  |
  | $is_identified          | true  |
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event properties should include:
  | property                | value |
  | $process_person_profile | true  |
  | $is_identified          | true  |

#### Scenario: Caller property changes that event only (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and person profiles mode "never"
- **WHEN** capture is called with event "Signed Up" and properties:
  | property                | value |
  | $process_person_profile | true  |
  | $is_identified          | true  |
- **AND** capture is called with event "Viewed Dashboard"
- **THEN** one event named "Viewed Dashboard" should be enqueued
- **AND** the enqueued "Viewed Dashboard" event properties should include:
  | property                | value |
  | $process_person_profile | false |
  | $is_identified          | false |

### Requirement: Client-level GeoIP control with per-call override

A server SDK SHALL expose a client-level GeoIP option (`disableGeoip`, `disable_geoip`, or the
platform's casing) that controls whether the events it sends ask the backend to skip GeoIP
enrichment. That option SHOULD default to disabling enrichment: server SDKs send events from
their own network, so enriching them would attribute every event to the server's location.
posthog-php and posthog-rs currently default to enabling enrichment. Changing a shipped default
is a breaking change, so each SDK makes it, if at all, in its next major release. Client SDKs
SHALL NOT require the option: they run in the end user's network context, where GeoIP
enrichment is the intended behavior.

Event-producing APIs that accept options — at least `capture`, `identify`, `alias`, and
`group_identify` — SHALL accept the same option per call. A per-call value that is not set
(omitted or null) SHALL inherit the client-level setting and SHALL NOT be read as `false`. An
explicitly set per-call value SHALL override the client-level setting in both directions: an
explicit `false` SHALL re-enable GeoIP enrichment for that call even when the client-level
setting disables it.

An SDK whose shipped per-call option can't represent "not set", such as posthog-go's
non-nullable `DisableGeoIP` message field, conforms by keeping the client-level setting
authoritative for that API until a major release lets it tell an unset value from an explicit
one. It SHALL NOT read the zero value as an explicit `false`. Scenarios that need an explicit
per-call override on an event API are tagged `@geoip_per_call_unset_capable`.

When the effective value disables GeoIP, the SDK SHALL mark the event with
`$geoip_disable: true` among the event's ordinary properties and SHALL stamp it before
`before_send` runs, so a hook can inspect, replace, or remove it. The marker SHALL NOT be copied
into `$set`, `$set_once`, or `$group_set`, because it is event context rather than a person or
group property. When the effective value does not disable GeoIP, the SDK SHALL omit the marker
and SHALL NOT remove a `$geoip_disable` property the caller supplied in the call's properties.

A remote feature-flag evaluation request SHALL carry the same effective value as the
`geoip_disable` field of its request body, resolved from the per-call option where the flag API
exposes one and otherwise from the client-level setting.

`$geoip_disable` is a processing-control sentinel in the sense of the
`feature-flag-called-tracker` minimal-event allowlist, so a minimized `$feature_flag_called`
event SHALL retain it when the SDK stamped it.

#### Scenario: The client-level setting marks an ordinary event (@server)
- **GIVEN** the client is constructed with the GeoIP option set to disable enrichment
- **WHEN** capture is called with event "Save" and no per-call GeoIP option
- **THEN** the enqueued "Save" event should have property "$geoip_disable" equal to true

#### Scenario: An explicit per-call false re-enables enrichment for one call (@server @geoip_per_call_unset_capable)
- **GIVEN** the client is constructed with the GeoIP option set to disable enrichment
- **WHEN** capture is called with event "Save" and the per-call GeoIP option set to false
- **THEN** the enqueued "Save" event should omit "$geoip_disable"
- **WHEN** capture is called with event "Save Again" and no per-call GeoIP option
- **THEN** the enqueued "Save Again" event should have property "$geoip_disable" equal to true

#### Scenario: An omitted per-call value inherits an enabled client setting (@server)
- **GIVEN** the client is constructed with the GeoIP option set to allow enrichment
- **WHEN** capture is called with event "Save" and no per-call GeoIP option
- **THEN** the enqueued "Save" event should omit "$geoip_disable"

#### Scenario: A caller-supplied marker survives an enabled client setting (@server)
- **GIVEN** the client is constructed with the GeoIP option set to allow enrichment
- **WHEN** capture is called with event "Save" and properties:
  | property        | value |
  | $geoip_disable  | true  |
- **THEN** the enqueued "Save" event should have property "$geoip_disable" equal to true

#### Scenario: Group identify carries the marker outside $group_set (@server)
- **GIVEN** the client is constructed with the GeoIP option set to disable enrichment
- **WHEN** group identify is called for group type "company" and key "acme" with properties:
  | property | value |
  | name     | Acme  |
- **THEN** the enqueued "$groupidentify" event should have property "$geoip_disable" equal to true
- **AND** the enqueued "$groupidentify" event "$group_set" should omit "$geoip_disable"

#### Scenario: A flag evaluation request carries the effective value (@server)
- **GIVEN** the client is constructed with the GeoIP option set to disable enrichment
- **WHEN** a remote feature-flag evaluation request is made with no per-call GeoIP option
- **THEN** the request body field "geoip_disable" should be true
- **WHEN** a remote feature-flag evaluation request is made with the per-call GeoIP option set to false
- **THEN** the request body field "geoip_disable" should be false

### Requirement: Event uuid is sent in canonical form

A server SDK SHALL serialize the event `uuid` in canonical lowercase hyphenated form (`8-4-4-4-12`, no braces, no `urn:uuid:` prefix). A caller-supplied uuid in another form the SDK accepts — uppercase, unhyphenated, brace-wrapped, or `urn:uuid:`-prefixed — SHALL be normalized to that form before the event is enqueued, and the uuid the capture call returns SHALL be the normalized value that was sent. The normalization SHALL be applied after the `before_send` hook, so a uuid the hook sets is normalized too.

A caller-supplied value the SDK cannot parse as a uuid SHALL NOT fail or drop the capture call: the SDK SHALL replace it with a freshly generated UUIDv7 and SHOULD log a warning. The warning SHOULD NOT include the discarded value, because callers can put their own data in the uuid field.

Capture v1 keys the per-event `results` map in a 2xx response by the canonical uuid while parsing the request's uuid leniently, so an event sent under a non-canonical uuid cannot be correlated with its own verdict: a retryable verdict is never retried and a drop verdict never reaches the SDK's error reporting.

#### Scenario: Non-canonical caller uuid is normalized before send (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** capture is called with distinct id "user-123", event "Signed Up", and uuid "0199C3E8-4C7B-7E2E-9F21-2B6D5A1C9E04"
- **THEN** one event named "Signed Up" should be enqueued
- **AND** the enqueued event uuid should be "0199c3e8-4c7b-7e2e-9f21-2b6d5a1c9e04"
- **AND** the call should return the enqueued event's uuid

#### Scenario: Unparseable caller uuid falls back to a generated uuid (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token"
- **WHEN** capture is called with distinct id "user-123", event "Signed Up", and uuid "not-a-uuid"
- **THEN** the capture call should not throw
- **AND** one event named "Signed Up" should be enqueued
- **AND** the enqueued event uuid should not equal "not-a-uuid"
- **AND** the enqueued event should include an event uuid
- **AND** the call should return the enqueued event's uuid

### Requirement: Client-side capture rate limiting never loses tokens to a clock change

A client SDK that drops captures on a client-side rate limit (today posthog-js, as listed under "Drop silently") SHALL meter that limit with a token bucket persisted alongside the rest of its state. The bucket holds a token balance and the clock instant the balance was last computed at. Its size and refill rate are configurable per platform convention (posthog-js: `rate_limiting.events_per_second`, default 10, and `rate_limiting.events_burst_limit`, default ten times the per-second rate and never below it); a bucket with no persisted state starts full at the burst limit.

The bucket is refilled from the device's wall clock, which can move backward — a manual change, an NTP correction, a timezone daemon. The refill SHALL therefore be monotonic:

- The SDK SHALL refill the balance by the elapsed time since the stored instant, counting elapsed time as zero when the clock is behind that instant, multiplied by the per-second rate, and SHALL cap the balance at the burst limit. A backward clock change refills nothing and SHALL NOT remove tokens from the bucket.
- The SDK SHALL store the later of the stored instant and the current instant, so the bucket does not refill again until the clock passes the latest instant it has seen. A rollback followed by the clock catching up SHALL NOT refill the bucket twice for the same stretch of real time.
- An admitted capture SHALL consume one token and the balance SHALL NOT go below zero. A capture is rate limited when fewer than one token is available.

A backward clock change SHALL only pause refill until the clock catches up. It SHALL NOT take away tokens the bucket already held, so a capture that had a token available before the change is still admitted after it.

#### Scenario: A backward clock change does not drop the next capture (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and client rate limiting of 1 capture per second with a burst limit of 100
- **WHEN** capture is called with event "Before Rollback"
- **AND** the SDK clock moves backward by "143 seconds"
- **AND** capture is called with event "After Rollback"
- **THEN** one event named "Before Rollback" should be enqueued
- **AND** one event named "After Rollback" should be enqueued

#### Scenario: The bucket does not refill until the clock passes the latest instant it has seen (@client)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00Z"
- **AND** persistent storage is empty
- **AND** the mock PostHog server is reset
- **GIVEN** the SDK is initialized with token "test-token" and client rate limiting of 1 capture per second with a burst limit of 2
- **WHEN** capture is called with event "One"
- **AND** capture is called with event "Two"
- **AND** the SDK clock moves backward by "10 seconds"
- **AND** capture is called with event "Three"
- **AND** the SDK clock advances by "10 seconds"
- **AND** capture is called with event "Four"
- **AND** the SDK clock advances by "1 second"
- **AND** capture is called with event "Five"
- **THEN** one event named "One" should be enqueued
- **AND** one event named "Two" should be enqueued
- **AND** no event named "Three" should be enqueued
- **AND** no event named "Four" should be enqueued
- **AND** one event named "Five" should be enqueued

### Requirement: Capture v1 wire contract

An SDK that delivers events through capture v1 SHALL send analytics events with `POST {host}/i/v1/analytics/events` and SHALL NOT use `/batch`, `/capture`, `/e`, `/track` or `/i/v0/e`. The request body SHALL be a JSON object `{"created_at": <RFC 3339 string>, "historical_migration"?: <boolean>, "batch": [<event>, ...]}`, with at least one event, and `historical_migration` present only when true. Historical-migration events and live events SHALL NOT share a request.

Each event SHALL be a JSON object with the fields `event`, `uuid`, `distinct_id` and `timestamp` as JSON strings, `properties` as a JSON object, `options` as a JSON object (an empty object when the event has no options), and `session_id` and `window_id` as JSON strings only when present. The SDK SHALL NOT send any other top-level event field; a top-level `$set` or `$set_once` the SDK's API accepts is placed inside `properties`. The SDK SHALL NOT send `api_key`, `sent_at` or `offset` in the body.

Capture v1 parses the request with one strict JSON parse and rejects the whole request with `400 request_parsing_error` when any field has the wrong JSON type, a required field is missing, or the body is not valid JSON. The SDK SHALL therefore guarantee these types on the wire, including after `before_send`: an event whose hook leaves `distinct_id` or `event` non-string, or whose serialization fails, is dropped locally and reported through the SDK's error surface or a log line, and never sent.

Legacy capture: the body carried `api_key` and `sent_at`, `uuid` and `timestamp` were optional, and a non-string `distinct_id` was converted to text.

#### Scenario: Analytics events go to the capture v1 endpoint only (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with distinct id "user-123" and event "Signed Up"
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** every capture request path should be "/i/v1/analytics/events"
- **AND** no capture request should use "/batch", "/capture", "/e", "/track" or "/i/v0/e"

#### Scenario: The body carries the batch envelope and typed event fields (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with distinct id "user-123", event "Signed Up", and properties:
  | property | value |
  | plan     | pro   |
- **AND** pending captures are flushed
- **THEN** the first request body should contain a string "created_at" and an array "batch" with exactly 1 event
- **AND** the first request body should omit these root fields:
  | field                |
  | api_key              |
  | sent_at              |
  | historical_migration |
- **AND** the first received event should have string fields "event", "uuid", "distinct_id" and "timestamp"
- **AND** the first received event field "properties" should be an object containing "plan" equal to "pro"
- **AND** the first received event field "options" should be an object

#### Scenario: Historical migration is a request flag (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key", flush threshold 1, and historical migration enabled
- **WHEN** capture is called with distinct id "user-123" and event "Imported"
- **AND** pending captures are flushed
- **THEN** the first request body should contain historical_migration equal to true

#### Scenario: A hook that leaves a non-string distinct id drops only that event (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 2
- **AND** before-send replaces the distinct id of events named "Broken" with the number 42
- **WHEN** capture is called with distinct id "user-123" and event "Broken"
- **AND** capture is called with distinct id "user-123" and event "Fine"
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** the request should contain only the event "Fine"
- **AND** the SDK should report the event "Broken" as dropped locally

### Requirement: Capture v1 request headers

An SDK that delivers events through capture v1 SHALL send these headers on every capture request:

- `Authorization: Bearer <project token>`. The token is never placed in the body.
- `Content-Type: application/json`.
- `User-Agent`, equal to the `PostHog-Sdk-Info` value.
- `PostHog-Sdk-Info: <library>/<version>`, where `<library>` is the SDK's own canonical `$lib` name (`posthog-python`, `posthog-go`, `posthog-rs`, `posthog-node`) and `<version>` is the package version actually shipped. Capture derives `$lib` and `$lib_version` from this header, so a built-in integration SHALL NOT relabel the client.
- `PostHog-Request-Id`: a UUID minted once per batch and kept across every retry of that batch.
- `PostHog-Attempt`: `1` on the first attempt, incremented by one on each retry of the same batch.
- `PostHog-Request-Timestamp`: the send time of this attempt as an RFC 3339 string with an explicit offset and at least millisecond precision, taken from the same clock as the event timestamps and stamped again on every attempt.
- `Content-Encoding` only when the body is compressed, with one of `gzip`, `deflate`, `br` or `zstd`.

Every header value SHALL be visible ASCII. The body's `created_at` SHALL be set once per batch and kept across retries. Capture uses `PostHog-Request-Timestamp` to correct for client clock skew, so a retry that resends a stale timestamp shifts every event in the request by the retry delay; the SDK SHALL NOT let an HTTP library retry a capture request on its behalf.

#### Scenario: The first attempt carries the required headers (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with distinct id "user-123" and event "Signed Up"
- **AND** pending captures are flushed
- **THEN** the first request should authenticate with bearer token "phc_test_key"
- **AND** the first request header "Content-Type" should start with "application/json"
- **AND** the first request header "PostHog-Sdk-Info" should match "<library>/<version>" for the SDK under test
- **AND** the first request header "User-Agent" should equal the "PostHog-Sdk-Info" header
- **AND** the first request header "PostHog-Request-Id" should be a valid UUID
- **AND** the first request header "PostHog-Attempt" should be integer 1
- **AND** the first request header "PostHog-Request-Timestamp" should be an RFC 3339 timestamp with an explicit offset and at least millisecond precision

#### Scenario: A retry keeps the request id and restamps the attempt and timestamp (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the mock serves these ordered analytics responses:
  | status | body                                   |
  | 503    | {"error":"service_unavailable"}        |
  | 200    | {"results":{"*":{"result":"ok"}}}      |
- **WHEN** capture is called with distinct id "user-123" and event "Signed Up"
- **AND** pending captures are flushed
- **THEN** at least 2 capture request should have been received
- **AND** all recorded request IDs should equal the nonempty first request ID
- **AND** all recorded request attempts should be consecutive integers starting at one
- **AND** the first two request headers "PostHog-Request-Timestamp" should be nonempty and different
- **AND** the first two request bodies should have the same "created_at"

### Requirement: Per-event results drive what is resent and what is reported

An SDK that delivers events through capture v1 SHALL read the `results` object of a 2xx response, keyed by the event `uuid` in canonical lowercase hyphenated form, and treat each entry as the verdict for that event:

- `ok` and `warning` mean the event was stored; the SDK SHALL NOT resend it or report it as a failure. `details` on an `ok` or `warning` entry (for example `person_processing_disabled`) is informational.
- `drop` means capture refused the event; the SDK SHALL NOT resend it and SHALL report it through its error surface with the `details` tag as an opaque string.
- `retry` means capture could not store the event this time; the SDK SHALL resend only the `retry` events, in their original relative order, as a new attempt of the same batch, and SHALL report an event still `retry` after the last attempt as exhausted.
- An entry whose `result` value the SDK does not recognize, and an event whose uuid is absent from `results`, SHALL be treated as delivered.
- A 2xx whose body cannot be read as `{"results": {...}}` is a terminal failure of the whole batch.

The SDK SHALL NOT hard-code the set of `details` tags. When a `results` entry carries `duplicates_dropped: n`, the request repeated that uuid: the first event with that uuid in the request takes the entry's `result` and `details`, and the SDK SHALL report exactly the next `n` events with that uuid as `drop` with the reason `duplicate_event_uuid`, never retrying them. The SDK SHALL NOT guard, split, rewrite or deduplicate repeated uuids before sending.

When no error handler is registered, the SDK SHALL log one aggregate line per batch that lost events, carrying the count, the cause and the endpoint, and never event content.

Legacy capture: a 2xx meant the whole request was accepted and there was no per-event verdict.

#### Scenario: Only retry verdicts are resent (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 3
- **AND** the mock serves these ordered analytics responses:
  | status | body                                                                                                                                    |
  | 200    | {"results":{"<uuid 0>":{"result":"ok"},"<uuid 1>":{"result":"drop","details":"event_name_too_long"},"<uuid 2>":{"result":"retry","details":"not_persisted"}}} |
  | 200    | {"results":{"<uuid 2>":{"result":"ok"}}}                                                                                                |
- **WHEN** capture is called sequentially 3 times with zero-based top-level index substitution:
  """application/json
  {"distinct_id":"user-123","event":"event-{index}"}
  """
- **AND** pending captures are flushed
- **THEN** at least 2 capture request should have been received
- **AND** the second request should retain first-response retry UUIDs and omit its terminal UUIDs
- **AND** the SDK should report event "event-1" as dropped with details "event_name_too_long"
- **AND** the SDK should not report event "event-0" or "event-2" as failed

#### Scenario: Duplicate copies are reported, not resent (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 3
- **AND** the mock serves these ordered analytics responses:
  | status | body                                                                 |
  | 200    | {"results":{"0199c3e8-4c7b-7e2e-9f21-2b6d5a1c9e04":{"result":"ok","duplicates_dropped":2}}} |
- **WHEN** capture is called sequentially 3 times with the same uuid "0199c3e8-4c7b-7e2e-9f21-2b6d5a1c9e04" and events "first", "second" and "third"
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** the first request should contain 3 events with uuid "0199c3e8-4c7b-7e2e-9f21-2b6d5a1c9e04"
- **AND** the SDK should report events "second" and "third" as dropped with details "duplicate_event_uuid"
- **AND** the SDK should not report event "first" as failed

#### Scenario: Unknown verdicts and absent uuids count as delivered (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 2
- **AND** the mock serves these ordered analytics responses:
  | status | body                                                   |
  | 200    | {"results":{"<uuid 0>":{"result":"accepted_later"}}}   |
- **WHEN** capture is called sequentially 2 times with zero-based top-level index substitution:
  """application/json
  {"distinct_id":"user-123","event":"event-{index}"}
  """
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** the SDK should not report any event as failed

### Requirement: Per-event options replace the legacy option properties

An SDK that delivers events through capture v1 SHALL accept an `options` object on every event-producing call (capture, AI capture, exception capture, identify or person-property calls, alias and group identify), SHALL send it as the event's `options` with every key and value as given, and SHALL NOT validate, convert or filter option values: capture reads them leniently and drops an event whose value it cannot read with `details: invalid_options`, which the SDK reports like any other drop. Keys the SDK does not know SHALL pass through unchanged. A non-object `options` value on a dynamically typed SDK SHALL be logged as an error and the event sent without caller options.

The legacy option properties are the `$`-prefixed properties legacy capture reads as settings: `$process_person_profile`, `$cookieless_mode`, `$ignore_sent_at` and `$product_tour_id`. In the wire builder, after the last `before_send` hook and once per event, the SDK SHALL remove each of them from `properties` and SHALL copy its value into the matching option (`process_person_profile`, `cookieless_mode`, `disable_skew_correction`, `product_tour_id`) only when that option is absent or `null`. An option set by any layer therefore wins over a legacy property set by any layer. SDK-internal code (personless defaults, built-in AI and MCP integrations) SHALL set options directly and never write a legacy option property.

An SDK with global default properties SHALL offer global default options with the same interface, and an SDK with a request-context layer for properties SHALL offer context options (for example `super_options` and `set_context_option` in posthog-python, `Config.DefaultEventOptions` and `RequestContext.Options` in posthog-go, `registerOptions()` and context `options` in posthog-node). An SDK with neither layer needs neither.

Legacy capture: SDKs validated and converted `$process_person_profile` and `$cookieless_mode` themselves and sent them as properties.

#### Scenario: A caller option is sent as given and the legacy property is removed (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Signed Up","properties":{"$cookieless_mode":true},"options":{"process_person_profile":"no","custom_flag":7}}
  """
- **AND** pending captures are flushed
- **THEN** the first received event option "process_person_profile" should equal JSON "no"
- **AND** the first received event option "custom_flag" should equal JSON 7
- **AND** the first received event option "cookieless_mode" should equal JSON true
- **AND** the first received event property "$cookieless_mode" should be absent

#### Scenario: An option beats its legacy property (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Signed Up","properties":{"$process_person_profile":true},"options":{"process_person_profile":false}}
  """
- **AND** pending captures are flushed
- **THEN** the first received event option "process_person_profile" should equal JSON false
- **AND** the first received event property "$process_person_profile" should be absent

#### Scenario: Unset options are omitted (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with distinct id "user-123" and event "Signed Up"
- **AND** pending captures are flushed
- **THEN** the first received event field "options" should be an object
- **AND** the first received event option "process_person_profile" should be absent
- **AND** the first received event option "cookieless_mode" should be absent
- **AND** the first received event option "disable_skew_correction" should be absent
- **AND** the first received event option "product_tour_id" should be absent

#### Scenario: Hoisting runs after before_send (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** before-send deletes the property "$process_person_profile"
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Signed Up","properties":{"$process_person_profile":false}}
  """
- **AND** pending captures are flushed
- **THEN** the first received event option "process_person_profile" should be absent
- **AND** the first received event property "$process_person_profile" should be absent

### Requirement: Server SDKs build every event in one layer order

An SDK that delivers events through capture v1 SHALL build each event in this order, for every event type its public API produces (capture, AI capture, exception capture, identify or person-property events, alias and group identify):

1. **Identity resolves first.** The distinct id comes from the call, then the ambient request context, then a generated personless id (or the SDK's existing error for a missing id). A context session id becomes `$session_id` unless the event has its own.
2. **The call's own values.** The call's `properties` and `options`, and typed call values (`groups`, a typed `$set` or `$set_once`), which win key by key over the same key in `properties`.
3. **Fill-only defaults**, each layer filling only what the layers above left unset: the ambient request context, then the SDK-level default properties and options, then the values the SDK adds itself (`$is_server`, `$geoip_disable` from the client setting, system context, the `$feature/<key>` and `$active_feature_flags` properties derived from a flags snapshot or `send_feature_flags`, `$release_id`, the `process_person_profile: false` option for a personless event, and `$trace_id` with `$span_id` from an active OpenTelemetry span, added as a pair only when no layer set either key). A property is unset only when its key is missing, so a `null` property blocks the fill; an option is unset when it is missing or `null`. `$set`, `$set_once`, `$groups` and `$group_set` fill one level deep when both values are objects.
4. **`before_send`** runs on an isolated copy of the assembled event, including `options`, and has the final say. The SDK SHALL NOT add or re-add any value after the hook. Where a minimized `$feature_flag_called` event is built, its allowlist SHALL be applied after step 3 and before step 4, and SHALL keep the legacy option properties, `$session_id` and `$window_id`.
5. **Hoisting**, once, in the wire builder: the legacy option properties move into `options`, `$session_id` and `$window_id` move to their top-level fields, and `$lib` and `$lib_version` are removed.

A per-call argument such as `disable_geoip` belongs to step 2, so it beats a context or global `$geoip_disable`; the client-level setting belongs to step 3, so a context or global value beats it. A built-in AI or MCP integration SHALL set `process_person_profile: false` at step 2 when it substitutes a trace or session id for a missing user id. Adding groups to an event SHALL NOT turn person processing on.

Legacy capture: posthog-python 7.x merged `super_properties` over the call's properties and posthog-go 1.x merged `DefaultEventProperties` over the call's properties; both reversed in their capture v1 majors. This requirement states the server part of the order that #145 proposes for flag properties.

#### Scenario: The call wins over context, global and SDK values (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the SDK-level default properties carry "plan" equal to "free" and "$is_server" equal to false
- **AND** the ambient request context, where the SDK has one, carries "plan" equal to "team"
- **WHEN** capture is called with distinct id "user-123", event "Signed Up", and properties:
  | property | value |
  | plan     | pro   |
- **AND** pending captures are flushed
- **THEN** the first received event property "plan" should equal JSON "pro"
- **AND** the first received event property "$is_server" should equal JSON false

#### Scenario: Lower layers fill only unset keys and a null property blocks the fill (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the SDK-level default properties carry "plan" equal to "free" and "region" equal to "eu"
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Signed Up","properties":{"plan":null}}
  """
- **AND** pending captures are flushed
- **THEN** the first received event property "plan" should equal JSON null
- **AND** the first received event property "region" should equal JSON "eu"

#### Scenario: A global option fills an unset option and a null option does not block it (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the SDK-level default options carry "cookieless_mode" equal to true
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Signed Up","options":{"cookieless_mode":null}}
  """
- **AND** pending captures are flushed
- **THEN** the first received event option "cookieless_mode" should equal JSON true

#### Scenario: Nested person and group properties fill one level deep (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the SDK-level default properties carry "$set" equal to JSON `{"tier":"gold","source":"default"}`
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Signed Up","properties":{"$set":{"source":"call"}}}
  """
- **AND** pending captures are flushed
- **THEN** the first received event property "$set" should equal JSON `{"tier":"gold","source":"call"}`

#### Scenario: before_send sees the filled event and can remove a default (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the SDK-level default properties carry "plan" equal to "free"
- **AND** before-send records the event it receives and deletes the property "$is_server"
- **WHEN** capture is called with distinct id "user-123" and event "Signed Up"
- **AND** pending captures are flushed
- **THEN** the event before-send received should have property "plan" equal to "free" and property "$is_server" equal to true
- **AND** the first received event property "$is_server" should be absent
- **AND** the first received event property "plan" should equal JSON "free"

#### Scenario: Groups never force person processing (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Signed Up","groups":{"company":"acme"}}
  """
- **AND** pending captures are flushed
- **THEN** the first received event property "$groups" should equal JSON `{"company":"acme"}`
- **AND** the first received event option "process_person_profile" should be absent

### Requirement: Library identity comes from the request header

An SDK that delivers events through capture v1 SHALL NOT send `$lib` or `$lib_version` in `properties`. The wire builder SHALL remove both keys after `before_send`, whoever set them, because capture derives them from `PostHog-Sdk-Info` and writes them after the event's own properties. `before_send` may still see a caller-supplied value. Built-in integrations (MCP servers, AI wrappers, framework middleware) SHALL NOT change the client's `PostHog-Sdk-Info` value.

Legacy capture: server SDKs stamped `$lib` and `$lib_version` into `properties`, and some integrations relabeled the client.

#### Scenario: A caller-set $lib never reaches the wire (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with distinct id "user-123", event "Signed Up", and properties:
  | property     | value      |
  | $lib         | custom-lib |
  | $lib_version | 9.9.9      |
- **AND** pending captures are flushed
- **THEN** the first received event property "$lib" should be absent
- **AND** the first received event property "$lib_version" should be absent
- **AND** the first request header "PostHog-Sdk-Info" should match "<library>/<version>" for the SDK under test

### Requirement: Session and window ids are lifted only as strings

An SDK that delivers events through capture v1 SHALL remove `$session_id` and `$window_id` from `properties` in the wire builder. A value whose JSON form is a string, including the empty string, SHALL be sent as the top-level `session_id` or `window_id` field. A `null` value SHALL be dropped silently. Any other value SHALL be dropped with a warning that names the key and the JSON type and never the value, because capture rejects the whole request when either field is not a string.

#### Scenario: A string session id is lifted and a numeric one is dropped with a warning (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 2
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"With Session","properties":{"$session_id":"session-123"}}
  """
- **AND** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Bad Session","properties":{"$session_id":123}}
  """
- **AND** pending captures are flushed
- **THEN** the received event "With Session" should have top-level "session_id" equal to "session-123"
- **AND** the received event "With Session" should have property "$session_id" absent
- **AND** the received event "Bad Session" should have top-level "session_id" absent
- **AND** the received event "Bad Session" should have property "$session_id" absent
- **AND** the SDK should record a warning that names "$session_id" and the JSON type "number" and does not contain "123"

### Requirement: Distinct ids and identity fallbacks on capture v1

An SDK that delivers events through capture v1 SHALL treat an empty or whitespace-only caller `distinct_id` as missing. A missing id keeps the SDK's existing behavior: a generated personless id (UUIDv7, with `process_person_profile: false` set as an option) or a clear error returned to the caller. The SDK SHALL never send an event without a `distinct_id` key.

The SDK SHALL NOT shorten, hash or reject distinct ids by length or by placeholder value: capture v1 drops an event whose `distinct_id` is over 200 UTF-8 bytes (`distinct_id_too_large`) and accepts placeholder values such as `anonymous` without a person profile, and reports both per event. A `$groupidentify` event's `distinct_id` SHALL be the caller's id when given, else the request-context id where the SDK has one, else `$<group type>_<group key>`, and never a random value. An `alias` call SHALL never take its target from the request context. Global and context layers reach person-only events (`$identify`, `$create_alias`, `$merge_dangerously`, `$groupidentify`) like any other event; `$groupidentify` never takes the context session id.

Legacy capture: distinct ids over 200 characters were shortened and the event kept; posthog-python 6.x used a random id for `$groupidentify` without a caller id.

#### Scenario: A whitespace distinct id becomes a personless event (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the SDK generates a personless id for a missing distinct id
- **WHEN** capture is called with distinct id "   " and event "Anonymous Action"
- **AND** pending captures are flushed
- **THEN** the first received event field "distinct_id" should be a nonempty string that is not "   "
- **AND** the first received event option "process_person_profile" should equal JSON false

#### Scenario: Group identify falls back to the type and key id (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** group identify is called for group type "company" and key "acme" with no distinct id and properties:
  | property | value |
  | name     | Acme  |
- **AND** pending captures are flushed
- **THEN** the first received event field "event" should equal "$groupidentify"
- **AND** the first received event field "distinct_id" should equal "$company_acme"
- **AND** the first received event field "session_id" should be absent

#### Scenario: A long distinct id is sent unchanged (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with a distinct id of 250 ASCII characters and event "Long Id"
- **AND** pending captures are flushed
- **THEN** the first received event field "distinct_id" should have length 250

### Requirement: Timestamps on capture v1

An SDK that delivers events through capture v1 SHALL stamp a missing event `timestamp` once, when the event is captured or enqueued, from the same clock as `PostHog-Request-Timestamp`, and SHALL NOT change it afterwards (not on retry, not after a restart). Every timestamp on the wire (`timestamp`, `created_at`, `PostHog-Request-Timestamp`) SHALL be RFC 3339 with an explicit offset (`Z` or `±HH:MM`) and at least millisecond precision; finer precision the caller or the clock provides SHALL be kept. The SDK SHALL NOT correct clock skew locally, SHALL NOT reject or clamp a future timestamp, and SHALL NOT send an `offset` field. An unparseable caller timestamp SHALL be replaced with the current time and logged with a warning that names the rule and never the value. A naive caller timestamp follows the SDK's documented zone rule.

Legacy capture: `timestamp` was optional and some SDKs sent an `offset`; posthog-rs rejected future timestamps.

#### Scenario: A caller timestamp keeps its sub-millisecond precision and offset semantics (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"user-123","event":"Precise","timestamp":"2025-01-02T08:34:05.123456+05:30"}
  """
- **AND** pending captures are flushed
- **THEN** every event in the first capture request should have UTC timestamp "2025-01-02T03:04:05.123456Z"

#### Scenario: A generated timestamp has at least millisecond precision (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK clock is fixed at "2025-01-01T00:00:00.250Z"
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with distinct id "user-123" and event "Stamped"
- **AND** pending captures are flushed
- **THEN** every event in the first capture request should have UTC timestamp "2025-01-01T00:00:00.250Z"

#### Scenario: A retry resends the original event timestamp (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the mock serves these ordered analytics responses:
  | status | body                                   |
  | 503    | {"error":"service_unavailable"}        |
  | 200    | {"results":{"*":{"result":"ok"}}}      |
- **WHEN** capture is called with distinct id "user-123" and event "Retried"
- **AND** pending captures are flushed
- **THEN** at least 2 capture request should have been received
- **AND** the present event "timestamp" lists in requests zero and one should be identical
- **AND** the present event "uuid" lists in requests zero and one should be identical

### Requirement: Each event is serialized on its own and the body is strict JSON

An SDK that delivers events through capture v1 SHALL serialize each event independently, so that one event the encoder cannot write never costs its batch, and SHALL send a body a strict JSON parser accepts: no bare `NaN`, `Infinity` or `-Infinity` tokens and no duplicate keys. An event whose serialization fails SHALL be dropped alone and reported through the SDK's local-drop path. A non-finite number inside `properties` SHALL be sent as JSON `null` and the event kept (posthog-node, posthog-rs, posthog-python, and posthog-go from v2). The SDK SHALL NOT add a per-value check to events that hold no non-finite number: an encoder that already writes `null` needs nothing, and an encoder that rejects non-finite numbers SHALL encode each event strictly first and rewrite its non-finite numbers to `null` only when that encoding fails (posthog-python, posthog-go). A client SDK MAY drop the non-finite property instead and keep the event (posthog-ios, posthog-android).

A missing, `null`, empty or non-string event name SHALL be dropped locally and never sent, converted or raised to the caller. A non-string property or option key with a natural string form (number, boolean, symbol) MAY be converted as the language's JSON encoder does; a key the encoder cannot write drops only that key.

Legacy capture: whole-batch serialization let one bad value lose every event in the batch.

#### Scenario: An unserializable event does not cost its neighbors (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 2
- **WHEN** capture is called with distinct id "user-123", event "Bad", and a property value the SDK's JSON encoder cannot write
- **AND** capture is called with distinct id "user-123" and event "Good"
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** the request should contain only the event "Good"
- **AND** the request body should parse under a strict JSON parser

#### Scenario: An empty event name is dropped locally (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with distinct id "user-123" and event ""
- **AND** pending captures are flushed
- **THEN** the capture call should not throw
- **AND** no capture request should have been received

### Requirement: The client fails open on a missing or personal API key

Constructing an SDK client SHALL never throw or fail because of the project token. An empty or whitespace-only token, or a token that starts with `phx_` (a personal API key, which capture always rejects), SHALL produce a disabled client that accepts every call, sends nothing, returns flag defaults and logs one error, so a secret key never reaches the wire. Any other malformed token SHALL be sent as given, and capture's `401` SHALL reach the error surface. The SDK SHALL offer an explicit way to build a disabled client for tests. A built-in integration SHALL NOT raise or return a constructor error over an analytics-only setup problem; it logs one error and turns its own capture off.

#### Scenario: A personal API key disables the client without throwing (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **WHEN** the SDK is initialized with token "phx_secret_personal_key" and flush threshold 1
- **AND** capture is called with distinct id "user-123" and event "Signed Up"
- **AND** pending captures are flushed
- **THEN** the initialization should not throw
- **AND** no capture request should have been received
- **AND** the SDK should record one error log about the personal API key that does not contain "phx_secret_personal_key"

#### Scenario: A blank token disables the client (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the mock PostHog server is reset
- **WHEN** the SDK is initialized with token "   " and flush threshold 1
- **AND** capture is called with distinct id "user-123" and event "Signed Up"
- **AND** pending captures are flushed
- **THEN** the initialization should not throw
- **AND** no capture request should have been received

