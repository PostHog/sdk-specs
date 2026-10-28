## Overview

This change adds one requirement to the existing `surveys` capability, covering the interval between
the SDK deciding to display a survey and the survey appearing. It does not change survey loading,
eligibility rules, branching, or event shapes.

## Key Decisions

- **Reserve before the wait, not when shown.** The reservation is what makes "only one active prompt"
  hold during the delay. Reserving at display time (Android before #849) means every repeat trigger
  event sees a free slot, re-renders the survey, and restarts the delegate's countdown; a trigger
  that fires faster than the delay starves the survey entirely. Reserving first also fixes which
  trigger the delay is measured from — the first one.
- **Measure the delay from the first trigger.** The alternative, letting each later trigger restart
  the countdown, is the Android bug stated as a rule. A user who keeps doing the thing that triggers
  the survey is the user the survey is for.
- **Treat a non-positive or missing delay as "show now".** All four implementations already clamp:
  iOS `max(..., 0)` and a `guard delay > 0`, the browser `|| 0` then `delaySeconds <= 0`, and Flutter
  matched them deliberately. Writing it down keeps a future SDK from inventing a "negative means
  never" reading.
- **A survey that never reached the screen is not seen and not dismissed.** Seen state and
  `survey dismissed` describe what the user did with a prompt they saw. Marking a dropped pending
  survey seen would hide it permanently from a user who never saw it, and emitting `survey dismissed`
  for it would overcount dismissals — which also keeps the existing ordering rule (`survey shown`
  precedes `survey sent` / `survey dismissed`) true for delayed surveys.
- **Make the delegate's report-back a requirement, not an implementation note.** Once the
  reservation gates later surveys, a host UI layer that silently drops a survey blocks every
  subsequent one until reset. iOS and Android both work this way, and #849's KDoc change says so for
  Android; stating it here is what makes the reservation safe to require. Reporting "closed" is only
  safe once the core treats a close for a survey that was never shown as a silent release; iOS does
  not yet, which is why Flutter's cancelled delay stays silent today (see Open Questions).
- **Eligibility re-check on elapse is SHOULD.** The browser re-checks the full display predicate
  when the timer fires, because an `identify()` mid-delay can flip a targeting flag or the person
  can opt out. The native SDKs do not. Both readings are defensible and no SDK is currently wrong
  under the weaker one, so this change states the safer behavior without declaring the others
  non-conforming. Opt-out is already covered by the existing *Surveys respect opt-out state*
  scenario.

## Alternatives Considered

- **Specify the delay as purely a UI-layer concern.** Rejected. The delay decides whether
  `survey shown` is ever emitted and whether the survey is marked seen, both of which this spec
  already governs.
- **Require the browser's resume-from-activation behavior everywhere.** Rejected for now. It depends
  on a persisted, session-scoped activation timestamp that only the browser records today, and on
  navigation semantics that do not map cleanly onto a mobile app's lifecycle. It is recorded as
  allowed so the browser is not non-conforming.
- **Require a `cancelPendingSurvey`-style public API.** Rejected. Only the browser exposes one; the
  requirement is about what happens to a dropped pending survey, however it is dropped.

## Open Questions

- posthog-react-native does not implement the delay yet; when it does, it should keep reserving the
  survey (`activeSurvey`) before the wait, as its provider already does before rendering.
- posthog-ios marks a survey seen and emits `survey dismissed` when its delegate closes it before
  `onSurveyShown` ran (`PostHogSurveyIntegration.handleSurveyClosed` does not track whether the
  active survey was shown). This is an implementation gap against the dropped-before-shown rule.
- posthog-flutter's cancelled delay reports neither shown nor closed, so the native reservation is
  held until native reset or teardown. It can report closed once the iOS gap above is fixed.
