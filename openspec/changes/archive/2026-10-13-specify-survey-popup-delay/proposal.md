## Why

Every surveys-capable SDK except posthog-react-native reads `appearance.surveyPopupDelaySeconds` off
the survey definition and waits before showing the prompt, but the `surveys` spec never mentions
the delay. The spec's only nearby rules are "allow only one active prompt" and "a survey should be
marked active before its shown/response/closed callbacks can mutate response state" — both written
for a survey that is already on screen, which leaves the window between "we decided to show this
survey" and "the survey is on screen" unspecified.

That gap produced a real divergence. posthog-android
[#849](https://github.com/PostHog/posthog-android/pull/849) found that Android marked a survey
active only once it was **shown**, so while the delay ran nothing was reserved: every repeat trigger
event re-rendered the survey and restarted the delegate's timer. Trigger events firing faster than
the delay kept the survey from ever showing. iOS (`PostHogSurveysDefaultDelegate.scheduleSurveyDisplay`)
and the browser (`_addSurveyToFocus` before the delay timer in `handlePopoverSurvey`) already
reserved the survey before the wait, so Android was the outlier — and nothing in the spec said so.
posthog-flutter [#627](https://github.com/PostHog/posthog-flutter/pull/627), which plumbs the delay
through to its own bottom sheet, had to rediscover the same rules ("zero, negative, or missing
values still show immediately (same rule as native)", a dropped pending survey does not call
`onClosed`) from the native implementations rather than from the contract.

The delay also interacts with state the spec does govern: seen state and `survey shown` /
`survey dismissed`. A survey that waits and is then dropped before it reaches the screen must not be
marked seen or dismissed, or the user loses a survey they never saw.

## What Changes

- Add a **Survey popup delay** requirement to `surveys`: a positive `surveyPopupDelaySeconds` delays
  display; missing, zero, or negative shows immediately.
- Require the survey to be reserved as the pending prompt **before** the wait starts, so a repeat
  trigger or another eligibility pass during the wait neither restarts the wait nor shows a second
  copy, and other eligible surveys stay queued.
- State that nothing is seen, dismissed, or emitted for a survey that never reached the screen, and
  that the reservation is released when the survey is shown, dropped before showing, or reset.
- Require a delegating SDK's host UI layer to report back (shown or closed), since the reservation
  is what gates every later survey.
- Record the browser-only refinements (resume from the trigger's activation timestamp across
  navigations; an explicit display call may bypass the delay) as allowed, not required.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `surveys`: adds the **Survey popup delay** requirement.

## Impact

No application-visible change for SDKs that already behave this way; this writes down the behavior
three SDKs already shipped.

- **posthog-js** (browser) conforms: `handlePopoverSurvey` claims focus before arming the timer,
  re-checks eligibility when the timer fires, and releases focus when the survey is dropped.
- **posthog-ios** conforms: `scheduleSurveyDisplay` sets `pendingSurvey` before the delay and
  `dismissPendingSurveyIfNeeded` releases it through the closed handler without marking it seen.
- **posthog-android** conforms as of #849 (`pendingPresentation` reserved before `renderSurvey`).
- **posthog-flutter** conforms as of #627 for its own bottom sheet; it relies on the native
  integration for the reservation.
- **posthog-react-native** does not implement the delay yet: `PostHogSurveyProvider` only mentions
  `surveyPopupDelaySeconds` in commented-out code (`TODO: sort by appearance delay, implement
  delay`) and shows a positive-delay survey immediately, so it does not conform to the delay rule.
  It already reserves the survey (`activeSurvey`) before rendering.

Re-checking eligibility when the delay elapses is stated as SHOULD rather than SHALL: the browser
does it, and the native SDKs do not, so this change does not declare either side non-conforming.
