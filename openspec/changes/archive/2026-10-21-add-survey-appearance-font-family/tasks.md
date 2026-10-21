## 1. Spec delta

- [x] 1.1 Add the **Survey appearance font family** requirement to the `surveys` delta
- [x] 1.2 Define the unset cases and the `inherit` sentinel
- [x] 1.3 Define the unresolvable-family fallback and the delegated pass-through

## 2. Acceptance coverage

- [x] 2.1 Reviewed `acceptance/private/surveys.feature`; no steps added, because the shared harness
      observes enqueued events and storage rather than resolved fonts, and no SDK adapter exposes a
      rendered font family today

## 3. Validation

- [x] 3.1 Check the delta against the published behavior of posthog-js, posthog-ios, posthog-android
      and posthog-flutter
- [x] 3.2 Sync the delta into `openspec/specs/surveys/spec.md` and archive the change
