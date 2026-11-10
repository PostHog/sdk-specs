# Emails Specification

## Purpose

Send one email, such as a password reset, a receipt or, from code, a newsletter in a marketing message category, to one recipient — from a transactional template in PostHog, or from content the caller's code rendered — and read the email's delivery status by its message ID. Every attempt of one call uses the same idempotency key so PostHog can deduplicate retries, and an error keeps PostHog's stable code.

## Applicability

Server SDKs only. Both operations need a secret key (a project secret API key), which must never reach a client. The reference surfaces are `posthog.emails` in posthog-node and `client.emails`, `Emails` and `AsyncEmails` in posthog-python's `posthog.emails`. Other SDKs can use native names, async conventions, and error channels, as the requirements allow.

Not covered: local templates (template data on a code send, the content hash, the upload by key), `cc`, `bcc`, custom headers, tags and attachments, which the send API does not accept yet, and managing message categories and recipients' opt-outs outside a send.

## Public surface

Names below use posthog-node spelling, then posthog-python spelling.

| Operation | Inputs and defaults | Result |
|---|---|---|
| `send`, template form | Required `to`, `templateId` / `template_id`; optional `templateData` / `template_data`, `distinctId` / `distinct_id`, `idempotencyKey` / `idempotency_key` (default: a UUID v4 for the call), `maxRetries` (default: the client's) | Send result: `id`, `replayed`, `warnings` |
| `send`, code form | Required `to`, `templateKey` / `template_key`, `subject`, and `html`, `text` or both; optional `from` / `from_`, `replyTo` / `reply_to`, `captureEngagement` / `capture_engagement` (default: true), `category` (default: none sent), plus the same `distinctId`, `idempotencyKey` and `maxRetries` | Send result: `id`, `replayed`, `warnings` |
| `get` | Message ID from a send result | Status record: `id`, `status`, `createdAt` / `created_at`, `statusAt` / `status_at`, `reason` |

| Client option | posthog-node | posthog-python | Default |
|---|---|---|---|
| Secret key | `secretKey` | `secret_key` | none |
| App host | `appHost` | `app_host` | derived from a PostHog Cloud host |
| Request timeout | `emailRequestTimeoutMs` | `email_request_timeout_seconds` | 15 seconds |
| Maximum retries | `emailRequestMaxRetries` | `email_request_max_retries` | 2 |
| Migrated from | `migratedFrom` | `migrated_from` | none |

## HTTP mapping

| Operation | Request | Success |
|---|---|---|
| `send`, template form | `POST {app host}/api/projects/@current/messaging/send/email/` with `{"template_id", "to", "message_data", "distinct_id"}` | `2xx` with `{"message_id", "replayed", "warnings"}` |
| `send`, code form | the same route, with `{"template_key", "subject", "html" and/or "text", "to", "capture_engagement", "from", "reply_to", "distinct_id", "category"}` | `2xx` with `{"message_id", "replayed", "warnings"}` |
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

A server SDK SHALL expose transactional email on its client as `emails`, with two operations: `send`, which queues one email, and `get`, which reads the status of an email that `send` queued. `send` SHALL take two forms on one call: the template form, which names a transactional template made in PostHog by its ID, and the code form, which carries content the caller's code rendered. An SDK MAY also offer a standalone emails client that does not capture events.

#### Scenario: The client exposes send and get
- **GIVEN** a server SDK client created with a secret key
- **WHEN** the caller reads `emails` on the client
- **THEN** it offers `send` and `get`

#### Scenario: One send takes either form
- **GIVEN** a server SDK client created with a secret key
- **WHEN** the caller reads `send`
- **THEN** it accepts a template ID, and it accepts a template key with a subject and content

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

### Requirement: Migration header

The client SHALL take an optional migrated-from option naming the email provider the caller moved from. When it is set, the SDK SHALL add `X-PostHog-Migrated-From` with that value to every email request, both sends and status reads. When it is not set, the SDK SHALL NOT send the header.

#### Scenario: The migration header rides every email request
- **GIVEN** a client whose migrated-from option is `resend`
- **WHEN** the caller sends an email and then reads its status
- **THEN** both requests carry `X-PostHog-Migrated-From: resend`

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

`send` SHALL send `POST {app host}/api/projects/@current/messaging/send/email/` with a flat JSON body whose fields follow the form the caller chose.

The template form SHALL hold `template_id` (the template ID in lowercase), `to`, `message_data` (the template data, or an empty object), and `distinct_id` only when the caller passed a distinct ID.

The code form SHALL hold `template_key`, `subject`, `to`, `capture_engagement`, and `html`, `text` or both. It SHALL hold `from`, `reply_to`, `distinct_id` and `category` only when the caller passed them. A reply-to given as one address SHALL be sent as a one-item list, and an empty reply-to list SHALL be left out of the body.

#### Scenario: The template and its data reach the send route
- **WHEN** the caller sends to `user@example.com` with template ID `0190F6D2-7C1E-7B3A-9F5E-1C2D3E4F5A6B`, template data `{"name": "Ada"}` and distinct ID `user_123`
- **THEN** the body is `{"template_id": "0190f6d2-7c1e-7b3a-9f5e-1c2d3e4f5a6b", "to": "user@example.com", "message_data": {"name": "Ada"}, "distinct_id": "user_123"}`

#### Scenario: Rendered content reaches the same send route
- **WHEN** the caller sends to `user@example.com` with template key `password-reset`, subject `Reset your password`, HTML `<p>Hi</p>` and distinct ID `user_123`
- **THEN** the body is `{"template_key": "password-reset", "subject": "Reset your password", "html": "<p>Hi</p>", "capture_engagement": true, "to": "user@example.com", "distinct_id": "user_123"}`

#### Scenario: One reply-to address is sent as a list
- **WHEN** the caller sends a code-form email with reply-to `support@example.com`
- **THEN** the body holds `"reply_to": ["support@example.com"]`

#### Scenario: An empty reply-to list is left out
- **WHEN** the caller sends a code-form email with an empty reply-to list
- **THEN** the body has no `reply_to`

### Requirement: Send request headers

A send SHALL carry `Content-Type: application/json`, `Accept: application/json`, the `Idempotency-Key`, and the SDK's user agent. The SDK SHALL NOT take the distinct ID from a request context.

#### Scenario: A send without a distinct ID ignores the request context
- **GIVEN** a request context whose distinct ID is `context_user`
- **WHEN** the caller sends an email without a distinct ID
- **THEN** the body has no `distinct_id`

### Requirement: Send code form

The code form SHALL take a required template key and subject, with `html`, `text` or both, and SHALL take an optional sender address, an optional reply-to of one address or a list of addresses, and an optional capture-engagement flag that defaults to true. The template key names the email so PostHog can group its metrics, logs and status under it; it is not a template stored in PostHog. PostHog sends the content as given and does not store it.

The shared send inputs — the recipient, the distinct ID, the idempotency key and the per-send retry limit — apply to both forms.

One call SHALL carry exactly one form. The SDK SHALL refuse, before any request, a call that names neither form, a call that names both, and a call that sets a field belonging to the other form, such as template data on a code send or a subject on a template send. Capture engagement belongs to the code form only: a template made in PostHog follows the project's engagement setting.

#### Scenario: Capture engagement defaults to true
- **WHEN** the caller sends a code-form email without a capture-engagement value
- **THEN** the body holds `"capture_engagement": true`

#### Scenario: A call that names both forms sends nothing
- **WHEN** the caller sends an email with both a template ID and a template key
- **THEN** the SDK reports an argument error
- **AND** no request is made

#### Scenario: A template send refuses a code-form field
- **WHEN** the caller sends an email with a template ID and a subject
- **THEN** the SDK reports an argument error
- **AND** no request is made

### Requirement: Argument checks

Before any request, the SDK SHALL check that `to` is one nonempty string, a distinct ID is a nonempty string, an idempotency key is 1 to 255 visible ASCII characters, and a retry limit is a nonnegative integer.

For the template form it SHALL check that the template ID is a UUID and template data is a mapping. For the code form it SHALL check that the template key is 1 to 400 characters of letters, digits, hyphens and underscores, that a subject is present, that at least one of `html` and `text` is present and each given one is a string, and that a capture-engagement value is a boolean.

For a message category it SHALL check what the SDK's types cannot enforce: that the category is the built-in transactional value or a category object, that its type is `marketing` or `transactional`, that its key and name are strings, and that a description, when given, is a string. The SDK MAY also refuse an empty or blank key or name, and a field that a category object doesn't have. PostHog owns the key's format and every length, so the SDK SHALL NOT check them.

A failed check SHALL send no request.

#### Scenario: A template ID that is not a UUID sends nothing
- **WHEN** the caller sends an email with template ID `welcome`
- **THEN** the SDK reports an argument error
- **AND** no request is made

#### Scenario: A code-form send without content sends nothing
- **WHEN** the caller sends an email with template key `password-reset` and a subject, and neither HTML nor text
- **THEN** the SDK reports an argument error
- **AND** no request is made

#### Scenario: A message category of an unknown type sends nothing
- **WHEN** the caller sends a code-form email with a category whose type is `promo`
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

An error SHALL carry a `name`, a coarse class for callers that branch on the kind of failure rather than on the exact code. The name SHALL follow the mapping in the Error names table of this spec, which keys on the HTTP status and, for `409`, `422` and `429`, on the code. A local argument error with an `invalid_*` code and no HTTP status SHALL be named `validation_error`.

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

### Requirement: Send message category

The code form SHALL take an optional message category: either the built-in transactional value, which the SDK SHALL expose as a named value in its idiom, such as a constant, an enum variant or a function, or a category object with a required key, a required type of `marketing` or `transactional`, a required name, and an optional description. The message category belongs to the code form only, so the one-form rule of **Send code form** refuses it on a template send, through the SDK's types or before any request. A template made in PostHog sends in its own category.

In the body, `category` SHALL be the string `"transactional"` for the built-in transactional value, or an object with `key`, `type` and `name`, and with `description` unless the caller left it out. An empty description SHALL be sent as `""`. A category or a description counts as left out when the caller didn't pass it, or passed the unset value of an SDK that marks unset options that way, such as null, nil or None. The SDK SHALL NOT send a default category.

PostHog upserts a category object by its key: an unknown key creates the category, a changed name or description updates it, a left-out description keeps the stored one, `""` clears it, and a key that exists with another type is refused. Without a category, or with the built-in transactional value, the email is transactional with no category. A marketing email honors the recipient's opt-outs, and its HTML, or its text when it has no HTML, needs an `{{ unsubscribe_url }}` placeholder.

PostHog can refuse a send in a message category with `category_mismatch`, `too_many_categories`, `unsubscribe_link_required` or `copies_not_allowed` (`400`), or `recipient_opted_out` (`422`). **Error fields**, **Error names** and **Retryable responses** apply to them as to any other code. An SDK that types PostHog's error codes as a closed set, such as an enum or a union, SHALL include these five. `copies_not_allowed` answers a marketing send with copies, which the code form doesn't take yet.

#### Scenario: A marketing category reaches the send route
- **WHEN** the caller sends a code-form email with category key `newsletter`, type `marketing`, name `Newsletter` and description `Monthly product news`
- **THEN** the body holds `"category": {"key": "newsletter", "type": "marketing", "name": "Newsletter", "description": "Monthly product news"}`

#### Scenario: The built-in transactional value is sent as a string
- **WHEN** the caller sends a code-form email with the built-in transactional value
- **THEN** the body holds `"category": "transactional"`

#### Scenario: A left-out description is left out of the body
- **WHEN** the caller sends a code-form email with category key `receipts`, type `transactional`, name `Receipts` and no description
- **THEN** the body holds `"category": {"key": "receipts", "type": "transactional", "name": "Receipts"}`

#### Scenario: An empty description is sent to clear the stored one
- **WHEN** the caller sends a code-form email with category key `newsletter`, type `marketing`, name `Newsletter` and an empty description
- **THEN** the body holds `"category": {"key": "newsletter", "type": "marketing", "name": "Newsletter", "description": ""}`

#### Scenario: No category leaves the field out
- **WHEN** the caller sends a code-form email without a category
- **THEN** the body has no `category`

#### Scenario: An opted-out recipient keeps PostHog's code
- **WHEN** a code-form send in a marketing category fails with a `422` and code `recipient_opted_out`
- **THEN** the SDK makes 1 attempt and reports the error code `recipient_opted_out` with the name `validation_error`
