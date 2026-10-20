## Context

The standard posthog-js `captureException` path emits exception type and message inside `$exception_list[0].type` and `$exception_list[0].value`. The current capture-exception acceptance scenario instead requires legacy flat `$exception_type` and `$exception_message` event properties. That mismatch makes SDKs that follow the structured exception envelope appear non-compliant and encourages adding duplicate deprecated fields.

## Goals / Non-Goals

**Goals:**

- Make `$exception_list` the canonical producer source for exception type and message.
- Keep compatibility for SDKs or integrations that still emit flat fields.
- Avoid requiring SDK implementation changes solely to add deprecated summary properties.

**Non-Goals:**

- Require SDKs to remove existing `$exception_type` / `$exception_message` fields.
- Change Cymbal's derived `$exception_types` / `$exception_values` behavior.
- Re-audit every SDK's broader exception-event-metadata compliance.

## Decisions

- Assert primary type/message via `$exception_list` in acceptance tests. This matches the canonical structured envelope and the standard posthog-js capture path.
- Treat `$exception_type` / `$exception_message` as legacy compatibility metadata. Existing emitters can keep them, but conformance does not require adding them to SDKs that only emit `$exception_list`.
- Document the ownership rule in `exception-event-metadata` so future compliance work does not confuse legacy compatibility fields with producer-owned canonical data.

## Risks / Trade-offs

- Some downstream consumers may still read flat fields. The change allows SDKs to keep emitting them for compatibility, so those consumers are not broken by the spec update.
- Compliance notes generated before this change may mention flat-field gaps. Those notes need to be refreshed where they drive remediation work, but the canonical spec should no longer create new remediation requests for the deprecated fields.
