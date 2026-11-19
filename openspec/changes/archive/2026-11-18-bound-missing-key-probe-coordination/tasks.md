## 1. Bound probe coordination

- [x] 1.1 Limit coordination to one SDK instance in one process or node, and forbid waits and locks that span processes or nodes.
- [x] 1.2 Require a finite wait that does not depend on network timeouts, unregistration on expiry, and release when the owner ends or coordination fails.
- [x] 1.3 Require concurrent fallbacks for waiters of a probe that returned the key or was not clean.
- [x] 1.4 Use one wait deadline per evaluation, limit the no-duplicate rule to waiters that see the clean omission in time, and make returned keys win over overlapping clean omissions. Suppress duplicates only while valid negative knowledge is still retained at the waiter's decision, release waiters concurrently after any probe that leaves no negative knowledge, release mixed-scope waiters early on owner exit or coordination failure, and count the refresh bound per instance.
- [x] 1.5 Allow SDKs to retain positive knowledge for returned keys and skip coordination for them, and release waiters of an inconclusive probe concurrently without a shared retry.
- [x] 1.6 Qualify the shared-probe and mixed-scope scenarios, and add scenarios for stalled probes, abandoned probes, concurrent fallbacks after a returned key, and per-instance scope.

## 2. Validation

- [x] 2.1 Validate the change, sync it into the canonical spec, archive it, and run strict validation for all specs.
