## Overview

`fontFamily` is one appearance field with several shipped behaviors. posthog-ios and the
posthog-android Compose renderer now agree on how a non-CSS renderer reads it, so the requirement
writes their shared reading down: take the first family of the CSS list, treat CSS keywords as
unset, apply the result everywhere in the survey, and fall back safely.

## Key Decisions

- **The value is a CSS list.** Survey authors set it in the PostHog UI, which targets posthog-js, so
  values like `"Times New Roman", serif` are normal. iOS (`surveyFontFamilyName` in
  `PostHog/Surveys/Utils/SurveyFontFamily.swift`) and Android (`surveyFontFamilyName` in
  `posthog-android-surveys-compose/.../theme/SurveyAppearance.kt`) both use only the first family,
  unquoted and trimmed. A native font loader asked for the whole string finds nothing.
- **A quoted first family keeps its commas.** CSS allows a comma inside a quoted family name, and iOS
  keeps it (`"Georgia, Display"` in `SurveyFontFamilyTests`). Android splits on the first comma
  before it removes quotes, so it reads that rare value differently.
- **Match case-insensitively.** CSS family names are case-insensitive. iOS compares the resolved
  `familyName` case-insensitively, and Android lowercases the name because Android's system font
  aliases are lowercase.
- **`inherit` and `system-ui` are unset, not families.** `inherit` is the surveys API default and a
  CSS keyword, and `system-ui` is a CSS generic family. A native font loader asked for either gets
  nothing, so both mean "use the default font". iOS and Android check the keywords against the first
  family, so `inherit, serif` is unset too. An empty first family (`, serif`) is unset as well, and
  does not fall through to the next entry.
- **A CSS renderer keeps CSS semantics.** posthog-js emits `inherit` verbatim, so the survey takes
  the host document's font, and applies that default to an absent field. An explicit null or empty
  value takes the js default stack instead. Both are the js renderer's default font, so the
  requirement allows them rather than forcing one.
- **Apply at the root of the survey surface, not per widget.** posthog-flutter#654 moved the font
  from individual `TextStyle`s to the sheet root because per-widget application missed button labels
  and text-field placeholders. iOS applies it through a `surveyFont` modifier that keeps each text
  style's size and Dynamic Type scaling, and Android registers the weights the sheet uses so button
  labels keep their Medium face. The requirement states the surfaces and the preserved attributes,
  not the mechanism.
- **An unresolvable family is a silent fallback.** iOS builds a family descriptor and keeps the
  system font when the resolved family does not match, Android's `DeviceFontFamilyName` falls back to
  the default typeface, Flutter falls back in the framework, and a browser walks the rest of the
  stack. None of them fail the survey.
- **Delegating SDKs pass the raw value through.** The iOS and Android display models carry
  `fontFamily` unchanged to a host or wrapper renderer, which is how posthog-flutter receives it.
  Normalizing in the pass-through layer would hide the sentinel from a renderer that handles CSS
  correctly.

## Alternatives Considered

- **Normalize `inherit` to null in the pass-through display model.** Rejected: a CSS-based wrapper
  renderer can use `inherit` as written, and dropping it loses the distinction between "the survey
  author chose the default" and "the field was absent".
- **Try each family in the CSS list until one resolves.** Rejected: neither native SDK does it, and
  the trailing entries are usually CSS generic families (`serif`, `sans-serif`) with no native
  equivalent.
- **Specify a concrete default font stack.** Rejected: the default is per-platform by design, and
  posthog-js's stack is a browser concern. The requirement anchors on "the SDK's existing default"
  so applying the field cannot regress a survey that does not set one.

## Open Questions

None.
