## Why

A code send (the `template_key` form of `emails.send`) can only send a transactional email with no message category. A team that moves a marketing email from a PostHog workflow to a code send loses the email's category, so the recipient's opt-outs and the unsubscribe headers stop applying.

The send API now takes an optional `category` on a code send: the key of one of the project's message categories, defined in PostHog/posthog#142574 and PostHog/posthog#142564. Each server SDK has an open change that adds it to `emails.send`: posthog-node (PostHog/posthog-js#5638), posthog-python (PostHog/posthog-python#1218), posthog-go (PostHog/posthog-go#435), posthog-ruby (PostHog/posthog-ruby#350), posthog-php (PostHog/posthog-php#309), posthog-dotnet (PostHog/posthog-dotnet#378), posthog-elixir (PostHog/posthog-elixir#244) and posthog-rs (PostHog/posthog-rs#345). The SDKs treat this spec as their shared contract, so it records the field they agree on.

## What Changes

- **New `Send message category`**: the code form takes an optional `category`, the key of one of the project's message categories, such as `newsletter`, as a string.
  - In the body, `category` is the key as given. "Left out" means not passed, or the SDK's own unset value where it marks unset options that way (null, nil, None).
  - The SDK never sends a default. Without a category, the email is transactional with no category, as before.
  - A marketing category skips recipients who opted out of it or of all marketing email, fills `{{ unsubscribe_url }}` with the recipient's preferences link, and adds List-Unsubscribe headers. A transactional category only files the email.
  - The template form doesn't take `category`: a template made in PostHog sends in its own category.
  - PostHog's refusal codes `category_not_found`, `marketing_copies_unsupported` and `sandbox_fields_unsupported` (all `400`) follow the existing error rules: they keep their code, are named `validation_error`, and are not retried. An SDK that types error codes as a closed set includes them.
- **`Send code form`**: lists the message category among the code form's inputs, so the one-form rule refuses it on a template send, through the SDK's types or with an argument error.
- **`Send request`**: the code form holds `category` only when the caller passed one.
- **`Error names`**: the error name is called "a coarse class" instead of "a coarse category", so it can't be confused with a message category.
- Prose alignment at archive: the Purpose, the "Not covered" line, and the code-form rows of the public surface and HTTP mapping tables.
- `acceptance/public/emails.feature`: scenarios for the category key on the wire, and for a refused category send keeping PostHog's code without a retry.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `emails`: the **Send code form**, **Send request** and **Error names** requirements, plus the new **Send message category** requirement.

## Impact

- **Server SDKs** (node, python, go, ruby, php, dotnet, elixir, rs): each adds `category` to the code form in the PR listed above. A send without `category` keeps today's body.
- **Client SDKs**: not applicable. Sending needs a secret key.
- Batch sends refuse `category`, and batch sends are not part of this spec.
- While categories are switched off for a project, PostHog refuses `category` with a `400` field error that has no dedicated code. The contract leaves it out on purpose.
- `cc` and `bcc` stay out of scope. `marketing_copies_unsupported` answers a marketing send with copies, which the code form doesn't take yet.
- Creating, renaming and deleting message categories, and managing recipients' opt-outs, stay out of scope.
