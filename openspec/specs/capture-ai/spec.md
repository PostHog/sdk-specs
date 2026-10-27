# Capture AI Specification

## Purpose

`capture_ai` records a single AI observability event (the `$ai_*` family:
`$ai_generation`, `$ai_span`, `$ai_trace`, `$ai_embedding`, ...). It takes
exactly the same arguments as the host SDK's `capture` but delivers the event
on an isolated route to PostHog's dedicated AI ingestion endpoint, which
accepts much larger payloads than analytics capture. PostHog's own AI wrapper
libraries always send through it; users call it directly for manual AI
capture.

`capture_ai` is a pipe: it sends the payload as given. Redaction, truncation,
and media handling are wrapper concerns governed by configuration — never
applied to manual `capture_ai` payloads.

On capture v1 the AI route is `POST /i/v1/ai/events`, the AI lane of the same
API that serves `/i/v1/analytics/events`; see `capture` for the shared wire
contract, headers, per-event results and event-building order.

## Applicability

`server` — implemented by posthog-python 8.0 (`capture_ai`), posthog-node 6.0
(`captureAi`), posthog-go v2 (`EnqueueAI`) and posthog-rs 1.0 (`capture_ai`),
all on capture v1. Other server SDKs (Ruby, PHP, .NET, ...) adopt this spec if
and when they add AI support; until then their AI events ride plain `capture`
under its standard limits. The **AI instrumentation attributes events to the active context**
requirement binds any SDK shipping the OpenTelemetry AI bridge — today
posthog-js (`@posthog/ai`), posthog-python, and posthog-go (`otel`) — whether or
not that SDK exposes `capture_ai`.

## Public signatures

### posthog-python

```python
def capture_ai(event: str, **kwargs: Unpack[OptionalCaptureArgs]) -> Optional[str]
```

Exposed on `Client`/`Posthog` and as a module-level `posthog.capture_ai`,
mirroring `capture`'s two exposures. Returns the event UUID, or `None` when
the event was not admitted (disabled client, `before_send` drop, post-shutdown).

### posthog-node

```ts
captureAi(props: EventMessage): string | undefined
captureAiImmediate(props: EventMessage): Promise<string | undefined>
```

Mirrors the host SDK's `capture`/`captureImmediate` pair. Returns the event
UUID, or `undefined` when the client is disabled. The immediate variant
resolves only after the network send completes (the serverless use case).

### posthog-go

```go
func (c Client) EnqueueAI(msg Message) error
func (c *client) EnqueueAIWithContext(ctx context.Context, msg Message) error
```

Accepts any message type, like `Enqueue`. Returns an error only for a local
problem (closed or disabled client, validation); delivery results arrive
through `Config.Callback`.

### posthog-rs

```rust
fn capture_ai(&self, event: Event)
fn capture_ai_batch(&self, events: Vec<Event>, historical_migration: bool)
async fn capture_ai_immediate(&self, event: Event) -> Result<CaptureSummary, Error>
async fn capture_ai_batch_immediate(&self, events: Vec<Event>, historical_migration: bool) -> Result<CaptureSummary, Error>
```

The blocking client has the same names, synchronous. The queued methods are
fire-and-forget; the immediate variants return the per-event summary.

### Surface-parity rule

`capture_ai` mirrors the host SDK's public `capture` surface: the same
parameters (every future `capture` parameter implicitly joins `capture_ai`),
and an immediate/awaitable variant exactly where the host SDK has one for
`capture` — no more, no less.

## Configuration

One public flag, named per platform convention (`enable_full_ai_capture` in
Python — constructor kwarg and module attribute; `enableFullAiCapture` in
Node — client option), default false. When true, PostHog's AI wrapper
libraries:

1. skip string truncation (a cut through base64 corrupts media; large text
   contexts stay intact), and
2. pass media (raw bytes, base64, data URIs) through unredacted instead of
   replacing it with type-aware placeholders.

The flag does not choose the route: on capture v1 the wrappers always send
through the AI method (see **Built-in AI integrations always use the AI
method**). On legacy capture they sent through analytics `capture` unless the
flag was set.

