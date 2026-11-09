## Context

On iOS and Android a fatal crash is not captured in-process. A platform recorder writes it to disk and the SDK reconstructs the `$exception` on the launch that next installs the error tracking integration. `optOut()` uninstalls the integration, but neither recorder can be disabled once installed: PLCrashReporter refuses a second `enable` and its Mach and signal handlers cannot be deregistered, and Android's tombstones are written by the OS regardless of the app. So the consent gate cannot sit in front of the recorder; it has to sit in front of reconstruction, and it has to know what consent was at crash time.

## Goals

- Record the rule: a deferred crash report follows the consent state at the time of the failure.
- Keep the rule symmetric with the queued-events decision in posthog-ios#1003: consented data is delivered, nothing recorded without consent is.
- Leave the mechanism open, because the two shipped implementations differ.

## Decisions

**The requirement lives in `opt-in`, not `consent-gating` or `capture-exception`.** The hook is `optOut()` / `optIn()`: both implementations act at those transitions, and the two mobile replay requirements in `opt-in` are the precedent for a mobile-only consent edge with its own normative text and GIVEN/WHEN/THEN scenarios. `consent-gating` gets a pointer sentence only; its requirements are about in-process capture calls.

**Consent is measured at the failure, not at discovery.** Otherwise a crash while opted out is sent as soon as the user opts in (the bug), or a consented crash is lost because the next launch happens to be opted out (the opposite bug). PR 1040's `optInCapturesCrashReportRecordedWhileOptedIn` and Android's `a consented native crash survives a launch that starts opted out` both pin the second half.

**Outcome, not mechanism.** iOS marks the recording context at opt-out: `PostHogCrashCustomDataWriter.markOptedOut()` replaces PLCrashReporter's custom data with `{"$opted_out": true}` and empty steps, and `processPendingCrashReport` drops a report that carries the key. Android cannot write into the OS tombstone, so it persists wall-clock opt-out intervals and skips any `ApplicationExitInfo` record whose timestamp falls inside one. Both satisfy the same scenarios. The requirement names both as examples with MAY and requires neither.

**Opted-out launches wait; they do not purge.** A consented report found by an opted-out launch must stay on disk until the user opts in. iOS does this by not installing the integration while opted out (the report is never read). Android does the same: `install` only runs while opted in, so no scan happens and the watermark does not move. The requirement says SHALL NOT discard or acknowledge.

**Identity is a SHALL, conditioned on the SDK writing it.** iOS writes `distinct_id` and `event_properties` into the crash context so the reconstructed event carries the crash-time identity; after opt-out that snapshot must not ride into a later crash, and `markOptedOut()` clears it. Android writes nothing of PostHog's into the tombstone, so the sentence holds there with no code. A SHOULD would weaken iOS for no gain on Android, so the condition carries the platform difference instead.

**Legacy reports are out of scope.** A report written by an SDK version that predates the marker or the interval store carries no consent signal. Dropping it would also drop consented crashes; sending it preserves today's behaviour for one upgrade. The requirement says so explicitly.

**Scenarios stay in the spec.** The replay restart requirements in `opt-in` did not extend `acceptance/public/opt-in.feature`, because the shared harness has no mobile crash-recorder step. These scenarios follow that precedent and use the same preamble, so they can move to the feature file when a step exists.
