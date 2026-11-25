## MODIFIED Requirements

### Requirement: Observer-only instrumentation

An SDK SHALL let a server be instrumented with one call taking the MCP server and a configured PostHog
client. Instrumentation SHALL NOT change what the server returns, apart from the injected arguments of
"Arguments the SDK injects", the conversation handle and session token of "Session identity", and the
virtual tools of "Optional events". A failure inside instrumentation (an exception, a panic, a
serialization error, an unreachable PostHog endpoint) SHALL NOT change the response or reach the tool
handler or the MCP client.

Instrumentation SHALL NOT add avoidable latency to the response: sanitizing, truncating, and
serializing an event SHOULD happen after the response is handed to the transport, and sending SHALL use
the host SDK's asynchronous capture. State kept per session (identity, advertised schemas, pending
tasks) SHALL be bounded by count, for example a least-recently-used cache, so a long-lived server with
many conversations does not grow without limit. On a server that lives for a single request, the SDK
SHALL let the host flush without delaying the response (for example through the platform's wait-until
hook).

Flushing means every event captured so far is sent, including events still being sanitized or passed
through the before-send hook when the host asks:

- Automatic instrumentation SHALL give the host a `flush()`, following platform idiom: on the handle
  it returns, or on the analytics object the host passes in where it returns none. It SHALL wait until
  every capture started before the call has been handed to the PostHog client or dropped, then flush
  the PostHog client. Captures that start while it waits belong to the next call, so steady traffic on
  a shared server cannot hold it open. `flush()` SHALL NOT raise or reject: a failed client flush is
  logged. Without a working client it completes at once.
- Where the SDK's PostHog client is itself the MCP wrapper (such as posthog-js's `PostHogMCP`), that
  client's flush and shutdown SHALL first wait for its pending MCP captures the same way.
- Flushing SHOULD be bounded by a deadline where the language makes that natural (a timeout argument,
  a context, a cancellable future). Elsewhere the platform's wait-until limit bounds it.

An SDK whose capture is synchronous already has nothing pending, so flushing the client satisfies the
wait. In scenarios, "the SDK is flushed" means this flush.

#### Scenario: A tool result reaches the client unchanged
- **GIVEN** an MCP server instrumented by the SDK with conversation anchoring disabled and a tool "search_docs" that returns the text "Found 3 results"
- **WHEN** an MCP client calls tool "search_docs" with arguments `{"query": "flags"}`
- **THEN** the client should receive a result whose content is exactly one text block "Found 3 results"
- **AND** the result should not be marked as an error

#### Scenario: Instrumentation's flush right after a call sends that call
- **GIVEN** an MCP server instrumented by the SDK with a tool "search_docs"
- **WHEN** an MCP client calls tool "search_docs" with arguments `{"query": "flags"}`
- **AND** the host calls instrumentation's `flush()` as soon as the client receives the result
- **THEN** by the time `flush()` completes, exactly one event named "$mcp_tool_call" should be sent
- **AND** its property "$mcp_tool_name" should be the string "search_docs"

#### Scenario: A client wrapper's shutdown right after a call sends that call
- **GIVEN** an SDK client that is itself the MCP wrapper
- **WHEN** the host records a call to tool "search_docs" through it
- **AND** the host shuts the client down right after

- **THEN** by the time shutdown completes, exactly one event named "$mcp_tool_call" should be sent
- **AND** its property "$mcp_tool_name" should be the string "search_docs"
