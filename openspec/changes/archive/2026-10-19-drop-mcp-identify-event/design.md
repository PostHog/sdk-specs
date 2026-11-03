## Overview

Identity travels on every event, so a separate identity event adds nothing. Remove it from the
contract instead of keeping it optional.

## Key Decisions

- Forbid `$identify` rather than leave it optional. An optional event invites SDKs to diverge, and an
  SDK that sends it on stateless servers emits one per request.
- Keep the `identify` option as is. It still resolves `distinct_id`, `$set`, and `$groups` per request.

## Alternatives Considered

- **Keep `$identify` once per session.** Rejected because stateless servers have no session that
  outlives a request, and nothing reads the event.
- **Send `$identify` with `$anon_distinct_id` to merge the session's anonymous events.** Rejected
  because anonymous MCP events set `$process_person_profile: false` and create no person to merge.

## Open Questions

None.
