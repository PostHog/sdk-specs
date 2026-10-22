## Overview

This change adds no capability. It records the attribution contract that posthog-js, posthog-python
and posthog-go implemented identically for the OpenTelemetry span processor that turns AI SDK spans
into PostHog AI events.

## Key Decisions

- **Keep it in `capture-ai` rather than `traces` or a new capability.** `traces` specifies
  PostHog's own tracing API, which carries no OpenTelemetry dependency and uses the logs wire keys
  (`posthogDistinctId`, `sessionId`); the AI bridge is OTel-native and uses the ingestion keys
  (`posthog.distinct_id`, `$session_id`). `capture-ai` is the spec that already governs what
  PostHog's AI instrumentation emits, so attribution belongs next to it. A separate
  `ai-otel-bridge` capability would be justified if more of the bridge were written down; today
  attribution is the only part with three agreeing implementations.
- **Specify the outcome, not the mechanism.** The three SDKs store the snapshot differently (a
  `WeakMap`, a lock-guarded map keyed by trace/span id with fork reset, a mutex-guarded map) and
  convert values differently, because attribute typing differs per platform. What they agree on is
  observable: which keys appear, what wins, and that nothing else on the provider sees the context.
  Value conversion is therefore left platform-idiomatic, with only the skip rules pinned, since a
  skipped key and a coerced key are both observable at ingestion.
- **Pin the snapshot to span start and the stamp to span end.** All three snapshot in `onStart` and
  merge in `onEnd`, which is what makes concurrent requests attribute correctly — a span started
  inside one request keeps that request's person even if it ends after the context exits.
- **Require that the live span is not mutated.** Each implementation's first version wrote onto the
  live span, and each was changed after review because that leaks the person, session and properties
  to every other processor and exporter on the same provider. Writing it down is what stops the next
  port from repeating it.
- **Leave the context primitive to the platform.** Node reads an explicit client option because each
  client owns its own `AsyncLocalStorage`; Python reads its contextvars-based context; Go reads the
  `context.Context` the span was started from. The requirement binds the attribution, not the wiring.

## Alternatives Considered

- **Require the AI bridge everywhere.** Rejected. Only three SDKs ship it, and `capture-ai` already
  conditions its surface on an SDK supporting AI capture at all.
- **Specify `$ai_session_id` as the session key.** Rejected, and explicitly the other way round: all
  three map the context session to `$session_id` so AI events join replays, and deliberately leave
  `$ai_session_id` to the instrumentation's conversation id.
- **Wait for a fourth SDK.** Rejected. Three independent implementations agreeing is the strongest
  signal this repo gets that a behavior is contractual rather than incidental.

## Open Questions

- Whether the value-conversion rules (which types pass through as attributes, which become JSON
  strings) should be pinned cross-SDK. They are close but not identical — Go has typed slices,
  Python stringifies out-of-range integers — and no user-visible disagreement is known, so the
  requirement pins only the skip rules.
- Whether this belongs in `capture-ai` long term, or in a dedicated capability covering the rest of
  the OTel AI bridge (span-to-event mapping, redaction, the exporter). Worth a human call.
