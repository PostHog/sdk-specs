## Why

Transactional email ships in posthog-node (`posthog.emails`) and posthog-python (`client.emails`, `Emails`, `AsyncEmails`). The two SDKs share a contract that so far lives only in a comment on PostHog/posthog#120921. They agree on the request, the retry policy and the error codes, but they differ in how they report an error, in local argument checks, and in per-send retry overrides. Other server SDKs have no contract to implement against except these two implementations, and the weekly compliance audit does not track email at all.

This change records one contract for sending a transactional email from a template and reading its status, before more SDKs add it.

## What Changes

- New capability spec `emails` for server SDKs, covering: the public surface (`send` and `get`), authentication with a secret key, the app host and the refusal to send the key to a custom host, the send request, the idempotency key, the retry policy, the send result and its warnings, structured errors with PostHog's code and a category name, the status read, disabled and shut-down clients, and shutdown draining.
- New acceptance feature `acceptance/public/emails.feature`.
- Not in scope: the code-content form (subject and body in the call), the `capture_engagement` send option, and client SDKs. The send API does not accept the first two yet, and a secret key must never reach a client.

## Capabilities

### New Capabilities

- `emails`: server-side transactional email. Sends one email from a transactional template to one recipient, with a stable idempotency key across retries, and reads the email's delivery status by its message ID.

### Modified Capabilities

None.
