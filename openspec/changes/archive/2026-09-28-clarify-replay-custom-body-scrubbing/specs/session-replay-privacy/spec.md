## Narrative alignment

When syncing this delta, align Behavior items 9–10, Error handling, and Concurrency & ordering guarantees with the requirement below: only mandatory header redaction, payload-size limiting, and ingestion-path filtering precede the custom callback. Body-content heuristics run only without a custom callback. Preserve capture opt-ins, host exclusions, and all unrelated privacy requirements.

## ADDED Requirements

### Requirement: Browser replay network body scrubber replacement

A **network capture masking callback** is an SDK-provided hook that allows applications to sanitize or drop captured replay network records (for example, `session_recording.maskCapturedNetworkRequestFn` in posthog-js). API names vary by SDK; the SDK MUST follow the behavior below regardless of the hook's API name. It refers to a hook receiving the captured record, not a deprecated URL-only hook.

For browser replay network capture, the SDK MUST apply mandatory sensitive-header redaction, payload-size limits, and PostHog ingestion-path filtering regardless of whether a custom network capture masking callback is supplied. These protections MUST run before invoking a custom callback; requests dropped by mandatory filtering MUST NOT reach that callback. Existing capture opt-ins and host exclusions remain in force. Mandatory cleaning protects the callback input, not arbitrary callback output: the SDK does not reapply these cleaners after the callback. The callback is responsible for sensitive data it adds or restores, including header values.

When no custom callback is supplied, the SDK MUST apply its default body-content scrubber to eligible request and response bodies after mandatory cleaning. When a custom callback is supplied, it MUST replace the default body-content scrubber: the SDK MUST NOT run default keyword or other body-content heuristics either before or after that callback. The callback is responsible for sanitizing the request and response bodies it retains and MAY modify or drop a request. Callback inputs can still contain absent bodies or size-limit replacement markers produced by mandatory cleaning; replacing default scrubbing does not bypass those protections.

For posthog-js compatibility, the deprecated `maskNetworkRequestFn` is adapted into `maskCapturedNetworkRequestFn` when no modern callback is supplied. This adapter also replaces default body-content scrubbing, even though the deprecated hook receives only the URL and cannot sanitize bodies. Applications using this hook with body capture enabled MUST NOT rely on default body scrubbing; they SHOULD migrate to `maskCapturedNetworkRequestFn` to sanitize bodies or disable body capture. When both hooks are supplied, the modern callback takes precedence. Retaining default body scrubbing for the URL-only hook would be a separate SDK behavior change.

For the network capture masking callback, returning `null` or `undefined` MUST drop an ordinary non-initial replay network record and its derived server timings. For an initial performance entry, a nullish return MUST instead retain only required timing metadata, entry type, and the initial-entry flag with an empty URL; headers, bodies, and customer-controlled server timing data MUST NOT be retained. This fallback MUST use metadata preserved before invoking the callback, not callback-mutated values.

If the network capture masking callback throws, the SDK MUST catch the exception per record and drop that record and its derived server timings, including for initial entries. It MUST NOT record the unmasked input, use the default scrubber as a fallback, or retain a timing-only fallback for a thrown callback. Unrelated records in the same batch and subsequent batches MUST continue to be processed, and the exception MUST NOT escape the recorder. These rules affect replay records, not the application's HTTP requests.

#### Scenario: Default body scrubbing runs without a custom callback
- **GIVEN** browser replay body capture is enabled without either a modern or deprecated network masking callback
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

#### Scenario: Deprecated URL-only masking also replaces default body scrubbing
- **GIVEN** browser replay body capture is enabled with only a deprecated `maskNetworkRequestFn` that returns its input URL unchanged
- **AND** an eligible non-initial request has a body below the payload-size limit containing `{"password":"secret"}`
- **WHEN** the request is processed for replay capture
- **THEN** the deprecated hook receives only the URL
- **AND** the recorded body remains `{"password":"secret"}` because the compatibility adapter bypasses default body-content scrubbing

#### Scenario: Mandatory header redaction runs before a custom callback
- **GIVEN** browser replay header capture is enabled with a custom network masking callback that returns its input
- **AND** an eligible request has an `Authorization` header and its response has a `Set-Cookie` header
- **WHEN** the request is processed for replay capture
- **THEN** neither original sensitive header value is present in the callback input; header names MAY remain with redacted values
- **AND** neither original sensitive header value is recorded in replay

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
- **GIVEN** browser replay network capture is enabled with a network capture masking callback that returns `null` or `undefined`
- **WHEN** an otherwise eligible non-initial fetch request is processed for replay capture
- **THEN** that request is not attached to replay
- **AND** its derived server timings are not attached to replay
- **AND** the default body scrubber is not used as a fallback for the callback's drop decision

#### Scenario: A nullish result for an initial entry retains only timing metadata
- **GIVEN** an initial performance entry contains a URL and customer-controlled server timings
- **AND** the network capture masking callback mutates its input and returns `null` or `undefined`
- **WHEN** the entry is processed for replay capture
- **THEN** only required timing metadata preserved before the callback, entry type, and the initial-entry flag are retained with an empty URL
- **AND** no headers, bodies, or customer-controlled server timing data are recorded

#### Scenario: A throwing callback drops only the affected record
- **GIVEN** a replay network batch contains unrelated records before and after a record with derived server timings
- **AND** the network capture masking callback throws for that record, whether it is initial or non-initial
- **WHEN** the batch is processed for replay capture
- **THEN** the affected record and its derived server timings are not recorded
- **AND** no unmasked input, default-scrubbed record, or timing-only fallback is recorded for the failure
- **AND** unrelated records before and after it and records in subsequent batches are processed normally
- **AND** the exception does not escape the recorder or interfere with the application's HTTP requests
