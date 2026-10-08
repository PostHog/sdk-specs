## Why

The `surveys` spec says what happens for an "unsupported survey type", but says nothing about a
survey whose **questions** the SDK cannot display. The question types a survey can contain are
server-side data that grows over time, so an SDK that shipped before a type was added will meet one.

posthog-ios [#887](https://github.com/PostHog/posthog-ios/pull/887) found what that costs. The SDK
rendered the questions it understood and silently dropped the rest, while question identity,
branching, and response keys were still computed against the survey's **full** question list. After
the last displayed question the SDK branched to a question that was not on screen: the prompt
collapsed to an empty pill with only a close button, and no `survey sent` event was captured. Its
description states directly that "the surveys spec in sdk-specs doesn't cover unknown question
types" and that it followed the closest existing rule — unsupported surveys log and return without
emitting events.

Partial display is the trap here, and it is reachable by any SDK that renders a question list by
type. Writing the rule down makes the safe behavior the contract rather than one SDK's bug fix.

## What Changes

- Add a requirement to `surveys`: a survey is displayed only if the SDK can display **every** one of
  its questions. An undisplayable question makes the whole survey not displayable — log and return,
  no interaction events, and no partial display.
- A survey skipped this way is not marked seen and writes no seen key or device-wide last-seen
  survey date, so a later SDK version that understands the question type can still show it.
- A public renderability check (`canRenderSurvey`-style) reports the survey as not displayable.
- A skipped survey does not prevent another eligible survey from being displayed.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `surveys`: adds the **Surveys with undisplayable questions are not shown** requirement.

## Impact

Not a breaking change for applications: the affected surveys cannot be completed today.

- **posthog-ios** conforms as of #887. `canRenderSurvey` skips a survey when any question cannot be
  displayed and logs why; because the displayed questions now always match the full survey, the
  response's question id is read straight from the full survey. The same path covers its custom and
  Flutter UIs.
- **posthog-android** does not conform: `toDisplaySurvey` drops questions it cannot display with
  `mapIndexedNotNull` and shows the rest, the same partial display #887 removed on iOS. Conforming
  is an SDK-side change.
- **posthog-flutter** inherits the native behavior on each platform: it conforms on iOS through #887
  and follows posthog-android on Android.
- **posthog-js** (browser and React Native) renders questions by type (a switch in the browser, a
  component map in React Native) and has no equivalent guard in
  `canRenderSurvey`/`_checkSurveyRenderability`, so it is the SDK this requirement is most likely to
  be ahead of. Conforming is an SDK-side change, which the repo's workflow does not block archiving
  on.
