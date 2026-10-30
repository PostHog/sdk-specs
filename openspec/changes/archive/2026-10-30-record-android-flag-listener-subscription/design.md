## Context

Sources:

1. posthog-android 4.0: [posthog-android#878](https://github.com/PostHog/posthog-android/pull/878),
   merged into the 4.0 integration line (`chore/v4-remove-deprecated`). It adds
   `posthog/src/main/java/com/posthog/PostHogFeatureFlagsSubscription.kt` and the
   `onFeatureFlags(PostHogFeatureFlagsCallback): PostHogFeatureFlagsSubscription` entries in
   `posthog/api/posthog.api` on both `PostHog` and `PostHogInterface`.
2. The existing spec text for posthog-js (`onFeatureFlags(callback): () => void`) and posthog-ios
   4.0 (`onFeatureFlags(callback) -> Subscription` with `unsubscribe()`), which Android cites as
   the surfaces it converges on.

## Decisions

- **Record the surface, not a new generic contract.** The spec already carries scenarios for a
  listener registered after flags are ready and for unsubscribing. Android now satisfies both, so
  the change is to the narrative that said it did not, rather than to the requirement.
- **Scope the new requirement to SDKs that offer a runtime registration.** A config field set
  before `setup()` has no independent lifetime, so the `close()`/`setup()` and in-flight-load rules
  only mean something for a registration handle. Flutter and Unity are not in scope.
- **The in-flight-load rule is a correctness rule, not a preference.** A load started for the
  previous identity that completes after `reset()` carries that identity's flags. Delivering it to
  a listener would hand the app the previous user's values after the SDK's own getters have already
  stopped returning them. Android drops such a load by bumping a generation on `reset()` and
  `close()`; the requirement states the observable outcome and leaves the mechanism to the SDK.

## Conformance at the time of writing

| Requirement | posthog-android 4.0 | posthog-ios 4.0 | posthog-js |
| --- | --- | --- | --- |
| Method-style registration returning a handle | Pass | Pass | Pass (an unsubscribe function) |
| Replay to a late-registered listener | Pass | Pass | Pass |
| Registration survives `close()` / `setup()` | Pass | Not assessed | Not assessed |
| In-flight load across `reset()` / `close()` not delivered | Pass | Not assessed | Not assessed |

The two unassessed rows were derived from posthog-android#878 alone and were not checked against
posthog-ios or posthog-js source. They are stated as the canonical behavior because the alternative
(delivering the previous identity's flags) is a defect on any platform, but they are the part of
this change most worth a reviewer's attention.
