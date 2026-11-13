## Narrative alignment

When syncing this delta into the canonical `capture-ai` spec:

- In Purpose, replace "PostHog's own AI wrapper libraries route through it when the client opts in" with: PostHog's own AI wrapper libraries always send through it; users call it directly for manual AI capture. Drop the "public beta" status line and say the surface is the capture v1 AI lane.
- In Applicability, list the implementations: posthog-python 8.0 (`capture_ai`), posthog-node 6.0 (`captureAi`), posthog-go v2 (`EnqueueAI`), posthog-rs 1.0 (`capture_ai`). Keep the sentence that other server SDKs adopt the spec when they add AI support.
- In Public signatures, add the Go and Rust shapes: `client.EnqueueAI(msg)` / `posthog.EnqueueAIWithContext(ctx, client, msg)` accepting any message type; `client.capture_ai(event)`, `capture_ai_batch(events, historical_migration)`, and the `*_immediate` variants returning the per-event summary.
- In Configuration, rewrite the content-capture flag text so items 1 to 3 become: skip string truncation, and pass media through unredacted. Remove "route their events through the dedicated AI path", and add the AI lane delivery section from **AI lane configuration is scoped to the AI lane**.
- In Behavior step 1, keep "`$lib`/`$lib_version`", point it at `capture`'s **Events name their own library**, and point at `capture`'s layer order.
- In Behavior step 2, return the UUID only where the AI method returns a value (posthog-python, posthog-node); name Go's error-only `EnqueueAI` and Rust's unit-returning queued methods, whose events still carry the UUID on the wire.
- In Behavior step 4, keep at-least-once delivery, and add that on capture v1 only `retry` results are resent.
- Replace the Transport (non-normative) section with the capture v1 values: endpoint `/i/v1/ai/events`, request body up to 20 MiB compressed, an 8 MiB ceiling on `properties`, a 5 MiB batch target, per-event results, and the retry rules of `retry-queue`.

## ADDED Requirements

### Requirement: AI events travel on their own lane to the capture v1 AI endpoint

An SDK that delivers events through capture v1 and supports AI capture SHALL send events captured through its AI method with `POST {host}/i/v1/ai/events`, using the request body, headers, per-event results and retry rules defined for analytics capture in `capture` and `retry-queue`. The AI method SHALL send the event as given, with the same event-building order as `capture`, and SHALL NOT reroute by event name: a non-`$ai_` event captured through the AI method is sent to the AI endpoint, where capture drops it with `details: misrouted_event`, and an `$ai_*` event captured through `capture` is sent to the analytics endpoint. The SDK MAY log at debug level when the AI method receives a non-`$ai_` name.

The AI lane SHALL have its own queue, flush cycle, retry state and in-flight request, started lazily on the first AI event on server SDKs, so that a slow or failing AI lane never delays, drops or resends analytics events, and the reverse. `flush()` and `shutdown()` SHALL signal both lanes before waiting on either, under one deadline. Client SDKs: the AI queue is durable (on disk), starts at launch so events left from an earlier launch are sent, and `flush()` and `close()` signal both lanes without blocking.

Every platform of an SDK that delivers events through capture v1 SHALL ship this lane and the AI method; a wrapper SDK SHALL NOT leave a capture v1 platform without them. On a platform still on legacy capture (posthog-flutter on the web, which sends through posthog-js), the AI method SHALL send nothing, log that AI capture is unsupported there, and return the SDK's not-admitted value, and SHALL NOT fall back to `capture`.

Capture also accepts `$ai_*` events on the analytics endpoint and forwards them to the AI pipeline, but only temporarily; the SDK and its built-in integrations SHALL NOT rely on it.

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

On capture v1 a built-in AI integration SHOULD accept event options per call, named after its per-call properties argument: `posthog_options` next to `posthog_properties` in posthog-python, and `posthogOptions` next to `posthogProperties` in `@posthog/ai`. They are the event's own options, so context and global options fill only the keys they leave unset. The integration SHALL apply its `process_person_profile: false` for a missing user id last, so it wins over a per-call `process_person_profile`.

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

An SDK that delivers events through capture v1 and supports AI capture SHALL expose the AI lane's compression mode, queue capacity and request timeout as public options named after the lane (for example `capture_ai_compression`, `capture_ai_max_queue_size` and `capture_ai_timeout` in posthog-python; `CaptureAICompression`, `CaptureAIMaxQueueSize` and `CaptureAIBatchUploadTimeout` in posthog-go; `capture_ai_compression` and `capture_ai_max_queue_size` in posthog-rs, whose request timeout is shared; `captureAiCompression`, `captureAiMaxQueueSize` and `captureAiRequestTimeoutMs` in posthog-node; `captureAiCompression`, `captureAiMaxQueueSize`, `captureAiTimeout` and `captureAiMaxEventBytes` in posthog-ios, posthog-android and the posthog-flutter `PostHogConfig`). The defaults SHALL be a queue capacity of 1000 events and a request timeout of 30 seconds on server SDKs. Client SDKs: posthog-ios 4.0, posthog-android 4.0 and the posthog-flutter 6.0 Windows and Linux lane default to 100 events and a 60 second timeout, which is an idle read and write timeout, not a deadline for the whole request, with a fixed 50 MiB disk cap that drops the oldest events. The default compression is the SDK's choice and SHALL be documented: posthog-python, posthog-go and posthog-rs default to none; posthog-node, posthog-ios, posthog-android and the posthog-flutter 6.0 Windows and Linux lane to gzip. The SDK SHALL offer only the codecs its runtime provides and SHALL validate the effective lane values after defaults are applied.

