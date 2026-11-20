## Why

The `evaluate-flags` contract requires concurrent evaluations of the same unknown missing key to coordinate on one in-flight existence probe. It does not limit how long a waiter can wait, or how far the coordination may reach. posthog-elixir implemented it with a cluster-wide lock that was held for the whole `/flags` request and retried forever. After a deploy, a customer's clustered app stopped responding. Every evaluation in the cluster that requested a missing key waited in one queue, one request at a time. The queue also formed whenever the probe returned the key or reported an error, because waiters were released one at a time.

The coordination exists to avoid duplicate requests. It must not become a single point that can stall application traffic, especially when PostHog is slow, which is when local evaluation should insulate callers.

## What Changes

- Scope probe coordination to one SDK instance in one process or node, the same scope as the negative-knowledge store. Forbid locks and waits that span processes or nodes.
- Require one finite wait deadline per evaluation, covering every overlapping key. After it expires, the waiter proceeds with its own fallback and is no longer registered as a waiter.
- Release waiters when the probe owner ends without completing or when the coordination mechanism fails.
- Require waiters of a probe that returned the key or was not clean to begin their own fallbacks concurrently instead of one at a time.
- Permit the duplicate requests these rules can cause, and make a returned key win over a clean omission from an overlapping probe in the same definitions generation.
- Allow SDKs to retain positive knowledge for returned keys and skip coordination for them, so only keys whose existence is unknown are coordinated.
- Limit the no-duplicate rule to waiters that see valid negative knowledge established before they stop waiting.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `evaluate-flags`: Bound and localize missing-key probe coordination.

## Impact

Specification and acceptance-fixture change only. Clean omissions that complete within the wait still share one probe per SDK instance, so the existing bound of one probe per definitions-refresh interval per instance is unchanged in the normal case. Multi-process and multi-node deployments may make one probe per instance, which was already true for SDKs whose negative knowledge is per process. Acceptance fixtures add concurrent-release cases after a returned or errored probe with three identities, and the single-probe fixtures now require the delayed response before the coordination wait expires. Other new scenarios need harness steps for stalled probes, owner exits, and multiple processes. The harness does not bind the concurrent probe fixtures yet. The posthog-elixir change that motivated this is PostHog/posthog-elixir#258.
