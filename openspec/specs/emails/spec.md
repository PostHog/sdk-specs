# Emails Specification

## Purpose

Send one transactional email, such as a password reset or a receipt, from a transactional template in PostHog to one recipient, now or at a scheduled time on PostHog Cloud, or to each of up to 100 recipients in one batch, and read each email's delivery status by its message ID. Every attempt of one call uses the same idempotency key, one per recipient in a batch, so PostHog can deduplicate retries, and an error keeps PostHog's stable code.

## Applicability

Server SDKs only. Every operation needs a secret key (a project secret API key), which must never reach a client. The reference surfaces are `posthog.emails` in posthog-node and `client.emails`, `Emails` and `AsyncEmails` in posthog-python's `posthog.emails`. Other SDKs can use native names, async conventions, and error channels, as the requirements allow.

Not covered: the code-content form (subject and body in the call), for a send or a batch, and the `capture_engagement` send option, which the send API does not accept yet. Cancelling, moving or listing scheduled emails is not covered either: PostHog doesn't offer it.

## Public surface

Names below use posthog-node spelling, then posthog-python spelling.

| Operation | Inputs and defaults | Result |
|---|---|---|
| `send` | Required `to`, `templateId` / `template_id`; optional `templateData` / `template_data`, `distinctId` / `distinct_id`, `idempotencyKey` / `idempotency_key` (default: a UUID v4 for the call), `maxRetries` (default: the client's), `scheduledAt` / `scheduled_at` | Send result: `id`, `replayed`, `warnings`, and for a scheduled send the confirmed scheduled time, or none when the email goes out now |
| `batch` | Required `templateId` / `template_id` and 1 to 100 `recipients`, each with required `to` and optional `distinctId` / `distinct_id`, `templateData` / `template_data` and `idempotencyKey` / `idempotency_key` (default: a UUID v4 for the recipient); optional shared `templateData` / `template_data`, `maxRetries` (default: the client's) | Batch result: one result per recipient, in order, with its position, `to`, idempotency key, status (`queued`, `failed` or `unconfirmed`), message ID, `replayed` and error; and `warnings` |
| `get` | Message ID from a send or batch result | Status record: `id`, `status`, `createdAt` / `created_at`, `statusAt` / `status_at`, `reason` |

| Client option | posthog-node | posthog-python | Default |
|---|---|---|---|
| Secret key | `secretKey` | `secret_key` | none |
| App host | `appHost` | `app_host` | derived from a PostHog Cloud host |
| Request timeout | `emailRequestTimeoutMs` | `email_request_timeout_seconds` | 15 seconds |
| Maximum retries | `emailRequestMaxRetries` | `email_request_max_retries` | 2 |

## HTTP mapping

| Operation | Request | Success |
|---|---|---|
| `send` | `POST {app host}/api/messaging/send/email/` with `{"template_id", "to", "message_data", "distinct_id"}` | `2xx` with `{"message_id", "replayed", "warnings"}` |
| `send` with a scheduled time | The same, with `"scheduled_at"` in UTC to the millisecond | `202` with `"status": "scheduled"` and the time, or `"status": "queued"` and `"scheduled_at": null` when the time had passed |
| `batch` | `POST {app host}/api/messaging/send/email_batch/` with `{"template_id", "message_data", "recipients": [{"to", "idempotency_key", "distinct_id", "message_data"}]}`, and no `Idempotency-Key` header | `200` with `{"results": [{"message_id", "status", "replayed"} or {"message_id", "error": {"code", "detail", "status", "retryable"}}], "warnings"}` |
| `get` | `GET {app host}/api/messaging/emails/{message_id}/` | `200` with `{"id", "status", "created_at", "status_at", "reason"}` |

These routes take the project from the secret key, so the path names no project. They accept project secret API keys only.

The status is one of `scheduled`, `queued`, `sent`, `failed`, `delivered`, `bounced`, or `complained` today, and new statuses can appear.

## Error names

| Response | Name |
|---|---|
| `missing_secret_key`, or `401` | `missing_api_key` |
| `400` | `validation_error` |
| `403` | `invalid_permission` |
| `404` | `not_found` |
| `409` with `template_outdated` | `validation_error` |
| `409` with `batch_unavailable` | `application_error` |
| Other `409` | `concurrent_idempotent_requests` |
| `422` with `idempotency_key_reused` | `invalid_idempotent_request` |
| Other `422` | `validation_error` |
| `429` with `quota_limited` | `monthly_quota_exceeded` |
| Other `429` | `rate_limit_exceeded` |
| `503`, or a network error | `service_unavailable` |
| A local `invalid_*` argument error, with no HTTP status | `validation_error` |
| Anything else | `application_error` |

## Batch errors

How a batch's request fails as a whole. A recipient is Failed when PostHog didn't send its email, and Unconfirmed when PostHog may still send it. Every Unconfirmed recipient keeps its idempotency key and the advice to send it again with that key. When any recipient is Unconfirmed, the error of the call never says the emails weren't sent.

| What happened | Recipients | The error |
|---|---|---|
| A failure before the request, such as a failed argument check, `missing_secret_key`, `missing_app_host`, `client_disabled` or `client_closed` | Every recipient fails, and no request is made | The check's code |
| `409` with `batch_unavailable` | Every recipient Failed | `batch_unavailable`: batch sends aren't available for the project, so send each recipient on its own with `send`, with its key and the email the batch would have sent |
| `409` with any other code, or with no code | Every recipient Unconfirmed | PostHog's code, or `api_error`; says PostHog didn't confirm the emails, never that they weren't sent; `idempotency_key_in_flight` is retried first |
| `413` | Every recipient Failed | PostHog's code, or `content_too_large` when it has none, with advice to split the recipients into smaller batches |
| `400` with `content_too_large` | Every recipient Failed | `content_too_large`, with PostHog's message and no advice to split |
| `404` that names no field, with code `not_found`, `api_error`, or none | Every recipient Failed, and nothing was sent | `not_found` with status 404: no template with this ID, or batch sends aren't available for this project |
| Any other refusal, such as a `400`, `403`, `422`, or `429` once the retries are spent | Every recipient Failed | PostHog's code |
| A network error, a timeout or a `5xx`, once the retries are spent | Every recipient Unconfirmed | The last attempt's code; says PostHog didn't confirm the emails, never that they weren't sent |
| A `2xx` without a result for each recipient | Every recipient Unconfirmed | `api_error`, not retried; says PostHog didn't confirm the emails |
| Any refusal of a retry of the whole batch after an earlier attempt of the same call got no usable answer | Every recipient Unconfirmed | Says some emails may have gone out, never that nothing was sent, and advises sending each recipient again with the same email and key |

## Requirements

### Requirement: Public surface

A server SDK SHALL expose transactional email on its client as `emails`, with three operations: `send`, which queues or schedules one email from a transactional template, `batch`, which sends one email from a transactional template to each of up to 100 recipients, and `get`, which reads the status of an email that `send` or `batch` queued. An SDK MAY also offer a standalone emails client that does not capture events.

#### Scenario: The client exposes send, batch and get
- **GIVEN** a server SDK client created with a secret key
- **WHEN** the caller reads `emails` on the client
- **THEN** it offers `send`, `batch` and `get`

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
- **THEN** the request goes to `https://eu.posthog.com/api/messaging/send/email/`

### Requirement: Custom host refusal

For a client host that is not PostHog Cloud and no caller-set app host, the SDK SHALL report the error `missing_app_host` without sending a request. A custom host is often an ingestion proxy, which must not receive the secret key.

#### Scenario: A custom host without an app host is refused
- **GIVEN** a client whose host is `https://proxy.example.com` and that sets no app host
- **WHEN** the caller sends an email
- **THEN** the SDK reports the error code `missing_app_host`
- **AND** no request is made

### Requirement: Send request

`send` SHALL send `POST {app host}/api/messaging/send/email/` with a JSON body holding `template_id` (the template ID in lowercase), `to`, `message_data` (the template data, or an empty object), and `distinct_id` only when the caller passed a distinct ID. The path SHALL NOT name a project; PostHog takes the project from the secret key.

#### Scenario: The template and its data reach the send route
- **WHEN** the caller sends to `user@example.com` with template ID `0190F6D2-7C1E-7B3A-9F5E-1C2D3E4F5A6B`, template data `{"name": "Ada"}` and distinct ID `user_123`
- **THEN** the request is `POST {app host}/api/messaging/send/email/`
- **AND** the body is `{"template_id": "0190f6d2-7c1e-7b3a-9f5e-1c2d3e4f5a6b", "to": "user@example.com", "message_data": {"name": "Ada"}, "distinct_id": "user_123"}`

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

`get` SHALL check that the message ID is a UUID before any request, then send `GET {app host}/api/messaging/emails/{message ID in lowercase}/`. It SHALL use the authentication, host rules and retry policy of a send, with no body and no idempotency key.

#### Scenario: The status read uses the key-scoped path
- **WHEN** the caller reads the status of message `01A18356-C56C-0001-E494-7666BC915188`
- **THEN** the request is `GET {app host}/api/messaging/emails/01a18356-c56c-0001-e494-7666bc915188/`

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

### Requirement: Scheduled send request

`send` SHALL take an optional scheduled time, `scheduledAt` / `scheduled_at`, as the language's date-time or an ISO 8601 time with a UTC offset. The SDK SHALL round the time up to the next millisecond and send it in the body as `scheduled_at`, an RFC 3339 time in UTC with milliseconds. A send without a scheduled time SHALL carry no `scheduled_at`. A time without a UTC offset, or one that isn't a real calendar time, such as `2026-02-30T09:00:00Z`, SHALL fail the argument check with `invalid_scheduled_at`, and SHALL NOT be normalized into another time. The SDK SHALL NOT refuse a time for being in the past or more than 7 days ahead: PostHog sends a passed time now, and refuses a time more than 7 days after the request with `400` and `scheduled_too_far`.

#### Scenario: A scheduled time rounds up to the next millisecond
- **WHEN** the caller sends an email with scheduled time `2026-11-20T09:00:00.000400Z`
- **THEN** the body has `"scheduled_at": "2026-11-20T09:00:00.001Z"`

#### Scenario: A time with an offset is sent in UTC
- **WHEN** the caller sends an email with scheduled time `2026-11-20T10:00:00+01:00`
- **THEN** the body has `"scheduled_at": "2026-11-20T09:00:00.000Z"`

#### Scenario: A time without an offset sends nothing
- **WHEN** the caller sends an email with scheduled time `2026-11-20T09:00:00`
- **THEN** the SDK reports the error code `invalid_scheduled_at`
- **AND** no request is made

#### Scenario: A date that doesn't exist sends nothing
- **WHEN** the caller sends an email with scheduled time `2026-02-30T09:00:00Z`
- **THEN** the SDK reports the error code `invalid_scheduled_at`
- **AND** no request is made

### Requirement: Scheduling only on PostHog Cloud

Only PostHog Cloud schedules emails. A PostHog that doesn't schedule would send the email at once, and no check of its answer can undo that. So a send with a scheduled time SHALL fail with `scheduling_requires_cloud`, naming the scheduled time field and without sending any request, unless the app host it sends to, after the rules of "App host", is exactly `https://us.posthog.com` or `https://eu.posthog.com`. A reverse proxy or custom domain in front of PostHog Cloud SHALL be refused too. The error's message SHALL name only the host, never a credential in the app host URL. A client with no app host MAY report `missing_app_host` instead.

#### Scenario: A custom app host can't schedule
- **GIVEN** a client whose app host is `https://posthog.example.com`
- **WHEN** the caller sends an email with a scheduled time
- **THEN** the SDK reports the error code `scheduling_requires_cloud`
- **AND** no request is made

#### Scenario: A Cloud ingestion host can schedule
- **GIVEN** a client whose host is `https://eu.i.posthog.com` and that sets no app host
- **WHEN** the caller sends an email with a scheduled time
- **THEN** the request goes to `https://eu.posthog.com/api/messaging/send/email/` with `scheduled_at`

#### Scenario: A send without a scheduled time skips the check
- **GIVEN** a client whose app host is `https://posthog.example.com`
- **WHEN** the caller sends an email without a scheduled time
- **THEN** the request goes to `https://posthog.example.com/api/messaging/send/email/`

### Requirement: Scheduled send confirmation

For a send with a scheduled time, a `2xx` with a message ID SHALL count as a success only when PostHog confirms the time. It confirms it when the response has `"status": "scheduled"` and a `scheduled_at` that is the sent time to the millisecond, compared as an instant and not as text. The result SHALL then carry that time and show that the email is scheduled. It also confirms it with `"status": "queued"` and `"scheduled_at": null` within the grace of "Grace window for a passed time". The result SHALL then carry no scheduled time and show that the email goes out now. A send without a scheduled time SHALL ignore both fields.

#### Scenario: A scheduled answer confirms the time
- **GIVEN** a send with scheduled time `2026-11-20T09:00:00.000Z`
- **WHEN** the response is `202` with `{"message_id": "msg_1", "status": "scheduled", "scheduled_at": "2026-11-20T09:00:00Z"}`
- **THEN** the result has ID `msg_1` and scheduled time `2026-11-20T09:00:00.000Z`

#### Scenario: A scheduled answer with another time is not a confirmation
- **GIVEN** a send with scheduled time `2026-11-20T09:00:00.000Z`
- **WHEN** the response is `202` with `{"message_id": "msg_1", "status": "scheduled", "scheduled_at": "2026-11-20T09:00:00.001Z"}`
- **THEN** the SDK reports the error code `schedule_not_confirmed`

### Requirement: Grace window for a passed time

PostHog answers `"status": "queued"` with `"scheduled_at": null` when the time had passed by its clock, and sends the email now. Because the two clocks can drift apart, the SDK SHALL accept that answer as an immediate send when the scheduled time, rounded up to the millisecond, is at most 60 seconds after the send's first attempt, by the client's clock. The first attempt is the moment the SDK sends the first request of the send to the send route. The SDK SHALL NOT measure the window from when the answer arrives or from a retry. A later time with that answer SHALL fail with `schedule_not_confirmed`.

#### Scenario: A slow answer doesn't stretch the window
- **GIVEN** a send whose scheduled time is 62 seconds after its first attempt
- **WHEN** the response arrives 3 seconds after the first attempt and is `202` with `{"message_id": "msg_1", "status": "queued", "scheduled_at": null}`
- **THEN** the SDK reports the error code `schedule_not_confirmed`
- **AND** never a success

#### Scenario: A retry doesn't shrink the window
- **GIVEN** a send whose scheduled time is 58 seconds after its first attempt
- **WHEN** the first attempt fails with a `503`, and the retry's response arrives 30 seconds after the first attempt and is `202` with `{"message_id": "msg_1", "status": "queued", "scheduled_at": null}`
- **THEN** the result has ID `msg_1` and shows that the email goes out now

#### Scenario: A retry doesn't restart the window
- **GIVEN** a send whose scheduled time is 62 seconds after its first attempt
- **WHEN** the first attempt fails with a `503`, and the retry starts 5 seconds after the first attempt and is answered `202` with `{"message_id": "msg_1", "status": "queued", "scheduled_at": null}`
- **THEN** the SDK reports the error code `schedule_not_confirmed`

### Requirement: Unconfirmed schedule

A `2xx` with a message ID that doesn't confirm the scheduled time SHALL produce the error `schedule_not_confirmed`, and SHALL NOT be retried. That includes a response with no `status` or no `scheduled_at`, as from a PostHog that ignored the time. The error SHALL carry the response's HTTP status, the scheduled time field, and the message ID, because PostHog accepted the email and it may go out at another time. Its fix SHALL say to read the email's status with `get` and that message ID before sending it again, and SHALL NOT advise sending it with another idempotency key. When the SDK generated the send's key, the fix SHALL say not to send the email again, since any new send makes a second email. The SDK SHALL still log the response's warnings.

#### Scenario: An acceptance that ignores the time is not a success
- **GIVEN** a send with a scheduled time
- **WHEN** the response is `202` with `{"message_id": "msg_1"}`
- **THEN** the SDK makes 1 attempt and reports the error code `schedule_not_confirmed` with status 202 and message ID `msg_1`

#### Scenario: An unconfirmed schedule with a generated key says not to send again
- **GIVEN** a send with a scheduled time and no idempotency key from the caller
- **WHEN** the response is `202` with `{"message_id": "0190f6d2-7c1e-7b3a-9f5e-1c2d3e4f5a6b"}`
- **THEN** the fix says to read the status of `0190f6d2-7c1e-7b3a-9f5e-1c2d3e4f5a6b` with `get`
- **AND** the fix says not to send the email again
- **AND** the fix doesn't advise sending it with another idempotency key

### Requirement: Scheduled delivery status

The status read SHALL pass through `scheduled`, the status of an email that waits for its scheduled time. An SDK that models statuses as a closed type SHALL have a member for `scheduled`, and SHALL still pass through statuses it doesn't know.

#### Scenario: A scheduled email reads as scheduled
- **WHEN** the response is `200` with a valid record whose status is `scheduled`
- **THEN** the record has status `scheduled`

### Requirement: Batch request

`batch` SHALL take a template ID, optional shared template data, a list of recipients, and an optional per-call maximum number of retries. Each recipient SHALL take `to`, and optionally a distinct ID, its own template data and an idempotency key. Each attempt SHALL send one request for every recipient, and a call SHALL NOT split its recipients across requests: `POST {app host}/api/messaging/send/email_batch/` with a JSON body holding `template_id` (in lowercase), `message_data` (the shared template data, or an empty object), and `recipients`, each with `to`, `idempotency_key`, and `distinct_id` and `message_data` only when the caller passed them. The request SHALL use the authentication and host rules of a send, SHALL carry `Content-Type: application/json`, `Accept: application/json` and the SDK's user agent, and SHALL carry no `Idempotency-Key` header. Each attempt SHALL wait at least 45 seconds for the answer, or the client's request timeout when that is longer. A batch SHALL NOT take a scheduled time.

#### Scenario: A batch is one request with a key per recipient
- **WHEN** the caller sends a batch with template ID `0190F6D2-7C1E-7B3A-9F5E-1C2D3E4F5A6B`, shared template data `{"plan": "pro"}`, and recipients `ada@example.com` with key `key_ada` and template data `{"name": "Ada"}`, and `bob@example.com` with no key
- **THEN** the SDK makes one request, `POST {app host}/api/messaging/send/email_batch/` with `Content-Type: application/json`, `Accept: application/json` and the SDK's user agent
- **AND** the body is `{"template_id": "0190f6d2-7c1e-7b3a-9f5e-1c2d3e4f5a6b", "message_data": {"plan": "pro"}, "recipients": [{"to": "ada@example.com", "idempotency_key": "key_ada", "message_data": {"name": "Ada"}}, {"to": "bob@example.com", "idempotency_key": "<a UUID v4>"}]}`

### Requirement: Batch argument checks

Before any request, the SDK SHALL check the template ID, shared template data and retry limit as "Argument checks" checks a send, that the batch has 1 to 100 recipients, and each recipient as "Argument checks" checks a send. A recipient without an idempotency key SHALL get a UUID v4. Two recipients with the same key SHALL fail the check with `invalid_idempotency_key`. No recipients SHALL fail with `invalid_recipients`, and more than 100 SHALL fail with `invalid_recipients` and a fix that says to split them into batches of at most 100. A failed check SHALL send no request.

#### Scenario: More than 100 recipients sends nothing
- **WHEN** the caller sends a batch with 101 recipients
- **THEN** the SDK reports the error code `invalid_recipients` with a fix to split the recipients into batches of at most 100
- **AND** no request is made

#### Scenario: Two recipients with one key send nothing
- **WHEN** the caller sends a batch whose two recipients both have the idempotency key `key_1`
- **THEN** the SDK reports the error code `invalid_idempotency_key`
- **AND** no request is made

#### Scenario: A batch without recipients sends nothing
- **WHEN** the caller sends a batch with no recipients
- **THEN** the SDK reports the error code `invalid_recipients`
- **AND** no request is made

#### Scenario: A template ID that is not a UUID sends no batch
- **WHEN** the caller sends a batch with template ID `welcome`
- **THEN** the SDK reports an argument error
- **AND** no request is made

### Requirement: Batch retries

The SDK SHALL retry a batch's request as "Retryable responses" and "Retry timing" retry a send, with the same body, so every recipient keeps its idempotency key on every attempt. Unlike a send, a batch SHALL send no retry once shutdown has started: a batch that waits to retry ends at once. A recipient that was Unconfirmed then stays Unconfirmed, and every other recipient fails with `client_closed`.

#### Scenario: A retry reuses each recipient's key
- **GIVEN** a batch of two recipients without idempotency keys
- **WHEN** the first attempt fails with a `503` and the retry is answered `200` with a result for each
- **THEN** both attempts send the same body, with the same `idempotency_key` for each recipient

#### Scenario: Shutdown keeps the results of an attempt in flight
- **GIVEN** a batch of two recipients whose request PostHog has received but not answered yet
- **WHEN** the caller shuts the client down, and PostHog then answers `200` with both recipients queued
- **THEN** the batch call returns both recipients Queued with their message IDs
- **AND** no recipient fails with `client_closed`

#### Scenario: Shutdown ends a batch's wait to retry at once
- **GIVEN** a batch of two recipients whose first attempt failed with a `503`, and a controlled clock that the test does not advance
- **WHEN** the caller shuts the client down while the batch waits to retry
- **THEN** the batch call ends before the clock advances
- **AND** the SDK sends no retry
- **AND** both recipients are Unconfirmed

#### Scenario: Shutdown after a refused attempt fails every recipient
- **GIVEN** a batch of two recipients whose first attempt was answered `429` with code `throttled`, and a controlled clock that the test does not advance
- **WHEN** the caller shuts the client down while the batch waits to retry
- **THEN** the batch call ends before the clock advances
- **AND** the SDK sends no retry
- **AND** both recipients are Failed with `client_closed`

### Requirement: Batch recipient results

A `200` with one result per recipient, in request order, SHALL settle each recipient as one of three statuses. Each result SHALL carry the recipient's position, `to`, idempotency key, status, the message ID when PostHog named one as a nonempty string, and an error unless the recipient is Queued. A `message_id` of any other type SHALL be left out of the result.

- **Queued**: the result has `"status": "queued"`, a message ID that is a nonempty string, and no error. The result SHALL carry the message ID and `replayed`.
- **Unconfirmed**: the result's error has code `delivery_unavailable` or `idempotency_key_in_flight`, or no code, or the result is neither Queued nor an error. PostHog may still send the email.
- **Failed**: the result's error has any other code, such as `recipient_suppressed`. The error SHALL carry that code, a message from `detail`, and the status from the result's error.

PostHog derives a recipient's message ID from its idempotency key, so the ID on a Failed or Unconfirmed result names whatever email that key sent, if any, which may be an earlier email to another address. Only a Queued result's ID is this recipient's email for sure. With `idempotency_key_reused`, the ID is the email that first used the key, and the recipient's error SHALL say that this ID belongs to the earlier email, not to this recipient's.

When an earlier attempt of the same call got no usable answer, as in "Batch refusal after a lost answer", a result that would be Failed SHALL leave the recipient Unconfirmed instead, under "Unconfirmed recipient wording". Only a Queued result settles such a recipient, except that `idempotency_key_reused` MAY fail it, since sending it again with the same key can't succeed.

A `2xx` without a result for each recipient SHALL produce the error `api_error`, leave every recipient Unconfirmed, and SHALL NOT be retried. The SDK SHALL log the response's warnings.

#### Scenario: Each recipient gets its own outcome
- **GIVEN** a batch of three recipients
- **WHEN** the response is `200` with results `{"message_id": "m0", "status": "queued", "replayed": false}`, `{"message_id": "m1", "error": {"code": "recipient_suppressed", "detail": "Suppressed.", "status": 422, "retryable": false}}` and `{"message_id": "m2", "error": {"code": "delivery_unavailable", "detail": "Not confirmed.", "status": 503, "retryable": true}}`
- **THEN** the first recipient is Queued with message ID `m0`
- **AND** the second is Failed with code `recipient_suppressed` and message ID `m1`
- **AND** the third is Unconfirmed with message ID `m2`

#### Scenario: An answer without a result per recipient leaves them unconfirmed
- **GIVEN** a batch of two recipients
- **WHEN** the response is `200` with `{"results": [{"message_id": "m0", "status": "queued"}]}`
- **THEN** the SDK makes 1 attempt and reports the error code `api_error`
- **AND** both recipients are Unconfirmed

#### Scenario: A key conflict's message ID names the earlier email
- **GIVEN** a batch of one recipient, `bob@example.com` with key `key_1`, after an earlier send to `ada@example.com` with key `key_1`
- **WHEN** the response is `200` with `{"results": [{"message_id": "m_ada", "error": {"code": "idempotency_key_reused", "detail": "This key was already used.", "status": 422, "retryable": false}}]}`
- **THEN** the recipient is Failed with code `idempotency_key_reused`
- **AND** its error says the message ID `m_ada` belongs to the email that first used the key, not to this recipient's

#### Scenario: A queued result without a string message ID is not Queued
- **GIVEN** a batch of one recipient
- **WHEN** the response is `200` with `{"results": [{"message_id": 42, "status": "queued"}]}`
- **THEN** the recipient is Unconfirmed
- **AND** its result has no message ID

### Requirement: Batch refusals

When the batch fails as a whole, the SDK SHALL report the error through "Error channel", and the error SHALL carry every recipient's result once the request was sent. Which recipients fail and which stay Unconfirmed SHALL follow the Batch errors table of this spec. In particular:

- A failure before the request, such as a failed argument check, `missing_secret_key`, `missing_app_host`, `client_disabled` or `client_closed`, SHALL send nothing and fail every recipient.
- A `409` with `batch_unavailable` SHALL fail every recipient: PostHog sent nothing. Its error SHALL say that batch sends aren't available for the project, and its fix SHALL say to send each recipient on its own with `send`. The fix SHOULD say to send each with the same template, `to`, distinct ID and idempotency key, and the recipient's template data merged over the shared data at the top level, which is the email the batch would have sent.
- A `409` with any other code, or with no code, SHALL leave every recipient Unconfirmed, with their keys and the same-key advice of "Unconfirmed recipient wording". Only `batch_unavailable` says that a `409` sent nothing.
- A network error, a timeout or a `5xx`, once the retries are spent, SHALL leave every recipient Unconfirmed.

When the call fails with any recipient Unconfirmed, the error of the call SHALL NOT say that the emails weren't sent or weren't queued, and SHALL NOT advise new idempotency keys, even when the response's `detail`, `why` or `fix` says so. For such text this rule overrides "Error fields": the SDK SHALL leave it out or replace it. It SHALL say that PostHog didn't confirm them, so they may still go out, and its fix SHALL say to send each Unconfirmed recipient again with the same email and idempotency key, within 24 hours of the first request that used it.

#### Scenario: batch_unavailable fails every recipient
- **GIVEN** a batch of two recipients
- **WHEN** the response is `409` with code `batch_unavailable`
- **THEN** the SDK makes 1 attempt and reports the error code `batch_unavailable` with name `application_error`
- **AND** both recipients are Failed
- **AND** the fix says to send each recipient on its own with `send`

#### Scenario: Another 409 leaves every recipient unconfirmed
- **GIVEN** a batch of two recipients and a maximum of 0 retries
- **WHEN** the response is `409` with code `conflict`
- **THEN** the SDK reports the error code `conflict`
- **AND** both recipients are Unconfirmed, each with its idempotency key and advice to send it again with the same key

#### Scenario: A 409 without a code leaves every recipient unconfirmed
- **GIVEN** a batch of two recipients and a maximum of 0 retries
- **WHEN** the response is `409` with a body that isn't JSON
- **THEN** the SDK reports the error code `api_error`
- **AND** both recipients are Unconfirmed

#### Scenario: The error of a call with Unconfirmed recipients never says they weren't sent
- **GIVEN** a batch of two recipients and a maximum of 0 retries
- **WHEN** the response is `409` with `{"detail": "No emails were sent.", "why": "No emails were sent.", "fix": "Send them again with new idempotency keys."}` and no code
- **THEN** both recipients are Unconfirmed
- **AND** the error of the call says PostHog didn't confirm the emails, so they may still go out
- **AND** no field of the error, `why` included, says the emails weren't sent or weren't queued
- **AND** its fix says to send each recipient again with the same email and idempotency key, and never with new keys

#### Scenario: A failed check before the request fails every recipient
- **GIVEN** a client created without a secret key
- **WHEN** the caller sends a batch of two recipients
- **THEN** the SDK reports the error code `missing_secret_key`
- **AND** no request is made
- **AND** no recipient is Queued or Unconfirmed

### Requirement: Batch 404 without a field

PostHog answers an unknown template, batch sends that are off for the project, and a server without the batch route with the same `404`. So a `404` that names no field and whose code is `not_found`, `api_error`, blank or missing SHALL fail every recipient: PostHog sent nothing. The error SHALL keep code `not_found` and status 404. Its message SHALL say that PostHog found no template with this ID, or batch sends aren't available for this project, so it sent no email of this request. Its fix SHALL say to check the template ID and, if it is right, to send each recipient on its own with `send` until batch sends are available. The fix SHOULD say to send each as "Batch refusals" says for `batch_unavailable`. The error SHALL NOT advise updating PostHog or say that batch sends are unavailable on this server, and the SDK SHALL NOT key on PostHog's `detail` text.

#### Scenario: A 404 without a field names both causes
- **GIVEN** a batch of two recipients
- **WHEN** the response is `404` with `{"code": "not_found", "detail": "Not found.", "attr": null}`
- **THEN** the SDK makes 1 attempt and reports the error code `not_found` with status 404
- **AND** both recipients are Failed
- **AND** the message says PostHog found no template with this ID, or batch sends aren't available for this project, so it sent no email of this request
- **AND** the fix says to check the template ID, and otherwise to send each recipient on its own

### Requirement: Batch content too large

A `413` SHALL fail every recipient with PostHog's code, or `content_too_large` when the response has none, and a fix that says to split the recipients into smaller batches: the request is more than PostHog takes at once. A `400` with code `content_too_large` SHALL fail every recipient without that advice: the content or data sent to every recipient is over PostHog's limit for a batch, so splitting doesn't help, and the error SHALL keep PostHog's message and fix.

#### Scenario: A 413 says to split the batch
- **GIVEN** a batch of two recipients
- **WHEN** the response is `413` with code `content_too_large`
- **THEN** the SDK reports the error code `content_too_large` with status 413 and a fix to split the recipients into smaller batches
- **AND** both recipients are Failed

#### Scenario: A 413 without a code still says to split the batch
- **GIVEN** a batch of two recipients
- **WHEN** the response is `413` with a body that isn't JSON
- **THEN** the SDK reports the error code `content_too_large` with a fix to split the recipients into smaller batches

#### Scenario: A 400 content_too_large doesn't say to split the batch
- **GIVEN** a batch of two recipients
- **WHEN** the response is `400` with `{"code": "content_too_large", "detail": "The content or message_data that a batch sends to every recipient can be at most 256 KiB. Send larger emails one at a time."}`
- **THEN** the SDK reports the error code `content_too_large` with status 400 and PostHog's message
- **AND** the error doesn't say to split the recipients
- **AND** both recipients are Failed

### Requirement: Batch refusal after a lost answer

When an earlier attempt of the same call got no usable answer, such as a network error, a timeout, a `5xx`, or a `409` that left recipients Unconfirmed, that attempt may have queued every email. A refusal of a later attempt, such as a `400`, a `404`, a `409` with `batch_unavailable` or a `413` with `content_too_large`, SHALL then leave every recipient Unconfirmed. Its error SHALL NOT say that PostHog sent nothing, and SHALL NOT advise splitting the batch or sending with new keys. Its message SHALL say that some emails may have gone out, and its fix SHALL say to send each recipient again with the same email and idempotency key, within 24 hours of the first request that used it, and to read each recipient's result. After a refusal that says batch sends aren't available, such as `batch_unavailable` or a `404` without a field, the fix SHALL say to send each recipient with `send` as "Batch refusals" says, since another batch would be refused too. After a `404` without a field, the fix SHALL first say to check the template ID, since the template may be gone, as "Batch 404 without a field" says. The error of the call SHALL carry this advice, not only the recipients' results.

#### Scenario: A refused retry after a lost answer never says nothing was sent
- **GIVEN** a batch of two recipients
- **WHEN** the first attempt times out, and the retry is answered `404` with code `not_found`
- **THEN** the SDK reports the error code `not_found`
- **AND** both recipients are Unconfirmed
- **AND** the message says some emails may have gone out, and never that nothing was sent
- **AND** the fix says to check the template ID first
- **AND** the fix says to then send each recipient with `send`, with the same idempotency key, and doesn't say to send the batch again

#### Scenario: batch_unavailable on a retry after a lost answer
- **GIVEN** a batch with shared template data `{"plan": "pro", "user": {"name": "there", "tier": "free"}}` and two recipients, one with template data `{"user": {"name": "Ada"}}`
- **WHEN** the first attempt fails with a `503`, and the retry is answered `409` with code `batch_unavailable`
- **THEN** both recipients are Unconfirmed
- **AND** the error says some emails may have gone out
- **AND** the fix says to send each recipient with `send`, with the same template, `to`, distinct ID and idempotency key, and its template data merged over the shared data at the top level, such as `{"plan": "pro", "user": {"name": "Ada"}}`, where the recipient's `user` replaces the shared one whole
- **AND** the fix doesn't say to send the batch again

### Requirement: Unconfirmed recipient wording

An Unconfirmed recipient's error SHALL say that PostHog didn't confirm the email and that it may still go out, and its fix SHALL say to send that recipient again with the same email and idempotency key, within 24 hours of the first request that used it, so it goes out once. It SHALL NOT say that the email wasn't queued, wasn't sent or failed. When a later answer refuses a recipient that is already Unconfirmed, the SDK SHALL keep the recipient's first cause as its error, and MAY keep the later answer in a separate field. A later `idempotency_key_reused` MAY fail the recipient instead, since sending it again with the same key can't succeed.

#### Scenario: An unconfirmed recipient is never told its email wasn't queued
- **GIVEN** a batch of one recipient
- **WHEN** the first attempt fails on the network, and the retry is answered `200` with `{"results": [{"message_id": "m0", "error": {"code": "recipient_unreachable", "detail": "PostHog can't reach this address, so this email wasn't sent.", "status": 422, "retryable": false}}]}`
- **THEN** the recipient is Unconfirmed
- **AND** its error says PostHog didn't confirm the email and it may still go out
- **AND** its error doesn't say the email wasn't sent
