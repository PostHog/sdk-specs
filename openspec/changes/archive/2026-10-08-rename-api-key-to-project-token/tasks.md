## 1. Contract update

- [x] 1.1 Confirm the shipped option name, alias, and deprecation message in posthog-ios, posthog-android, posthog-flutter, posthog-dotnet, and posthog-kmp, and confirm React Native and Unity have not renamed.
- [x] 1.2 Draft the project-token option requirement and its acceptance scenarios.
- [x] 1.3 Sync the requirement and the narrative notes into the canonical `setup` spec.

## 2. Validation and archive

- [x] 2.1 Validate the change and canonical specs strictly; check the diff.
- [x] 2.2 Archive the completed change on this branch.

Validation: reviewed the shipped source for each renamed SDK (`PostHogConfig.swift`, `posthog_config.dart`, `PosthogFlutterPlugin.kt`/`.swift`, `PostHogAndroidConfig.kt`, `PostHogOptions.cs`) and the diff. `openspec validate --specs --strict` passes (64 passed, 0 failed), the same as on `main`. These are specification checks, not executed SDK conformance tests.
