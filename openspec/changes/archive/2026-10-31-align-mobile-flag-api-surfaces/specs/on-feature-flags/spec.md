## Narrative alignment

When syncing this delta, update **Surface variants**, **Behavior** items 4 and 5, **Concurrency & ordering guarantees** and **Lifecycle** in `on-feature-flags` to drop `PostHogConfig.onFeatureFlags` for Android 4.0 and Flutter 6.0, and to record Flutter 6.0's `Posthog().onFeatureFlags(callback)`. Update the Android entry in `get-feature-flag` and the iOS and Flutter entries in `is-feature-enabled`. No requirement changes.
