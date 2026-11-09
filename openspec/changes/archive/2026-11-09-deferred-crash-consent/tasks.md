## 1. Spec delta

- [x] 1.1 Add the **Deferred crash reports honour consent at crash time** requirement to `opt-in` with three scenarios
- [x] 1.2 Record the narrative notes for `optOut` step 5 and Interactions in `opt-in`, and the pointer sentence for `consent-gating` Interactions
- [x] 1.3 Keep `acceptance/public/opt-in.feature` unchanged: the shared harness has no crash-recorder step, matching the replay restart requirements

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` with openspec 1.6.0 (CI pins 1.4.1)
- [x] 2.2 Sync the delta into `specs/opt-in/spec.md`, apply the narrative notes to `opt-in` and `consent-gating` by hand, and archive the change

## 3. Provenance

Each normative sentence maps to the implementing code and the covering test. The posthog-ios references are at the **unmerged** head of [PR 1040](https://github.com/PostHog/posthog-ios/pull/1040), `fb380fe03eb0420a58e48a29c8e9a62dbe6f6275`; the posthog-android references are at local commit `1f10328b` on branch `fix/native-crash-recorded-while-opted-out`, which has no PR yet and carries uncommitted edits in the integration and the interval store. **Re-point every line below at the merged SHAs before this spec PR leaves draft.**

| Normative sentence | posthog-ios (PR 1040 @ fb380fe) | posthog-android (1f10328b) |
|---|---|---|
| Decide from consent at the time of the failure, not at discovery | marker written at uninstall while opted out: `PostHog/ErrorTracking/PostHogErrorTrackingAutoCaptureIntegration.swift:126-127`; dropped when found: `:269-271`. Test: `PostHogTests/PostHogIntegrationInstallationTest.swift:453` `optOutMarksCrashContextAsOptedOut` | opt-out interval opened on `onOptOut()`: `posthog-android/src/main/java/com/posthog/android/errortracking/PostHogNativeCrashIntegration.kt:183`, closed on install `:116`; record timestamp compared against the intervals `:326-327`. Store: `posthog-android/src/main/java/com/posthog/android/internal/errortracking/NativeCrashOptOutIntervalStore.kt:20,30,47` |
| A failure while opted out is never sent on any later launch | `PostHogErrorTrackingAutoCaptureIntegration.swift:269-271`. Test: `PostHogIntegrationInstallationTest.swift:484` `optInDropsCrashReportRecordedWhileOptedOut` | `PostHogNativeCrashIntegration.kt:326-327`. Tests: `posthog-android/src/test/java/com/posthog/android/errortracking/PostHogNativeCrashConsentTest.kt:188` `a native crash recorded during a launch that started opted out is not sent after optIn`, `:201` `a native crash recorded after a runtime optOut is not sent after optIn` |
| A failure while opted in remains deliverable, and is sent once the user opts in | unmarked report captured on the next install: `PostHogErrorTrackingAutoCaptureIntegration.swift:275-301`. Test: `PostHogIntegrationInstallationTest.swift:503` `optInCapturesCrashReportRecordedWhileOptedIn` | integration not installed while opted out, so no scan and no watermark advance; capture `PostHogNativeCrashIntegration.kt:354`, watermark `:372`. Tests: `PostHogNativeCrashConsentTest.kt:179` `a native crash recorded while opted in is sent`, `:216` `a consented native crash survives a launch that starts opted out`, `:230` `a native crash recorded after optIn is sent` |
| Do not discard or acknowledge a consented report because opt-out happened later | `close()` while opted in leaves the context unmarked: `PostHogErrorTrackingAutoCaptureIntegration.swift:126` (guarded on `config.optOut`). Test: `PostHogIntegrationInstallationTest.swift:472` `closeWhileOptedInKeepsCrashContext` | interval filter only skips records inside an opt-out interval; a consented record is captured and acknowledged normally `PostHogNativeCrashIntegration.kt:326-372`. Test: `PostHogNativeCrashConsentTest.kt:216` |
| MAY mark the recording context at opt-out | `PostHog/ErrorTracking/PostHogExceptionStepsBuffer.swift:123` (`optedOutKey`), `:158-164` (`markOptedOut()`) | not used |
| MAY persist opt-out intervals and filter by failure time | not used | `NativeCrashOptOutIntervalStore.kt:13-92`; wired through `posthog/src/main/java/com/posthog/PostHogOptOutReceiver.kt:12` and `posthog/src/main/java/com/posthog/PostHog.kt:395,489,1431`. Tests: `posthog-android/src/test/java/com/posthog/android/internal/errortracking/NativeCrashOptOutIntervalStoreTest.kt` |
| Opting out stops the crash context carrying identity or properties | `PostHogExceptionStepsBuffer.swift:158-164` clears context and steps; later writes ignored `:141,:150`. Tests: `PostHogIntegrationInstallationTest.swift:453`, `PostHogTests/PostHogExceptionStepsBufferTest.swift:235` `markOptedOutIsTerminal` | holds with no code: the SDK writes nothing of PostHog's into the OS tombstone |
| Reports from SDK versions predating the consent signal are out of scope | stated in PR 1040 body and changeset `.changeset/drop-opted-out-crash-reports.md` | stated in `.changeset/warm-crabs-teach.md`; records older than the first stored interval match nothing |

Not yet covered by any implementation: iOS out-of-memory terminations reported through MetricKit (`PostHogMemoryExceptionReporter`, [#853](https://github.com/PostHog/posthog-ios/pull/853)); a stacked follow-up PR on the same marker design is planned.
