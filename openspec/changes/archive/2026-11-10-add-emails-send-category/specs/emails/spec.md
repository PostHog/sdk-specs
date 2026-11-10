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

The code form SHALL take a required template key and subject, with `html`, `text` or both, and SHALL take an optional sender address, an optional reply-to of one address or a list of addresses, an optional capture-engagement flag that defaults to true, and an optional message category, as **Send message category** says. The template key names the email so PostHog can group its metrics, logs and status under it; it is not a template stored in PostHog. PostHog sends the content as given and does not store it. A key that matches a template stored in PostHog sends in that template's message category, as **Send message category** says.

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

### Requirement: Argument checks

Before any request, the SDK SHALL check that `to` is one nonempty string, a distinct ID is a nonempty string, an idempotency key is 1 to 255 visible ASCII characters, and a retry limit is a nonnegative integer.

For the template form it SHALL check that the template ID is a UUID and template data is a mapping. For the code form it SHALL check that the template key is 1 to 400 characters of letters, digits, hyphens and underscores, that a subject is present, that at least one of `html` and `text` is present and each given one is a string, and that a capture-engagement value is a boolean.

For a message category it SHALL check what the SDK's types cannot enforce: that the category is the built-in transactional value or a category object, that its type is `marketing` or `transactional`, that its key and name are strings, and that a description, when given, is a string. The SDK MAY also refuse an empty or blank key or name, which is the only length-related check it may make, or a field that a category object doesn't have. PostHog owns the key's format and every other length, so the SDK SHALL NOT check them.

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

The code form SHALL take an optional message category: either the built-in transactional value, which the SDK SHALL expose as a named value in its idiom, such as a constant, an enum variant or a function, or a category object with a required key, a required type of `marketing` or `transactional`, a required name, and an optional description. The message category belongs to the code form only, as **Send code form** says.

In the body, `category` SHALL be the string `"transactional"` for the built-in transactional value, or an object with `key`, `type` and `name`, and with `description` unless the caller left it out. An empty description SHALL be sent as `""`. A category or a description counts as left out when the caller didn't pass it, or passed the unset value of an SDK that marks unset options that way, such as null, nil or None. The SDK SHALL NOT send a default category.

When the template key matches a template stored in PostHog, the email sends in that template's category. PostHog accepts a `category` that is left out or matches it, with the same key and type, or the built-in transactional value for a template without a category; it refuses anything else with `category_mismatch`, and creates or updates no category. Otherwise PostHog upserts a category object by its key: an unknown key creates the category, a changed name or description updates it, a left-out description keeps the stored one, `""` clears it, and a key that exists with another type is refused. Without a category, or with the built-in transactional value, that email is transactional with no category. A marketing email honors the recipient's opt-outs, and its HTML, or its text when it has no HTML, needs an `{{ unsubscribe_url }}` placeholder.

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
