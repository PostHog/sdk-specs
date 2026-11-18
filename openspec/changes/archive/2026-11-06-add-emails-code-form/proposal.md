## Why

The `emails` spec says the code-content form and the `capture_engagement` send option are out of
scope because "the send API does not accept them yet". The send API now accepts them, and both
reference SDKs have shipped the form: posthog-node in PostHog/posthog-js#5509 and posthog-python
in PostHog/posthog-python#1171, each merged on 2026-11-05 and each naming
`openspec/specs/emails/spec.md` as its contract. Both PRs reference a draft change
`add-emails-code-form` that was never opened here, so the canonical spec is behind the two SDKs
it describes, and the next SDK to port `emails` has no contract for the second form.

The two implementations already agree on the surface, the wire body and the refusals, so this
change records what they shipped rather than deciding anything new.

## What Changes

- **Public surface**: `send` takes two forms — a transactional template made in PostHog, by its
  ID (unchanged), or content the caller's code rendered, named by a template key.
- **Code form fields**: required `templateKey` / `template_key` and `subject`, with `html`, `text`
  or both; optional `from` / `from_`, `replyTo` / `reply_to`, and `captureEngagement` /
  `capture_engagement` (default true). The shared `to`, `distinctId`, `idempotencyKey` and
  `maxRetries` apply to both forms.
- **One form per call**: a call that sets neither form field, both, or a field belonging to the
  other form is refused before any request.
- **Send request**: the code form posts a flat body with `template_key`, `subject`, `html` and/or
  `text`, `to`, `capture_engagement`, and `from`, `reply_to` and `distinct_id` only when the
  caller passed them. An empty reply-to list is left out; a single string becomes a one-item list.
- **Migration header**: a client-level migrated-from option adds `X-PostHog-Migrated-From` to
  every email request.
- Prose alignment at archive: the Purpose, the "Not covered" line, the public surface table, the
  client option table and the HTTP mapping table.
- `acceptance/public/emails.feature`: one scenario for a code-form send.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `emails`: the **Public surface**, **Send request** and **Argument checks** requirements, plus
  the new **Send code form** and **Migration header** requirements.

## Impact

- **posthog-node** and **posthog-python**: already shipped. No change.
- **Other server SDKs** (go, ruby, rs, elixir, dotnet, php): the code form is additive; the
  template form they shipped is unchanged.
- **Client SDKs**: not applicable — sending needs a secret key.

## Open questions

- Local templates (`template_data` on a code send, the content hash, the upload by key), `cc`,
  `bcc`, `headers`, `tags` and `attachments` are parked in both SDKs and stay out of scope here.
- Both SDKs refuse a mixed call locally but choose their own error channel. This change keeps the
  existing **Argument error channel** requirement rather than pinning one code for every SDK.