Privacy mode always takes precedence: with it on, content properties are
stripped regardless of this flag.

### AI lane delivery

The AI lane has its own delivery configuration, separate from the analytics
lane's: compression, queue capacity and request timeout, named after the lane
(`capture_ai_compression`, `capture_ai_max_queue_size`, `capture_ai_timeout`
in posthog-python; `CaptureAICompression`, `CaptureAIMaxQueueSize`,
`CaptureAIBatchUploadTimeout` in posthog-go; `capture_ai_compression`,
`capture_ai_max_queue_size` in posthog-rs, whose request timeout is shared;
`captureAiCompression`, `captureAiMaxQueueSize`, `captureAiRequestTimeoutMs`
in posthog-node). The defaults are a 1000-event queue and a 30 second timeout,
longer than analytics because AI payloads are much larger. The compression
default is the SDK's: none in posthog-python, posthog-go and posthog-rs, gzip
in posthog-node. The analytics lane's compression and queue capacity never
reach the AI lane; batching settings may be shared. The per-event cap is
optionally exposed (`capture_ai_max_event_bytes` in posthog-python) and can
only be lowered; the batch target is an internal constant. See **AI
lane configuration is scoped to the AI lane**.

## Behavior

1. **Admission.** Same enrichment pipeline as `capture` (distinct id,
   timestamp, the layer order, `before_send`, hoisting of the legacy option
   properties; on capture v1 the library identity comes from the
   `PostHog-Sdk-Info` header, not from properties), differing only in the
   delivery route.
2. **UUID.** The SDK attaches a client-generated UUID to every event on the
   AI path when the caller supplies no UUID, and returns the attached UUID to
   the caller. Handling of an invalid supplied UUID is platform-idiomatic
   (replace or reject).
3. **Isolation.** AI events ride their own queue/buffer with independent
   size caps, batching, and retry policy; they never share a send cycle with
   analytics events. The queue starts lazily — clients that never capture AI
   events pay no overhead.
4. **Delivery.** At-least-once delivery is permitted (retries may duplicate):
   a retry MUST resend the event with its entire original envelope
   unchanged — timestamp, distinct id, event name, and UUID, all stamped once
   at enqueue — never regenerated per attempt. The server dedupes on that
   full envelope (`[timestamp, distinct_id, event, uuid]`), which is what
   makes at-least-once delivery safe: duplicates collapse to one stored
   event. At-most-once (drop after retry exhaustion) is equally compliant.
   The invariant is the stable envelope, not the delivery count. On capture
   v1 the server answers with a per-event verdict and the SDK resends only the
   events marked `retry` (see `capture` and `retry-queue`).

## Error handling

- `capture_ai` never throws under normal operation, matching `capture`.
- Events exceeding the operational per-event size cap are dropped in the
  consumer, logging the event name and byte size only — never payload
  content, which may be unredacted multimodal data.
- Delivery failures surface through the SDK's existing error hooks
  (`on_error` and equivalents), not through the return value.

## Content

`$ai_input` / `$ai_output_choices` (and the `$ai_*_state` properties) carry
provider-native content parts, including base64 and data URIs. The public
promise is: send provider-native payloads, the platform recognizes them.
Ingestion is the authoritative media-detection layer; any SDK-side redaction
or detection is a lossy optimization that may change without breaking this
promise. Reference forms (e.g. `phaiblob://`) may join the schema additively.

## Transport (non-normative)

These are current operational values and may change without notice. Capture
v1: endpoint `/i/v1/ai/events`; the request body limit is larger than the
analytics endpoint's (20 MiB compressed and 100 MiB decompressed today);
capture drops an event whose `properties` exceed 8 MiB
(`ai_event_too_big`) and an event over the project's AI byte budget
(`ai_byte_rate_limited`); SDKs target about 5 MiB per request; retries follow
`retry-queue`. Legacy capture: endpoint `/i/v0/ai/batch/` with the v0 batch
wire shape, where a non-AI event rejected the whole batch. The exposure of the
per-event cap (lower-only) and the lane configuration are normative (see the
Requirements); the cap's value and the batch target are not.
## Requirements
### Requirement: Canonical capture_ai behavior

