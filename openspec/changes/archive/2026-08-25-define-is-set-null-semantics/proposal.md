## Why

Server SDK local evaluators disagree about whether a property that is present with an explicit null value satisfies `is_set` and whether an omitted property satisfies `is_not_set`. This can make local feature flag evaluation disagree with the authoritative PostHog flags-service runtime for the same person or group properties.

## What Changes

- Define `is_set` using property-key presence, including when the present value is null.
- Define `is_not_set` using partial-property semantics: a present key definitively does not match, while an omitted key remains inconclusive.
- Retain false, zero, empty strings, and empty collections as present values for both operators.
- Keep a missing evaluation property inconclusive when the SDK cannot know whether PostHog has a stored value and remote fallback is available.
- Add acceptance coverage for absent, null, false, zero, empty, and non-empty property values.
- Record the current SDK split so follow-up implementation work can target only divergent SDKs.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `local-feature-flag-evaluator`: Define `is_set` and `is_not_set` for present values and unavailable partial property context.

## Impact

For `is_set`, Python, the Android server SDK, and .NET currently treat explicit null as not set and require follow-up changes. Node.js, Ruby, Go, PHP, and Rust already use key-presence semantics.

For `is_not_set`, Node.js and Rust currently match when the property is omitted and must instead remain inconclusive for partial SDK property maps. Python, Go, PHP, Ruby, .NET, and the Android server SDK already keep missing context inconclusive but also remain inconclusive when the key is present; they can definitively return a non-match in that case. The pending Elixir local-evaluation implementation in PostHog/posthog-elixir#192 implements both required `is_not_set` outcomes and serves as the reference implementation.

Public method signatures and wire formats do not change. A definitive `is_not_set` match remains unavailable until a future API can represent complete context or explicit known absence.
