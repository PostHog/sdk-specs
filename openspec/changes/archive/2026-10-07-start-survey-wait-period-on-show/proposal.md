## Why

[posthog-android #844](https://github.com/PostHog/posthog-android/pull/844) and
[posthog-ios #917](https://github.com/PostHog/posthog-ios/pull/917) (both merged 2026-10-07) fixed
the same bug: the mobile SDKs wrote the device-wide last-seen survey date only when a survey was
answered or closed, so showing a survey started no wait period. If the app was killed while a
survey was open, `seenSurveyWaitPeriodInDays` never began and other surveys could show immediately
on the next launch.

Both PRs name the surveys spec and both had to reason about what it does and does not require. The
spec lists "seen keys and last-seen dates" as state the SDK writes, but it only says *when* the
per-survey seen key is written ("a survey should be marked seen when it is submitted or dismissed").
The device-wide last-seen date — the one the wait period reads — has no stated write moment. That
gap is the drift.

## What drifted

Writing the last-seen date on show is already the behavior in posthog-js. The browser extension
writes it in `showSurvey` (`packages/browser/src/extensions/surveys.tsx`), alongside
`setIsPopupVisible(true)` and before the `survey shown` capture, and `hasWaitPeriodPassed` in
`surveys-extension-utils.tsx` reads it. React Native writes it in the provider's `onShow`
(`packages/react-native/src/surveys/PostHogSurveyProvider.tsx`). posthog-ios and posthog-android now
match. The two states are deliberately distinct: the last-seen date is written on show, the
per-survey seen key only on submit or dismiss.

The consequence worth stating is the one both PRs had to argue about: a survey resumed from
persisted in-progress responses is subject to the wait period like any other display, because the
earlier show already wrote the date.

## What changes

Adds one requirement to `surveys`:

- The device-wide last-seen survey date is written when a survey is shown, not when it is submitted
  or dismissed. Where the SDK serializes active-survey state, the write happens within it and is
  skipped if a reset has occurred since the display decision, so a reset in between cannot be
  followed by a stale date.
- `seenSurveyWaitPeriodInDays` is evaluated against that date, so showing any survey starts the wait
  period for every survey that has one.
- The per-survey seen key is unchanged: still written on submit or dismiss only.
- A survey resumed from in-progress response state is subject to the wait period.
- `reset` clears the last-seen date along with the rest of survey history.
- The State-written, Lifecycle-behavior and Concurrency prose in the spec name the show moment.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `surveys`: one added requirement, plus matching wording in the State written, Lifecycle behavior
  and Concurrency & ordering sections.

## Impact

No API or service change; this is display-logic state. End users of an app see at most one survey
per wait period even across a restart or crash mid-survey.

- **posthog-js** browser: already conforms; this records the reference behavior. React Native writes
  the date on show but does not evaluate it (see below), so it does not yet conform.
- **posthog-ios**, **posthog-android**: conform as of #917 and #844.
- **posthog-flutter**, **posthog-kmp**: inherit through the native SDKs.
- posthog-js React Native has the wait-period check itself commented out in
  `getActiveMatchingSurveys.ts` even though it writes the date, so it writes the state without
  reading it. That is a separate pre-existing gap, not changed here.
