## Narrative alignment

When syncing this delta, align Behavior items 9–10, Error handling, and Concurrency & ordering guarantees with the requirement below: only mandatory header redaction, payload-size limiting, and ingestion-path filtering precede the custom callback. Body-content heuristics run only without a custom callback. Preserve capture opt-ins, host exclusions, and all unrelated privacy requirements.

## ADDED Requirements

### Requirement: Browser replay network body scrubber replacement

For browser replay network capture, the SDK MUST apply mandatory sensitive-header redaction, payload-size limits, and PostHog ingestion-path filtering regardless of whether a custom `session_recording.maskCapturedNetworkRequestFn` is supplied. These protections MUST run before invoking a custom callback; requests dropped by mandatory filtering MUST NOT reach that callback. Existing capture opt-ins and host exclusions remain in force.

When no custom callback is supplied, the SDK MUST apply its default body-content scrubber to eligible request and response bodies after mandatory cleaning. When a custom callback is supplied, it MUST replace the default body-content scrubber: the SDK MUST NOT run default keyword or other body-content heuristics either before or after that callback. The callback is responsible for sanitizing the request and response bodies it retains and MAY modify or drop a request. Callback inputs can still contain absent bodies or size-limit replacement markers produced by mandatory cleaning; replacing default scrubbing does not bypass those protections.

#### Scenario: Default body scrubbing runs without a custom callback
- **GIVEN** browser replay body capture is enabled without a custom network masking callback
- **AND** an eligible request and response each have a body below the payload-size limit containing `{"password":"secret"}`
- **WHEN** the request is processed for replay capture
- **THEN** default body-content scrubbing redacts both bodies before they are attached to replay
- **AND** neither recorded body contains `secret`

#### Scenario: Custom body scrubbing replaces default heuristics rather than composing with them
- **GIVEN** browser replay body capture is enabled with a custom network masking callback
- **AND** an eligible request and response each have a body below the payload-size limit containing `{"author":"Ada","password":"secret"}`
- **AND** the callback parses each body as JSON, removes `password`, serializes the remaining object, and returns the request
- **WHEN** the request is processed for replay capture
- **THEN** the callback receives both original JSON bodies without default body-content redaction
- **AND** the recorded request and response bodies each contain `{"author":"Ada"}` and no `password` property
- **AND** the default `auth` substring heuristic does not redact `author` before or after the callback

#### Scenario: Mandatory header redaction runs before a custom callback
- **GIVEN** browser replay header capture is enabled with a custom network masking callback that returns its input
- **AND** an eligible request has an `Authorization` header and its response has a `Set-Cookie` header
- **WHEN** the request is processed for replay capture
- **THEN** neither sensitive header is present in the callback input
- **AND** neither sensitive header is recorded in replay

#### Scenario: Mandatory payload-size limits run before a custom callback
- **GIVEN** browser replay body capture is enabled with a custom network masking callback that returns its input
- **AND** an eligible request and response each have a body exceeding the SDK payload-size limit
- **WHEN** the request is processed for replay capture
- **THEN** the callback receives size-limited replacements rather than either oversized body
- **AND** neither oversized body is recorded in replay

#### Scenario: Mandatory ingestion-path filtering cannot be bypassed by a custom callback
- **GIVEN** browser replay network capture is enabled with a custom network masking callback that returns its input
- **WHEN** a request to a PostHog ingestion path covered by mandatory filtering is processed for replay capture
- **THEN** the callback is not invoked for that request
- **AND** that request is not attached to replay

#### Scenario: A custom callback can drop an ordinary network request
- **GIVEN** browser replay network capture is enabled with a custom network masking callback that returns `undefined`
- **WHEN** an otherwise eligible non-initial fetch request is processed for replay capture
- **THEN** that request is not attached to replay
- **AND** the default body scrubber is not used as a fallback for the callback's drop decision