Server SDKs that support AI capture SHALL implement `capture_ai` as described
by this spec. Implementations MAY adapt method names, parameter casing, and
option naming to platform idioms, but MUST preserve the observable outcomes in
the scenarios below.

#### Scenario: capture_ai mirrors capture's parameters and returns the event UUID (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **WHEN** capture_ai is called with distinct id "user-123", event "$ai_generation", and properties:
  | property  | value |
  | $ai_model | gpt   |
- **THEN** one event named "$ai_generation" should be enqueued on the AI route
- **AND** the call should return the enqueued event's uuid
- **AND** the enqueued event should include a timestamp and uuid

#### Scenario: capture_ai rides an isolated route to the AI endpoint (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **WHEN** capture is called with distinct id "user-123" and event "button_clicked"
- **AND** capture_ai is called with distinct id "user-123" and event "$ai_generation"
- **AND** the SDK is flushed
- **THEN** the analytics batch endpoint should receive only "button_clicked"
- **AND** the AI batch endpoint should receive only "$ai_generation"

#### Scenario: capture never reroutes AI-named events (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **WHEN** capture is called with distinct id "user-123" and event "$ai_generation"
- **AND** the SDK is flushed
- **THEN** the analytics batch endpoint should receive "$ai_generation"
- **AND** the AI batch endpoint should receive no events

#### Scenario: the SDK generates a UUID when the caller supplies none (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **WHEN** capture_ai is called with distinct id "user-123" and event "$ai_generation" and no uuid
- **AND** the SDK is flushed
- **THEN** the event received on the AI batch endpoint should carry a client-generated uuid
- **WHEN** capture_ai is called with an explicit valid uuid
- **AND** the SDK is flushed
- **THEN** the event received on the AI batch endpoint should carry exactly that uuid
- **AND** handling of an invalid supplied uuid is platform-idiomatic (replace or reject)

#### Scenario: oversized events are dropped logging name and size only (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **WHEN** capture_ai is called with an event whose serialized size exceeds the per-event cap
- **AND** the SDK is flushed
- **THEN** no event should reach the AI batch endpoint
- **AND** the SDK should log the event name and byte size
- **AND** the log output should not contain the event's property values

#### Scenario: capture_ai never throws (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **AND** the AI batch endpoint is unreachable
- **WHEN** capture_ai is called with distinct id "user-123" and event "$ai_generation"
- **AND** the SDK is flushed
- **THEN** the caller should observe no exception

### Requirement: Full AI capture flag

The SDK SHALL expose a single boolean option (default false), named
`enable_full_ai_capture` adapted to platform convention, that governs what the
SDK's AI wrapper libraries capture. When true, the wrappers skip string truncation and pass media through unredacted; when false, they truncate long strings and replace media with a type-aware placeholder. The flag SHALL NOT change which route the wrappers use: on a capture v1 SDK they always send through the AI method (see **Built-in AI integrations always use the AI method**). It SHALL NOT alter payloads passed to
`capture_ai` directly.

#### Scenario: wrapper media is redacted by default and passed through when enabled (@server)
- **GIVEN** an AI wrapper capturing a payload containing base64 media
- **WHEN** the client has the flag unset
- **THEN** the captured content should replace the media with a type-aware placeholder
- **AND** the event should be sent through the AI method
- **WHEN** the client has the flag set to true
- **THEN** the captured content should contain the media unmodified
- **AND** no string truncation should be applied to the captured content
- **AND** the event should be sent through the AI method

#### Scenario: privacy mode wins over the flag (@server)
- **GIVEN** an AI wrapper capturing a payload containing base64 media
- **AND** the client has privacy mode enabled and the flag set to true
- **THEN** the captured event should carry no input or output content

### Requirement: AI capture drops null-valued object properties

