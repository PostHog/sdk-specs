## Context

The current contract requires the first fallback for a requested key missing from loaded local definitions but makes clean-omission retention optional. Python, Node.js, Go, and .NET therefore repeat the same existence probe on every call. Android retains the omission for the current definitions generation and coordinates concurrent probes by key.

For a deleted flag or stale application reference, per-call probing scales remote requests with application traffic. A refresh-scoped omission instead scales them with the definitions refresh interval while preserving a bounded opportunity to discover newly created flags.

## Goals / Non-Goals

**Goals:**

- While its knowledge remains retained, bound a cleanly omitted key to one fallback caused solely by that key per definitions-refresh interval.
- Clear omission knowledge after every successful refresh, regardless of whether definitions changed or came from the API or shared cache.
- Prevent failures, quota limits, and computation errors from suppressing a later required probe.
- Coalesce concurrent first probes for the same missing key without serializing unrelated keys.
- Define observable behavior while allowing platform-specific synchronization and cache designs.

**Non-Goals:**

- Require a particular lock, future, task, set, or cache implementation.
- Share identity-specific flag values between callers.
- Change the original requested-key scope, local-wins merge, local-only behavior, or result filtering.
- Require persistent negative knowledge across process restarts.
- Require retention from an SDK that has no successful local-definition refresh lifecycle with which to invalidate it.

## Decisions

### Scope omission knowledge to a definitions generation

An SDK that refreshes local definitions records a requested key only after both the loaded definitions and a clean remote response omit it. The knowledge is scoped to the current definitions generation rather than to one identity because the probe establishes whether the requested key exists, not the value it has for a particular identity.

The state is held in a finite-capacity in-memory store and cleared after every successful definitions refresh. This includes changed definitions, an unchanged or `304` response, and a successful shared-cache load. A failed refresh leaves the current generation and its retained omission knowledge intact. Adding a new key at capacity may evict an older key, which becomes eligible for a fresh probe. Each in-flight probe captures its starting generation and may publish an omission only if that generation is still current when the response completes. This prevents a delayed pre-refresh response from installing stale knowledge after refresh.

Permanent suppression was rejected because it would hide a key created after the omission. Per-call probing was rejected for refresh-capable SDKs because it does not bound recurring traffic.

### Learn only from clean remote responses

A response may establish omission knowledge only when remote evaluation completed successfully, was not quota limited, and reported no flag-computation errors. Transport and API failures have no trustworthy absence information.

A current-generation response that explicitly returns a retained-missing key removes the contradictory omission immediately, including when another unresolved key caused the original-scope fallback. A later call with the same identity and scope remains eligible to probe after an inconclusive response. Implementations with a general evaluated-result cache must bypass or distinguish cached inconclusive entries when that cache would suppress the required retry.

### Coordinate unknown-key existence probes by key

Concurrent evaluations whose only new missing-key work overlaps wait for one in-flight existence probe for that key. After the probe completes, waiters re-evaluate the state. A clean omission suppresses their duplicate probes. If the key is returned, a waiter with any different evaluation-affecting input must perform its own remote evaluation because the first response's value and payload are context-specific. This includes distinct ID, device ID, groups, person and group properties, GeoIP control, request scope, and platform-specific remote inputs. Only a complete cache hit for the same reusable evaluation context may avoid that request.

Coordination is per key. Evaluations with disjoint missing-key sets may probe concurrently, and no global coordination lock may be held across network I/O. A mixed-scope evaluation that overlaps an in-flight key waits for that probe before deciding whether it still needs one fallback using its original scope. If another key still requires fallback after the overlap settles, the original-scope request may include the settled key again, but that key did not cause the request. Launching a subset-scope request for only the new key was rejected because it would violate the original-request-scope contract, while launching the original scope immediately would duplicate an in-flight probe. Global serialization of disjoint key sets was rejected because one slow key would delay unrelated evaluations.

### Keep cache APIs platform-specific

The specification defines request counts and invalidation outcomes, not the public or internal cache shape. For example, .NET can add private missing-key state without changing `IFeatureFlagCache`, while other SDKs can attach the generation state to their definition poller.

## Risks / Trade-offs

- **A newly created flag can remain suppressed until the next successful refresh** -> Clear state on every successful refresh, including unchanged responses and shared-cache loads.
- **Additional concurrent state increases implementation complexity** -> Specify only observable outcomes and let each platform use native synchronization primitives.
- **Capacity eviction can allow another probe before definitions refresh** -> Require finite-capacity storage, define eviction as forgetting rather than absence, and apply suppression guarantees only while an entry remains retained.
- **An SDK without a refresh lifecycle cannot safely invalidate omission knowledge** -> Allow that architecture to continue probing per call rather than retain indefinitely.
