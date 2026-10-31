## ADDED Requirements

### Requirement: Host callback request context

The host callbacks that run per request — identify, intent fallback, and event properties — SHALL be
able to read every header of the request, not a subset the SDK picked. A server resolves identity from
whichever header it authenticates with (`Authorization`, `X-Api-Key`, a tenant header), so an allowlist
leaves those servers unable to identify anyone, and the documented identify-by-bearer-token pattern
silently returns nothing. Header names SHALL be matchable without regard to case: the SDK either
lowercases the names it hands over or exposes a case-insensitive map. A request that did not arrive
over HTTP (stdio, in-memory) carries no headers, and the SDK SHALL report their absence rather than
fabricate an empty set.

How the headers reach the callback follows platform convention: a helper that unwraps the MCP SDK's own
per-request object (posthog-js `getRequestHeaders`, posthog-python `get_request_headers`), the request
on the callback's own argument (posthog-rs `request.http`), or a header bag on the callback's extra
context (posthog-ruby `extra['headers']`). An SDK that hands over a mutable bag SHALL give each request
its own copy, because instrumentation reads the request's headers again after the callbacks run.

Widening what a callback can read SHALL NOT widen what the SDK captures. The SDK SHALL NOT capture the
header bag on any event, and the headers it derives properties from are unchanged (`User-Agent` and
`X-Anthropic-Client`, per "Client and server identity"). A value a callback returns as an identity
property or an event property is captured as the callback returns it: "Payload privacy" redacts it only
when it is recognized by name or shape, not because it came from a header. SDK documentation SHALL tell
hosts to resolve a header to an id or a role and never return the raw value, because person properties
outlive event retention on the person profile.

#### Scenario: Identify resolves a person from the authorization header
- **GIVEN** an MCP server instrumented by the SDK over HTTP, whose identify option reads the "authorization" header and resolves distinct id "user-1" for the token it carries
- **WHEN** an MCP client calls tool "search_docs" with header "Authorization" set to "Bearer token-abc"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's distinct_id should be "user-1"
- **AND** no captured event should contain "token-abc"

#### Scenario: A callback cannot change the headers instrumentation reads
- **GIVEN** an MCP server instrumented by the SDK over HTTP, whose identify option deletes "user-agent" and overwrites "mcp-session-id" in the headers it receives
- **WHEN** an MCP client calls tool "search_docs" with header "User-Agent" set to "agent/1.0" and header "Mcp-Session-Id" set to "session-1"
- **AND** the SDK is flushed
- **THEN** the "$mcp_tool_call" event's property "$mcp_client_user_agent" should be "agent/1.0"
- **AND** its "$session_id" should be the session id derived from "session-1"

#### Scenario: A non-HTTP transport has no headers
- **GIVEN** an MCP server instrumented by the SDK over stdio, whose identify option reads the request's headers
- **WHEN** an MCP client calls tool "search_docs"
- **THEN** the callback should see no headers rather than an empty header set
