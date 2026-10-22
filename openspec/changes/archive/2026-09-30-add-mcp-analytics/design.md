## Context

Sources, in priority order:

1. The shipped SDKs: `@posthog/mcp` 0.21.1 (`posthog-js/packages/mcp/src/extensions/`, vocabulary in
   `constants.ts`) and `posthog.mcp` 0.3.0 in posthog 7.60.2 (`posthog-python/posthog/mcp/`,
   vocabulary in `constants.py`). Both are at feature parity; the differences are listed under
   Conformance below.
2. The product that reads the events: `PostHog/posthog` `products/mcp_analytics/` (query runners in
   `backend/hogql_queries/`, harness resolution in `backend/mcp_harness.py`, sessions and intent in
   `backend/logic.py` and `backend/intent_generation.py`, clustering in
   `posthog/temporal/mcp_analytics/`) and `posthog/taxonomy/taxonomy.py`.
3. The MCP specification, revision 2026-07-28 (`basic/index.mdx` per-request `_meta` fields and
   statelessness, `server/tools.mdx` error handling, `basic/patterns/mrtr.mdx` multi-round-trip
   requests, `seps/2567-sessionless-mcp.md`), and open proposals SEP-2817 (`aiInvocation` intent and
   model in `_meta`) and SEP-2145 (tool-not-found as an `isError` result).
4. posthog-go `posthogmcp` (v1.28.0) and its go-sdk adapter (in review), which were built against this
   contract while it was being written.

## Goals / Non-Goals

**Goals:**

- One contract every MCP analytics SDK implements, so ports stop inheriting each other's drift.
- Every required property is one the product reads, with the type and meaning it assumes, so
  conformance means the dashboards are correct rather than merely that events arrive.
- Executable acceptance scenarios that a new SDK can run to prove conformance.

**Non-Goals:**

- Specifying the product's queries. The spec states what SDKs send; the product's use of it is cited
  only to justify requirements.
- LLM analytics. Token counts, cost, and prompt or completion content belong to `$ai_*` events.
- Requiring every property an SDK emits. A property some SDKs ship and others do not (such as
  `$mcp_input_keys`) is defined as optional, so the next SDK to add it sends the same name and shape.

## Decisions

### The spec covers data collection, not how the product uses it

The spec states what an SDK sends and what the data means; each rule's reason is given in terms of the
data. How PostHog's product reads the events (which queries, views, and reports) is recorded here as
the history of a decision, never in the spec, so the contract does not change when the product does.

### Required properties are the ones the product reads

`$mcp_tool_name`, `$mcp_is_error`, `$mcp_duration_ms`, `$mcp_source`, `$session_id`, and the
request-start timestamp are required because each feeds counts, filters, or ordering: the dashboard
drops calls without a tool name, `toBool($mcp_is_error)` miscounts non-boolean encodings, percentiles
need a numeric duration, per-tool views filter on `$mcp_source`, and neighbors, journeys, and the intent
carried forward within a session depend on timestamp order. Properties the product reads but can live
without (`$mcp_error_type`, `$mcp_intent`, client identity, tool description and category, model) are
required when known. `$mcp_session_id` is constrained rather than required, because the product
prefers it over `$session_id` when grouping conversations. Everything else is optional. Alternative considered: requiring the full union
of what the SDKs emit. Rejected because it would lock in properties no one reads and block leaner
ports.

### One event per final tool-call outcome

Under the 2026-07-28 revision a tool call can span several requests: an `input_required` result
followed by a retry. Counting each request would inflate call counts and error rates, so only the
request that ends the call emits `$mcp_tool_call`. No SDK implements this yet; each emits per request,
which is correct only while no tool returns `input_required`.

### `context` is required only where the SDK strips it before validation

A required `context` argument gets much better intent coverage, because models fill required
arguments. But if the MCP framework validates arguments against the advertised schema before the SDK
can remove `context`, requiring it rejects calls from clients that omit it. So the rule is by
mechanism, not by language: required where the SDK strips first (TypeScript, the Python high-level
server, the Go adapter), optional elsewhere (the Python low-level server). This matches what each SDK
already does.

