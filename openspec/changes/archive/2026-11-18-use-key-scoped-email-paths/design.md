## Context

The new routes resolve the project from the project secret API key in the `Authorization` header, so the path holds no project. The SDK already sends that key on every email request, so only the path changes.

## Goals / Non-Goals

**Goals:**

- Point `send` and `get` at the key-scoped paths.

**Non-Goals:**

- Attachment uploads and email preferences. PostHog serves them on `/api/messaging/attachments/uploads/` and `/api/messaging/preferences/`, but this spec does not cover them yet.
- Other capabilities that name `@current` routes.

## Decisions

- **No fallback to the old paths.** An SDK sends each request to the new path only. Retrying on the `@current` path after a `404` would hide a misconfigured key and stop working when the alias is removed.
- **Personal API keys are not supported.** The new routes accept project secret API keys only, which the spec already requires.

## Risks / Trade-offs

- An SDK version built on the old spec keeps calling `@current` and breaks when the alias is removed. Callers need to upgrade before then.
