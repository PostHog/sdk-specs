## Why

The spec let an SDK send `$identify` once per session and again when the identity changed. Stateless
servers have no process-wide session, so in practice the SDKs sent it on almost every request and its
volume tracked tool-call volume. The event did nothing: it carries no `$anon_distinct_id`, so ingestion
merges no person from it, and every other MCP event already carries the same `distinct_id`, `$set`, and
`$groups`. The JavaScript and Python SDKs have stopped sending it
([posthog-js#5306](https://github.com/PostHog/posthog-js/pull/5306),
[posthog-python#1067](https://github.com/PostHog/posthog-python/pull/1067)).

## What Changes

- Replace the optional `$identify` with a prohibition: the SDK SHALL NOT send a standalone `$identify`
  event for any MCP revision or session mode.
- Keep the per-event identity unchanged: `distinct_id`, `$set`, and `$groups` on every event of an
  identified request, and `$process_person_profile: false` on every event of an anonymous one.
- Add a scenario that an identified call sends no `$identify`.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `mcp-analytics`: the **Person identity** requirement forbids the standalone `$identify` event.

## Impact

Insights built on `$identify` from MCP servers stop receiving that event. Person properties are
unaffected, because every event still carries `$set` and `$groups`.
