## Context

Sources, in priority order:

1. The shipped SDKs: posthog-node `packages/node/src/emails/` (`emails.ts`, `errors.ts`, `types.ts`) in PostHog/posthog-js#5418, and posthog-python `posthog/emails.py` in PostHog/posthog-python#1093.
2. The backend: PostHog/posthog `products/messaging/backend/presentation/views/message_templates.py` (`MessagingSendViewSet`, the send serializers and `TransactionalEmailRejected`) and `transactional_email_status.py` (`MessagingEmailsViewSet`).
3. The shared contract in the PostHog/posthog#120921 comment thread, which named the template form, the idempotency key default, and the per-send retry override.

## Goals / Non-Goals

**Goals:**

- One contract every server SDK implements for sending a transactional email and reading its status.
- A retry policy that reuses one idempotency key across a call's attempts, so PostHog can deduplicate retries, and never retries what waiting can't fix. PostHog's deduplication has a known gap: if an email is queued but its key's completion record is lost, an attempt that arrives after the 60 second pending reservation expires can queue it again.
- Errors that keep PostHog's stable `code`, so a new server code needs no SDK change.

**Non-Goals:**

- Client SDKs. The send and status APIs take a secret key, which must stay on a server.
- The code-content form and `capture_engagement`. The send API does not accept them yet.

## Decisions

- **Error channel follows the language.** posthog-node returns `{ data, error }` and does not reject, which matches its other awaited methods. posthog-python raises `EmailError`. Both are idiomatic, so the spec requires the platform's idiomatic channel and forbids both at once, rather than forcing one shape.
- **Local argument checks follow the language.** posthog-node returns a `validation_error` with an `invalid_*` code, and posthog-python raises `TypeError` or `ValueError`. The spec requires the check to happen before any request and allows either channel.
- **Per-send `max_retries` is canonical.** The shared contract named it. posthog-node has it and posthog-python does not, so posthog-python is the SDK to change.
- **The custom-host refusal is canonical.** Both SDKs refuse to send the secret key to a host that is not PostHog Cloud unless the caller names the app host, because a custom host is often an ingestion proxy.
- **The status record keeps native types.** posthog-python returns datetimes and posthog-node returns ISO 8601 strings. The spec requires the timestamps and allows either representation.

## Conformance at the time of writing

Assessed at posthog-node `eb01f45` (PostHog/posthog-js#5418) and posthog-python `5abcf29` (PostHog/posthog-python#1093).

| Requirement | posthog-node | posthog-python |
| --- | --- | --- |
| Public surface | Pass | Pass |
| Per-send `max_retries` | Pass | Pass, from `5abcf29`. Earlier revisions had no per-send override |
| Shutdown | Pass | Partial: async shutdown waits for email requests in flight. Synchronous shutdown closes the session without waiting for a send or a retry running on another thread |
| All other requirements | Pass | Pass |

## Risks / Trade-offs

- Both SDKs had not published when this was written. The contract describes the merged code in the two PRs, and a change before release means a delta here.