`capture_ai` and its immediate/awaitable variants SHALL follow capture's "Capture drops null-valued object properties" requirement for caller-supplied custom properties, including nested objects and objects inside arrays. Null array elements SHALL retain their positions. This is a specific normalization exception to manual AI capture's payload pass-through promise, not permission to add redaction, truncation, or media processing.

#### Scenario: AI capture drops null-valued properties on its delivery route (@server)
- **GIVEN** an initialized SDK supporting AI capture with no property-changing hooks or filters
- **WHEN** capture_ai is called with distinct id "user-123", event "$ai_generation", and custom properties represented by JSON `{"test":null,"nested":{"drop":null},"items":["1",null,2]}`
- **AND** the SDK is flushed
- **THEN** one event named "$ai_generation" should be received on the AI batch endpoint
- **AND** its custom properties should equal JSON `{"nested":{},"items":["1",null,2]}`
- **AND** the analytics batch endpoint should receive no events

### Requirement: AI instrumentation attributes events to the active context

AI instrumentation that emits AI events from OpenTelemetry spans SHALL attribute the events it
exports to the active context where the SDK has an ambient or request context primitive. This
covers the `PostHogSpanProcessor` / `SpanProcessor` bridge in posthog-js `@posthog/ai`,
posthog-python, and posthog-go `otel`. The requirement is conditioned on both: an SDK with no AI
bridge, or an AI bridge on a platform with no context primitive, is conformant. Where the bridge
takes the SDK client as an option to reach the context (posthog-js `@posthog/ai` reads it only
when `PostHogSpanProcessor` is given `client`), the requirement applies once that option is set.

Where it applies:

- The context's distinct id SHALL be exported as the `posthog.distinct_id` attribute, and the
  context's session id as `$session_id` — the same session key as `capture`, so AI events join
  session replays. `$ai_session_id` SHALL NOT be used for the context session; it stays available
  for the instrumentation's own conversation id or an explicit caller-supplied property.
- Each context property SHALL be exported as an attribute under its own key, unchanged.
- Precedence SHALL be: an attribute the span already carries, then a context property, then the
  context's distinct id or session id.
- Where the span already names a user, the instrumentation SHALL NOT add `posthog.distinct_id`
  from the context or from a context property. The identity attributes recognized for this are
  `posthog.distinct_id`, `user.id`, and the instrumentation's own distinct-id metadata keys
  (`ai.telemetry.metadata.posthog_distinct_id`, `ai.settings.context.posthog_distinct_id`).
- The active context SHALL be captured when the span starts and applied when it ends, so
  concurrent requests each export their own values and a span outliving its context keeps the
  context it started in. Whether a context property mutated in place while the span is open is
  seen at export is platform-specific.
- The instrumentation SHALL NOT mutate the live span: the attributes SHALL be merged into the
  exported copy only, so other processors and exporters on the same tracer provider never observe
  the context. Spans the bridge does not export as AI events SHALL be left untouched.
- Attribution SHALL be best effort and SHALL NOT raise into the instrumented call: a failing or
  unavailable context source, and a value the platform cannot represent as an attribute, SHALL
  skip the affected key rather than propagate an error or drop the span.
- A value that is absent, null, an empty string, or a non-finite number SHALL be skipped rather
  than exported. Conversion of the remaining values to attributes is platform-idiomatic.

#### Scenario: the active context attributes the exported AI event (@server)
- **GIVEN** AI instrumentation wired to the SDK's context primitive
- **AND** an active context with distinct id "user-123", session id "s-1", and property "plan" set to "pro"
- **WHEN** an AI span started inside that context ends
- **THEN** the exported AI event should carry `posthog.distinct_id` "user-123"
- **AND** it should carry `$session_id` "s-1"
- **AND** it should carry "plan" equal to "pro"

#### Scenario: concurrent contexts do not mix (@server)
- **GIVEN** AI instrumentation wired to the SDK's context primitive
- **AND** two requests running concurrently, one in a context with distinct id "user-a" and one with "user-b"
- **WHEN** an AI span started in each request ends
- **THEN** each exported AI event should carry the distinct id of the context its span started in

