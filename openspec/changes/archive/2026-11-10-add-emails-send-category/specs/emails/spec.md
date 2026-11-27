## MODIFIED Requirements

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

### Requirement: Send code form

The code form SHALL take a required template key and subject, with `html`, `text` or both, and SHALL take an optional sender address, an optional reply-to of one address or a list of addresses, an optional capture-engagement flag that defaults to true, and an optional message category, as **Send message category** says. The template key names the email so PostHog can group its metrics, logs and status under it; it is not a template stored in PostHog. PostHog sends the content as given and does not store it.

The shared send inputs — the recipient, the distinct ID, the idempotency key and the per-send retry limit — apply to both forms.

One call SHALL carry exactly one form. The SDK SHALL refuse, before any request, a call that names neither form, a call that names both, and a call that sets a field belonging to the other form, such as template data on a code send or a subject on a template send. Capture engagement and the message category belong to the code form only: a template made in PostHog follows the project's engagement setting and sends in its own category. An SDK whose types already keep a field off the template form refuses it through its types.

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

#### Scenario: A template send refuses a message category
- **WHEN** the caller sends an email with a template ID and a message category
- **THEN** the SDK refuses the call, through its types or with an argument error
- **AND** no request is made

### Requirement: Error names

An error SHALL carry a `name`, a coarse class for callers that branch on the kind of failure rather than on the exact code. The name SHALL follow the mapping in the Error names table of this spec, which keys on the HTTP status and, for `409`, `422` and `429`, on the code. A local argument error with an `invalid_*` code and no HTTP status SHALL be named `validation_error`.

#### Scenario: A quota error has the quota name
- **WHEN** the response is `429` with code `quota_limited`
- **THEN** the error name is `monthly_quota_exceeded`

#### Scenario: A reused idempotency key has the idempotency name
- **WHEN** the response is `422` with code `idempotency_key_reused`
- **THEN** the error name is `invalid_idempotent_request`

## ADDED Requirements

### Requirement: Send message category

The code form SHALL take an optional message category: the key of one of the project's message categories, such as `newsletter`, as a string. The message category belongs to the code form only, as **Send code form** says.

In the body, `category` SHALL be the key as the caller gave it. A category counts as left out when the caller didn't pass it, or passed the unset value of an SDK that marks unset options that way, such as null, nil or None. The SDK SHALL NOT send a default category.

PostHog sends the email in the category with that key. A marketing category skips recipients who opted out of it or of all marketing email, fills `{{ unsubscribe_url }}` with the recipient's preferences link, and adds List-Unsubscribe headers. A skipped recipient is not a send error: PostHog accepts the send. A transactional category only files the email. Without a category, the email is transactional with no category, as before. When the project has no verified sending domain, a send in a transactional category goes out from the PostHog test sender with the `sandbox_sender` warning, as a send without a category does, and a send in a marketing category is refused with `sandbox_fields_unsupported`.

PostHog can refuse a send in a message category with `400` and one of these codes: `category_not_found` when the project has no category with that key or it is deleted, `marketing_copies_unsupported` when a marketing email has copies, and `sandbox_fields_unsupported` when a marketing email would go out from the PostHog test sender because the project has no verified sending domain. **Error fields**, **Error names** and **Retryable responses** apply to them as to any other code. An SDK that types PostHog's error codes as a closed set, such as an enum or a union, SHALL include these three. `marketing_copies_unsupported` answers a marketing send with `cc` or `bcc`, which the code form doesn't take yet.

#### Scenario: A category key reaches the send route
- **WHEN** the caller sends a code-form email with category `newsletter`
- **THEN** the body holds `"category": "newsletter"`

#### Scenario: No category leaves the field out
- **WHEN** the caller sends a code-form email without a category
- **THEN** the body has no `category`

#### Scenario: An unknown category keeps PostHog's code
- **WHEN** a code-form send with category `newsletter` fails with a `400` and code `category_not_found`
- **THEN** the SDK makes 1 attempt and reports the error code `category_not_found` with the name `validation_error`