The analytics lane's compression and queue capacity, including environment variables that set analytics compression, SHALL NOT change AI uploads, and the reverse. Batching settings such as the flush threshold, flush interval and batch size, and the request timeout where the SDK has one shared value, MAY be shared between the lanes. The 5 MiB batch target SHALL NOT be configurable. The per-event size cap MAY be exposed (`capture_ai_max_event_bytes` in posthog-python) and then only lowered: a configured value above the SDK's ceiling SHALL NOT take effect, and the SDK SHALL either refuse it (posthog-python raises) or clamp it to the ceiling with a log (posthog-ios and posthog-android). The cap measures what the SDK's size check measures (see **AI event size and batching on capture v1**): where that is the whole serialized event, the cap's ceiling is the 8 MiB properties limit plus the SDK's envelope headroom (64 KiB in posthog-python, posthog-go, posthog-ios, posthog-android and the posthog-flutter 6.0 Windows and Linux lane).

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

An SDK that delivers events through capture v1 and supports AI capture SHALL NOT send an AI event it measures over the 8 MiB ceiling on `properties`. With the default cap and an exact `properties` measure, it SHALL NOT refuse one at or under that size; a lowered cap, or the whole-event measure described next, MAY refuse a smaller event. The SDK SHALL either measure `properties` exactly or measure the whole serialized event against the ceiling plus a fixed envelope headroom (64 KiB in posthog-python, posthog-go, posthog-ios, posthog-android and the posthog-flutter 6.0 Windows and Linux lane); an event the whole-event measure admits but capture rejects comes back as `details: ai_event_too_big` and is surfaced like any other drop. An event over the SDK's measure SHALL be dropped on every send path, including immediate and synchronous ones, and reported through the SDK's error surface or a log line that names the event and its byte size (or "over N bytes" when the SDK stops measuring at the cap) and never its content.

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
- **AND** the SDK should report "over-ceiling" as dropped or log its event name and byte size
- **AND** the log output should not contain "SECRET-MARKER"

#### Scenario: AI batches close before the byte target (@server)
- **GIVEN** an isolated SDK with empty persistent storage
- **AND** the mock PostHog server is reset
- **AND** the SDK is initialized with token "phc_test_key" and flush threshold 10
- **WHEN** capture_ai is called sequentially 3 times with an event named "gen-{index}" whose properties serialize to about 3 MiB
- **AND** pending captures are flushed
- **THEN** at least 2 capture request should have been received on the AI batch endpoint
- **AND** no received request body should exceed the SDK's byte target plus envelope overhead
- **AND** the events "gen-0", "gen-1" and "gen-2" should all have been received, in any order across the requests

## MODIFIED Requirements

### Requirement: Canonical capture_ai behavior

Server SDKs that support AI capture SHALL implement `capture_ai` as described
by this spec. Implementations MAY adapt method names, parameter casing, and
option naming to platform idioms, but MUST preserve the observable outcomes in
the scenarios below.

#### Scenario: capture_ai mirrors capture's parameters (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **WHEN** capture_ai is called with distinct id "user-123", event "$ai_generation", and properties:
  | property  | value |
  | $ai_model | gpt   |
- **THEN** one event named "$ai_generation" should be enqueued on the AI route
- **AND** the enqueued event should include a timestamp and uuid

#### Scenario: capture_ai returns the event UUID where the AI method returns a value (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK's AI method returns a value
- **AND** the SDK is initialized with token "test-token"
- **WHEN** capture_ai is called with distinct id "user-123" and event "$ai_generation"
- **THEN** the call should return the enqueued event's uuid

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
- **AND** the SDK should report the drop or log the event name and byte size
- **AND** the log output should not contain the event's property values

#### Scenario: capture_ai never throws (@server)
- **GIVEN** a fresh SDK acceptance test harness
- **AND** the SDK is initialized with token "test-token"
- **AND** the AI batch endpoint is unreachable
- **WHEN** capture_ai is called with distinct id "user-123" and event "$ai_generation"
- **AND** the SDK is flushed
- **THEN** the caller should observe no exception

### Requirement: Full AI capture flag

An SDK that ships PostHog AI wrapper libraries SHALL expose a single boolean
option (default false), named `enable_full_ai_capture` adapted to platform
convention (posthog-python and posthog-node ship it), that governs what the
SDK's AI wrapper libraries capture. When true, the wrappers skip string truncation and pass media through unredacted; when false, they truncate long strings and replace media with a type-aware placeholder. The flag SHALL NOT change which route the wrappers use: on a capture v1 SDK they always send through the AI method (see **Built-in AI integrations always use the AI method**). It SHALL NOT alter payloads passed to
`capture_ai` directly.

#### Scenario: wrapper media is redacted by default and passed through when enabled (@server)
- **GIVEN** an AI wrapper on a capture v1 SDK capturing a payload containing base64 media
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