#### Scenario: a span that already names a user keeps it (@server)
- **GIVEN** an active context with distinct id "user-123"
- **WHEN** an AI span carrying its own `user.id` attribute "span-user" ends
- **THEN** the exported AI event should not carry `posthog.distinct_id` "user-123"

#### Scenario: the span's own attribute wins over a context property (@server)
- **GIVEN** an active context with property "plan" set to "pro"
- **WHEN** an AI span carrying its own "plan" attribute "enterprise" ends
- **THEN** the exported AI event should carry "plan" equal to "enterprise"

#### Scenario: the live span is not changed (@server)
- **GIVEN** AI instrumentation and a second span processor registered on the same tracer provider
- **AND** an active context with distinct id "user-123"
- **WHEN** an AI span started inside that context ends
- **THEN** the second processor should observe no `posthog.distinct_id` attribute on the span

#### Scenario: a broken context source does not break the call (@server)
- **GIVEN** AI instrumentation whose context source raises when read
- **WHEN** an AI span ends
- **THEN** the instrumented call should observe no exception
- **AND** the AI event should still be exported, without context attributes

#### Scenario: unrepresentable context values are skipped (@server)
- **GIVEN** an active context with properties that include a null value, an empty string, and a non-finite number
- **WHEN** an AI span started inside that context ends
- **THEN** the exported AI event should omit those keys rather than export empty or non-finite values

### Requirement: AI events travel on their own lane to the capture v1 AI endpoint

An SDK that delivers events through capture v1 and supports AI capture SHALL send events captured through its AI method with `POST {host}/i/v1/ai/events`, using the request body, headers, per-event results and retry rules defined for analytics capture in `capture` and `retry-queue`. The AI method SHALL send the event as given, with the same event-building order as `capture`, and SHALL NOT reroute by event name: a non-`$ai_` event captured through the AI method is sent to the AI endpoint, where capture drops it with `details: misrouted_event`, and an `$ai_*` event captured through `capture` is sent to the analytics endpoint. The SDK MAY log at debug level when the AI method receives a non-`$ai_` name.

The AI lane SHALL have its own queue, flush cycle, retry state and in-flight request, started lazily on the first AI event, so that a slow or failing AI lane never delays, drops or resends analytics events, and the reverse. `flush()` and `shutdown()` SHALL signal both lanes before waiting on either, under one deadline.

Every platform of an SDK that delivers events through capture v1 SHALL ship this lane and the AI method; a wrapper SDK SHALL NOT leave a capture v1 platform without them. On a platform still on legacy capture (posthog-flutter on the web, which sends through posthog-js), the AI method SHALL send nothing, log that AI capture is unsupported there, and return the SDK's not-admitted value, and SHALL NOT fall back to `capture`.

Capture currently accepts `$ai_*` events on the analytics endpoint and forwards them to the AI pipeline. That acceptance is temporary; the SDK and its built-in integrations SHALL NOT rely on it.

Legacy capture: the AI route was `/i/v0/ai/batch/`, which rejected a whole batch containing a non-AI event.

#### Scenario: AI capture uses the capture v1 AI endpoint (@server)
- **GIVEN** an isolated SDK with empty persistent storage
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture_ai is called with JSON arguments:
  """application/json
  {"distinct_id":"test_user","event":"$ai_generation","properties":{"$ai_model":"gpt"}}
  """
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** every capture request path should be one of:
  | path             |
  | /i/v1/ai/events  |
- **AND** the first received event field "event" should equal "$ai_generation"
- **AND** the first request should authenticate with bearer token "phc_test_key"

#### Scenario: Ordinary capture does not reroute AI-named events (@server)
- **GIVEN** an isolated SDK with empty persistent storage
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **WHEN** capture is called with JSON arguments:
  """application/json
  {"distinct_id":"test_user","event":"$ai_generation"}
  """
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** every capture request path should be one of:
  | path                   |
  | /i/v1/analytics/events |
- **AND** no capture request should use "/i/v1/ai/events"

