## Why

The mcp-analytics spec is the source of truth for every MCP analytics SDK, but some rules live in two
or three places, and one requirement, "Session identity", holds five topics. A reader has to find
every copy of a rule to know it, and an edit to one copy can leave another stale. This change gives
each rule one home and splits Session identity. No rule changes.

## What Changes

- **One home per kind of fact.** Property reference holds types and limits, Configuration holds
  defaults and a one-line effect, Terminology holds definitions, and requirements hold behavior:
  - Tool call event names "the properties Property reference marks required" instead of restating
    their types, and keeps only what that table does not say (`timestamp`, how `$mcp_duration_ms` is
    measured).
  - Configuration rows for the session resolver, conversation anchoring, the initialize and tools list
    events, error message capture, and the virtual tools point to their requirement. The two rules
    only a row stated (a resolver that returns nothing or throws falls through; only automatic
    instrumentation offers one) move into Session identity.
  - Session identity no longer redefines "client conversation id", which Terminology defines.
  - "A client conversation id wins over a handle" is stated once instead of three times.
  - Optional events drops its own copy of the rule that every event carries client, server and session
    identity, which those requirements already state for every MCP event.
  - The model-source rule, which applies to every event that carries a model, moves from Tool call
    event to Arguments the SDK injects, next to the intent-source rule.
- **Session identity splits in three.** Session identity keeps the ranking, the resolver, derivation,
  the session source, custom events, and the session token. **Client conversation ids** (new) holds
  the client table, recognition, and handle-free clients. **Conversation anchoring** (new) holds
  handles. Each scenario moves with its rule, unchanged.
- **Virtual tool annotations becomes Virtual tools** and takes in the `get_more_tools` and
  `send_feedback` rules and the virtual tool paragraph from Optional events.
- The wrapper flush scenario loses a stray blank line between its AND and THEN steps.

Library identity and Interface identity stay separate: `capture` refers to Library identity by name,
and merging them would add a cross-capability change to save one heading.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: structure only. Observer-only instrumentation, Tool call event, Session identity,
  Arguments the SDK injects, Optional events, and Virtual tools (renamed from Virtual tool
  annotations) are modified; Client conversation ids and Conversation anchoring are added; the
  Terminology and Configuration prose is aligned.

## Impact

None for SDKs: every scenario is unchanged, so harness bindings keep working. Code comments and docs
that cite "Session identity" for client conversation ids or handles can cite the new requirements.
