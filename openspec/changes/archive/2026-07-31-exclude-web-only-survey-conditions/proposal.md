## Why

posthog-ios#733 ("don't show web-only surveys (selector/url) on iOS") fixed iOS's
`getActiveMatchingSurveys` eligibility filter, which decoded a survey's `conditions.selector`
and `conditions.url` display-targeting fields but never evaluated them — a survey scoped to
web via CSS selector/URL matching rendered natively on iOS with non-functional buttons, since
those conditions have no meaning outside a browser DOM. The PR description claims this
"keeps parity with the other native SDKs."

That claim was verified directly against source and is **only partially true**: posthog-js's
React Native package (`getActiveMatchingSurveys.ts`) already excludes surveys whose only
targeting is `conditions.url`/`conditions.selector`, with dedicated test coverage. But
posthog-android's `PostHogSurveysIntegration.getActiveMatchingSurveys()` never reads
`conditions.selector`/`conditions.url` at all — the same gap iOS just fixed. posthog-flutter
has no independent eligibility logic; it delegates entirely to whichever native SDK it wraps,
so it inherits Android's gap when running on Android and iOS's (now-fixed) behavior on iOS.

`openspec/specs/surveys/spec.md` behavior item 5 only says eligibility includes "device type...
and platform-specific display constraints" — it names no concrete rule for
selector/URL-only-conditioned surveys on non-web platforms. This is a real gap, and per this
repo's convention of "descriptive of a canonical target... where SDKs diverge today, the spec
names the winner," React Native's already-correct behavior (now matched by iOS) is the
canonical target — Android and Flutter are documented as not yet conforming.

## What Changes

- **Requirement prose** (`Canonical surveys behavior`): adds the web-only-condition exclusion
  rule for non-web SDKs.
- **New scenario**: a survey whose only display condition is a CSS selector or URL match is
  excluded from active matching surveys on a non-web/native SDK.
- **Prose alignment at archive**: Behavior item 5 names the concrete rule instead of the vague
  "platform-specific display constraints" phrase.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `surveys`: the single `Canonical surveys behavior` requirement gains one new scenario. The
  four existing scenarios are unchanged.

## Impact

- `openspec/specs/surveys/spec.md` — source of truth, updated via this change's delta plus a
  prose correction applied at archive.
- Implementations: posthog-js's React Native package already conforms (existing, pre-dating
  this change). posthog-ios conforms as of PostHog/posthog-ios#733.
  **posthog-android and posthog-flutter do not conform** — confirmed by reading
  `PostHogSurveysIntegration.kt`, which never reads `conditions.selector`/`conditions.url` in
  its eligibility filter. This is documented as a known implementation gap, not silently
  assumed fixed.
- No acceptance-harness changes in this proposal; the new scenario is written so a future
  harness port can implement it directly.
- **Flagged for human review:** posthog-android should get the same fix iOS just shipped
  (potentially reusing iOS's approach) — this proposal only documents the target contract, it
  does not open or track that implementation work.