### Conversation anchoring on by default, with the session id derivation written down

The 2026-07-28 revision removed protocol sessions (SEP-2567), so a stateless client has no in-protocol
grouping key. An SDK-minted handle echoed by the agent is the only stable one. Session ids derived from
the same handle must match across SDKs so that one conversation served by a TypeScript gateway and a
Python backend is one session, so the spec states the derivation (two FNV-1a lanes, as in
`deterministicPrefixedId` in `@posthog/mcp` and `deterministic_prefixed_id` in `posthog.mcp`) and pins
a test vector computed by both. Inputs are ASCII in practice (UUIDv7 handles and transport ids); the
two SDKs iterate UTF-16 code units and code points respectively, which agree on ASCII. Minting is
skipped when the request has a transport session (a session id, a PostHog session token, or a stdio process), because
the connection already groups those calls, and a handle that cannot be returned to the agent is not recorded, because it would never be echoed.

### Stateless revisions shape sessions, listings, and outcomes

Probing `@posthog/mcp` and `posthog.mcp` on real servers across 2025-11-25 (stateful, stateless,
stdio) and 2026-07-28, then an adversarial review, settled these rules:

- The SDK-generated session is scoped to one connection. One shared stateless instance put unrelated
  clients in one session; per-request instances gave each request its own. A stateless request with no
  handle now gets its own id, so sessions never merge clients.
- `$mcp_tools_list` describes the catalogue. A `tools/list` request has no arguments, so it cannot
  carry a conversation handle, and under anchoring its `$session_id` never matched the calls that
  followed. The product's per-session discovery rate needs to join on the server's catalogue instead.
- A task handle is not an outcome. The legacy experimental tasks path reported creation as a 2 ms
  success and never recorded the real result, so the call is emitted at the task's terminal status.
- The SDK never writes its session token onto a transport several clients share. Doing so broke the
  second client's `initialize` on a long-lived stateless transport. The token format both SDKs already
  share (base64url JSON with `sid`, `cn`, `cv`, `pv`) is written down, so a Go or Ruby server decodes
  it instead of hashing it into a different session.
- A transport session suppresses minting, on stdio as on legacy HTTP. Both SDKs minted a handle on
  every stdio call without one, so an agent that does not echo the handle turned each call into its
  own session although the process already groups them.
- A tool's own `context` argument is the tool's data, not the agent's intent. Reading it as intent fed
  tool payloads into intent clustering.
- An unknown tool name is not a call: it is whatever the agent sent, so counting it would fill the
  per-tool views with tools that do not exist. It gets its own `$mcp_unknown_tool` event instead,
  because an agent reaching for a missing tool is a missing-capability signal. Invalid arguments to a
  real tool are a failed call, labeled `validation` where the SDK can tell.
- An `input_required` round is not a call either, but it gets its own `$mcp_input_required` event:
  it shows how often a tool has to ask and what for. Linking a round to the retry that answers it, to
  see abandoned calls, is left open (see Known limitations).
- A task handle is never a successful call. The task's call is emitted only where the SDK sees its
  terminal status recorded and still holds the originating call, after the store accepts the status.
  Emitting on `tasks/get` duplicated events across replicas, and emitting from "the process that ran
  the work" named something no framework lets an SDK observe.
- `$mcp_parameters` holds only the tool name and arguments. An MRTR retry's `inputResponses` carry the
  user's elicitation answers, which the free-text privacy pass does not cover.
- Events come only from requests the client sent. `posthog.mcp` on mcp 2.2.0 recorded the framework's
  internal `tools/list` before every call and synthesized `$mcp_initialize` for sessionless requests.

### Responses are captured on every call

No dashboard query reads a successful call's `$mcp_response`; the activity feed reads it only as a
fallback error message for SDK versions that did not set `$mcp_error_message`, which is now required.
It stays on by default anyway, because it serves the server owner investigating a problem: the
hardest MCP failures are successful calls that return an empty or wrong result, and the response is
the only record of what the agent saw. Capturing it only for failed calls, considered during review,
would have kept the copy that repeats `$mcp_error_message` and dropped the one that explains a silent
failure. The cost that mattered was CPU on large payloads, which "Payload privacy" now bounds.

