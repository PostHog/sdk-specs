## Why

PostHog now takes a `scheduled_at` on a single send and serves `POST /api/messaging/send/email_batch/`, which sends one email to each of up to 100 recipients. The server SDKs are adding `scheduled_at` and `emails.batch`, and today they agree on the behavior only through each other's pull requests. They already drifted once: one SDK counted the 60-second grace for a time that had passed from when PostHog's answer arrived, while the others counted it from the send's first attempt. This change gives every server SDK one contract to check itself against before release.

## What Changes

- **Scheduled sends.** `send` takes an optional scheduled time. The SDK rounds it up to the next millisecond and sends it as `scheduled_at`. Only PostHog Cloud schedules emails, so any other app host fails with `scheduling_requires_cloud` before any request.
- **Confirming a schedule.** A `202` confirms the schedule only when it answers `status: "scheduled"` with the same time, or `status: "queued"` with `scheduled_at: null` for a time at most 60 seconds after the send's first attempt. Any other acceptance fails with `schedule_not_confirmed` and the email's message ID.
- **Scheduled status.** A status read can return `scheduled` until the email goes out.
- **Batch sends.** A new `batch` operation sends one request per call to at most 100 recipients, each with its own idempotency key that every retry reuses. Each recipient ends `queued`, `failed` or `unconfirmed`.
- **Batch errors.** A new Batch errors table says which answers fail every recipient and which leave them unconfirmed: `409` with `batch_unavailable`, other `409`s, failures before the request, `413` and `400` `content_too_large`, the `404` that names no field, and a refused retry after a lost answer.
- **Unconfirmed wording.** When any recipient is Unconfirmed, neither its result nor the call's error says the emails weren't sent.
- **Error names.** A `409` with `batch_unavailable` is named `application_error`.
- **Public surface.** It now has three operations: `send`, `batch` and `get`.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `emails`: the **Public surface** requirement, and new requirements for scheduled sends and batch sends.

## Impact

- **posthog-node, posthog-python, posthog-go, posthog-php, posthog-ruby, posthog-dotnet, posthog-elixir and posthog-rs**: each has `scheduled_at` and `emails.batch` changes open, and each checks them against this contract before release.
- **Client SDKs**: not applicable.
