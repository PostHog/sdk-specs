## Why

Server SDK local evaluators disagree about whether a property that is present with an explicit null value satisfies `is_set`. This can make local feature flag evaluation disagree with the authoritative PostHog flags-service runtime for the same person or group properties.

## What Changes

- Define `is_set` using property-key presence, including when the present value is null.
- Retain false, zero, empty strings, and empty collections as set values.
- Keep a missing evaluation property inconclusive when the SDK cannot know whether PostHog has a stored value and remote fallback is available.
- Add acceptance coverage for absent, null, false, zero, empty, and non-empty property values.
- Record the current SDK split so follow-up implementation work can target only divergent SDKs.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `local-feature-flag-evaluator`: Define `is_set` as property-key presence and distinguish a present null from unavailable property context.

## Impact

The local feature flag evaluators in Python, the Android server SDK, and .NET currently treat explicit null as not set and will require follow-up changes if this proposal is accepted. Node.js, Ruby, Go, and PHP already use key-presence semantics. The pending Elixir local-evaluation implementation is being aligned with this proposal in PostHog/posthog-elixir#192 before release. Public method signatures and wire formats do not change, but affected SDKs can return a different local flag value for callers that explicitly provide null evaluation properties.
