## 1. Verification

- [x] 1.1 Read posthog-flutter's 6.0 changeset and `MIGRATION.md` (PostHog/posthog-flutter#701) and the 6.0 Dart API for every Flutter surface the specs name
- [x] 1.2 Grep `openspec/specs/` for Flutter mentions of removed APIs (`disable()`, `apiKey`, `getFeatureFlagPayload`, `sendFeatureFlagEvents`, config `onFeatureFlags`) and for Flutter 6.0 "unreleased" markers

## 2. Spec delta

- [x] 2.1 Write the narrative deltas and the `get-feature-flag-result` requirement delta
- [x] 2.2 Review the delta: the modified requirement keeps its scenarios, and scenarios use WHEN/THEN

## 3. Archive

- [x] 3.1 Sync the deltas into `openspec/specs/` and archive the change
