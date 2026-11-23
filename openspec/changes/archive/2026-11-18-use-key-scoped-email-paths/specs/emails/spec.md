## MODIFIED Requirements

### Requirement: App host

The SDK SHALL send email requests to the PostHog app host, not the ingestion host. A caller-set app host SHALL win, except that a PostHog Cloud host maps to its region's app host. Without one, `us.i.posthog.com`, `us.posthog.com` and `app.posthog.com` SHALL map to `https://us.posthog.com`, and `eu.i.posthog.com` and `eu.posthog.com` SHALL map to `https://eu.posthog.com`.

#### Scenario: An ingestion host maps to its region's app host
- **GIVEN** a client whose host is `https://eu.i.posthog.com` and that sets no app host
- **WHEN** the caller sends an email
- **THEN** the request goes to `https://eu.posthog.com/api/messaging/send/email/`

### Requirement: Send request

`send` SHALL send `POST {app host}/api/messaging/send/email/` with a JSON body holding `template_id` (the template ID in lowercase), `to`, `message_data` (the template data, or an empty object), and `distinct_id` only when the caller passed a distinct ID. The path SHALL NOT name a project; PostHog takes the project from the secret key.

#### Scenario: The template and its data reach the send route
- **WHEN** the caller sends to `user@example.com` with template ID `0190F6D2-7C1E-7B3A-9F5E-1C2D3E4F5A6B`, template data `{"name": "Ada"}` and distinct ID `user_123`
- **THEN** the request is `POST {app host}/api/messaging/send/email/`
- **AND** the body is `{"template_id": "0190f6d2-7c1e-7b3a-9f5e-1c2d3e4f5a6b", "to": "user@example.com", "message_data": {"name": "Ada"}, "distinct_id": "user_123"}`

### Requirement: Status read request

`get` SHALL check that the message ID is a UUID before any request, then send `GET {app host}/api/messaging/emails/{message ID in lowercase}/`. It SHALL use the authentication, host rules and retry policy of a send, with no body and no idempotency key.

#### Scenario: The status read uses the key-scoped path
- **WHEN** the caller reads the status of message `01A18356-C56C-0001-E494-7666BC915188`
- **THEN** the request is `GET {app host}/api/messaging/emails/01a18356-c56c-0001-e494-7666bc915188/`

#### Scenario: An unknown message ID is not retried
- **WHEN** the response is `404` with code `not_found`
- **THEN** the SDK makes 1 attempt and reports the error code `not_found`
