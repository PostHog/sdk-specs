## Overview

This change treats `/flags` retry behavior as endpoint-specific transport behavior under `http-client`, not as part of the durable event retry queue. Feature flag evaluation is latency-sensitive and should avoid amplifying API errors, while still smoothing over one transient transport failure such as a timeout or connection reset.

## Key Decisions

- Use `http-client` because it already owns endpoint execution and failure classification for `fetchFlags(context)`.
- Keep `/flags` retry behavior separate from ingestion retry behavior. Ingestion may retry status codes like `408`, `429`, and `5xx`; flag evaluation must not retry HTTP/API responses.
- Default to exactly one retry after the initial attempt. This bounds latency while covering common one-off transport failures.
- Allow `0` retries to disable the behavior and higher values where SDKs expose a configuration option.
- Standardize backoff to start at 300ms, then double: 300ms, 600ms, 1.2s, etc. Implementations may cap the delay to preserve bounded behavior.
- Preserve the same request context/body on retry so a retry is the same evaluation request, not a new evaluation for a changed identity.

## Open Questions

None.
