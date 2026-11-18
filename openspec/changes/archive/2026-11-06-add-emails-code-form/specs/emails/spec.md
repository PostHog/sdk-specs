## MODIFIED Requirements

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

### Requirement: Send request

`send` SHALL send `POST {app host}/api/projects/@current/messaging/send/email/` with a flat JSON body whose fields follow the form the caller chose.

The template form SHALL hold `template_id` (the template ID in lowercase), `to`, `message_data` (the template data, or an empty object), and `distinct_id` only when the caller passed a distinct ID.

The code form SHALL hold `template_key`, `subject`, `to`, `capture_engagement`, and `html`, `text` or both. It SHALL hold `from`, `reply_to` and `distinct_id` only when the caller passed them. A reply-to given as one address SHALL be sent as a one-item list, and an empty reply-to list SHALL be left out of the body.

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

### Requirement: Argument checks

Before any request, the SDK SHALL check that `to` is one nonempty string, a distinct ID is a nonempty string, an idempotency key is 1 to 255 visible ASCII characters, and a retry limit is a nonnegative integer.

For the template form it SHALL check that the template ID is a UUID and template data is a mapping. For the code form it SHALL check that the template key is 1 to 400 characters of letters, digits, hyphens and underscores, that a subject is present, that at least one of `html` and `text` is present and each given one is a string, and that a capture-engagement value is a boolean.

A failed check SHALL send no request.

#### Scenario: A template ID that is not a UUID sends nothing
- **WHEN** the caller sends an email with template ID `welcome`
- **THEN** the SDK reports an argument error
- **AND** no request is made

#### Scenario: A code-form send without content sends nothing
- **WHEN** the caller sends an email with template key `password-reset` and a subject, and neither HTML nor text
- **THEN** the SDK reports an argument error
- **AND** no request is made

## ADDED Requirements

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

### Requirement: Migration header

The client SHALL take an optional migrated-from option naming the email provider the caller moved from. When it is set, the SDK SHALL add `X-PostHog-Migrated-From` with that value to every email request, both sends and status reads. When it is not set, the SDK SHALL NOT send the header.

#### Scenario: The migration header rides every email request
- **GIVEN** a client whose migrated-from option is `resend`
- **WHEN** the caller sends an email and then reads its status
- **THEN** both requests carry `X-PostHog-Migrated-From: resend`
