## Why

Three SDKs shipped the same behavior in the same week: the OpenTelemetry span processor that
turns AI SDK spans into PostHog AI events now stamps the active PostHog context onto the AI
spans it exports, so a server that traces LLM calls for many users attributes each AI event to
the right person and session instead of to one process-wide resource attribute.

- [PostHog/posthog-js#5299](https://github.com/PostHog/posthog-js/pull/5299) — `@posthog/ai`
  `PostHogSpanProcessor`, new `client` option reading `withContext`/`enterContext`
- [PostHog/posthog-python#1060](https://github.com/PostHog/posthog-python/pull/1060) —
  `PostHogSpanProcessor` reading `new_context()` / `identify_context` / `tag`
- [PostHog/posthog-go#371](https://github.com/PostHog/posthog-go/pull/371) — `otel`
  `SpanProcessor` reading `RequestContextFromContext`

`capture-ai` is the only spec that governs how PostHog's AI instrumentation emits AI events, and
it says nothing about attribution: which keys carry the person and session, what wins when the
span already names a user, and whether the instrumentation may mutate the span other processors
and exporters see. All three implementations agreed on every one of those answers, so the
contract exists already — it is just unwritten, and the next port has nothing to copy.

## What Changes

- Add one requirement to `capture-ai`, **AI instrumentation attributes events to the active
  context**, stating: attribution is read from the SDK's own context primitive; the wire keys are
  `posthog.distinct_id` and `$session_id`; `$ai_session_id` stays free for the instrumentation's
  conversation ID; precedence runs span attribute → context property → context distinct id /
  session id; a span that already names a user keeps it; the live span is never mutated; and
  stamping never raises into the instrumented call.
- Note in `Applicability` that this requirement binds any SDK shipping the OTel AI bridge, which
  now includes posthog-go, whether or not it exposes `capture_ai`.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `capture-ai`: adds the **AI instrumentation attributes events to the active context**
  requirement and one `Applicability` sentence.

## Impact

Not a breaking change for the contract: it records what posthog-js, posthog-python and
posthog-go all do as of the PRs above. It is a behavior change for *users* of those SDKs — an app
that already runs PostHog contexts (Django/Flask/ASGI middleware, `NewRequestContextMiddleware`,
posthog-node `withContext`) sees its AI events attributed to the context's person after
upgrading, which each SDK's changeset calls out.

SDKs with no AI instrumentation, and AI instrumentation on a platform with no ambient or request
context primitive, stay conformant: the requirement is conditioned on both existing.
