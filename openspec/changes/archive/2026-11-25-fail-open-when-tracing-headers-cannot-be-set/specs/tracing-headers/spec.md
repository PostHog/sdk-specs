## ADDED Requirements

### Requirement: Client injection fails open and keeps the request intact

A client SDK that injects tracing headers SHALL NOT change whether, or how, an application request
is sent. When the SDK cannot prepare its tracing headers for a matched request — URL parsing, SDK
state lookup, or header construction fails — it SHALL send the request as the application built
it, without PostHog tracing headers, and SHALL NOT throw to application code.

A value the platform's HTTP stack cannot carry as a header is such a failure, not a reason to send
part of the set. A distinct id is caller-supplied and may hold characters a header value cannot:
`identify()` accepts any string, while a browser `Headers` value is limited to Latin-1. When the
current distinct id cannot be set as a header value, the SDK SHALL omit **every** PostHog tracing
header for that request — the distinct-id header, the session-id header, and any platform
window-id header — rather than sending the remaining ones. A session id without a distinct id
would stop a server from resolving the person another way, such as the posthog-js cookie fallback,
and would make a cross-origin request need CORS permission for headers the application otherwise
never sends.

Preserving the request includes its body. A platform that builds a copy of the caller's request
object in order to set headers on it, as the browser does for `fetch(Request)`, SHALL send that
copy even when header preparation fails, because constructing it has already consumed the
caller's body and the original can no longer be sent.

A W3C `traceparent` the SDK propagates under its own target list is independent of the PostHog
tracing headers and SHALL still be added when its own targets match.

#### Scenario: a distinct id that cannot be a header value sends no tracing headers
- **GIVEN** tracing headers are enabled for hostname "api.example.com"
- **AND** the current distinct id is a string the platform cannot send as a header value
- **AND** an active session id exists
- **WHEN** the application sends a request to "https://api.example.com/v1/work"
- **THEN** the request is sent and reaches the server
- **AND** the request includes no `X-POSTHOG-DISTINCT-ID`
- **AND** the request includes no `X-POSTHOG-SESSION-ID` and no window-id header
- **AND** the application's own headers are unchanged

#### Scenario: a request keeps its body when tracing headers cannot be prepared
- **GIVEN** tracing headers are enabled for hostname "api.example.com"
- **AND** the current distinct id cannot be set as a header value
- **WHEN** the application sends a POST with a body to "https://api.example.com/v1/work", including through a request object the SDK copies to set headers on
- **THEN** the server receives the request once, with its method and body
- **AND** the SDK does not throw to the caller

#### Scenario: traceparent propagation is unaffected
- **GIVEN** tracing headers are enabled for hostname "api.example.com"
- **AND** traceparent propagation targets include "https://api.example.com"
- **AND** the current distinct id cannot be set as a header value
- **WHEN** the application sends a request to "https://api.example.com/v1/work"
- **THEN** the request includes a `traceparent` header
- **AND** the request includes no PostHog tracing headers
