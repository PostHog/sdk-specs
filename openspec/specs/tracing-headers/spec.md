# Tracing Headers Specification

## Purpose

Tracing headers let client-side SDKs attach the current PostHog analytics context to outgoing
application HTTP requests so server-side SDKs can correlate backend events, exceptions, LLM/AI
calls, and request metadata back to the same frontend user/session/replay. This is an analytics
correlation feature, not a distributed tracing or authentication mechanism.

The canonical PostHog tracing headers are:

| Header | Meaning | Server-side use |
| --- | --- | --- |
| `X-POSTHOG-DISTINCT-ID` | Current frontend distinct id | Request context `distinctId`; used as event `distinct_id` only when no explicit capture id or stronger authenticated application context is supplied |
| `X-POSTHOG-SESSION-ID` | Current frontend session id | Request context `sessionId`; emitted as event property `$session_id` |

HTTP header names are case-insensitive. SDKs MAY preserve their platform's conventional casing on
write, but server-side readers MUST accept any framework-normalized casing.

## Applicability

`both` — client-side SDKs produce tracing headers for selected outgoing application requests, and
server-side SDKs consume tracing headers through request-scoped middleware or framework helpers.

### Client vs. server responsibilities

| Concern | Client-side SDKs | Server-side SDKs |
| --- | --- | --- |
| Direction | Inject headers into outgoing requests to application backends. | Extract headers from incoming application requests. |
| Configuration | Disabled by default; enabled with an allow-list of hostnames or an equivalent explicit opt-in. | Middleware/helper opt-in; framework integrations may enable extraction by default once installed. |
| Values | Current distinct id and active session id. | Sanitized request-local context values. |
| Trust model | Headers are client-controlled and may be overwritten on allow-listed requests. | Headers are untrusted analytics context only; never authentication or authorization evidence. |
| Propagation | Fetch/XHR/URLSession/OkHttp or equivalent HTTP client interception. | Request-local context (`AsyncLocalStorage`, `contextvars`, `AsyncLocal<T>`, `context.Context`, thread/request-local storage, or equivalent). |

## Public/configuration surface

There is no single cross-SDK method name. Canonical public surfaces are:

- **Client configuration:** an option equivalent to `tracing_headers` / `tracingHeaders` containing
  hostnames for which the SDK should inject PostHog tracing headers. Hostnames are matched exactly
  after normalization; ports, schemes, paths, and wildcard subdomains are not part of the canonical
  match.
- **Client interceptor installation:** platforms that cannot patch global HTTP primitives safely MAY
  require the application to install an SDK-provided HTTP interceptor/wrapper (for example OkHttp)
  or enable URLSession swizzling/wrapping.
- **Server middleware/helpers:** a framework integration or request-context helper that extracts
  tracing headers and request metadata, runs request handling inside that context, and optionally
  autocaptures exceptions.
- **Server context APIs:** lower-level SDKs MAY expose explicit `withContext` / `enterContext` /
  request-context data helpers for frameworks that cannot use a bundled middleware.

Legacy client SDK aliases are allowed for backwards compatibility, but new SDKs SHOULD expose a
clear public tracing-header host allow-list rather than a broad boolean "all hosts" switch.

## Behavior

### Client-side production

1. **Disabled by default.** The SDK does not add tracing headers unless the application explicitly
   enables the feature for one or more hostnames, or installs an explicitly configured interceptor.
2. **Exact hostname allow-list.** For each outgoing application HTTP request, parse the destination
   hostname and inject headers only when it matches a configured hostname after trimming and
   case-normalization. Do not match by URL path, scheme, port, suffix, or subdomain wildcard unless
   an SDK documents an additional platform-specific extension.
3. **Inject current values at request time.** Read the distinct id and session id when
   the request is made, not when the HTTP primitive was patched, so changes from bootstrap,
   `identify`, `reset`, or session rotation are reflected.
4. **Header set.** Add `X-POSTHOG-DISTINCT-ID` when the current distinct id is present. Add
   `X-POSTHOG-SESSION-ID` when an active session id is present.
5. **Overwrite stale tracing headers on matched requests.** When a matched request already contains
   PostHog tracing headers, replace them with the SDK's current values. Do not mutate the caller's
   original header collection if the platform supports immutable/copy-on-send request objects.
6. **Leave unmatched requests untouched.** Requests to unlisted hosts must not gain or modify
   PostHog tracing headers.
7. **Fail open.** If URL parsing, header construction, or SDK state lookup fails, send the original
   request without tracing headers rather than breaking application network traffic.
8. **Preserve HTTP semantics.** Interception must preserve method, body, credentials/cookies,
   abort/signal handling, request cloning semantics, and downstream errors.

### Server-side consumption

1. **Create request-scoped context.** Middleware/helpers create context for the lifetime of a single
   incoming request and propagate it through async work started by that request.
2. **Read headers case-insensitively.** Recognize `X-POSTHOG-DISTINCT-ID` and
   `X-POSTHOG-SESSION-ID` regardless of framework header casing or normalization.
3. **Sanitize values before storing context.** Accept string values only (or the first valid string
   in an array-valued header), trim surrounding whitespace, remove control characters, cap each
   value at a bounded length such as 1000 characters, and treat empty results as missing.
4. **Store analytics context.** Valid values become request context `distinctId` and `sessionId`.
   `sessionId` is also represented as `$session_id` in context properties.
5. **Capture request metadata where available.** Middleware SHOULD add safe request metadata such as
   `$current_url`, `$request_method`, `$request_path`, `$user_agent`, `$ip`, and, for exception
   events where known, `$response_status_code`.
6. **Apply capture precedence.** Explicit per-call `distinct_id` / `distinctId` wins over request
   context. Explicit event properties win over context-derived properties, including `$session_id`.
