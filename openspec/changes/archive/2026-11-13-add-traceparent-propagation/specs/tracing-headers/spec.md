## ADDED Requirements

### Requirement: Client-side W3C traceparent propagation

A client SDK MAY propagate a W3C `traceparent` header on outgoing application requests, so the application's backend can continue a trace from the browser request. It SHALL be a separate opt-in from the PostHog tracing headers: its own target list, unset by default, usable with or without the tracing-header allow-list, and never inferred from it. An unexpected header fails CORS preflight, so each host SHALL opt in explicitly.

#### Scenario: propagation is off unless its own targets are set
- **GIVEN** tracing headers are enabled for "api.example.com" and traceparent propagation is not configured
- **WHEN** the application sends a request to "https://api.example.com/v1/work"
- **THEN** the request includes the PostHog tracing headers
- **AND** the request does not include a `traceparent` header

### Requirement: Traceparent target matching

Traceparent targets SHALL match exactly: a scheme-qualified entry matches that origin only, a bare entry matches that hostname, and nothing matches by suffix, subdomain, or path. An unlisted target SHALL NOT gain the header. Changes to the target list SHALL apply to later requests without reinstalling the interception, and the capability's fail-open rule applies unchanged.

#### Scenario: an unlisted target is untouched
- **GIVEN** traceparent propagation is enabled for "api.example.com"
- **WHEN** the application sends a request to "https://other.example/v1/work"
- **THEN** the request does not include a `traceparent` header

#### Scenario: a scheme-qualified entry matches that origin only
- **GIVEN** traceparent propagation is enabled for "https://api.example.com"
- **WHEN** the application sends a request to "http://api.example.com/v1/work"
- **THEN** the request does not include a `traceparent` header

### Requirement: Traceparent header generation

For each matching request the SDK SHALL generate a fresh, cryptographically random `traceparent` of the form `00-<32 hex digit trace id>-<16 hex digit span id>-01`, and SHALL NOT replace a `traceparent` the application already set. The propagated span id parents the server's root span; the SDK records no span of its own. An SDK that implements `traces` MAY propagate its active span's context instead, keeping this format and the target gate.

#### Scenario: a listed target receives a sampled traceparent
- **GIVEN** traceparent propagation is enabled for "api.example.com"
- **WHEN** the application sends a request to "https://api.example.com/v1/work"
- **THEN** the request includes a `traceparent` header of the form `00-<32 hex digits>-<16 hex digits>-01`

#### Scenario: each request gets its own ids
- **GIVEN** traceparent propagation is enabled for "api.example.com"
- **WHEN** the application sends two requests to "https://api.example.com/v1/work"
- **THEN** the two requests carry different trace ids and different span ids

#### Scenario: an application traceparent is preserved
- **GIVEN** traceparent propagation is enabled for "api.example.com"
- **AND** the application sets its own `traceparent` on the request
- **WHEN** the request is sent to "https://api.example.com/v1/work"
- **THEN** the request carries the application's `traceparent` unchanged
