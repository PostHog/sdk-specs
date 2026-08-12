# Capture AI Specification

## Purpose

`capture_ai` records a single AI observability event (the `$ai_*` family:
`$ai_generation`, `$ai_span`, `$ai_trace`, `$ai_embedding`, ...). It takes
exactly the same arguments as the host SDK's `capture` but delivers the event
on an isolated route to PostHog's dedicated AI ingestion endpoint, which
accepts much larger payloads than analytics capture. PostHog's own AI wrapper
libraries route through it when the client opts in; users call it directly for
manual AI capture.

`capture_ai` is a pipe: it sends the payload as given. Redaction, truncation,
and media handling are wrapper concerns governed by configuration — never
applied to manual `capture_ai` payloads.

Status: public beta. The surface described here is frozen; guarantees may
strengthen, never weaken, before GA.

## Applicability

`server` — currently implemented by posthog-python and posthog-node. Other
server SDKs (Rust, Go, Ruby, ...) adopt this spec if and when they add AI
support; until then their AI events ride plain `capture` under its standard
limits.

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

1. route their events through the dedicated AI path instead of analytics
   `capture`,
2. skip string truncation (a cut through base64 corrupts media; large text
   contexts stay intact), and
3. pass media (raw bytes, base64, data URIs) through unredacted instead of
   replacing it with type-aware placeholders.

Privacy mode always takes precedence: with it on, content properties are
stripped regardless of this flag.

## Behavior

1. **Admission.** Same enrichment pipeline as `capture` (distinct id,
   timestamp, `$lib`/`$lib_version`, `before_send`), differing only in the
   delivery route.
2. **UUID.** The SDK attaches a client-generated UUID to every event on the
   AI path when the caller supplies no UUID, and returns the attached UUID to
   the caller. Handling of an invalid supplied UUID is platform-idiomatic
   (replace or reject).
3. **Isolation.** AI events ride their own queue/buffer with independent
   size caps, batching, and retry policy; they never share a send cycle with
   analytics events. The queue starts lazily — clients that never capture AI
   events pay no overhead.
4. **Delivery.** At-least-once delivery is permitted (retries may duplicate)
   only because of rule 2 — the server dedupes on
   `[timestamp, distinct_id, event, uuid]`. At-most-once (drop after retry
   exhaustion) is equally compliant. The invariant is the UUID, not the
   delivery count.

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

These are current operational values, explicitly NOT part of this contract,
and may change without notice: endpoint `/i/v0/ai/batch/` (v0 batch wire
shape), 8 MiB per-event cap, ~5 MiB batch target, compression per SDK default
(Node: transport gzip on unless disabled; Python: gzip opt-in), bounded
retries with backoff. Capture v1 re-implements the same contract on
`/i/v1/ai/...` with per-event outcomes; that cutover must not change anything
in the Requirements below.

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
- **THEN** the event received on the AI batch endpoint should carry exactly that uuid

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
SDK's AI wrapper libraries capture. It SHALL NOT alter payloads passed to
`capture_ai` directly.

#### Scenario: wrapper media is redacted by default and passed through when enabled (@server)
- **GIVEN** an AI wrapper capturing a payload containing base64 media
- **WHEN** the client has the flag unset
- **THEN** the captured content should replace the media with a type-aware placeholder
- **WHEN** the client has the flag set to true
- **THEN** the captured content should contain the media unmodified
- **AND** no string truncation should be applied to the captured content

#### Scenario: privacy mode wins over the flag (@server)
- **GIVEN** an AI wrapper capturing a payload containing base64 media
- **AND** the client has privacy mode enabled and the flag set to true
- **THEN** the captured event should carry no input or output content

