## Why

When local evaluation cannot resolve a flag and no remote value fills the gap, the flag is absent from the `evaluate-flags` snapshot and nothing tells the caller. A flag that exists but was inconclusive looks the same as a flag that does not exist: the key is absent, enablement reads false, and `$feature_flag_called` reports `flag_missing`. That error is wrong for a flag whose definition was loaded.

Remote fallback hides this most of the time. Local-only mode has no fallback, so the flag reads as off for as long as the condition holds. The most common trigger is a flag with experience continuity enabled, which the definitions endpoint returns and the local evaluator declines to evaluate. See PostHog/sdk-specs#84.

## What Changes

- A server SDK MAY expose the unresolved flags of a snapshot: the keys that have a loaded local definition, are in the requested scope, were inconclusive in local evaluation, and have no value in the snapshot. Each entry carries a stable reason.
- The spec defines a closed set of reasons, split by what the caller can do about them: `experience_continuity`, `unsupported_definition`, `missing_context` and `unresolved_dependency`. A new reason lands in the spec before an SDK reports it.
- Any SDK that evaluates locally SHOULD report the `local_evaluation_inconclusive` error, in place of `flag_missing`, when the enablement or value of such a key is read on an original snapshot; an SDK that exposes unresolved flags SHALL. Other errors reported for the same read are unchanged.
- Filtered snapshots do not carry unresolved entries.
- An SDK that evaluates locally SHOULD log one warning per flag when loaded definitions include a flag that local evaluation can never resolve.
- Unresolved flags stay absent from the snapshot. Accessor return values, the key list, capture enrichment and the local-only absence rule are unchanged.
- New scenarios are tagged `@unresolved_flags_capable`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `evaluate-flags`: adds the "Snapshot unresolved flag reporting" requirement and an exception to the `flag_missing` rule in "Lazy feature-flag access tracking".

## Impact

Specs and acceptance documentation. The change is additive and optional, so no SDK becomes non-conformant.