#### Scenario: A non-AI event on the AI method is sent and its misroute is reported (@server)
- **GIVEN** an isolated SDK with empty persistent storage
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the mock serves these ordered AI responses:
  | status | body                                                          |
  | 200    | {"results":{"*":{"result":"drop","details":"misrouted_event"}}} |
- **WHEN** capture_ai is called with JSON arguments:
  """application/json
  {"distinct_id":"test_user","event":"button_clicked"}
  """
- **AND** pending captures are flushed
- **THEN** exactly 1 capture request should have been received
- **AND** every capture request path should be one of:
  | path             |
  | /i/v1/ai/events  |
- **AND** the SDK should report the event "button_clicked" as dropped with details "misrouted_event"

#### Scenario: A failing AI lane does not delay analytics delivery (@server)
- **GIVEN** an isolated SDK with empty persistent storage
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** the mock delays every request to "/i/v1/ai/events" until released
- **WHEN** capture_ai is called with distinct id "test_user" and event "$ai_generation"
- **AND** capture is called with distinct id "test_user" and event "button_clicked"
- **AND** 2000 milliseconds elapse without a public SDK call
- **THEN** the analytics batch endpoint should have received "button_clicked"
- **WHEN** the delayed AI request is released and succeeds
- **AND** pending captures are flushed
- **THEN** the AI batch endpoint should have received "$ai_generation"

### Requirement: Built-in AI integrations always use the AI method

PostHog's own AI wrapper libraries and instrumentation that emit `$ai_*` events through the SDK (provider wrappers, the OpenTelemetry AI bridge where it captures events, MCP add-ons) SHALL send them through the client's AI method on every capture v1 SDK, regardless of `enable_full_ai_capture` or any other setting. They SHALL set `process_person_profile: false` as an option when they substitute a trace or session id for a missing user id, and SHALL never write a legacy option property. A wrapper given a client object that lacks the AI method (a stand-in or mock) SHALL log one error when it is constructed and turn its own AI capture off; it SHALL NOT fall back to `capture` and SHALL NOT raise into the host application.

Legacy capture: wrappers sent through `capture` unless `enable_full_ai_capture` was set.

#### Scenario: A wrapper event rides the AI lane with the flag unset (@server)
- **GIVEN** an isolated SDK with empty persistent storage
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 1
- **AND** a PostHog AI wrapper is attached to the client with the full-capture flag unset
- **WHEN** the wrapper records one generation
- **AND** pending captures are flushed
- **THEN** the AI batch endpoint should receive "$ai_generation"
- **AND** the analytics batch endpoint should receive no events

#### Scenario: A client without the AI method disables the wrapper's capture without raising (@server)
- **GIVEN** a client object that exposes capture but not the AI method
- **WHEN** a PostHog AI wrapper is constructed around it
- **AND** the wrapper records one generation
- **THEN** the construction and the recording should not throw
- **AND** the wrapper should log one error about the missing AI method
- **AND** no event should be sent through capture

### Requirement: AI lane configuration is scoped to the AI lane

An SDK that delivers events through capture v1 and supports AI capture SHALL expose the AI lane's compression mode, queue capacity and request timeout as public options named after the lane (for example `capture_ai_compression`, `capture_ai_max_queue_size` and `capture_ai_timeout` in posthog-python; `CaptureAICompression`, `CaptureAIMaxQueueSize` and `CaptureAIBatchUploadTimeout` in posthog-go; `capture_ai_compression` and `capture_ai_max_queue_size` in posthog-rs, whose request timeout is shared; `captureAiCompression`, `captureAiMaxQueueSize` and `captureAiRequestTimeoutMs` in posthog-node). The defaults SHALL be a queue capacity of 1000 events and a request timeout of 30 seconds. The default compression is the SDK's choice and SHALL be documented: posthog-python, posthog-go and posthog-rs default to none, posthog-node to gzip. The SDK SHALL offer only the codecs its runtime provides and SHALL validate the effective lane values after defaults are applied.