### Privacy work is bounded by the limits, not the payload

A benchmark of both shipped SDKs (stateless HTTP, instrumented against uninstrumented, A/B/B/A blocks
on a shared machine, so orders of magnitude only) found small calls cheap: TypeScript adds 0.06 ms and
Python 0.25 ms at p50. Large payloads are not: both SDKs run the privacy passes over the whole raw
string and truncate afterwards, and both build the event before the first response byte. A 2 MB result
adds 43 ms in TypeScript and 447 ms in Python; a 1 MB argument 22 ms and 225 ms; a 200-tool
`tools/list` 27 ms and 234 ms. At 16 requests in flight, Python's 2 MB throughput fell from 379 to 2
requests per second. The hot spots are the URL pattern in `mcp-payloads.ts` and the per-word secret
check in `_sanitization.py`.

The contract therefore cuts each string to its limit plus a 1,024-character margin before the passes,
and to its limit after them, so their cost is bounded by the limits and a match that crosses the limit
is still redacted whole. It asks for event building after the response where the platform allows. It
sets no millisecond budget, which would depend on the machine. Two implementation notes from the same
run: arguments were sanitized twice (before the handler and in the event), about half the cost of a
large argument, and the injected tool schemas were rebuilt on every listing. Per-session memory was
bounded in both SDKs: 20,000 sessions added about 2.5 MB of heap in TypeScript and 11 MB in Python.

### Rules no SDK ships yet

`openspec/project.md` asks for specs that describe shipped behavior and name the winner where SDKs
diverge. These rules have no shipped winner. Each one exists because every shipped behavior sends
data the product reads wrongly, as the probes showed, so the spec names the target instead:

