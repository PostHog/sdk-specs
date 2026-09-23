## Why

The server `identify` contract currently requires a per-call distinct id and its shared negative scenario expects no event when that id is omitted. Server capture already has a request-context / generated-id fallback in the tracing-header contract. Identify needs an explicit, non-throwing identity-resolution rule so an omitted id is not mistaken for a drop.

## What Changes

- **BREAKING (canonical behavior):** Server `identify` resolves an omitted distinct id from the request-scoped analytics context, or generates a fresh UUID if no context id is available, instead of dropping or throwing.
- A generated id is marked personless on the outgoing `$identify` event. Explicit ids continue to win over request context.
- Split the existing shared missing-id scenario by applicability: keep the client scenario and add observable server delivery coverage. Do not change `alias` or the production SDKs in this change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `identify`: Define server missing-id precedence, generated personless event behavior, and no-throw semantics, while preserving client identity semantics.

## Impact

The canonical `openspec/specs/identify/spec.md` and `acceptance/public/identify.feature` change after the OpenSpec delta is applied and archived. The compliance harness needs to honor the canonical `@client` / `@server` applicability tags and bind an observable UUID assertion; the Node adapter must faithfully pass an omitted id. SDKs that currently drop or raise on server `identify` without an id will need separate production corrections; this specification change does not make them conformant.
