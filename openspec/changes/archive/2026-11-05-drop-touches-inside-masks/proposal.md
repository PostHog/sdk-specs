## Why

`session-replay-privacy` covers the pixels of an explicitly masked region but says nothing about
the interactions recorded on top of them. On mobile, session replay masked a `ph-no-capture` view
or a `postHogMask()` region and then uploaded every tap inside it as a TouchStart/TouchEnd at the
exact coordinates, so a recording still showed which key of a masked PIN pad was pressed. The mask
hid the pixels and the touch gave the content back.

The browser has never had this problem: rrweb drops the whole interaction when its target is inside
a blocked (`ph-no-capture`) element. posthog-ios and posthog-android have now matched that, and both
PRs note that the spec only covers dropping touches on Android secure windows.

The one requirement the spec does carry — touches on an Android `FLAG_SECURE` window are not
recorded — is the same rule for a different trigger, so the contract should state the general one.

## What Changes

- New requirement in `session-replay-privacy`: an interaction that begins inside an **explicit mask
  region** is not recorded, and the interaction still reaches the application.
- Only explicit region masks count: `ph-no-capture`, `postHogMask()` / `Modifier.postHogMask()`, and
  the wrapper components that compile to them. Category masking (`maskAllTextInputs`,
  `maskAllTexts`, `maskAllImages`) does not drop interactions — otherwise every tap on a text field
  would disappear from recordings.
- Explicit unmask markers keep their existing precedence, so an interaction inside an unmasked
  subtree is recorded as usual.
- The decision is made when the interaction begins and carries to its end, even if the masked view
  is hidden or removed first, or the finger ends outside the mask. An interaction that *ends* inside
  a mask is also dropped.
- The mask is evaluated where the view is drawn — the same geometry the frame masker uses — and
  against the UI state before the application handles the event, so an application handler cannot
  hide the masked view and let the interaction through.
- When the SDK cannot determine the mask geometry for the interaction, it should drop the
  interaction, matching the spec's existing fail-closed rule for uncertain snapshots.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `session-replay-privacy`: adds the **Interactions inside an explicit mask are not recorded**
  requirement.

## Impact

- **posthog-js (browser)**: already conforms — rrweb drops interactions whose target is inside a
  blocked element.
- **posthog-ios**: conforms as of PostHog/posthog-ios#1006 (issue PostHog/posthog-ios#995). It also
  drops touches on camera windows, which replay frames already skip; that is an iOS detail beyond
  this requirement.
- **posthog-android**: conforms as of PostHog/posthog-android#922 (issue
  PostHog/posthog-android#907).
- **posthog-flutter**, **posthog-react-native**, **posthog-kmp**: touch recording comes from the
  native SDK they wrap, so they conform once their pinned version includes the behavior.
- **posthog-unity**: captures its own frames and is a named follow-up, as it already is for the
  Android secure window requirement.
- Known implementation gaps tracked in the SDKs, not relaxations of this requirement: on iOS a
  `ph-no-capture` subview drawn outside the bounds of a non-clipping ancestor is masked in frames
  but not found by the touch search; on Android a `postHogMask()` that merges under a
  `postHogMask(false)` parent is missed by both the frame mask walk and the touch check.
- Recordings of masked regions lose their interaction markers. That is the intent: the coordinates
  were the leak.
