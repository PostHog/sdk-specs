## Context

Customers listing MCP servers in the ChatGPT Directory had submissions rejected or flagged for what
the SDK adds. The review scans each tool's name, description, input schema, and annotations, and
reads the tool results.

On 2026-11-04 OpenAI's plugin review team sent this guidance through our shared Slack channel:

- Use `_meta["openai/session"]` instead of passing a conversation id through tool responses.
  The [Apps SDK reference](https://developers.openai.com/plugins/reference) documents it as an
  anonymized conversation id that ChatGPT sends on tool calls. The
  [plugin guidelines](https://developers.openai.com/plugins/plugin-guidelines) section "Response
  minimization" names session ids among the identifiers a response must not return, and the
  [review FAQ](https://developers.openai.com/plugins/deploy/app-review) lists them as a common
  rejection reason.
- A short intent field is acceptable when it holds no verbatim content and no personal data.
- A tool that records feedback needs `readOnlyHint: false`.

OpenAI has not answered on `llm_model` or on a metadata key for Codex. Anthropic has not answered
for the Claude directory. This change applies only the guidance received.

## Goals / Non-Goals

**Goals:** a rule for client-provided conversation ids that any client can join by adding a table
row; no handle, argument, or result block for a client that sends one; accurate annotations on the
virtual tools; a shorter `context` request.

**Non-goals:**

- `llm_model`. It stays as it is until OpenAI answers.
- The wording of the `conversation_id` description. It still tells agents how to sequence calls,
  which the review may also flag. That is a separate change.
- Keys for Claude or Codex. Neither client documents one yet. Adding a row needs no new rule.

## Decisions

### 1. The client's id wins over the SDK's handle

When a call carries both, `$session_id` comes from the client's id and the handle is ignored for
`$session_id` and `$mcp_conversation_id`. The SDK still strips the handle argument, which it owns.

The client's id names the conversation from its first call. A handle exists only after the first
result reaches the agent, and holds only while the agent copies it, so a conversation grouped by
handle splits its first call off and splits again whenever the agent drops or reuses the handle.
Taking the client's id whenever it is present makes every call of the conversation carry one key.
Taking the handle when present would mix the two keys within one conversation.

### 2. The id is hashed into `$session_id` and never sent as is

The SDK derives `$session_id` from `<key>:<value>` with the existing derivation. Prefixing the key
keeps ids from two clients from colliding. The value itself appears in no property: `$session_id`
carries all the grouping it gives, and the raw value would add an identifier to every event with no
further meaning. `$mcp_conversation_id` keeps its meaning (an SDK-minted UUIDv7 handle) and is unset
for these calls.

The 128-character printable ASCII bound matches the session token's `sid` and keeps the derivation
identical across languages, since the hash runs over characters.

### 3. Leaving `conversation_id` out of the listing (schema injection timing)

The SDK adds `conversation_id` at `tools/list`, before any call shows whether the client sends its own
id. The question is whether, and how, to leave it out for clients that do.

| Option | How the SDK knows | Tradeoff |
|---|---|---|
| A. Always advertise it; only skip the result block | No need to know | Simplest. The scanned listing still asks for a field the client already supplies, and every ChatGPT agent sees it. |
| B. Recognize the client per request at `tools/list` (**chosen**) | The table's recognition rule, read from the listing request | The listing matches what the client needs. A missed match keeps today's behavior. A false match costs that client handle anchoring only. |
| C. Learn it from the first call that carries an id | A call's `_meta` | Too late: the listing comes first, and a stateless HTTP request has no session to remember it in. |
| D. Host option only (turn conversation anchoring off) | The host decides | Already exists. Loses grouping for every stateless client the server serves, not only ChatGPT. |

For option B the SDK needs a signal present on ChatGPT's `tools/list`. The candidates:

- `clientInfo` from `initialize`. A legacy stateful session has it, but a stateless HTTP request is
  bound to no handshake, and a 2026-07-28 client sends no `initialize`. The name ChatGPT reports there
  is also not something we have confirmed.
- `clientInfo` in a 2026-07-28 request's `_meta`. Present only on that revision.
- The HTTP `User-Agent`. Present on every HTTP request of every revision, and ChatGPT reaches MCP
  servers only over HTTP. Its form `openai-mcp/<version> (ChatGPT...)` is what the SDKs already record
  as `$mcp_client_user_agent`, and it tells ChatGPT apart from Codex and the other OpenAI surfaces,
  which share the `openai-mcp` token but carry their own parenthetical.

The rule uses `User-Agent`. Each table row states its own recognition rule, so a future client can
use whichever signal it sends.

A recognized client's call that lacks its id gets no handle either. Minting one would put the block
back in the results of the very client the rule is for, and that client's listing has no argument to
echo it through. Such a call falls back to the transport session, or to a fresh session.

Option D stays the fallback for a host that must pass review when the scanner is not recognized (see
Open Questions).

A listing now depends on the requesting client. A cache that serves one client's listing to another
(the 2026-07-28 `cacheScope` result field allows a shared scope) either drops the argument for an
unrecognized client, which then loses anchoring, or shows it to ChatGPT, which is today's behavior.
Neither corrupts data, so the spec adds no cache rule.

### 4. Virtual tool annotations

Earlier SDKs declared `readOnlyHint: true`, `idempotentHint: true`, and `openWorldHint: true`. Per the
definitions in the Apps SDK reference:

- `readOnlyHint: false`. Each call sends an event to the server owner's PostHog project.
- `destructiveHint: false`. Nothing is deleted or overwritten.
- `idempotentHint: false`. A repeated call sends another event.
- `openWorldHint: false`. The event goes to one bounded project, not the public internet.

The host cannot change them, because they describe what the SDK's own handler does.

### 5. `context` asks for a few words

The value is recorded as `$mcp_intent`, the purpose of the call. A few words carry that purpose.
Longer answers tend to restate the user's request, which adds conversation content and names the
redaction pass cannot catch. The 2,048-character limit stays as the hard bound; the description sets
the expectation.

## Risks / Trade-offs

- ChatGPT conversations change how they are grouped. A conversation that was split by its first call,
  or by a dropped handle, becomes one session. Session counts for ChatGPT traffic go down and sessions
  get longer, which is the more accurate count.
- The recognition rule depends on ChatGPT's `User-Agent`. If it changes, the SDK falls back to
  advertising `conversation_id`, which is today's behavior.

## Open Questions

- Does OpenAI's review scanner send ChatGPT's `User-Agent` on `tools/list`? If not, the scanned
  listing still shows `conversation_id`, and a host submitting for review needs option D.
- Is `openai/session` constant across a whole ChatGPT conversation, and does it fit 128 printable
  ASCII characters? The reference documents only its type. The first SDK implementation checks this
  against a real ChatGPT connection.
