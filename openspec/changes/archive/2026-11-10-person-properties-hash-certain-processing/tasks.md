## 1. Spec delta

- [x] 1.1 Add **The person-properties hash only tracks updates that surely process the person** to `set-person-properties` with three scenarios
- [x] 1.2 Point `set-person-properties` Behavior step 5 and the `identify` hash notes at the requirement
- [x] 1.3 Keep registered person-processing settings off identity events in `capture` **Caller-supplied event properties take precedence**, with one scenario mirrored in `acceptance/public/capture.feature` and a note in Behavior step 4
- [x] 1.4 Keep `acceptance/public/set-person-properties.feature` unchanged: the harness has no step for capture options on `set person properties`

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict`
- [x] 2.2 Sync the deltas into `specs/set-person-properties/spec.md` and `specs/capture/spec.md`, apply the narrative notes by hand, and archive the change

## 3. Provenance

posthog-ios references are at `0a5e7655228988894b522d1dc448cafaa595ffcc` (the merge of [#1050](https://github.com/PostHog/posthog-ios/pull/1050) into `chore/v4-remove-deprecated`). posthog-android references are at `358f9fe6245bffc09c226875098b02a04c74673e` ([#965](https://github.com/PostHog/posthog-android/pull/965), per-call values, on the 4.0 branch) and `6540a3f02e3d4bedfd8f6617f4a76f01759df7a7` ([#967](https://github.com/PostHog/posthog-android/pull/967), reads the event after `beforeSend` and records the hash once it is queued, on `main`). Registered settings off identity events: posthog-ios `c10b7b91b77b37d21e66965076f2e73a15dba476` ([#1067](https://github.com/PostHog/posthog-ios/pull/1067)), posthog-android [#979](https://github.com/PostHog/posthog-android/pull/979) (4.0 branch), posthog-flutter `0f8c376fde6f552e49d9347c35cbc44975d26b05` ([#730](https://github.com/PostHog/posthog-flutter/pull/730), desktop core).

| Normative sentence | posthog-ios (0a5e765) | posthog-android (#965, #967) |
|---|---|---|
| Read the setting as sent: a non-null option, else the legacy property | `PostHog/PostHogSDK.swift:693` `surelyProcessesPersonProfile` | `posthog/src/main/java/com/posthog/PostHog.kt` `surelyProcessesPersonProfile`; after `beforeSend`: #967 `updatePersonPropertiesHashForQueuedEvent` |
| Only a missing setting or a Boolean `true` checks and records the hash | `PostHogSDK.swift:2763-2776` | `PostHog.kt` `shouldCapturePersonPropertiesUpdate` and the `identify` transition; recorded once queued: #967 `updatePersonPropertiesHashForQueuedEvent`. Tests (#967): `setPersonProperties resends an update that beforeSend dropped`, `… that beforeSend made personless` |
| Any other value is sent and clears the stored hash | `PostHogSDK.swift:2757-2776` (`setPersonPropertiesHash(nil)`). Test: `PostHogTests/PostHogCaptureV1Test.swift:758` `personlessSetDoesNotDeduplicate` | Tests: `posthog/src/test/java/com/posthog/PostHogCaptureOptionsTest.kt` `a personless set neither stores nor matches the person properties hash`, `a set that may be personless neither matches nor keeps the person properties hash` |
| A registered `$process_person_profile` or `process_person_profile` option isn't sent with identity events | `PostHog/PostHogSDK.swift` `identityEvents`, `optionsForEvent`, `register` | #979 `IDENTITY_EVENTS`, `optionsForEvent(..., isIdentityEvent)`. Test: `a registered personless setting doesn't reach identity events` |
