## Context

posthog-elixir v2.15.0 coordinated missing-key probes with `:global.trans/2`. That call locks across every connected node, retries forever with random sleeps of up to 8 seconds, and was held for the whole `/flags` request. The SDK's negative knowledge is per node and is cleared on every successful definitions refresh. It is never set when the probe returns the key or reports an error. Under deploy traffic, every evaluation in the cluster that requested such a key waited in one queue. A local reproduction with 50 concurrent callers and a 100 ms `/flags` response took 11 to 13 seconds. A two-node cluster made one request at a time across both nodes.

The concern was raised during review of the Elixir implementation. It was kept because the spec required coordination and gave no limit on it.

## Goals / Non-Goals

**Goals:**

- Keep one shared probe for the common case: a cleanly omitted key within one SDK instance.
- Make sure coordination can never hold an evaluation longer than a finite wait, whatever the network does.
- Make sure coordination never adds work that spans processes or nodes.
- Prevent waiters from being serialized after a probe that did not establish negative knowledge.

**Non-Goals:**

- Fix the length of the wait. SDKs choose a value suited to their platform. posthog-elixir uses 2 seconds.
- Require a particular synchronization primitive.
- Change negative-knowledge retention, invalidation, ownership, or the one-request limit.

## Decisions

### Match coordination scope to the negative-knowledge scope

Negative knowledge is held in memory per SDK instance. Coordinating across processes or nodes saves at most one probe per extra instance per refresh interval. It also adds a dependency on distributed locking that can fail or stall in ways the SDK cannot control. Cross-process coordination was rejected because the cost is unbounded and the benefit is small.

### Bound the wait, then let the waiter probe

A waiter that gives up makes its own original-scope request. This can duplicate an in-flight probe, which is the same cost as an SDK without coordination. Waiting longer was rejected because a stalled probe would then stall application traffic. Failing the evaluation was rejected because it would turn a slow optional optimization into an error. The waiter also unregisters, so a stalled probe cannot collect an unbounded number of abandoned waiters.

### Use one deadline per evaluation

An evaluation can find a second key in flight after the first one settles. Giving each key its own wait would let one evaluation wait several times over. One deadline per evaluation keeps the total wait bounded by the same value.

### Let positive evidence win between overlapping probes

The bounded wait allows two probes for the same key in the same definitions generation. If the newer one returns a newly created flag before the older one cleanly omits it, the older omission must not hide the flag until the next refresh. The SDK remembers when each key was returned in the current generation. It ignores an omission from a probe that was already in flight when the key was returned. A probe that starts later can still record an omission, so a deleted flag stops being probed. When the bounded history has evicted entries newer than a probe's start, the SDK can't tell what that probe overlapped, so it doesn't record the probe's omissions.

### Coordinate only keys whose existence is unknown

Every caller needs its own remote result for a key that exists, because values depend on the evaluation context. Coordinating on such a key only makes callers wait for a request whose answer they can't reuse. SDKs may therefore remember keys a current-generation response returned and let later callers request them directly. Positive knowledge follows the same lifetime as negative knowledge. A later clean omission from a request that started after the key was returned clears it, so a deleted flag moves to missing instead of staying present until the next refresh.

A single shared retry after an inconclusive probe was considered and rejected. It only reduces requests while the remote service returns errors, it adds latency to every waiter in that case, and it needs per-group retry bookkeeping across multi-key waits, owner exits, and deadlines. The burst it avoids is bounded by one request per waiting evaluation.

### Release settled waiters together

When a probe returns the key or is not clean, every waiter needs its own request anyway. Releasing them one at a time behind a lock adds one request round trip per waiter and recreates the queue this change removes. Waiters still coordinate on other unsettled keys, so the mixed-scope rule keeps its meaning.

## Risks / Trade-offs

- **More requests when a probe is slow or when an app runs many instances** -> Each extra request is bounded by the wait and by the instance count. Clean omissions still suppress later probes once retained.
- **A short wait reduces sharing** -> The spec leaves the value to the SDK. The bound only has to be finite and independent of network timeouts.

## Validation

- `openspec validate --all --strict --no-interactive`
- posthog-elixir#258 implements this change. It has tests for a stalled probe, owner exit, concurrent fallback after a returned key, and mixed-scope reclaiming, plus a two-node reproduction.
