## 1. Verification

- [x] 1.1 Read posthog-ios#1009 and posthog-android#927 — sources, API dumps, changesets and migration guides — for the `$locale` source, the `$app_language` source and its availability, and the `setAppLanguage` surface and lifetime
- [x] 1.2 Check what every other in-scope client SDK sends for `$locale` today (posthog-js browser and react-native, posthog_flutter desktop, posthog-kmp, posthog-unity)
- [x] 1.3 Confirm `openspec/specs/`, `acceptance/` and `compliance/` say nothing about `$locale` or an app language
- [x] 1.4 Check no open sdk-specs PR covers it (#170, #171 are flag/Flutter surface records; #151, #166 are before-send)

## 2. Spec delta

- [x] 2.1 Write the `capture` delta
- [x] 2.2 Review the delta: the requirement has scenarios, and scenarios use WHEN/THEN

## 3. Archive

- [x] 3.1 Sync the delta into `openspec/specs/capture/spec.md` and archive the change
