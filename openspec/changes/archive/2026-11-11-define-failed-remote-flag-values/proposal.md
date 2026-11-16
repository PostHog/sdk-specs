## Why

The backend can return a per-flag `failed: true` record with an `enabled: false` placeholder. The specs describe evaluation failures generally but do not explicitly prevent direct getters and bulk conversions from presenting that placeholder as a successful disable.

## What Changes

This is a canonical specification clarification, not a claim that all SDKs already conform.

- Define a failed remote record as no evaluated value, independently of response-wide `errorsWhileComputingFlags`.
- Return no structured result when direct flag evaluation fails and no successful fallback supplies a value; preserve documented legacy scalar/boolean missing-result mappings.
- Omit failed remote values from bulk getters and automatic capture enrichment without overwriting a successful local decision for the same evaluation context.
- Report `evaluation_failed` when a tracked direct getter has no value because its remote record failed, rather than reporting a missing flag or a successful disable.
- Cover healthy disabled flags, absent/false failure markers, partial responses, local-value preservation, and tracking suppression with normative scenarios.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `get-feature-flag-result`: Distinguish a failed remote detail from a valid disabled result.
- `get-feature-flags`: Filter failed remote values and preserve successful local values during bulk/capture merges.
- `feature-flag-called-tracker`: Identify failed direct getter evaluations with `evaluation_failed` while retaining existing tracking controls.

## Impact

No new public API or SDK implementation is added here. The backend error record and Go's existing remote-only single-flag path supply the reference behavior; PostHog/posthog-go#434 extends it to that SDK's poller and bulk paths. Inspected Node and Python getter/conversion paths still expose failed placeholders and need separate SDK fixes. Source evidence and scope limits are recorded in the design.
