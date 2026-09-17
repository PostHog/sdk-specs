# Concurrent invocation fixture v1

Profiles may advertise `invocation.concurrent.v1` to accept
`POST /v2/fixtures/invoke-concurrent`, with generated `ConcurrentInvokeRequest`
and `ConcurrentInvokeResponse` schemas. This optional extension does not change
ordinary `/invoke`: it still rejects another owner of the same fixture.

A group owns the fixture for its entire lifetime. It contains 2–32 ordinary public
invocations with unique session-wide call IDs, existing receivers and references.
Validate the whole group before starting any SDK work. No call may consume another
member's result reference. Other top-level requests (including setup), fixture
controls, context scopes and other groups are prohibited while a group owns the fixture.

Initiate each native operation without waiting for another member to complete.
Do not implement the group as sequential awaited calls or fabricate concurrency
by replaying stored results. Hosts unable to represent native concurrency must
omit the capability. This launch rule is not scheduler quiescence; individual
scenarios need additional native or network observations to establish overlap.

The response contains exactly one ordinary terminal `CallReceipt` per requested
call, in request order. Calls are top-level, without invented parent/callback IDs.
Preserve actual native outcomes and retained objects. The group itself is fixture
coordination, not an SDK operation or outcome. Call observations remain available
and must agree with the response. Results may complete in any order.

Use one bounded monotonic deadline from group admission, independent of SDK timeout
arguments, plus the core's at-most-1000ms transport grace. At expiration, retain
already terminal outcomes, terminate outstanding members, and record `timeout`
receipts for those members. Mark the fixture unusable and invalidate references.
Close cancels outstanding members and awaits their bounded disposal, preserving
completed receipts. A host's cancellation control must similarly terminate the
whole group when cancelling an outstanding member, since the fixture becomes
unusable. No late result may overwrite a terminal receipt. Independent supervision
of blocked SDK execution remains a host requirement.

Duplicate requests are not idempotent and must never replay SDK work. Missing
capability is `blocked_fixture`; missing public operations remain
`unsupported_binding`. A failed group preflight must not invoke its supported
members as a partial batch. The runner must reject missing, duplicate, reordered,
misattributed or contradictory receipts and cannot pass with outstanding calls.
