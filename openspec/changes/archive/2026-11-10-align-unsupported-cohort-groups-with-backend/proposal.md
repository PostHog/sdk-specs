## Why

The cross-SDK review of [posthog-go#431](https://github.com/PostHog/posthog-go/pull/431) and the follow-up on [posthog-go#440](https://github.com/PostHog/posthog-go/pull/440#discussion_r4526467057) exposed a mismatch between the SDK contract and the Rust feature-flags backend. The current contract allows a later decisive sibling to override an unsupported cohort group, while the backend stops when that group is reached.

## What Changes

- Make backend parity the contract for a reached cohort group with an unsupported type, such as `XOR`: stop local evaluation and require server evaluation without visiting later siblings.
- Preserve definition-order short-circuiting. A decisive earlier sibling can finish the group before the unsupported child is reached.
- Keep three-valued composition for missing property context, valid AND/OR/property groups, empty groups, and negation safety unchanged.
- Clarify the distinction in the canonical spec and the existing descriptive acceptance matrix.
- Archive and sync this correction in the same PR.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `local-feature-flag-evaluator`: distinguish a reached unsupported group from a composable, context-inconclusive child.

## Impact

This is a canonical specification correction, not a change to the Rust SDK. The authority is the [Rust feature-flags backend](https://github.com/PostHog/posthog/blob/22a27e765f3e6a126a2cae814f0aba5b288424bd/rust/feature-flags/src/cohorts/cohort_operations.rs#L310-L450). Normal supported definitions and public APIs are unchanged. Malformed definitions may require a remote request where the previous specification allowed a local answer.

PostHog/posthog-go#440 will revert its sibling-composition follow-up to restore immediate server fallback. PostHog/posthog-js#5649 already uses the hard server-evaluation boundary. No dependency updates, harness changes, or new acceptance-suite opt-in tags are included.
