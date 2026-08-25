## Why

Server SDK local evaluators disagree about whether a property that is present with an explicit null value satisfies `is_set`. This can make local feature flag evaluation disagree with PostHog's query behavior and with remote evaluation for the same person or group.

## What Changes

- Define `is_set` as true only when the evaluation property is present with a non-null value.
- Define a present null value as not set, while retaining false, zero, empty strings, and empty collections as set values.
- Keep a missing evaluation property inconclusive when the SDK cannot know whether PostHog has a stored value and remote fallback is available.
- Add acceptance coverage for absent, null, false, zero, empty, and non-empty property values.
- Record the current SDK split so follow-up implementation work can target only divergent SDKs.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `local-feature-flag-evaluator`: Define null handling for `is_set` and distinguish null from other falsey values and from unavailable property context.

## Impact

The local feature flag evaluators in Node.js, Ruby, Go, PHP, and Elixir currently use key-presence semantics and will require follow-up changes if this proposal is accepted. Python, the Android server SDK, and .NET already treat explicit null as not set. Public method signatures and wire formats do not change, but affected SDKs can return a different local flag value for callers that explicitly provide null evaluation properties.
