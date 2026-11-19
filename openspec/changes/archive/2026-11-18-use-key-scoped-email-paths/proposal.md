## Why

The `emails` spec sends both operations to `/api/projects/@current/messaging/...`. PostHog now serves transactional email on routes that take the project from the project secret API key, with no project in the path (PostHog/posthog#137605). These routes are live in US and EU. The `@current` project alias is being removed, so SDKs that follow the current spec will break when it goes.

Every server SDK with transactional email is switching to the new paths, with no fallback to the old ones. This change makes the spec match them.

## What Changes

- **Send request**: `send` posts to `{app host}/api/messaging/send/email/`.
- **Status read request**: `get` reads `{app host}/api/messaging/emails/{message ID in lowercase}/`.
- **App host**: the scenario expects `https://eu.posthog.com/api/messaging/send/email/`.
- The HTTP mapping table uses the new paths and notes that these routes accept project secret API keys only. This table is outside the requirement delta and is aligned at archive.
- `acceptance/public/emails.feature`: the send and status read scenarios expect the new paths.
- Nothing else changes: the arguments, bodies, headers, results, errors and retry policy stay the same.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `emails`: the **App host**, **Send request** and **Status read request** requirements.

## Impact

- **posthog-node, posthog-python, posthog-go, posthog-php, posthog-ruby, posthog-dotnet, posthog-elixir and posthog-rs**: send email requests to the new paths. Each has a change open that does this.
- **Client SDKs**: not applicable.
