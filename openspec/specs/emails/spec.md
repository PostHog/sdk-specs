# Emails Specification

## Purpose

Send one transactional email, such as a password reset or a receipt, from a transactional template in PostHog to one recipient, and read the email's delivery status by its message ID. Every attempt of one call uses the same idempotency key so PostHog can deduplicate retries, and an error keeps PostHog's stable code.

## Applicability

Server SDKs only. Both operations need a secret key (a project secret API key), which must never reach a client. The reference surfaces are `posthog.emails` in posthog-node and `client.emails`, `Emails` and `AsyncEmails` in posthog-python's `posthog.emails`. Other SDKs can use native names, async conventions, and error channels, as the requirements allow.

Not covered: the code-content form (subject and body in the call) and the `capture_engagement` send option, which the send API does not accept yet.

## Public surface

Names below use posthog-node spelling, then posthog-python spelling.

| Operation | Inputs and defaults | Result |
|---|---|---|
| `send` | Required `to`, `templateId` / `template_id`; optional `templateData` / `template_data`, `distinctId` / `distinct_id`, `idempotencyKey` / `idempotency_key` (default: a UUID v4 for the call), `maxRetries` (default: the client's) | Send result: `id`, `replayed`, `warnings` |
| `get` | Message ID from a send result | Status record: `id`, `status`, `createdAt` / `created_at`, `statusAt` / `status_at`, `reason` |

| Client option | posthog-node | posthog-python | Default |
|---|---|---|---|
| Secret key | `secretKey` | `secret_key` | none |
| App host | `appHost` | `app_host` | derived from a PostHog Cloud host |
| Request timeout | `emailRequestTimeoutMs` | `email_request_timeout_seconds` | 15 seconds |
| Maximum retries | `emailRequestMaxRetries` | `email_request_max_retries` | 2 |

## HTTP mapping

| Operation | Request | Success |
|---|---|---|
| `send` | `POST {app host}/api/projects/@current/messaging/send/email/` with `{"template_id", "to", "message_data", "distinct_id"}` | `2xx` with `{"message_id", "replayed", "warnings"}` |
| `get` | `GET {app host}/api/projects/@current/messaging/emails/{message_id}/` | `200` with `{"id", "status", "created_at", "status_at", "reason"}` |

The status is one of `queued`, `sent`, `failed`, `delivered`, `bounced`, or `complained` today, and new statuses can appear.

## Error names

| Response | Name |
|---|---|
| `missing_secret_key`, or `401` | `missing_api_key` |
| `400` | `validation_error` |
| `403` | `invalid_permission` |
| `404` | `not_found` |
| `409` with `template_outdated` | `validation_error` |
| Other `409` | `concurrent_idempotent_requests` |
| `422` with `idempotency_key_reused` | `invalid_idempotent_request` |
| Other `422` | `validation_error` |
| `429` with `quota_limited` | `monthly_quota_exceeded` |
| Other `429` | `rate_limit_exceeded` |
| `503`, or a network error | `service_unavailable` |
| A local `invalid_*` argument error, with no HTTP status | `validation_error` |
| Anything else | `application_error` |

## Requirements

### Requirement: Public surface

A server SDK SHALL expose transactional email on its client as `emails`, with two operations: `send`, which queues one email from a transactional template, and `get`, which reads the status of an email that `send` queued. An SDK MAY also offer a standalone emails client that does not capture events.

#### Scenario: The client exposes send and get
- **GIVEN** a server SDK client created with a secret key
- **WHEN** the caller reads `emails` on the client
- **THEN** it offers `send` and `get`

### Requirement: Email options

The client SHALL take an optional app host, a per-request timeout with a default of 15 seconds, and a maximum number of retries with a default of 2. `send` SHALL take a per-send maximum number of retries that overrides the client's for that call.

#### Scenario: Defaults apply when the client sets no email options
- **GIVEN** a client created with a secret key and no email options
- **WHEN** the caller sends an email and every attempt fails with a `503`
- **THEN** the SDK makes 3 attempts in total

#### Scenario: A per-send retry limit overrides the client's
- **GIVEN** a client whose maximum number of retries is 2
- **WHEN** the caller sends an email with a per-send maximum of 0 and the first attempt fails with a `503`
- **THEN** the SDK makes 1 attempt and reports the error

### Requirement: Secret key

The SDK SHALL authenticate every email request with the client's trimmed secret key, sent as `Authorization: Bearer <key>`. A client without a secret key SHALL report the error `missing_secret_key` without sending a request. The SDK SHALL never put the secret key or the request body in an error message or a log line.

#### Scenario: A client without a secret key sends nothing
- **GIVEN** a client created without a secret key
- **WHEN** the caller sends an email
- **THEN** the SDK reports the error code `missing_secret_key`
- **AND** no request is made

### Requirement: App host

The SDK SHALL send email requests to the PostHog app host, not the ingestion host. A caller-set app host SHALL win, except that a PostHog Cloud host maps to its region's app host. Without one, `us.i.posthog.com`, `us.posthog.com` and `app.posthog.com` SHALL map to `https://us.posthog.com`, and `eu.i.posthog.com` and `eu.posthog.com` SHALL map to `https://eu.posthog.com`.

#### Scenario: An ingestion host maps to its region's app host
- **GIVEN** a client whose host is `https://eu.i.posthog.com` and that sets no app host
- **WHEN** the caller sends an email
- **THEN** the request goes to `https://eu.posthog.com/api/projects/@current/messaging/send/email/`

### Requirement: Custom host refusal

For a client host that is not PostHog Cloud and no caller-set app host, the SDK SHALL report the error `missing_app_host` without sending a request. A custom host is often an ingestion proxy, which must not receive the secret key.

#### Scenario: A custom host without an app host is refused
- **GIVEN** a client whose host is `https://proxy.example.com` and that sets no app host
- **WHEN** the caller sends an email
- **THEN** the SDK reports the error code `missing_app_host`
- **AND** no request is made

### Requirement: Send request

`send` SHALL send `POST {app host}/api/projects/@current/messaging/send/email/` with a JSON body holding `template_id` (the template ID in lowercase), `to`, `message_data` (the template data, or an empty object), and `distinct_id` only when the caller passed a distinct ID.

#### Scenario: The template and its data reach the send route
- **WHEN** the caller sends to `user@example.com` with template ID `0190F6D2-7C1E-7B3A-9F5E-1C2D3E4F5A6B`, template data `{"name": "Ada"}` and distinct ID `user_123`
- **THEN** the body is `{"template_id": "0190f6d2-7c1e-7b3a-9f5e-1c2d3e4f5a6b", "to": "user@example.com", "message_data": {"name": "Ada"}, "distinct_id": "user_123"}`

### Requirement: Send request headers

A send SHALL carry `Content-Type: application/json`, `Accept: application/json`, the `Idempotency-Key`, and the SDK's user agent. The SDK SHALL NOT take the distinct ID from a request context.

#### Scenario: A send without a distinct ID ignores the request context
- **GIVEN** a request context whose distinct ID is `context_user`
- **WHEN** the caller sends an email without a distinct ID
- **THEN** the body has no `distinct_id`

### Requirement: Argument checks

Before any request, the SDK SHALL check that `to` is one nonempty string, the template ID is a UUID, template data is a mapping, a distinct ID is a nonempty string, an idempotency key is 1 to 255 visible ASCII characters, and a retry limit is a nonnegative integer. A failed check SHALL send no request.

#### Scenario: A template ID that is not a UUID sends nothing
- **WHEN** the caller sends an email with template ID `welcome`
- **THEN** the SDK reports an argument error
- **AND** no request is made

### Requirement: Argument error channel

The SDK MAY report a failed argument check as a validation error with an `invalid_*` code, such as `invalid_template_id`, or raise the language's argument error. It SHALL follow the channel of "Error channel".

#### Scenario: posthog-node reports an invalid template ID as a validation error
- **GIVEN** posthog-node
- **WHEN** the caller sends an email with template ID `welcome`
- **THEN** the promise resolves to an error with code `invalid_template_id` and name `validation_error`

### Requirement: Idempotency key

Every send SHALL carry an `Idempotency-Key`. When the caller passes none, the SDK SHALL generate a UUID v4 for that call. Every attempt of one call, retries included, SHALL send the same key.

#### Scenario: Retries reuse the generated key
- **GIVEN** a send without an idempotency key
- **WHEN** the first attempt fails with a `503` and the retry succeeds
- **THEN** both attempts send the same `Idempotency-Key`
- **AND** the key is a UUID v4

### Requirement: Retryable responses

The SDK SHALL retry, up to the retry limit, only a network error or timeout, a `409` with code `idempotency_key_in_flight`, a `429` whose code is not `quota_limited`, and a `503`. It SHALL NOT retry any other response, including a `2xx` without a message ID.

#### Scenario: A monthly quota is not retried
- **WHEN** the first attempt fails with a `429` and code `quota_limited`
- **THEN** the SDK makes 1 attempt and reports the error code `quota_limited`

### Requirement: Retry timing

Before retry `n`, counting from 0, the SDK SHALL wait about `2^n` seconds with jitter, at most 30 seconds, or the server's `Retry-After` when that is longer. When `Retry-After` is longer than 30 seconds, the SDK SHALL report the error at once instead of waiting.

#### Scenario: A long Retry-After fails at once
- **WHEN** the first attempt fails with a `429`, code `throttled` and `Retry-After: 60`
- **THEN** the SDK makes 1 attempt and reports the error with a retry-after of 60 seconds

### Requirement: Send result

A `2xx` response with a nonempty string `message_id` SHALL produce a result with that message ID, `replayed` (true only when the response says `true`), and the response's warnings, each with a code, a message and an optional fix. The SDK SHALL log each warning. A result means PostHog queued the email, not that it was delivered.

#### Scenario: A replay returns the first send's ID
- **WHEN** the response is `202` with `{"message_id": "msg_1", "replayed": true}`
- **THEN** the result has ID `msg_1` and `replayed` true

### Requirement: Send response without a message ID

A `2xx` response whose body is not JSON, or whose `message_id` is missing, empty or not a string, SHALL produce the error `api_error` with the response's HTTP status, and SHALL NOT be retried.

#### Scenario: An acceptance without a message ID is an error
- **WHEN** the response is `202` with `{}`
- **THEN** the SDK makes 1 attempt and reports the error code `api_error` with status 202

### Requirement: Error fields

An error from a PostHog response SHALL carry the response's `code` unchanged, or `api_error` when it has none. It SHALL carry a message from `detail`, the HTTP status, the field from `attr`, `why`, `fix` and `docs_url` when present, and the server's retry-after. An SDK error without a response, such as `missing_app_host`, SHALL use the same fields with no status.

#### Scenario: A suppressed recipient keeps PostHog's code
- **WHEN** the response is `422` with `{"code": "recipient_suppressed", "detail": "Nope."}`
- **THEN** the error has code `recipient_suppressed`, message `Nope.` and status 422

### Requirement: Error names

An error SHALL carry a `name`, a coarse category for callers that branch on the kind of failure rather than the exact code. The name SHALL follow the mapping in the Error names table of this spec, which keys on the HTTP status and, for `409`, `422` and `429`, on the code. A local argument error with an `invalid_*` code and no HTTP status SHALL be named `validation_error`.

#### Scenario: A quota error has the quota name
- **WHEN** the response is `429` with code `quota_limited`
- **THEN** the error name is `monthly_quota_exceeded`

#### Scenario: A reused idempotency key has the idempotency name
- **WHEN** the response is `422` with code `idempotency_key_reused`
- **THEN** the error name is `invalid_idempotent_request`

### Requirement: Error channel

The SDK SHALL report an email error through the language's idiomatic channel only. An SDK whose awaited methods do not reject, such as posthog-node, SHALL resolve to `{ data, error }` with exactly one set, and SHALL report an unexpected internal failure as `unexpected_error`. An SDK that raises, such as posthog-python, SHALL raise one email error type for request and SDK failures, and MAY keep argument errors as native exceptions.

#### Scenario: posthog-node never rejects a send
- **GIVEN** posthog-node
- **WHEN** a send fails with a `404`
- **THEN** the promise resolves to `{ data: null, error }` with error code `not_found`

### Requirement: Status read request

`get` SHALL check that the message ID is a UUID before any request, then send `GET {app host}/api/projects/@current/messaging/emails/{message ID in lowercase}/`. It SHALL use the authentication, host rules and retry policy of a send, with no body and no idempotency key.

#### Scenario: An unknown message ID is not retried
- **WHEN** the response is `404` with code `not_found`
- **THEN** the SDK makes 1 attempt and reports the error code `not_found`

### Requirement: Status record

A `200` from the status read SHALL produce a record with the ID, the status passed through unchanged, the time PostHog queued the email, the time it reached its status, and the reason or null. A response without an ID, a status or either time SHALL produce an `api_error`. The times MAY be native date-times or ISO 8601 strings.

#### Scenario: A bounced email returns its status and reason
- **WHEN** the response is `200` with `{"id": "01a18356-c56c-0001-e494-7666bc915188", "status": "bounced", "created_at": "2026-10-28T16:27:44.364000Z", "status_at": "2026-10-28T16:30:02.100000Z", "reason": "hard"}`
- **THEN** the record has status `bounced`, reason `hard`, and both times

#### Scenario: A status the SDK doesn't know passes through
- **WHEN** the response is `200` with a valid record whose status is `archived`
- **THEN** the record has status `archived`

### Requirement: Disabled client

A disabled client SHALL send no email request and SHALL report the error `client_disabled`.

#### Scenario: A disabled client sends nothing
- **GIVEN** a disabled client with a secret key
- **WHEN** the caller sends an email
- **THEN** the SDK reports the error code `client_disabled`
- **AND** no request is made

### Requirement: Shutdown

After the client shuts down, it SHALL send no email request and SHALL report the error `client_closed`. Shutdown SHALL wait for email requests in flight, retries included, to settle. Where shutdown takes a timeout, it SHALL wait for them only within the remaining timeout.

#### Scenario: Shutdown waits for a send in its retry backoff
- **GIVEN** a send whose first attempt failed with a `503` and that waits about 1 second to retry
- **WHEN** the caller shuts the client down with a timeout of 30 seconds
- **THEN** shutdown finishes only after the retry settles

#### Scenario: Shutdown keeps to its timeout during a retry backoff
- **GIVEN** a send whose first attempt failed with a `503` and that waits about 1 second to retry
- **WHEN** the caller shuts the client down with a timeout of 100 milliseconds
- **THEN** shutdown finishes within about 100 milliseconds

#### Scenario: A shut-down client sends nothing
- **GIVEN** a client that has shut down
- **WHEN** the caller sends an email
- **THEN** the SDK reports the error code `client_closed`
- **AND** no request is made
