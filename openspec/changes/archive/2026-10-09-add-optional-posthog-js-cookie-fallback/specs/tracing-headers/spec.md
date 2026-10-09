## Narrative alignment

When syncing this delta, add to the Behavior list an item that a server SDK may offer an off-by-default option that reads the session id, and the distinct id of an identified visitor, from the posthog-js cookie when a request has neither tracing header. Add the posthog-js persistence and consent cookies to "Server-side state read" as optional inputs. Leave the existing requirements and scenarios unchanged.

## ADDED Requirements

### Requirement: Optional posthog-js cookie fallback

A server SDK MAY offer an option that lets request middleware read the posthog-js persistence cookie when a request has neither tracing header. The option SHALL be off by default, because the server cannot read an opt-out that posthog-js stores in localStorage. When either tracing header is present, the middleware SHALL use headers only. Cookie-derived identity SHALL NOT be used for authentication or authorization.

#### Scenario: cookie fallback is off by default
- **GIVEN** server request context middleware is installed with default options
- **AND** an incoming request has no tracing headers and a live posthog-js cookie for the project
- **WHEN** `capture("Backend Work")` is called inside that request with no explicit distinct id
- **THEN** the event properties do not include the cookie session id

#### Scenario: tracing headers disable the cookie fallback
- **GIVEN** server request context middleware is installed with the cookie fallback on
- **AND** an incoming request has `X-POSTHOG-DISTINCT-ID: header-user` and no `X-POSTHOG-SESSION-ID`
- **AND** the request has a live posthog-js cookie with session id `cookie-session`
- **WHEN** `capture("Backend Work")` is called inside that request with no explicit distinct id
- **THEN** the enqueued event distinct id is "header-user"
- **AND** the event properties do not include `$session_id: cookie-session`

### Requirement: Cookie fallback identity and consent

With the fallback on, the middleware SHALL read only the configured project's cookie, `ph_<token>_posthog` with `+`, `/`, `=` in the token replaced by `PL`, `SL`, `EQ`. It SHALL ignore the cookie when the consent cookie `__ph_opt_in_out_<token>` is no-like, or absent under configured opt-out by default. It SHALL use the cookie `distinct_id` only when `$user_state` is `identified`.

#### Scenario: cookie fallback links an identified visitor
- **GIVEN** server request context middleware is installed with the cookie fallback on
- **AND** an incoming request has no tracing headers
- **AND** the posthog-js cookie has `distinct_id: user-123`, `$user_state: identified`, and a live `$sesid` with session id `session-123`
- **WHEN** `capture("Backend Work")` is called inside that request with no explicit distinct id
- **THEN** the enqueued event distinct id is "user-123"
- **AND** the event properties include `$session_id: session-123`

#### Scenario: cookie fallback keeps an anonymous visitor personless
- **GIVEN** server request context middleware is installed with the cookie fallback on
- **AND** an incoming request has no tracing headers
- **AND** the posthog-js cookie has `$user_state: anonymous` and a live `$sesid` with session id `session-123`
- **WHEN** `capture("Backend Work")` is called inside that request with no explicit distinct id
- **THEN** the SDK enqueues a personless event with a generated distinct id
- **AND** the event properties include `$session_id: session-123`

#### Scenario: opted-out visitors are not linked
- **GIVEN** server request context middleware is installed with the cookie fallback on
- **AND** an incoming request has no tracing headers and a live posthog-js cookie
- **AND** the consent cookie `__ph_opt_in_out_<token>` is `0`
- **WHEN** `capture("Backend Work")` is called inside that request with no explicit distinct id
- **THEN** the event uses neither the cookie distinct id nor the cookie session id

### Requirement: Cookie fallback session liveness

With the fallback on, the middleware SHALL use the `$sesid` session id only when the absolute age of its last activity is within the idle timeout and the absolute age of its start is within 24 hours. The two-item form starts at its last activity. The idle timeout defaults to 30 minutes, MAY be configured, and SHALL be clamped to 60 seconds through 10 hours.

#### Scenario: an idle session is not linked
- **GIVEN** server request context middleware is installed with the cookie fallback on and the default idle timeout
- **AND** an incoming request has no tracing headers
- **AND** the posthog-js cookie `$sesid` last activity is 31 minutes old
- **WHEN** `capture("Backend Work")` is called inside that request with no explicit distinct id
- **THEN** the event properties do not include the cookie session id
