## ADDED Requirements

### Requirement: Capture v1 transport scope

Capture v1 is a **transport**, not a new public API. It ships the same analytics events produced
by `capture` (see the capture spec) over a newer wire contract: a versioned ingestion endpoint,
Bearer authentication, a per-event envelope, and a per-event result protocol that supports
partial retry. An SDK MAY select capture v1 instead of the legacy `/batch/` transport via
configuration (e.g. a capture-mode flag); event production, enrichment, and `before_send` are
unchanged and happen upstream. Capture v1 governs only how an already-assembled batch of events
is serialized, sent, and reconciled with the server's response.

The canonical contract is defined by the backend Rust type `rust/capture/src/v1/analytics/types.rs`
in PostHog/posthog and mirrored by the SDK implementations. `posthog-rs` is the reference
implementation; `posthog-go`, `posthog-node`, and `posthog-python` explicitly mirror it. Method
and type names are semantic — each SDK SHALL spell them per its platform conventions (e.g.
`posthog-rs` uses `v1_capture` / `V1Event` rather than `CaptureV1`).

#### Scenario: v1 mode reuses the enriched events
- **GIVEN** an SDK configured for capture v1
- **WHEN** the application captures an event and the batch is flushed
- **THEN** the event is delivered over the v1 transport with the same enrichment and `before_send`
  processing it would have received on the legacy transport

#### Scenario: transport is selectable
- **WHEN** an SDK exposes both the legacy and v1 transports
- **THEN** the transport is chosen by configuration and the public `capture` API is unchanged

### Requirement: Endpoint and Bearer authentication

The SDK SHALL POST batches to `{host}/i/v1/analytics/events`, where `host` is the configured
ingestion host with any trailing slash stripped. The request SHALL use method POST with
`Content-Type: application/json`. Authentication SHALL be **Bearer only**: the request carries an
`Authorization: Bearer <api_key>` header. Unlike the legacy v0 transport, the project API key
SHALL NOT be placed in a `token`/`api_key` query parameter or in the request body, and there
SHALL be no `sent_at` field.

#### Scenario: endpoint and auth header
- **WHEN** the SDK flushes with host `https://us.i.posthog.com` and key `phc_abc`
- **THEN** it POSTs to `https://us.i.posthog.com/i/v1/analytics/events`
- **AND** the request carries `Authorization: Bearer phc_abc`

#### Scenario: key is never in the body or query
- **WHEN** a v1 batch is sent
- **THEN** the request body contains no `api_key`/`token` field
- **AND** no `token` query parameter is appended to the URL

### Requirement: Batch request envelope

A batch SHALL serialize as a JSON object with `created_at` (an RFC 3339 / ISO 8601 timestamp,
UTC, for when the batch was assembled), `batch` (the array of per-event objects), and an optional
`historical_migration`. `historical_migration` SHALL be emitted **only when true** and omitted
otherwise so the server applies its default. `created_at` SHALL be computed once per batch and
SHALL remain stable across retry attempts of that batch.

#### Scenario: envelope shape
- **WHEN** a batch of 3 events is assembled at "2026-05-28T15:00:00Z"
- **THEN** the body is `{ "created_at": "2026-05-28T15:00:00Z", "batch": [ …3 events… ] }`
- **AND** `historical_migration` is absent

#### Scenario: historical migration flag
- **GIVEN** the batch is a historical migration
- **WHEN** the body is built
- **THEN** it includes `"historical_migration": true`

#### Scenario: created_at is stable across retries
- **GIVEN** a batch that is retried after a transient failure
- **WHEN** the retry request is built
- **THEN** its `created_at` equals the value sent on the first attempt

### Requirement: Per-event wire shape

Each event SHALL serialize as a JSON object with these fields: `event`, `uuid`, `distinct_id`,
`timestamp` (RFC 3339 / ISO 8601), an always-present `options` object, and `properties`.
`session_id` and `window_id` SHALL be present only when known and SHALL be omitted otherwise.
`event`, `uuid`, `distinct_id`, `timestamp`, `options`, and `properties` SHALL always be present.
The SDK SHALL NOT emit `$lib` / `$lib_version` inside `properties`; the server derives library
identity from the `PostHog-Sdk-Info` header (see the request-headers requirement).

