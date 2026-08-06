## Why

posthog-flutter#500 ("mask every element that matched a masking rule") fixed a shipped
privacy leak in the mobile screenshot-masking pipeline (both iOS and Android, since Flutter's
Dart-side `ImageMaskPainter` paints masks the same way on both platforms): the tree walk that
collects mask rectangles (`ElementData.extractRects()`) was not recursive. It visited a root's
direct children, and grandchildren only when a child itself had more than one child — dropping
the child in that branch instead of also visiting it. Concretely: a `PostHogMaskWidget`
wrapping several matched children lost its own mask rect, so anything inside the wrapper that
did not *itself* match a rule (an image with `maskAllImages` off, spacing, a decoration) was
recorded unmasked even though the developer explicitly wrapped that subtree to be masked.
Verified live on both iOS and Android simulators/emulators: before the fix, a `PostHogMaskWidget`
wrapping `Text` / unmasked-widget / `Text` masked only the two texts, leaving the widget between
them fully visible in the recording.

`openspec/specs/session-replay-privacy/spec.md` describes *how* masks are painted (behavior
item 6: "draw masks into the screenshot bitmap/canvas") but never states *completeness* — that
every element/subtree matching a masking rule must be included, not just the first match or a
subset. This is a real gap the shipped bug fell into, not a documented-then-violated rule.

## What Changes

- **Requirement prose** (`Canonical session-replay-privacy behavior`): adds a completeness
  clause to the masking-application behavior — screenshot/wireframe mask discovery must include
  every element/subtree matching a masking rule, including nested and sibling matches, not only
  the first match encountered during tree traversal.
- **New scenario**: multiple sibling/nested elements under an explicit mask marker are all
  masked, not just one.
- **Prose alignment at archive**: Behavior item 4 (apply masks before serialization/upload)
  gains a sentence on traversal completeness for screenshot/wireframe mask discovery.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `session-replay-privacy`: the single `Canonical session-replay-privacy behavior` requirement
  gains one new scenario on mask-discovery completeness. The four existing scenarios are
  unchanged.

## Impact

- `openspec/specs/session-replay-privacy/spec.md` — source of truth, updated via this change's
  delta plus a prose correction applied at archive.
- Implementations: posthog-flutter already conforms after PostHog/posthog-flutter#500 (both
  iOS and Android code paths, since Flutter paints masks itself rather than delegating to the
  wrapped native SDK's own masking). Native iOS/Android/web mask-discovery implementations were
  not independently re-audited for the same class of traversal bug in this pass.
- No acceptance-harness changes in this proposal; the new scenario is written so a future
  harness port can implement it (a masked wrapper containing multiple children, at least one of
  which does not independently match a masking rule, all of which must be masked in the
  resulting snapshot).
- **Low-confidence detail, flagged for human review:** two adjacent bugs the Flutter PR
  description explicitly found and *deliberately left unfixed* (stale masking-config parsers
  after re-`setup()`; `maskAllImages` masking text when `maskAllTexts` is off) are **not**
  addressed by this change. They may be worth their own follow-up if confirmed cross-platform.
