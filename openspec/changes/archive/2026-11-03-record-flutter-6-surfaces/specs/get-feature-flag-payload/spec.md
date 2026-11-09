## Narrative alignment

When syncing this delta, update the Flutter surface variant: `getFeatureFlagPayload(key)` exists in 5.x and is removed in 6.0 in favour of `getFeatureFlagResult(key, sendFeatureFlagEvent: false)` and its `payload`. No requirement changes.