#### Scenario: minimal event
- **WHEN** an event "test" for distinct id "user-1" with no session is serialized
- **THEN** the object has `event`, `uuid`, `distinct_id`, `timestamp`, `options`, and `properties`
- **AND** it has no `session_id` or `window_id`

#### Scenario: library identity is not duplicated into properties
- **WHEN** a v1 event is serialized
- **THEN** `properties` contains no `$lib` or `$lib_version`

### Requirement: Options sentinel lifting

Before serialization the SDK SHALL lift a fixed set of "sentinel" properties out of `properties`
into typed destinations, coercing each to the type the backend `options` struct expects. The
lifting table is: `$cookieless_mode` → `options.cookieless_mode` (bool); `$ignore_sent_at` →
`options.disable_skew_correction` (bool); `$product_tour_id` → `options.product_tour_id` (string);
`$process_person_profile` → `options.process_person_profile` (bool); `$session_id` → the
top-level `session_id` field (string); `$window_id` → the top-level `window_id` field (string).

Every sentinel key SHALL always be removed from `properties` (these keys must never reach v1
backend properties), whether or not it is emitted. A sentinel SHALL be emitted only when its value
coerces to the expected type; a value that cannot be coerced SHALL be **dropped** (so the backend
applies its default) rather than shipped mistyped — the SDK SHALL NOT let one mistyped sentinel
cause the server to reject the whole batch. The `options` object SHALL always serialize as `{}`
when empty, never `null` and never omitted. Only the keys in this table are lifted; any other
`$`-prefixed property SHALL remain in `properties`.

Boolean coercion SHALL accept: a native boolean; the strings `"true"`/`"1"` (→ true) and
`"false"`/`"0"` (→ false), trimmed and case-insensitive; and any number (nonzero → true, zero →
false). Any other value is uncoercible. String coercion SHALL accept only a native string
(including the empty string); any other type is uncoercible.

#### Scenario: sentinels lifted to options
- **WHEN** an event has properties `$cookieless_mode: true`, `$process_person_profile: false`, and `$product_tour_id: "tour-42"`
- **THEN** `options` is `{ "cookieless_mode": true, "process_person_profile": false, "product_tour_id": "tour-42" }`
- **AND** none of those keys remain in `properties`

#### Scenario: ignore_sent_at is renamed
- **WHEN** an event has property `$ignore_sent_at: true`
- **THEN** `options.disable_skew_correction` is `true`

#### Scenario: session and window lifted to top level
- **WHEN** an event has properties `$session_id: "sess-1"` and `$window_id: "win-1"`
- **THEN** the event's top-level `session_id` is "sess-1" and `window_id` is "win-1"
- **AND** neither key remains in `properties`

#### Scenario: string boolean coerced
- **WHEN** an event has property `$cookieless_mode: "1"`
- **THEN** `options.cookieless_mode` is the boolean `true`

#### Scenario: uncoercible sentinel is dropped, not shipped
- **WHEN** an event has property `$product_tour_id: 42` (a number, not a string)
- **THEN** `options` has no `product_tour_id`
- **AND** `$product_tour_id` is removed from `properties`

#### Scenario: empty options renders as object
- **WHEN** an event has no sentinel properties
- **THEN** `options` serializes as `{}`

#### Scenario: unknown reserved property is not lifted
- **WHEN** an event has a property `$future_backend_flag: "x"` not in the lifting table
- **THEN** it stays in `properties` and is not placed in `options`

### Requirement: Per-event result protocol

The success response is a JSON object `{ "results": { "<uuid>": { "result": <code>, "details"?: <string> } } }`
keyed by event uuid. The SDK SHALL classify each event by its result code: `ok` and `warning` are
**terminal success**; `drop` is **terminal failure** (the server rejected the event, e.g. billing
or person-processing); `retry` means the event may be **resent**. An unrecognized result code
SHALL be treated as terminal success (forward-compatibility), and a uuid **absent** from the
`results` map SHALL be treated as accepted. Terminal per-event outcomes SHALL be recorded/surfaced
in the attempt in which they resolve.

