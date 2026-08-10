## Why

[posthog-js#4436](https://github.com/PostHog/posthog-js/pull/4436) ("feat(surveys): add optional
intro screen shown before the first question") shipped a new, opt-in survey step: a leading
mirror of the existing trailing confirmation ("thank you") screen, requested in
[PostHog/posthog#74064](https://github.com/PostHog/posthog#74064) so survey authors can frame a
popover survey before question 1 without a throwaway first question polluting response data.

The change adds new `SurveyAppearance` fields (`displayIntroScreen`, `introScreenHeader`,
`introScreenDescription`, `introScreenDescriptionContentType`, `introScreenButtonText`) plus
matching `SurveyTranslation` fields, and ships in both the browser SDK and posthog-react-native
(both live in the `posthog-js` monorepo and share `@posthog/core`). The behavior is deliberate and
well-specified: off by default, no capture event or response recorded when advancing past it, no
effect on completion/partial-response accounting, skipped when a survey is resumed with
in-progress or URL-prefilled answers, skipped in favor of the confirmation branch for an
already-completed survey, and dismissing it emits the survey's normal `survey dismissed` event.

`openspec/specs/surveys/spec.md` and `acceptance/private/surveys.feature` predate this feature and
have no mention of an intro screen, its appearance fields, or its non-response semantics — this is
confirmed spec drift, not an ambiguous change (the source PR's design, tests, and changeset all
converge on one clear behavior).

## What Changes

- **New requirement**: `Survey intro screen`, describing the opt-in intro step, its appearance
  fields, its non-response/non-event semantics when advanced, its skip conditions (resumed/
  in-progress, URL-prefilled, already-completed), and that dismissing it emits the normal
  `survey dismissed` event.
- **Prose alignment** (applied at archive, outside the requirement-delta mechanism): a one-line
  pointer from Behavior item 7 ("Render through a platform UI layer") to the new requirement.
- No changes to existing requirements or scenarios.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `surveys`: gains one new requirement (`Survey intro screen`) with five scenarios. All existing
  requirements and scenarios are unchanged.

## Impact

- `openspec/specs/surveys/spec.md` — source of truth, updated via this change's delta.
- `acceptance/private/surveys.feature` — gains one representative scenario for the intro screen's
  non-response semantics, matching this repo's existing pattern of a subset (not 1:1) of spec
  scenarios in the Gherkin harness.
- Implementations: posthog-js (browser) and posthog-react-native (via the shared `posthog-js`
  monorepo) already conform as of PR #4436. posthog-android, posthog-ios, and posthog-flutter do
  not implement this yet — the source PR explicitly tracks native/Flutter parity as a follow-up in
  PostHog/posthog#74064, not a gap in this proposal.
- **Low-confidence detail flagged for reviewer attention:** the source PR describes the intro as
  "off by default," but this proposal does not attempt to state the literal default value type
  (e.g. `undefined` vs `false`) since that is an implementation detail rather than an observable
  contract difference — flagged here in case a future SDK's `undefined`-vs-`false` handling
  diverges observably.
