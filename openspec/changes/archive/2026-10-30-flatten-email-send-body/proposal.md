## Why

The `emails` spec pins the `send` request body as `{"template": {"id"}, "to", "message_data", "identifiers": {"distinct_id"}}`. That nesting does not match the names callers use. The SDK arguments are `templateId` / `template_id` and `distinctId` / `distinct_id`, and the HTTP API docs show a flat body with `template_id` and `distinct_id` at the top level. A caller who reads the HTTP docs and then inspects SDK traffic sees two different shapes for one request.

No released caller depended on the nested shape before the docs went out, so this is the point to make the SDK body match the docs. The server keeps accepting the old nested body, so SDK versions that already shipped with it keep working. That compatibility is server behavior, so this change adds no SDK requirement for it.

## What Changes

- **Send request**: the body holds `template_id` (the template ID in lowercase), `to`, `message_data`, and `distinct_id` only when the caller passed a distinct ID. It no longer holds a `template` object or an `identifiers` object. `message_data` is unchanged.
- **Send request headers**: the scenario for a send without a distinct ID now says the body has no `distinct_id`.
- The HTTP mapping table row for `send` shows the flat body. This row is outside the requirement delta and is aligned at archive.
- `acceptance/public/emails.feature`: the send scenario expects the flat body.
- The SDK-facing API does not change: the `send` arguments, the send result, the status read and the errors stay the same.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `emails`: the **Send request** and **Send request headers** requirements.

## Impact

- **posthog-node** and **posthog-python**: build the flat body for `send`. No change to their public API.
- **Other server SDKs**: implement the flat body from the start.
- **Client SDKs**: not applicable.
