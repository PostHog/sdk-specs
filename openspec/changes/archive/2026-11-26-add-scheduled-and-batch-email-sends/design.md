## Context

The PostHog server is the source of truth for every answer below. A single send that carries `scheduled_at` answers `202` with `status` (`scheduled` or `queued`) and `scheduled_at` (the time it waits for, or null when the time had passed). A send without `scheduled_at` gets neither field, and neither does a send to a PostHog from before scheduling, which ignores the time. A batch answers `200` with one result per recipient, in request order, or refuses the whole request.

The reference implementations are posthog-rs and posthog-node. Where they differ, this design names the winner.

## Goals / Non-Goals

**Goals:**

- One rule for when a `202` confirms a schedule, including what the 60-second grace counts from.
- One rule for each batch answer: which recipients fail, which stay unconfirmed, and what the error tells the caller.

**Non-Goals:**

- Cancelling, moving or listing scheduled emails. PostHog doesn't offer them.
- Scheduling a batch. PostHog refuses `scheduled_at` on a batch.
- The code-content form (`template_key` with `subject` and a body), for a single send or a batch, as before.
- Reading a recipient's status by its idempotency key. The SDKs read status by message ID only.

## Decisions

- **The grace counts from the send's first attempt.** PostHog answers `queued` with `scheduled_at: null` when the time had already passed by its clock. The SDK accepts that answer as an immediate send only when the time is at most 60 seconds after the first attempt of the send request, by the client's clock. Counting from when the answer arrives would let retries and a slow answer stretch the window, so the same answer would succeed in one SDK and fail in another. Rejected: counting from the answer, or from the latest retry. (Michael's decision, aligned across all SDKs.)
- **The Cloud check is local and comes first.** A PostHog from before scheduling ignores `scheduled_at` and sends the email at once, and no check of its answer can undo that. So the SDK refuses a scheduled send to any app host other than `https://us.posthog.com` or `https://eu.posthog.com` before any request. A reverse proxy or custom domain in front of PostHog Cloud is refused too.
- **A time must match to the millisecond.** PostHog keeps the time to the millisecond and rounds a finer one up. The SDK rounds up the same way, so a scheduled email never goes out early, and compares PostHog's time as an instant, not as a string.
- **Only `batch_unavailable` says a `409` sent nothing.** Any other `409`, coded or not, may hide a key still in flight, such as one from a proxy, so its recipients stay unconfirmed.
- **Unconfirmed is sticky.** Once an attempt of a batch got no usable answer, a later refusal of a retry doesn't prove that nothing was sent. The recipients stay unconfirmed, and the error says some emails may have gone out and to resend each recipient with the same key. Rejected: trusting the retry's refusal, which tells the caller to resend with new keys and sends the email twice.
- **The call's error follows its Unconfirmed recipients.** When any recipient is Unconfirmed, as after a first-attempt `409` with no code, the error of the call says PostHog didn't confirm the emails, with same-key advice, never that they weren't sent. A caller who reads only the top-level error would otherwise resend with new keys. (Found by the posthog-dotnet lane.)
- **A `404` that names no field is one case.** PostHog answers an unknown template, batch sends that are off for the project, and a server without the batch route with the same `404`. The SDK can't tell them apart, so its message names the two likely causes and never advises updating PostHog. Its text does not key on PostHog's `detail`.
- **A fallback send is the email the batch would have sent.** PostHog deduplicates a key across batch and single sends, and compares the whole email. So the advice to send a recipient on its own names the same template, `to`, distinct ID and key, with the recipient's data merged over the shared data at the top level. A resend of an Unconfirmed recipient sends that same email with the same key, by `batch` or by `send`, and by `send` once PostHog said batch sends aren't available.
- **Shutdown ends a batch's wait.** A send waiting to retry still retries during shutdown. A batch doesn't: it ends at once, and its Unconfirmed recipients stay Unconfirmed. An attempt already in flight still settles.
- **`413` and `400` `content_too_large` differ.** A `413` means the request is more than PostHog takes at once, so smaller batches help. A `400` means the content or data sent to every recipient is over PostHog's batch limit, so splitting doesn't help.
- **The error names follow the existing table.** `batch_unavailable` with `409` is named `application_error`, as both reference SDKs do. `scheduling_requires_cloud` is a local error whose code doesn't start with `invalid_`, so it is named `application_error` by the existing table.

## Disagreements found while writing this spec

Checked against posthog-rs#398 at 26a8938, posthog-js#5847 at e73e4ed and posthog-python#1240 at acb6c2f. Each is for the SDK's own pull request. This change edits no SDK.

- posthog-node treats a recipient result whose error has no code as failed unless its status is `409`. **Batch recipient results** leaves it unconfirmed, as posthog-rs does.
- posthog-node keeps a `413` without a code as `api_error` with no split advice. **Batch content too large** names it `content_too_large` with split advice, as posthog-rs does.
- posthog-node fails a recipient whose result is `idempotency_key_reused` after a lost answer, and posthog-rs keeps it unconfirmed. Both are allowed: a retry with the same key can't send it.
- posthog-rs names `scheduling_requires_cloud` `validation_error`. The Error names table names it `application_error`, as posthog-node does.
- posthog-rs checks for a missing app host before the Cloud check, and posthog-node checks the other way round. Both send nothing, and both orders are allowed.

posthog-python counted the grace from when the answer arrived, as reported on posthog-rs#398. It now counts it from the first attempt, as this spec does.

## Risks / Trade-offs

- A client clock that runs more than a minute slow can turn an email that went out on time into `schedule_not_confirmed`. The error carries the message ID, so the caller can read what happened instead of sending again.
- An unconfirmed recipient stays unconfirmed: the SDK never reads by key. The caller resends with the same key, and PostHog queues it at most once within 24 hours of the key's first request.
