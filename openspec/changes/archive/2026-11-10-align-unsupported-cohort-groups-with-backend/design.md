## Context

The canonical SDK contract currently treats all unsupported cohort children as composable uncertainty. The Rust feature-flags backend instead propagates a parsing error when a nested group with an unsupported type is reached. The operator's evaluation loop uses `?`, so later siblings are not evaluated after that error.

Evidence: [group parsing](https://github.com/PostHog/posthog/blob/22a27e765f3e6a126a2cae814f0aba5b288424bd/rust/feature-flags/src/cohorts/cohort_models.rs#L265-L309) and [group evaluation](https://github.com/PostHog/posthog/blob/22a27e765f3e6a126a2cae814f0aba5b288424bd/rust/feature-flags/src/cohorts/cohort_operations.rs#L310-L450).

## Goals / Non-Goals

**Goals:** Define backend-compatible traversal for a reached group with an unsupported type, distinguish hard fallback from missing-context uncertainty, and retain both child orders as contract examples.

**Non-Goals:** Change the Rust backend, unknown leaf-type semantics, missing-context composition, release-condition order, public APIs, cohort cycle handling, or harness suite selection.

## Decisions

- Treat a reached unsupported group as a hard local-evaluation boundary. A local SDK cannot claim a match from a later sibling when the backend would stop before that sibling.
- Retain short-circuiting before the invalid group is reached. Do not pre-scan all descendants for unsupported types.
- Keep missing property context composable. Local callers can provide partial context even when the backend has complete stored properties.
- Translate the backend error into the SDK's existing server-fallback signal, not an exception escaping into host application code.
- Apply and archive the delta with OpenSpec. Update the descriptive acceptance matrix without introducing new harness step phrases or executable opt-in tags.

The alternative was to change the Rust backend to continue after an unsupported group. That was rejected for this change because backend parity is the agreed contract.

## Risks / Trade-offs

- Unsupported definitions can require an extra remote request when the invalid group precedes a decisive sibling. The spec now makes that ordering visible instead of claiming order independence for errors.
- The local harness checkout at `15011d6868ee73e11333860b6392d35298b92535` has neither the v2 Gherkin catalogue nor its runner or step registry. Acceptance edits remain descriptive and unselected. Syntax validation is separate from executable harness coverage.
- PostHog/posthog-go#440's sibling-composition commit differs from this correction and must be reverted in a new signed commit. PostHog/posthog-js#5649 already preserves the hard fallback boundary.

## Migration Plan

Publish this spec correction and link it from PostHog/posthog-go#440. Revert Go's sibling-composition follow-up without rewriting history. No normal supported definitions, dependencies, CI selectors, or public signatures change. SDKs must only change code if they currently suppress a reached unsupported-group failure with later siblings.
