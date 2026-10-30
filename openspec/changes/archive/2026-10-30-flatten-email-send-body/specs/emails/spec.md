## MODIFIED Requirements

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