The analytics lane's compression and queue capacity, including environment variables that set analytics compression, SHALL NOT change AI uploads, and the reverse. Batching settings such as the flush threshold, flush interval and batch size, and the request timeout where the SDK has one shared value, MAY be shared between the lanes. The 5 MiB batch target SHALL NOT be configurable. The per-event size cap MAY be exposed (`capture_ai_max_event_bytes` in posthog-python) and then only lowered: a configured value above the SDK's ceiling SHALL NOT take effect, and the SDK SHALL either refuse it (posthog-python raises) or clamp it to the ceiling with a log.

#### Scenario: Analytics compression does not reach the AI lane (@server)
- **GIVEN** an isolated SDK with empty persistent storage
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key", flush threshold 1, and analytics compression "gzip"
- **AND** no AI lane compression is configured
- **WHEN** capture is called with distinct id "test_user" and event "button_clicked"
- **AND** capture_ai is called with distinct id "test_user" and event "$ai_generation"
- **AND** pending captures are flushed
- **THEN** the request received on the analytics batch endpoint should declare "Content-Encoding" "gzip"
- **AND** the request received on the AI batch endpoint should carry the SDK's documented AI compression default

#### Scenario: The per-event cap can be lowered but not raised (@server)
- **GIVEN** an isolated SDK with empty persistent storage
- **AND** the mock PostHog server is reset
- **AND** the SDK exposes a per-event size cap for the AI lane
- **WHEN** the SDK is initialized with a per-event cap below the SDK's ceiling
- **AND** capture_ai is called with an event whose properties exceed the configured cap but not the ceiling
- **AND** pending captures are flushed
- **THEN** no event should reach the AI batch endpoint
- **AND** the SDK should report the event as dropped locally
- **WHEN** the SDK is initialized with a per-event cap above the SDK's ceiling
- **THEN** the SDK should not use a cap above its ceiling

### Requirement: AI event size and batching on capture v1

An SDK that delivers events through capture v1 and supports AI capture SHALL NOT send an AI event it measures over the 8 MiB ceiling on `properties`, and SHALL NOT refuse one at or under that size. The SDK SHALL either measure `properties` exactly or measure the whole serialized event against the ceiling plus a fixed envelope headroom (64 KiB in posthog-python and posthog-go); an event the whole-event measure admits but capture rejects comes back as `details: ai_event_too_big` and is surfaced like any other drop. An event over the SDK's measure SHALL be dropped on every send path, including immediate and synchronous ones, and reported through the SDK's error surface or a log line that names the event and its byte size and never its content.

The AI lane SHALL batch by bytes with a 5 MiB target, checked before appending: when the batch is non-empty and the next event would exceed the target, the batch is sent first and the event starts the next one, so order is kept and an event over the target ships alone.

Capture drops an AI event over its own ceiling with `details: ai_event_too_big` and one over the project's AI byte budget with `details: ai_byte_rate_limited`; the SDK SHALL surface both as opaque `details` strings like any other drop.

#### Scenario: An event at the ceiling is sent and one over it is dropped with a content-free log (@server)
- **GIVEN** an isolated SDK with empty persistent storage
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 2
- **WHEN** capture_ai is called with event "$ai_generation" named "at-ceiling" whose properties serialize to exactly 8388608 bytes
- **AND** capture_ai is called with event "$ai_generation" named "over-ceiling" whose properties serialize to 9437184 bytes and contain the marker "SECRET-MARKER"
- **AND** pending captures are flushed
- **THEN** the AI batch endpoint should receive exactly 1 event
- **AND** the received event should be "at-ceiling"
- **AND** the SDK should log the event name and byte size of "over-ceiling"
- **AND** the log output should not contain "SECRET-MARKER"

#### Scenario: AI batches close before the byte target and keep order (@server)
- **GIVEN** an isolated SDK with empty persistent storage
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 10
- **WHEN** capture_ai is called sequentially 3 times with an event named "gen-{index}" whose properties serialize to about 3 MiB
- **AND** pending captures are flushed
- **THEN** at least 2 capture request should have been received on the AI batch endpoint
- **AND** no received request body should exceed the SDK's byte target plus envelope overhead
- **AND** the events "gen-0", "gen-1" and "gen-2" should have been received in that order across the requests

