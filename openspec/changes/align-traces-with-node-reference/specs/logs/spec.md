## MODIFIED Requirements

### Requirement: Resource and scope

The OTLP envelope SHALL carry **resource** attributes describing the producing service
(`service.name`, optional `service.version`, optional `deployment.environment`,
`telemetry.sdk.name`, `telemetry.sdk.version`, `os.name`, `os.version`) plus any user-supplied
`resourceAttributes`, and a **scope** of `{ name, version }` identifying the SDK. On key collision,
SDK-managed identity keys (`service.*`, `telemetry.sdk.*`) SHALL win over user `resourceAttributes`
so users cannot clobber identity keys. The SDK SHALL emit `telemetry.sdk.name` and
`telemetry.sdk.version`, and SHALL always emit `service.name` — even when a `resourceAttributes`
value is too large to encode in full: the SDK-set identity keys are encoded on a budget of their
own, after the user's attributes, so a user value that exhausts the encoder's traversal budget
cannot cost the resource its `service.name`.

#### Scenario: SDK identity keys protected
- **WHEN** a user sets `resourceAttributes: { "service.name": "evil" }` and the SDK resolves `service.name` to "checkout"
- **THEN** the emitted `service.name` is "checkout"

#### Scenario: scope identifies the SDK
- **WHEN** an iOS SDK at version 3.58.0 builds a payload
- **THEN** the scope is `{ "name": "posthog-ios", "version": "3.58.0" }`

#### Scenario: an oversized resource attribute does not cost service.name
- **GIVEN** `resourceAttributes` holding a value too large for the encoder to walk in full
- **WHEN** the envelope is built
- **THEN** it still carries `service.name` and `telemetry.sdk.*`

### Requirement: Batch assembly and concurrency

For a persistent queue the SDK SHALL take up to **max records per POST** from the head of the queue,
build one OTLP payload, POST it, and on success remove those records, repeating until the queue is
drained or a send fails. The per-POST cap SHALL keep each body comfortably under the service's 2 MiB
default limit, which a self-hosted deployment may keep; PostHog's hosted ingestion runs 10 MiB. The
SDK SHALL allow only **one flush in flight** at a time (joining or no-opping a concurrent flush
rather than double-sending), run logs on a worker/queue separate from the analytics-events pipeline,
and bound the drain loop by the queue length captured at flush start. `captureLog` SHALL be safe to
call from any thread.

#### Scenario: single flight
- **GIVEN** a flush already in progress
- **WHEN** a second flush is triggered
- **THEN** it joins or no-ops rather than re-sending the head of the queue

#### Scenario: bounded drain
- **GIVEN** records are enqueued during an active flush
- **WHEN** the drain loop runs
- **THEN** records added mid-flush are left for the next cycle

### Requirement: Server-side contract

The SDK SHALL design to the ingestion service's observed contract: a request body limit set per
deployment — 2 MiB by default (`MAX_REQUEST_BODY_SIZE_BYTES`), 10 MiB on PostHog's hosted US and EU
ingestion (verified 2026-09-10) — (exceed → 413) with **no** separate per-record size cap; success
is 200 with body `{}`; the service emits only 200/400/401/500 and **never** `429`, `Retry-After`, or
`quota_limited` (any 429 a client sees comes from shared infra); the server may re-derive severity,
clamp timestamps to ±24h of receive time (replacing out-of-range values with now and preserving the
original in `$originalTimestamp`), overwrite `observedTimeUnixNano`, zero `traceId`/`spanId` that
are not exactly 16/8 bytes, and flatten scope to `"{name}@{version}"`. The service accepts JSON or
protobuf, content-sniffed; SDKs SHALL send JSON.

#### Scenario: oversize body
- **WHEN** a request body exceeds the deployment's limit (10 MiB on PostHog's hosted ingestion)
- **THEN** the server responds 413 and the SDK applies the 413 batch-shrink path

#### Scenario: no quota signal from logs service
- **WHEN** the SDK handles responses
- **THEN** it does not depend on `429`/`Retry-After`/`quota_limited` from the logs endpoint

#### Scenario: invalid trace id zeroed
- **WHEN** a record sends a `traceId` that is not 16 bytes
- **THEN** the server zeroes it rather than rejecting the record
