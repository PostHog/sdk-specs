# Spec Delta

## Purpose

Network request metrics let SDKs report safe, low-cardinality timing and outcome
data for outgoing application requests through the existing PostHog Metrics product.

## ADDED Requirements

### Requirement: Network request timing scope

An SDK that supports this capability SHALL record one metric sample for each completed,
observable outgoing application request while network request metrics are enabled. The
sample SHALL describe the elapsed request duration and the available outcome. It SHALL
not record PostHog ingestion requests. Session Replay network entries and this Metrics
capability are separate data products; a replay recorder does not satisfy this
capability unless it also emits the required Metrics sample.

Automatic capture SHALL be provided only where the SDK can observe a documented host
network API without replacing request behaviour. An SDK that cannot do this safely
SHALL be recorded as a candidate or out of scope, not as a conformance failure.

#### Scenario: Completed application request creates one timing sample
- **GIVEN** network request metrics are enabled
- **WHEN** an observable application request completes
- **THEN** the SDK sends one timing sample with a finite, non-negative duration and its available outcome

#### Scenario: PostHog ingestion is excluded
- **GIVEN** network request metrics are enabled
- **WHEN** the SDK sends its own data to a PostHog ingestion endpoint
- **THEN** it does not create a network request timing sample for that request

#### Scenario: Session Replay evidence is not treated as Metrics support
- **GIVEN** an SDK records network data only in Session Replay
- **WHEN** its network request metrics support is assessed
- **THEN** it is not recorded as shipped for this capability

### Requirement: Safe metric dimensions

The timing sample SHALL use the metric identifier, unit, and bounded attribute names
defined by the shipped `posthog-js` reference implementation. It MAY contain only the
HTTP method, a normalized route or host category, a bounded response-status class, and
a bounded error class when each value is available. It MUST NOT contain a request or
response body, header, query-string value, full URL, session id, distinct id, request
id, or another unbounded or sensitive value.

#### Scenario: Sensitive request data is excluded
- **WHEN** a completed request has a URL with a query string, request headers, and a response body
- **THEN** none of those values is included in the timing sample

#### Scenario: Unknown outcome remains safe
- **WHEN** a request completes but its response status is not observable
- **THEN** the SDK records only the available bounded dimensions and does not invent a status value

### Requirement: Enablement and failure isolation

The SDK SHALL capture no timing data while the feature is disabled, while Metrics is
disabled, or after the user has opted out. Installation, observation, encoding, and
export failures SHALL not change application request behaviour or throw into application
code. An SDK SHALL remove or deactivate its observation hooks when it can do so after
the feature is disabled or the SDK is shut down.

#### Scenario: Disabled feature has no capture side effect
- **GIVEN** network request metrics are disabled
- **WHEN** the application completes an observable request
- **THEN** the SDK emits no timing sample and does not modify the request or response

#### Scenario: Capture failure does not affect the request
- **GIVEN** timing sample encoding fails
- **WHEN** the application completes an observable request
- **THEN** the application receives its normal request result and the SDK does not throw

### Requirement: Support classification is independent of compliance

The SDK-specs support record SHALL classify every assessed SDK as **shipped and
verified**, **partial or manual**, **candidate**, or **out of scope**. A shipped or
partial classification SHALL include implementation evidence. A candidate classification
SHALL identify the host network API to assess and SHALL not contribute to compliance
Pass, Partial, Fail, N/A, or Unknown totals until the SDK is audited against this
capability.

#### Scenario: Candidate does not change compliance score
- **GIVEN** an SDK has a plausible native request-observation API but no verified Metrics implementation
- **WHEN** the support record is updated
- **THEN** it is listed as a candidate and its compliance score is unchanged

#### Scenario: Verified implementation is auditable
- **GIVEN** an SDK is classified as shipped and verified
- **WHEN** a maintainer reviews the support record
- **THEN** the record links to the implementation version, tests, and the metrics output it verifies
