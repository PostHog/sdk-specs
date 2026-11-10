## Why

A code send (the `template_key` form of `emails.send`) can only send a transactional email with no message category. A team that moves a marketing email from a PostHog workflow to a code send loses the email's category, so the recipient's opt-outs and the unsubscribe headers stop applying.

The send API now takes an optional `category` on a code send, defined in PostHog/posthog#132118. Each server SDK has an open change that adds it to `emails.send`: posthog-node (PostHog/posthog-js#5638), posthog-python (PostHog/posthog-python#1218), posthog-go (PostHog/posthog-go#435), posthog-ruby (PostHog/posthog-ruby#350), posthog-php (PostHog/posthog-php#309), posthog-dotnet (PostHog/posthog-dotnet#378), posthog-elixir (PostHog/posthog-elixir#244) and posthog-rs (PostHog/posthog-rs#345). The SDKs treat this spec as their shared contract, so it records the field they agree on.

## What Changes

- **New `Send message category`**: the code form takes an optional `category`, either the built-in transactional value, which each SDK exposes as a named value in its idiom, or a category object with a required `key`, a required `type` (`marketing` or `transactional`), a required `name` and an optional `description`.
  - In the body, `category` is the string `"transactional"` or the object. A left-out `description` is left out, and an empty one is sent as `""`. "Left out" means not passed, or the SDK's own unset value where it marks unset options that way (null, nil, None); posthog-node uses `undefined` and refuses `null`.
  - The SDK never sends a default. Without a category, the email is transactional with no category, as before.
  - PostHog upserts the category by key: an unknown key creates it, a changed name or description updates it, a left-out description keeps the stored one, `""` clears it, and a type change is refused.
  - When the template key matches a template stored in PostHog, the email sends in that template's category instead: `category` must be left out or match it, PostHog refuses anything else with `category_mismatch`, and nothing is upserted.
  - A marketing email honors the recipient's opt-outs, and its HTML, or its text when it has no HTML, needs an `{{ unsubscribe_url }}` placeholder.
  - The template form doesn't take `category`: a template made in PostHog sends in its own category.
  - PostHog's refusal codes `category_mismatch`, `too_many_categories`, `unsubscribe_link_required`, `copies_not_allowed` (400) and `recipient_opted_out` (422) follow the existing error rules: they keep their code, are named `validation_error` like `recipient_suppressed`, and are not retried. An SDK that types error codes as a closed set includes them.
- **`Send code form`**: lists the message category among the code form's inputs, so the one-form rule refuses it on a template send, through the SDK's types or with an argument error.
- **`Send request`**: the code form holds `category` only when the caller passed one.
- **`Argument checks`**: the SDK checks the category's shape that its types can't enforce, and may also refuse an empty or blank key or name, the one length check it may make, or an unknown field. PostHog owns the key's format and every other length.
- **`Error names`**: the error name is called "a coarse class" instead of "a coarse category", so it can't be confused with a message category.
- Prose alignment at archive: the Purpose, the "Not covered" line, and the code-form rows of the public surface and HTTP mapping tables.
- `acceptance/public/emails.feature`: scenarios for the category on the wire, and for a refused category send keeping PostHog's code without a retry.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `emails`: the **Send code form**, **Send request**, **Argument checks** and **Error names** requirements, plus the new **Send message category** requirement.

## Impact

- **Server SDKs** (node, python, go, ruby, php, dotnet, elixir, rs): each adds `category` to the code form in the PR listed above. A send without `category` keeps today's body.
- **Client SDKs**: not applicable. Sending needs a secret key.
- `categories_not_enabled`, which PostHog returns only while the feature is switched off for a project, is left out of the contract on purpose.
- `cc` and `bcc` stay out of scope. `copies_not_allowed` answers a marketing send with copies, which the code form doesn't take yet.
- Managing message categories and recipients' opt-outs outside a send stays out of scope.
