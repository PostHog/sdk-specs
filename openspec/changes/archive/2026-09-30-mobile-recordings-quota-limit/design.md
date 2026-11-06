## Context

`quotaLimited` has been on the flags response for years, but only `feature_flags` was ever acted on, and no spec described the field. The server change splits replay into two independently metered resources, so the array is now the only signal that tells a mobile SDK to stop. Android had to move the field from its flags-response type to the shared base type to read it from `/config`, which is why the wire-representation half of this change matters as much as the gate.

## Goals / Non-Goals

**Goals:** State that quota limiting participates in the replay enablement gate, name the resources and their independence, and pin the cache-eviction and non-stickiness behavior that make the gate correct across restarts.

**Non-goals:** Browser replay quota handling, feature-flag quota semantics (already covered where flags are specified), ingestion-side `429`/`quota_limited` rate limiting, and billing tier math.

## Decisions

- Put the requirement in `session-replay-ingestion-controls` rather than `remote-config`. The observable contract is "does this session record", which is what the ingestion-controls gate owns; remote-config only gains the field in its wire table.
- Scope the requirement to SDKs that produce mobile-source recordings. The server splits the buckets by `$snapshot_source`, so the resource an SDK honors follows the source it emits, not its platform family.
- Require cache eviction, not just an in-memory stop. Mobile SDKs resolve enablement from the cached recording config on cold start, so leaving the cache in place would re-enable replay on the next launch and defeat the limit.
- Do not make the condition sticky. The server recomputes the array on every config rebuild, so the response is the current state; treating it as latched would keep replay off after the limit is lifted.
- Say nothing normative about browser replay and `recordings`. `posthog-js` does not act on the remote-config array for replay; it honors the ingestion `429`/`quota_limited` path instead. Specifying a second web mechanism here would be a guess.

## Risks / Trade-offs

- Only one SDK ships the behavior today, so the spec leads the other implementations → the backend contract is explicit and the requirement is scoped to the resource the server defines, so later SDKs have an unambiguous target. Flagged as a conformance gap, not a divergence to resolve.
- An SDK that reads `quotaLimited` only from the flags response satisfies the gate on a `/flags`-driven refresh but not on a `/config`-only startup → the wire-representation change states the field is on both responses.

## Migration Plan

Sync and archive on this branch. No SDK must change to keep working: the field is absent on older servers, and an SDK that ignores it behaves as it does today, with capture dropped server side instead.
