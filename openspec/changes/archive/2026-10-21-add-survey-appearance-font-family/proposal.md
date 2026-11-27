## Why

Survey definitions carry an `appearance.fontFamily`, and the native SDKs already parse it:
`PostHogDisplaySurveyAppearance.fontFamily` exists on iOS and Android, and posthog-js has rendered
it since surveys shipped. The spec never said what an SDK does with it, so the field drifted.
posthog-js appends its default stack after the requested family and treats the surveys API default
`inherit` as "use the host document font". posthog-ios
([posthog-ios#1121](https://github.com/PostHog/posthog-ios/pull/1121)) and the posthog-android
Compose renderer ([posthog-android#1007](https://github.com/PostHog/posthog-android/pull/1007)) read
the first family of the CSS list, treat `inherit` and `system-ui` as the system font, and fall back
to it for a family the device cannot resolve. posthog-flutter parsed the field and then ignored it,
so its built-in survey UI always rendered in the app's default font until
[posthog-flutter#654](https://github.com/PostHog/posthog-flutter/pull/654) applied it
([posthog-flutter#258](https://github.com/PostHog/posthog-flutter/issues/258)). That PR notes the
gap directly: no surveys spec covers fonts.

## What Changes

- Add a **Survey appearance font family** requirement to the `surveys` capability.
- State that a renderer applies the resolved font to the whole survey surface, not a subset of its
  text, and that doing so changes no other appearance attribute.
- Require a non-CSS renderer to read the value as a CSS list and use only its first family, unquoted
  and trimmed, matched case-insensitively.
- Define the unset cases — absent, null, empty, whitespace-only, an empty first family, and the CSS
  keywords `inherit` and `system-ui` — and require the SDK's existing default font for them.
- Require an unresolvable family to fall back to the default font without raising and without
  blocking display.
- Require an SDK that delegates rendering to carry the raw value through its display model.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `surveys`: adds the **Survey appearance font family** requirement.

## Impact

No wire format or event changes. Surveys whose appearance sets a font render in that font on SDKs
that currently ignore it; surveys that leave it unset, empty, or `inherit` render exactly as before.
posthog-flutter passes the whole trimmed value to Flutter, so a CSS list such as
`"Times New Roman", serif` falls back to the default font there instead of using its first family.
