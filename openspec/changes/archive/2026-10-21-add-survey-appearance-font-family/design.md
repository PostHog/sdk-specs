## Overview

`fontFamily` is one appearance field with four shipped behaviors, and the only real disagreement is
what "unset" means. Write down the shared parts — apply it everywhere in the survey, fall back
safely — and name `inherit` as a sentinel rather than a family so non-CSS renderers stop at the same
place posthog-js does.

## Key Decisions

- **`inherit` is unset, not a family.** It is the surveys API default and a CSS keyword. A CSS
  renderer can emit it verbatim; a native renderer asking its font loader for a family named
  "inherit" gets nothing, so the spec normalizes it to "use the default font" instead of leaving
  each SDK to discover the dead end. posthog-flutter also trims and lower-cases before the
  comparison, which the requirement keeps.
- **Apply at the root of the survey surface, not per widget.** posthog-flutter#654 moved the font
  from individual `TextStyle`s to the sheet root precisely because per-widget application missed
  button labels and text-field placeholders. The requirement states the surfaces rather than the
  mechanism, so each platform can use its own inheritance primitive.
- **An unresolvable family is a silent fallback.** iOS already returns `Font.body` when
  `UIFont(name:)` fails, Flutter falls back in the framework, and a browser walks the rest of the
  stack. None of them fail the survey, so the contract says so.
- **Delegating SDKs pass the raw value through.** Android's display model carries `fontFamily`
  unchanged to a host or wrapper renderer, which is how posthog-flutter receives it. Normalizing in
  the pass-through layer would hide the sentinel from a renderer that handles CSS correctly.

## Alternatives Considered

- **Normalize `inherit` to null in the pass-through display model.** Rejected: a CSS-based wrapper
  renderer can use `inherit` as written, and dropping it loses the distinction between "the survey
  author chose the default" and "the field was absent".
- **Specify a concrete default font stack.** Rejected: the default is per-platform by design, and
  posthog-js's stack is a browser concern. The requirement anchors on "the SDK's existing default"
  so applying the field cannot regress a survey that does not set one.

## Open Questions

None.