- one `$mcp_tool_call` per final outcome (every SDK counts each `input_required` round);
- task handles never counted as successful calls, and task calls emitted once where the terminal status is observed (TS and Python count creation as a success);
- no minting on a transport session, including stdio (TS and Python mint per stdio call);
- a fresh session per stateless request without a handle (Python shares one across clients);
- unknown tool names not counted as calls, and `$mcp_unknown_tool` and `$mcp_input_required` emitted (TS and Go count unknown tools as calls; no SDK emits either event);
- event building kept off the response path;
- dropping a call in the before-send hook drops its `$exception` too, because a host that drops a sensitive call otherwise still sends its error message (every SDK filters each event on its own);
- `$identify` carrying only identity (JS and Python send the raw request, injected arguments and report text included, as its `$mcp_parameters`);
- JSON members inside strings redacted by key, so a result's JSON text copy of `structuredContent` carries no credential the structured copy hides (every SDK redacts only object keys; Python sends `hunter2` in the text block, and PostHog/posthog-go#338 review found the same in Go);
- manual capture producing the same events as automatic instrumentation (every SDK's manual path diverges).

### The code around a tool call is written once

The spec requires the manual API to produce the same events as automatic instrumentation, and names
the inputs that makes possible; it does not fix the API's shape, because the shipped APIs and the
languages' idioms differ. The recommended way to get there is to write the code that runs around a
tool call once (strip the injected arguments, read intent and model, resolve the session, time the
call, append a minted handle, send the event), as the manual API's three steps: prepare the tool list,
prepare the call, finish the call. Automatic instrumentation then only hooks those steps into the
framework, so both paths run the same code and a new framework adapter is small.

Today TS and Python write that code twice, once in `instrument()` and once in `PostHogMCP`, and the
two copies have drifted: the manual one reads a tool's own `context` as intent, sends no `$session_id`
unless passed, and differs in the `$mcp_parameters` shape. Go already builds `posthogmcpsdk` on
`posthogmcp`, but its manual API has no prepare steps. Running every acceptance scenario through both
paths is what keeps them equal.

### Explicit error type labels the call, not the exception

`$mcp_error_type` is a grouping label the server may choose (for example `"validation"`). Error
tracking groups `$exception` by the thrown error's type. Letting the explicit label replace the
exception type would regroup error tracking under coarse labels, so the two are kept apart, as
posthog-python does.

### Intent is designed to move to `_meta`

SEP-2817 proposes `_meta["io.modelcontextprotocol/aiInvocation"]` with `userIntent`, `model`, and
`turnId`, and names server-specific arguments like `context` as the pattern it replaces. The spec says
SDKs SHOULD prefer the standardized field when present, so adopting it is additive.

## Risks / Trade-offs

- **The acceptance scenarios need harness work before they run.** The SDK test harness drives an SDK
  through an HTTP adapter and has no MCP route yet, and one step (a mock PostHog server that rejects
  every request) is new. The proposed shape keeps the harness unaware of
  MCP: each SDK's adapter hosts a small instrumented MCP server and exposes routes to list tools and
  call a tool. Until that lands, the scenarios report as unsupported bindings, which the harness shows
  visibly.
- **Current SDKs do not conform on multi-request calls.** Called out in Conformance below so the gap
  is visible rather than silently accepted.

## Migration Plan

Documentation-only in this repository. SDK conformance fixes and the harness MCP route are separate
changes in their own repositories, listed as follow-ups in tasks.md.

## Known limitations

The spec decides the behavior in each case below; these are the data it still cannot collect, and what would close the gap.

- **Task calls an SDK cannot see finish.** Frameworks without a task runtime (the TS MCP SDK v2, the
  Python MCP SDK) give instrumentation no hook on the recording of a task's status, so an automatic SDK
  there emits nothing for task-backed calls. The same happens when the status is recorded on another
  replica or by an external job worker, when the SDK has evicted the call, or when a task expires
  before it ends. A durable, shared record of the originating call would close these; the server can
  report them through the manual API meanwhile.
- **Abandoned calls.** A round never answered is an abandoned call. Linking a round to its answer needs
  a value both carry: the `requestState` the client echoes exactly. But the MCP frameworks seal or
  decode `requestState` before handlers run (the Python SDK's `RequestStateBoundary`, the TS SDK's verify
  hook), so a handler-level SDK sees plaintext that can repeat across users and rounds, and a framework
  shim can fulfil rounds internally. A link needs the SDK to hook at the wire boundary; until then
  `$mcp_input_required` counts rounds but not abandonment.
- **Replicated legacy servers.** On a legacy stateful deployment behind a non-sticky load balancer,
  only the replica that saw `initialize` knows the client's name and version; `User-Agent` still names
  the client on HTTP. During a rolling deploy, an old replica records `$mcp_unknown_tool` for a tool a
  new replica already has.
- **Long-lived connections.** Minting is skipped when a transport session exists, so a client that
  keeps one connection open across many chats puts them in one session: until 30 idle minutes pass on
  stdio, and never on a legacy `Mcp-Session-Id`. Rotating a transport-derived id would break replica
  agreement on it.
- **Go `$lib`.** posthog-go reports `$lib` as `posthog-go` because its core client overwrites it;
  `posthog-go-mcp` needs that fixed and the product's usage report updated (task 6.4). `$lib_version` is
  posthog-go's, since it builds the events for both Go packages. The adapter, `posthogmcpsdk`, is released
  separately, so no event shows which adapter version produced it; an optional adapter-version
  property would close that if it matters.

## Shipped entry points

What each SDK offers today, as of this change; "Manual capture" in the spec gives the required steps.

| SDK | Automatic | Manual |
|-----|-----------|--------|
| posthog-js | `instrument(server, posthog, options)` | `PostHogMCP`: `captureToolCall`, `captureToolsList`, `captureInitialize`, `captureMissingCapability`, `captureFeedback`; `prepareToolList`, `prepareToolCall`, `prepareToolResult` |
| posthog-python | `instrument(server, posthog_client, options)` | `PostHogMCP`: `capture_tool_call`, `capture_tools_list`, `capture_initialize`, `capture_missing_capability`, `capture_feedback`; `prepare_tool_list`, `prepare_tool_call` |
| posthog-go | `posthogmcpsdk.Instrument(server, posthogmcp.New(client))` | `(*posthogmcp.Analytics).CaptureToolCall` |

## Verifying an installation

Checks a customer can run in PostHog SQL to confirm the data is complete. Run each over the last day of
tool calls; the expected value is in the comment.

```sql
-- Calls arrive: more than 0
SELECT count() FROM events
WHERE event = '$mcp_tool_call' AND timestamp > now() - INTERVAL 1 DAY

-- Required properties present and well-formed: every column 0. This cannot tell a JSON boolean
-- $mcp_is_error from the string "true"; the SDK acceptance tests check the type.
SELECT
    countIf(coalesce(toString(properties.$mcp_tool_name), '') = '') AS missing_tool_name,
    countIf(coalesce(toString(properties.$mcp_is_error), '') NOT IN ('true', 'false')) AS missing_or_malformed_error_flag,
    countIf(toFloatOrNull(toString(properties.$mcp_duration_ms)) IS NULL) AS non_numeric_duration,
    countIf(coalesce(toString(properties.$mcp_source), '') != 'posthog_mcp_analytics') AS wrong_source,
    countIf(coalesce($session_id, '') = '') AS missing_session
FROM events
WHERE event = '$mcp_tool_call' AND timestamp > now() - INTERVAL 1 DAY

-- Sessions not fragmented: above 1 when agents make several calls per conversation.
-- About 1 means conversation anchoring is off or agents do not echo the handle.
SELECT count() / uniq($session_id) AS calls_per_session FROM events
WHERE event = '$mcp_tool_call' AND timestamp > now() - INTERVAL 1 DAY

-- Intent and client coverage: intent close to 1 with the context argument on; unidentified close to 0.
-- Approximate: the product only recognizes known X-Anthropic-Client values.
SELECT
    countIf(coalesce(toString(properties.$mcp_intent), '') != '') / count() AS intent_coverage,
    countIf(coalesce(
        nullIf(toString(properties.$mcp_vendor_client), ''),
        nullIf(toString(properties.$mcp_client_user_agent), ''),
        nullIf(nullIf(toString(properties.$mcp_client_name), ''), 'mcp')
    ) IS NULL) / count() AS unidentified_clients
FROM events
WHERE event = '$mcp_tool_call' AND timestamp > now() - INTERVAL 1 DAY
```

## Conformance

Known divergences from the spec at its creation; each is a follow-up in the SDK's repository. Every
SDK was probed on real servers across 2025-11-25 (stateful and stateless HTTP, stdio) and 2026-07-28,
and each divergence links to the source lines behind it at the audited commit:

- posthog-js [`928990d`](https://github.com/PostHog/posthog-js/tree/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp), assuming PostHog/posthog-js#5160 merged
- posthog-python [`c831a0c`](https://github.com/PostHog/posthog-python/tree/c831a0cef787c1d3a12c5c8c959cbd3eef1b9a86/posthog/mcp), on mcp 1.30.0 and 2.2.0
- posthog-go PostHog/posthog-go#337 [`eb536d6`](https://github.com/PostHog/posthog-go/tree/eb536d6de5770ab7cd3d2c141a814aac21628019) and #338 [`56f60fc`](https://github.com/PostHog/posthog-go/tree/56f60fcec5cfe03e865047382bdbbddfe2de058c), on go-sdk v1.6.1 and v1.8.0

A divergence without a link is behavior the probes observed (such as the absence of task handling or
of the two new events) rather than a line of code.

| Requirement | posthog-js | posthog-python | posthog-go |
|-------------|------------|----------------|------------|
| Tool call event: one event per final outcome under `input_required` | Emits per request (two events per MRTR call) ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/instrumentation.ts#L216-L228)) | Emits per request (two events, in two sessions) ([source](https://github.com/PostHog/posthog-python/blob/c831a0cef787c1d3a12c5c8c959cbd3eef1b9a86/posthog/mcp/_instrumentation.py#L551-L570)) | Emits per request on 2026-07-28 (go-sdk v1.8.0); on legacy, go-sdk fulfils the input itself and one event is sent ([source](https://github.com/PostHog/posthog-go/blob/56f60fcec5cfe03e865047382bdbbddfe2de058c/posthogmcpsdk/middleware.go#L88-L98)) |
| Tool call event: timestamp at request start | Conforms | Capture time, after the handler returns ([source](https://github.com/PostHog/posthog-python/blob/c831a0cef787c1d3a12c5c8c959cbd3eef1b9a86/posthog/mcp/_instrumentation.py#L643-L658)) | Conforms |
| Session identity | Derives `$session_id` from a minted handle even when it is not returned; mints on stdio ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/instrumentation.ts#L231-L242)) | One generated id per `instrument()`, so clients without a handle or token share a session; mints on stdio ([source](https://github.com/PostHog/posthog-python/blob/c831a0cef787c1d3a12c5c8c959cbd3eef1b9a86/posthog/mcp/session.py#L128-L137)) | No anchoring; stateless HTTP gets a new session per request, and on go-sdk v1.8.0 the adapter holds every stateless session in memory for 30 to 60 minutes ([source](https://github.com/PostHog/posthog-go/blob/56f60fcec5cfe03e865047382bdbbddfe2de058c/posthogmcpsdk/sessions.go#L37-L66)) |
| Person identity: `$identify` carries only identity | Sends the raw request, injected arguments included, as `$mcp_parameters` ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/internal.ts#L154)) | Sends the raw request as `$mcp_parameters` ([source](https://github.com/PostHog/posthog-python/blob/c831a0cef787c1d3a12c5c8c959cbd3eef1b9a86/posthog/mcp/_internal.py#L227)) | Conforms (sends no `$identify`) |
| Injected arguments: removed before the handler, root `$ref` skipped | Conforms (a tool's own `context` is not read as intent, as now required) | Raw low-level servers pass `context` and `conversation_id` to the handler; root `$ref` gets `context` ([source](https://github.com/PostHog/posthog-python/blob/c831a0cef787c1d3a12c5c8c959cbd3eef1b9a86/posthog/mcp/_instrument_lowlevel.py#L57-L63)) | Conforms; no warning logged for skipped schemas ([source](https://github.com/PostHog/posthog-go/blob/56f60fcec5cfe03e865047382bdbbddfe2de058c/posthogmcpsdk/tools.go#L235-L249)) |
| Payload privacy: credential detection | PostHog tokens only; no known-format or entropy detection ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/mcp-payloads.ts#L496-L508)) | Conforms | Conforms |
| Payload privacy: JSON members inside strings | Object keys only ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/mcp-payloads.ts#L123-L125)) | Object keys only; a text copy of `structuredContent` keeps the password ([source](https://github.com/PostHog/posthog-python/blob/c831a0cef787c1d3a12c5c8c959cbd3eef1b9a86/posthog/mcp/_sanitization.py#L416-L417)) | Object keys only ([source](https://github.com/PostHog/posthog-go/blob/eb536d6de5770ab7cd3d2c141a814aac21628019/posthogmcp/sanitize.go#L229)) |
| Payload privacy: base64url and `data:` URLs as binary | Conforms | Standard base64 only; `data:` URLs kept ([source](https://github.com/PostHog/posthog-python/blob/c831a0cef787c1d3a12c5c8c959cbd3eef1b9a86/posthog/mcp/_sanitization.py#L23-L24)) | Conforms |
| Payload privacy: MCP before-send hook | Filters each event on its own, so dropping a call leaves its `$exception` ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/sink.ts#L81-L90)) | Filters each event on its own, so dropping a call leaves its `$exception` ([source](https://github.com/PostHog/posthog-python/blob/c831a0cef787c1d3a12c5c8c959cbd3eef1b9a86/posthog/mcp/_sink.py#L75-L85)) | Core `BeforeSend` only; a panic drops the event, but dropping a call leaves its `$exception` ([source](https://github.com/PostHog/posthog-go/blob/eb536d6de5770ab7cd3d2c141a814aac21628019/posthogmcp/analytics.go#L64-L75)) |
| Event size bounds | Also shrinks `$set` and the error; stayed under 102,400 bytes in probes ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/truncation.ts#L380-L393)) | Drops `$mcp_error_message` before shrinking payloads | The manual API sends nothing when required properties plus `$groups` exceed the limit; responses over 1 MiB become a marker ([source](https://github.com/PostHog/posthog-go/blob/eb536d6de5770ab7cd3d2c141a814aac21628019/posthogmcp/sanitize.go#L57-L73)) |
| Failure capture: error type from the thrown error | `"Error"` on the v2 server even with `name` set ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/exceptions.ts#L46-L52)) | `$exception` type is the framework wrapper (`ToolError`, `UnexpectedToolError`); the error message includes the appended handle ([source](https://github.com/PostHog/posthog-python/blob/c831a0cef787c1d3a12c5c8c959cbd3eef1b9a86/posthog/mcp/_exceptions.py#L28-L33)) | `Error` for typed `mcp.AddTool` handlers (the adapter ignores `CallToolResult.GetError()`); `Server.AddTool` and the manual API conform with PostHog/posthog-go#337 ([source](https://github.com/PostHog/posthog-go/blob/56f60fcec5cfe03e865047382bdbbddfe2de058c/posthogmcpsdk/middleware.go#L238-L242)) |
| Length caps (256 identity, 2048 intent and error) | Capped values come out 3 characters over (the marker is added after the cut); `$mcp_protocol_version` uncapped ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/truncation.ts#L186-L193)) | Conforms | Conforms |
| Library identity | Relabels the whole client and does not document that MCP analytics needs a dedicated client ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/lib-identity.ts#L18-L25)) | Conforms | `$lib` is always `posthog-go`; the core client overwrites it ([source](https://github.com/PostHog/posthog-go/blob/eb536d6de5770ab7cd3d2c141a814aac21628019/capture.go#L242-L249)) |
| Client and server identity: per-request `_meta` | Falls back to the server's handshake, which on a shared instance answers for another client; no client info on legacy per-request instances ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/client-identity.ts#L173-L188)) | Conforms (its synthesized client params come from the request's own `_meta`) | On 2026-07-28 conforms (go-sdk v1.8.0 builds the handshake from `_meta`); on legacy stateless uses a handshake go-sdk makes up; never sets `$mcp_client_user_agent` or `$mcp_vendor_client`; no client info on legacy stateless ([source](https://github.com/PostHog/posthog-go/blob/56f60fcec5cfe03e865047382bdbbddfe2de058c/posthogmcpsdk/middleware.go#L221-L236)) |
| Session identity: token never on a shared transport | Writes its token onto a shared stateless transport, breaking the second client's `initialize` ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/instrumentation.ts#L1041-L1058)) | Conforms | Conforms (mints no token) |
| Tool call event: task handles | Legacy tasks: emits creation as a success, never the outcome | Emits creation as a success, never the outcome | go-sdk has no tasks |
| Injected arguments: `"{}"` intent omitted | Not checked | Not checked | Sends `"{}"` ([source](https://github.com/PostHog/posthog-go/blob/56f60fcec5cfe03e865047382bdbbddfe2de058c/posthogmcpsdk/arguments.go#L29-L35)) |
| Payload capture: manual API follows every other rule | No `$session_id` unless passed; `distinct_id` falls back to `"anonymous"`; `$mcp_duration_ms` omitted when not passed; `prepareToolCall` reads and strips a tool's own `context` as intent ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/posthog-mcp.ts#L378-L387)) | No `$session_id` unless passed; `distinct_id` falls back to `"anonymous"`; `$mcp_duration_ms` omitted when not passed; `prepare_tool_call` reads and strips a tool's own `context` as intent ([source](https://github.com/PostHog/posthog-python/blob/c831a0cef787c1d3a12c5c8c959cbd3eef1b9a86/posthog/mcp/_posthog_events.py#L40) and ([source](https://github.com/PostHog/posthog-python/blob/c831a0cef787c1d3a12c5c8c959cbd3eef1b9a86/posthog/mcp/posthog_mcp.py#L491-L494)) | No `$session_id` unless the caller passes one; handles not validated ([source](https://github.com/PostHog/posthog-go/blob/eb536d6de5770ab7cd3d2c141a814aac21628019/posthogmcp/event.go#L249)) |
| Tool call event: unknown tools not counted | Emits a failed call named after the requested tool ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/instrument-highlevel.ts#L287-L309)) | Not checked | Emits a failed call named after the requested tool ([source](https://github.com/PostHog/posthog-go/blob/56f60fcec5cfe03e865047382bdbbddfe2de058c/posthogmcpsdk/middleware.go#L200-L208)) |
| Payload privacy: passes bounded by the limits | Scans the whole payload before truncating ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/sink.ts#L41-L53)) | Scans the whole payload before truncating ([source](https://github.com/PostHog/posthog-python/blob/c831a0cef787c1d3a12c5c8c959cbd3eef1b9a86/posthog/mcp/_sink.py#L46-L56)) | Scans each string up to 1 MiB before truncating; `sanitizeString` measured 255 to 402 ms on 1 MiB of JSON at PostHog/posthog-go#337 |
| Observer-only: event built after the response | Built before the first response byte ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/sink.ts#L41-L62)) | Built before the first response byte ([source](https://github.com/PostHog/posthog-python/blob/c831a0cef787c1d3a12c5c8c959cbd3eef1b9a86/posthog/mcp/_instrument_lowlevel.py#L318-L323)) | Built on the reply path (2 MB result: 35.2 ms against 27.8 ms plain) ([source](https://github.com/PostHog/posthog-go/blob/eb536d6de5770ab7cd3d2c141a814aac21628019/posthogmcp/analytics.go#L56-L75)) |
| Optional events: no `$mcp_parameters` on missing-capability reports | Sends the report as `$mcp_parameters` ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/instrument-highlevel.ts#L253-L264)) | Sends the report as `$mcp_parameters` ([source](https://github.com/PostHog/posthog-python/blob/c831a0cef787c1d3a12c5c8c959cbd3eef1b9a86/posthog/mcp/_instrumentation.py#L1186-L1194)) | No virtual tools |
| Optional events: `$mcp_input_required` and `$mcp_unknown_tool` | Emits neither | Emits neither | Emits neither |
| Manual capture: same events as automatic instrumentation | A second copy of the call-handling code in `PostHogMCP`; diverges as the manual API row notes ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/posthog-mcp.ts#L373-L426)) | A second copy of the call-handling code in `PostHogMCP`; no result step, and no conversation handles on the manual path ([source](https://github.com/PostHog/posthog-python/blob/c831a0cef787c1d3a12c5c8c959cbd3eef1b9a86/posthog/mcp/posthog_mcp.py#L533-L546)) | Automatic path built on the manual API; no prepare steps ([source](https://github.com/PostHog/posthog-go/blob/56f60fcec5cfe03e865047382bdbbddfe2de058c/posthogmcpsdk/middleware.go#L200-L208)) |
| Manual capture: `$mcp_input_keys` and `$mcp_input_aliases_used` | Sent by `instrument()` only ([source](https://github.com/PostHog/posthog-js/blob/928990ded0ce03aad6ac51f4c4e8cd33bb84b558/packages/mcp/src/extensions/instrumentation.ts#L200)) | Conforms (sends neither) | Conforms (sends neither) |
| Optional events: only for client requests | Conforms | Records the framework's internal `tools/list` (mcp 2.2.0) and synthesizes `$mcp_initialize` ([source](https://github.com/PostHog/posthog-python/blob/c831a0cef787c1d3a12c5c8c959cbd3eef1b9a86/posthog/mcp/_instrumentation.py#L249-L267)) | Emits none |

