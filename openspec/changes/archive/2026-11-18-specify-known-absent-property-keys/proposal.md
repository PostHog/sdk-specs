## Why

Caller-supplied property maps cannot say that a property is absent. An omitted key is unavailable context, so `is_not_set` and every negated operator stay inconclusive and fall back to remote evaluation. The local evaluator spec deferred an explicit known-absence input to a separate change. PostHog/posthog issue #88947 and PostHog/posthog#138239 add the matching `/flags` request fields, so the contract can now be specified.

## What Changes

- Define a known-absence input: person property keys, and per group type group property keys, known to be absent for one evaluation.
- Specify the operator results for a known-absent key so local and remote evaluation agree.
- Replace the deferral in the `is_set` and `is_not_set` requirement, and carve known-absent keys out of the existing "missing key remains inconclusive" rules.
- Specify that remote fallback sends `person_property_keys_known_absent` and `group_property_keys_known_absent`, with the server limits.
- Add acceptance scenarios and apply/archive this change on the same branch.

## Capabilities

### Modified Capabilities

- `local-feature-flag-evaluator`: known-absent keys in presence, equality, string-search, multi-contains, operator-inventory, and enrollment requirements, plus a new remote-fallback requirement.

## Impact

SDKs that evaluate flags locally can accept a known-absence input and resolve more flags without a network call. Implementation changes belong in the SDK repositories, not this repository.

## Non-goals

No SDK option names, no SDK implementation, and no change to holdouts or cohort membership behavior. Requests that do not use the new fields behave as before.
