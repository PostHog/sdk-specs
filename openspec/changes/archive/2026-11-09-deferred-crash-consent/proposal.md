## Why

A fatal crash that happens while the user is opted out is still sent as `$exception` after the next `optIn()` ([posthog-ios#1039](https://github.com/PostHog/posthog-ios/issues/1039)). The crash is recorded by a platform mechanism the SDK cannot turn off once it is installed: PLCrashReporter's Mach and signal handlers on iOS, the OS tombstone read back through `ApplicationExitInfo` on Android, and MetricKit diagnostics for out-of-memory terminations on iOS. `optOut()` uninstalls the error tracking integration, but the recorder keeps writing to disk, and the launch that next installs the integration reconstructs whatever it finds and sends it. The report carries the last opted-in crash context, so it looks exactly like a consented crash.

The bug reproduces on both platforms: posthog-ios through the tests in [PR 1040](https://github.com/PostHog/posthog-ios/pull/1040), and posthog-android through a Robolectric test that drives the real client. [posthog-ios#963](https://github.com/PostHog/posthog-ios/pull/963) closed one route into it (the integration installing itself while opted out) but left a plain `optOut()` after a normal install as it was.

No spec records the rule. `consent-gating` says exception capture is "often separately gated to avoid collecting crash data while opted out", and its scenarios are in-process capture calls. `opt-in` has no requirement about crashes. `exception-event-metadata` and `exception-steps` already describe deferred crash reconstruction on the next launch, with no consent rule. The settled behaviour for queued events ([posthog-ios#1003](https://github.com/PostHog/posthog-ios/issues/1003), [posthog-js#5024](https://github.com/PostHog/posthog-js/pull/5024), [posthog-js#5020](https://github.com/PostHog/posthog-js/issues/5020)) is that data the SDK accepted while opted in is still delivered, including after opt-out or on a later launch, and nothing captured after opt-out is sent. This change applies the same rule to deferred crash reports.

## What Changes

- Add an `opt-in` requirement, **Deferred crash reports honour consent at crash time**, for client SDKs that reconstruct a terminating failure on a later launch rather than capturing it in-process. Whether the reconstructed `$exception` is sent follows the consent state at the time of the failure, not at the time the report is found.
- A report of a failure that occurred while opted out SHALL NOT be sent on any later launch. A report of a failure that occurred while opted in SHALL stay deliverable: an opted-out launch that finds it leaves it in place, and it is sent once the user opts in.
- The requirement names the outcome, not the mechanism. An SDK MAY mark the recording context at opt-out so later reports carry the marker, or MAY persist the opt-out intervals and compare each report's failure time against them. Reports written by SDK versions that predate the consent signal are out of scope.
- Where the SDK writes identity or event properties into the crash context, opting out SHALL also stop that context from carrying the user's identity into any later failure.
- Three scenarios: a crash while opted out followed by relaunch and opt-in sends nothing; a crash while opted in found by an opted-out launch is held and then sent exactly once on opt-in; a runtime `optOut()` followed by a crash and `optIn()` in the same install sends nothing.
- `consent-gating`: one sentence under Interactions pointing the "exception capture" line at the new requirement. No requirement in `consent-gating` changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `opt-in`: new requirement for deferred crash reports, plus narrative notes under `optOut` and Interactions.
- `consent-gating`: narrative pointer only, under Interactions. No requirement or scenario changes.

## Impact

- **posthog-ios**: [PR 1040](https://github.com/PostHog/posthog-ios/pull/1040) (draft, head `fb380fe03eb0420a58e48a29c8e9a62dbe6f6275`) implements the marker approach for PLCrashReporter reports. The MetricKit out-of-memory path (`PostHogMemoryExceptionReporter`, [#853](https://github.com/PostHog/posthog-ios/pull/853)) is a stacked follow-up PR, not yet open; until it lands posthog-ios is partial against the requirement.
- **posthog-android**: a fix on branch `fix/native-crash-recorded-while-opted-out` (local commit `1f10328b`, no PR yet) persists opt-out intervals and skips tombstone records whose timestamp falls inside one while still advancing the watermark. Android writes no PostHog identity into the OS tombstone, so the identity sentence holds there with no code.
- **React Native and Flutter on native** inherit the behaviour from the native SDKs; the wrappers have no crash recorder of their own.
- **posthog-js, Flutter on web, and in-process uncaught handlers** are out of scope: their fatal exceptions go through `capture()`, which `consent-gating` already blocks while opted out.
- Compliance matrix: `compliance/posthog-ios.md` and `compliance/posthog-android.md` are produced by the weekly audit (branch `posthog-code/weekly-sdk-compliance-matrix`), so they are not edited here. The next audit after the SDK PRs merge picks the new requirement up.
- The provenance mapping in `tasks.md` points at the unmerged PR 1040 head and the local Android commit; re-point it at the merged SHAs before this spec PR leaves draft.
