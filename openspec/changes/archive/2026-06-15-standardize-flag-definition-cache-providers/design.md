## Overview

This change does not introduce a new capability. It tightens `flag-definition-loader` so an SDK author adding distributed local-evaluation cache support in another language has the same contract as Node.js, Python, Ruby, and JVM/Java documentation describe.

## Key Decisions

- Treat the cache provider as part of the flag definition loader, not as a separate feature flag cache. It stores rule definitions for local evaluation, not per-user evaluated flag values.
- Require four lifecycle operations: retrieve cached definitions, decide whether this instance should fetch, store freshly fetched definitions, and shutdown cleanup.
- Keep the data shape semantic rather than language-specific. SDKs can use `groupTypeMapping`, `group_type_mapping`, typed DTOs, or JSON maps, as long as the data round-trips the same flags, group type mapping, and cohorts used by local evaluation.
- Allow sync-only, async-only, or dual surfaces based on language/runtime idioms. If an SDK accepts async provider results, the loader must wait for them before deciding the refresh outcome and should bound waits to avoid hung pollers.
- Prefer preserving last-known-good in-memory definitions during cache-provider failures. If no definitions are loaded and a provider cannot supply cache data, a direct API fetch is the fail-safe when privileged local-evaluation auth is configured.

## Open Questions

None.
