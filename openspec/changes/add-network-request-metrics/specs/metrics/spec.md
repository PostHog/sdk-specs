# Spec Delta

## ADDED Requirements

### Requirement: Network request timing metrics

A Metrics-capable SDK that declares network request timing support SHALL record one
histogram sample for each completed, observable outgoing application request while
network request metrics are enabled. The sample SHALL describe the elapsed request
duration and the available outcome, using the metric identifier, unit, and bounded
attribute names defined by the shipped `posthog-js` reference implementation. It SHALL
not record PostHog ingestion requests.

Session Replay network entries and this Metrics source are separate data products. A
replay recorder does not satisfy this requirement unless it also emits the required
Metrics sample. An SDK MAY declare the feature only where it can observe a documented
host network API without changing request behaviour; an SDK with no such adapter is
outside this optional feature's conformance scope.

#### Scenario: Completed application request creates one timing sample
- **GIVEN** network request metrics are enabled
- **WHEN** an observable application request completes
- **THEN** the SDK adds one histogram sample with a finite, non-negative duration and its available outcome

#### Scenario: PostHog ingestion is excluded
- **GIVEN** network request metrics are enabled
- **WHEN** the SDK sends its own data to a PostHog ingestion endpoint
- **THEN** it does not add a network request timing sample for that request

#### Scenario: Session Replay evidence is not treated as Metrics support
- **GIVEN** an SDK records network data only in Session Replay
- **WHEN** its network request metrics support is assessed
- **THEN** it is not recorded as shipped for this Metrics source

### Requirement: Safe network request metric dimensions

The optional network request timing metric MAY contain only the HTTP method, a
normalized route or host category, a bounded response-status class, and a bounded error
class when each value is available. It MUST NOT contain a request or response body,
header, query-string value, full URL, session id, distinct id, request id, or another
unbounded or sensitive value. A dimension which cannot be safely observed SHALL be
omitted; the SDK MUST NOT invent a value.

#### Scenario: Sensitive request data is excluded
- **WHEN** a completed request has a URL with a query string, request headers, and a response body
- **THEN** none of those values is included in the timing sample

#### Scenario: Unknown outcome remains safe
- **WHEN** a request completes but its response status is not observable
- **THEN** the SDK records only the available bounded dimensions and does not invent a status value

### Requirement: Network request timing enablement and failure isolation

A SDK that declares network request timing support SHALL capture no timing data while
the feature is disabled, while Metrics is disabled, or after the user has opted out.
Installation, observation, encoding, and export failures SHALL not change application
request behaviour or throw into application code. The SDK SHALL remove or deactivate
its observation hooks when it can do so after the feature is disabled or the SDK is
shut down.

#### Scenario: Disabled feature has no capture side effect
- **GIVEN** network request metrics are disabled
- **WHEN** the application completes an observable request
- **THEN** the SDK emits no timing sample and does not modify the request or response

#### Scenario: Capture failure does not affect the request
- **GIVEN** timing sample encoding fails
- **WHEN** the application completes an observable request
- **THEN** the application receives its normal request result and the SDK does not throw
