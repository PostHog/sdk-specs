## 1. Verification

- [x] 1.1 Read posthog-android#878's API dump and sources for the registration surface, the subscription handle, replay, and the `reset()`/`close()` generation
- [x] 1.2 Check the change against the spec's existing surface variants, Behavior items 4 and 5, and the registered-after-ready and unsubscribe scenarios
- [x] 1.3 Check that no open sdk-specs PR already records it (#158 covers the flags-loaded result and explicitly leaves item 5 alone)

## 2. Spec delta

- [x] 2.1 Write the `on-feature-flags` delta
- [x] 2.2 Review the delta: every requirement has at least one scenario, and scenarios use WHEN/THEN

## 3. Archive

- [x] 3.1 Sync the delta into `openspec/specs/on-feature-flags/spec.md` and archive the change
