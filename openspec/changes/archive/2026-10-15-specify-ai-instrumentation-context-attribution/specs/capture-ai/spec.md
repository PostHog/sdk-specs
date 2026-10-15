## ADDED Requirements

### Requirement: AI instrumentation attributes events to the active context

Where an SDK ships AI instrumentation that emits AI events from OpenTelemetry spans (the
`PostHogSpanProcessor` / `SpanProcessor` bridge in posthog-js `@posthog/ai`, posthog-python, and
posthog-go `otel`) **and** the SDK has an ambient or request context primitive, that
instrumentation SHALL attribute the AI events it exports to the active context. The requirement
is conditioned on both: an SDK with no AI bridge, or an AI bridge on a platform with no context
primitive, is conformant.

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
- The snapshot SHALL be taken when the span starts and applied when it ends, so concurrent
  requests each export their own values and a span outliving its context keeps the context it
  started in.
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