#### Scenario: mixed results
- **GIVEN** a batch of events A, B, C, D
- **WHEN** the server responds A=`ok`, B=`warning`, C=`drop`, D=`retry`
- **THEN** A and B are recorded as delivered, C as dropped, and D is eligible for resend

#### Scenario: unknown code is success
- **WHEN** an event's result code is a value the SDK does not recognize
- **THEN** it is treated as terminal success and not resent

#### Scenario: missing uuid is accepted
- **WHEN** an event's uuid does not appear in the `results` map
- **THEN** it is treated as accepted and not resent

### Requirement: Partial retry

On a successful (2xx) response the SDK SHALL resend **only** the events whose result was `retry`;
events with terminal results (`ok`/`warning`/`drop`/unknown/absent) SHALL NOT be resent. Terminal
results SHALL be preserved across attempts — a `drop` recorded in an early attempt SHALL survive
even when later attempts resolve the remaining retries — and the accumulated dropped and
still-undelivered outcomes SHALL be surfaced to the caller (e.g. via an error/result carrying the
dropped uuids and any retry-exhausted uuids). When the retry set becomes empty the batch is
complete. When the attempt budget is exhausted with events still tagged `retry`, those events
SHALL be surfaced as undelivered (retry-exhausted).

#### Scenario: only retry-tagged events are resent
- **GIVEN** a first response with A=`ok` and B=`retry`
- **WHEN** the SDK retries
- **THEN** the second request's `batch` contains only event B

#### Scenario: early drops are not lost
- **GIVEN** a first response with A=`drop` and B=`retry`
- **AND** the retry of B then succeeds with B=`ok`
- **THEN** the caller is still informed that A was dropped

#### Scenario: retry exhaustion is surfaced
- **GIVEN** an event remains `retry` after the final attempt
- **THEN** it is surfaced to the caller as undelivered rather than silently discarded

### Requirement: Retry classification and backoff

The retryable HTTP status set SHALL be exactly `{408, 500, 502, 503, 504}`. All other non-2xx
statuses SHALL be terminal. In particular **`429` SHALL be terminal** on the v1 transport — this
is a deliberate difference from the legacy v0 transport, which retries `429` when accompanied by
`Retry-After`; the v1 backend signals transient overload via retryable `5xx` plus `Retry-After`
instead. The whole 2xx class SHALL be treated as success (so a future 201/202 is not misread as a
failure), but a 2xx whose body cannot be parsed as the result protocol SHALL be terminal (a broken
success must not loop). Transport errors with no HTTP response SHALL be retried until the attempt
budget is exhausted.

Between attempts the SDK SHALL wait a backoff computed as exponential growth from an initial delay
(doubling per attempt) clamped to a maximum backoff. When the server sends `Retry-After` (delta
seconds or an HTTP date), it SHALL be honored as a **minimum** — the SDK waits the longer of the
configured backoff and `Retry-After` — but `Retry-After` itself SHALL be clamped to the maximum
backoff so a hostile or buggy header cannot park the sender indefinitely. The canonical maximum
backoff is **30s**. The configured backoff SHALL never be truncated below its own schedule.

#### Scenario: 429 is terminal on v1
- **WHEN** the server responds `429`
- **THEN** the batch is not retried and the failure is surfaced

#### Scenario: retryable 5xx backs off
- **GIVEN** attempts remain in the budget
- **WHEN** the server responds `503`
- **THEN** the SDK waits the backoff and retries the pending events

#### Scenario: Retry-After is a clamped minimum
- **GIVEN** a maximum backoff of 30s
- **WHEN** the server responds `503` with `Retry-After: 3600`
- **THEN** the next wait is clamped to 30s rather than an hour

#### Scenario: malformed success body is terminal
- **WHEN** the server responds `200` with a body that is not the result protocol
- **THEN** the SDK does not retry and surfaces the failure

#### Scenario: transport error retries within budget
- **WHEN** the connection fails before any HTTP response and attempts remain
- **THEN** the SDK backs off and retries the same batch

### Requirement: Request headers

