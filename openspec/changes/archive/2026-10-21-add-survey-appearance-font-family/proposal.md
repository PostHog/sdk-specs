## Why

Survey definitions carry an `appearance.fontFamily`, and the native SDKs already parse it:
`PostHogDisplaySurveyAppearance.fontFamily` exists on iOS and Android, and posthog-js has rendered
it since surveys shipped. The spec never said what an SDK does with it, so the field drifted. iOS
applies it to the whole sheet and falls back to the system body font for a family it cannot
resolve; posthog-js appends its default stack after the requested family and treats the surveys API
default `inherit` as "use the host document font"; Android hands the raw value to the host UI layer;
and posthog-flutter parsed it and then ignored it, so its built-in survey UI always rendered in the
app's default font until
[posthog-flutter#654](https://github.com/PostHog/posthog-flutter/pull/654) applied it
([posthog-flutter#258](https://github.com/PostHog/posthog-flutter/issues/258)). That PR notes the
gap directly: no surveys spec covers fonts.

## What Changes

- Add a **Survey appearance font family** requirement to the `surveys` capability.
- State that a renderer applies the resolved font to the whole survey surface, not a subset of its
  text, and that doing so changes no other appearance attribute.
- Define the unset cases — absent, null, empty, whitespace-only, and the API default sentinel
  `inherit` — and require the SDK's existing default font for them.
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