7. **Use context only as fallback identity.** If a server capture inside a request has no explicit
   distinct id, the SDK MAY use request context distinct id. If no explicit or context distinct id
   exists, SDKs that support personless server capture SHOULD generate a random id for the event and
   set `$process_person_profile = false` unless the caller explicitly supplied that property.
8. **Never trust headers for security.** Tracing header identity must not be used for authentication,
   authorization, account lookup, tenant isolation, or security decisions. Authenticated framework
   user context, when deliberately configured by the application, may override or supersede tracing
   header identity.
9. **Exception autocapture preserves semantics.** Middleware that autocaptures exceptions includes
   request context and tracing-derived properties, but it must rethrow or pass the exception to the
   framework's normal error handling and must not swallow it.
10. **Request isolation.** Concurrent requests must not leak tracing context into each other or into
    later background work unless the application explicitly carries that context forward.

## State & lifecycle

### Client-side state read

- current distinct id
- current session id
- configured tracing-header hostname allow-list
- enabled/installed interceptor state

### Client-side state written

- patched/wrapped HTTP primitive state or interceptor installation state
- no analytics event state is written merely because headers were injected

### Server-side state read

- incoming request headers
- optional authenticated application user context
- request metadata
- current request-local PostHog context

### Server-side state written

- request-local PostHog context values (`distinctId`, `sessionId`, `properties`)
- context-derived event properties during capture
- optional exception autocapture bookkeeping

## Error handling

- Client injection failures must not break application requests.
- Server extraction failures, malformed headers, or unsupported header value shapes are treated as
  missing context, not as request or capture failures.
- Capture and exception behavior should remain fire-and-forget: tracing context errors are logged at
  most and must not throw to application code.
- Server middleware must not swallow application exceptions while trying to capture them.

## Concurrency & ordering guarantees

- Client header values are snapshots taken at the time each request is sent.
- Server request contexts are isolated per request/task/fiber/thread according to platform
  conventions.
- Captures inside a request observe the context active for that request. Captures outside any
  request context behave like ordinary server captures and do not inherit stale headers.

## Interactions

- **`capture`** — server captures may use context distinct id and context `$session_id` when
  explicit values are absent.
- **`capture-exception`** — server middleware may attach tracing/request context to exception events.
- **`get-distinct-id` / `get-session-id`** — client header injection reads the same ambient values
  exposed by these public getters.
- **`session-manager`** — supplies session ids where available.
- **`reset` / `identify`** — future client requests use the updated distinct/session values because
  headers are read at request time.
- **Session replay and AI/LLM analytics** — tracing headers let backend events and generations link
  back to the frontend session/replay that initiated the request.

## Requirements

### Requirement: Client-side tracing header injection

The SDK SHALL provide an opt-in way for client applications to inject PostHog tracing headers into
outgoing requests to configured application backend hostnames.

#### Scenario: allowlisted client request receives tracing headers
- **GIVEN** tracing headers are enabled for hostname "api.example.com"
- **AND** the current distinct id is "user-123"
- **AND** the current session id is "session-123"
- **WHEN** the application sends a request to "https://api.example.com/v1/work"
- **THEN** the request includes `X-POSTHOG-DISTINCT-ID: user-123`
- **AND** the request includes `X-POSTHOG-SESSION-ID: session-123`

#### Scenario: unlisted client request is untouched
- **GIVEN** tracing headers are enabled for hostname "api.example.com"
- **WHEN** the application sends a request to "https://other.example/v1/work"
- **THEN** the request does not include PostHog tracing headers

#### Scenario: client reads identity at request time
- **GIVEN** tracing headers are enabled for hostname "api.example.com"
- **AND** the distinct id changes from "anonymous-1" to "user-123" after the HTTP primitive was patched
- **WHEN** the application sends a request to "https://api.example.com/v1/work"
- **THEN** the request includes `X-POSTHOG-DISTINCT-ID: user-123`

### Requirement: Server-side tracing header extraction

The SDK SHALL provide request-scoped server middleware or helpers that extract PostHog tracing
headers into analytics context for captures made while handling the request.

#### Scenario: server request context applies tracing headers to capture
- **GIVEN** server request context middleware is installed
- **AND** an incoming request has `X-POSTHOG-DISTINCT-ID: user-123`
- **AND** the request has `X-POSTHOG-SESSION-ID: session-123`
- **WHEN** `capture("Backend Work")` is called inside that request with no explicit distinct id
- **THEN** the enqueued event distinct id is "user-123"
- **AND** the event properties include `$session_id: session-123`

#### Scenario: explicit capture values override tracing context
- **GIVEN** server request context middleware stored tracing context distinct id "header-user"
- **AND** context properties include `$session_id: header-session`
- **WHEN** capture is called with distinct id "explicit-user" and property `$session_id: explicit-session`
- **THEN** the enqueued event distinct id is "explicit-user"
- **AND** the event properties keep `$session_id: explicit-session`

#### Scenario: malformed server headers are sanitized or omitted
- **GIVEN** server request context middleware is installed
- **WHEN** an incoming request contains tracing headers with whitespace, control characters, or overlong values
- **THEN** valid values are trimmed, stripped of control characters, and capped before capture context uses them
- **AND** empty or invalid values are omitted

#### Scenario: tracing header identity is not authentication
- **GIVEN** an incoming request has `X-POSTHOG-DISTINCT-ID: attacker-controlled-id`
- **WHEN** application authorization runs
- **THEN** the SDK does not treat the tracing header as proof of identity
- **AND** application-provided authenticated user context may override or supersede tracing header identity for analytics context

#### Scenario: request contexts are isolated
- **GIVEN** two server requests are handled concurrently with different PostHog tracing headers
- **WHEN** each request captures an event
- **THEN** each event uses only the tracing context from its own request
