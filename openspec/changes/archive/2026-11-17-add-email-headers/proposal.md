## Why

The send API now takes an optional `headers` object on a code send ([PostHog/posthog#136613](https://github.com/PostHog/posthog/pull/136613)). It accepts only `List-Unsubscribe`, with one https URL, and `List-Unsubscribe-Post`, with `List-Unsubscribe=One-Click`. A caller that sends a mailing from code, such as a subscription report, needs these headers so mail clients can offer one-click unsubscribe. The `emails` spec lists custom headers as not covered, so no SDK has a contract to add them against.

## What Changes

- **Send code form**: takes an optional headers mapping. The SDK checks only that it is a mapping and sends it as given. The server's allowlist decides which names and values it takes, so a new allowed header needs no SDK change. A template send refuses it like the other code-form fields.
- **Send request**: the code-form body holds `headers` only when the caller passed it.
- The "Not covered" line, the public surface table and the HTTP mapping table name `headers`. These are outside the requirement delta and are aligned at archive.
- `acceptance/public/emails.feature`: a scenario that sends both headers and checks the body.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `emails`: the **Send request** and **Send code form** requirements.

## Impact

- **posthog-python**: adds `headers` to the code form of `send`.
- **Other server SDKs**: add it on their own schedule.
- **Client SDKs**: not applicable.