Each request SHALL carry `Content-Type: application/json`, `Authorization: Bearer <api_key>`, and
four PostHog headers: `PostHog-Sdk-Info` — the library identity as `<name>/<version>` (e.g.
`posthog-go/1.2.3`), which is the authoritative source the server materializes into
`$lib`/`$lib_version`; `PostHog-Request-Id` — a request identifier generated once per batch and
**stable across all retry attempts** of that batch; `PostHog-Attempt` — the 1-based attempt number,
incremented on each attempt; and `PostHog-Request-Timestamp` — an RFC 3339 timestamp regenerated on
each attempt. When the body is compressed the request SHALL also carry the matching
`Content-Encoding` header.

#### Scenario: sdk-info carries library identity
- **WHEN** the `posthog-go` SDK at version 1.2.3 sends a batch
- **THEN** the request has `PostHog-Sdk-Info: posthog-go/1.2.3`

#### Scenario: request id is stable, attempt increments
- **GIVEN** a batch that is sent, fails transiently, and is retried
- **THEN** both requests carry the same `PostHog-Request-Id`
- **AND** the first carries `PostHog-Attempt: 1` and the retry carries `PostHog-Attempt: 2`

### Requirement: Compression

Compression is optional and negotiated per codec. When the SDK compresses the JSON body it SHALL
signal the codec with a `Content-Encoding` header whose value matches the wire token: `gzip`,
`deflate` (zlib-wrapped, RFC 1950 — the form the server's zlib decoder expects, not raw DEFLATE),
`zstd`, or `br` (Brotli). Which codecs an SDK supports MAY vary by platform and is a permitted
implementation choice — `gzip` is the common baseline every SDK supports, and an SDK MAY support
only `gzip`. If compression fails at runtime the SDK SHALL send the raw JSON body with no
`Content-Encoding` header rather than failing the send.

#### Scenario: gzip signalled by header
- **WHEN** an SDK compresses a v1 body with gzip
- **THEN** the request carries `Content-Encoding: gzip`

#### Scenario: gzip-only SDK is conformant
- **GIVEN** an SDK that supports only gzip compression
- **WHEN** it flushes a v1 batch
- **THEN** it either sends `Content-Encoding: gzip` or an uncompressed body, and is conformant

#### Scenario: compression failure falls back to raw
- **GIVEN** the configured codec fails to compress the body
- **WHEN** the request is sent
- **THEN** the body is the raw JSON and no `Content-Encoding` header is set

### Requirement: Attempt budget

The SDK SHALL bound delivery by a total attempt budget (one initial attempt plus a configurable
number of retries). The canonical default is **4 total attempts** (1 initial + 3 retries). A
misconfigured budget SHALL be clamped so that at least one attempt is always made (a bad
configuration surfaces an error rather than silently dropping the batch).

#### Scenario: default budget
- **WHEN** no retry count is configured
- **THEN** the SDK makes up to 4 total attempts before surfacing failure

#### Scenario: budget floored at one attempt
- **GIVEN** a retry count configured to a negative or zero-total value
- **WHEN** a batch is flushed
- **THEN** the SDK still makes at least one attempt

### Requirement: LLM analytics events stay on the legacy transport

Where an SDK also produces LLM analytics events (event names prefixed `$ai_`), those events SHALL
continue to be delivered over the legacy v0 transport even when the SDK is otherwise in v1 mode,
because the AI ingestion path has no v1 form yet. The routing decision SHALL be made on the
post-`before_send` event name, and the two routes SHALL use isolated queues so a v0 failure cannot
re-send events already accepted on v1. This requirement binds only SDKs that emit `$ai_` events
today (posthog-node); other SDKs have no such events to route.

#### Scenario: $ai_ event bypasses v1
- **GIVEN** an SDK in v1 mode that also emits LLM analytics events
- **WHEN** an event named `$ai_generation` is captured
- **THEN** it is delivered over the legacy v0 transport, not `/i/v1/analytics/events`

#### Scenario: routing decided after before_send
- **GIVEN** a `before_send` hook that renames an event to `$ai_generation`
- **WHEN** the SDK routes the event
- **THEN** it is treated as an LLM analytics event and sent over v0
