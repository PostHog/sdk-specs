## Overview

This change adds one requirement to the existing `surveys` capability. It does not change survey
loading, eligibility, branching, or event shapes; it settles what an SDK does when a survey it is
otherwise eligible to show contains a question it cannot render.

## Key Decisions

- **Skip the whole survey, not the question.** The alternative — drop the question and show the
  rest — is what posthog-ios did before #887, and it is unsafe by construction: branching targets
  and response keys are addressed against the full question list, so dropping a question
  desynchronizes the displayed index from that list. There is no local fix for that short of
  rewriting the survey's branching, which the SDK cannot do correctly without understanding the
  question it dropped.
- **Follow the existing "unsupported survey type" rule.** Error handling already says invalid ids,
  unsupported survey types, and missing render targets log and return without emitting interaction
  events. An undisplayable question type is the same class of problem, so it gets the same handling
  rather than a new one.
- **Do not mark the survey seen.** Seen state is for surveys the user was actually shown. Marking a
  skipped survey seen would hide it permanently from a user whose SDK later gains the question type.
- **State it as a property of the SDK's display capability, not a fixed list of types.** The spec
  does not enumerate question types; it says "every question this SDK can display", so the rule
  stays correct as the server adds types and as SDKs catch up at different rates.
- **Cover the public renderability check.** `canRenderSurvey`-style APIs exist to answer "will this
  show?", so they have to agree with the display path or callers route around the guard.

## Alternatives Considered

- **Display the known questions and renumber branching around the dropped one.** Rejected. Branching
  can target the dropped question, and a conditional branch defined on its answer has no answer to
  read. The resulting flow is not the survey its author published.
- **Display the known questions and end the survey at the first undisplayable one.** Rejected. It
  emits a `survey sent` for a partial response that the author did not ask for, and marks the survey
  seen, so the complete survey is never collected.
- **Leave it SDK-specific.** Rejected. The failure is silent — an inert prompt and a missing
  `survey sent` — and it only appears after the server ships a new question type, which is exactly
  when nobody is looking at an older SDK.

## Open Questions

- Whether posthog-js should also report a distinct `disabledReason` string for this case, and what
  it should be, is left to that SDK. This spec requires only that the check report the survey as not
  displayable.
