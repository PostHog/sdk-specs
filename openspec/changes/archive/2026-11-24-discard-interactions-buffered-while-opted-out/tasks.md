## 1. Spec delta

- [x] 1.1 Add "Interaction data buffered before a consent change is never sent" to `consent-gating`, covering the store-time consent read, the discard on a consent change in both directions, deferred reports of an earlier interaction, and a consent-triggered identity change
- [x] 1.2 Add scenarios for an interaction buffered while opted out, a buffer held at opt-out, and a deferred report of a pre-change interaction

## 2. Validation

- [x] 2.1 Review the delta against the shipped posthog-js behavior (PostHog/posthog-js#5833)
- [x] 2.2 Archive the change, syncing the delta into `specs/consent-gating/spec.md`
