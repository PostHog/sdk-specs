## Why

`session-replay-privacy` says replay capture masks text input values by default, but it never
says which inputs that covers. Browser replay used to exempt `hidden` inputs from
`maskAllInputs`, so their values were recorded in clear text in the full snapshot and in later
attribute mutations — hidden inputs routinely carry CSRF tokens, pricing, and account
identifiers. posthog-js closed that gap in PostHog/posthog-js#5561 by porting rrweb's hidden
input masking and adding `hidden` to the type-specific `maskInputOptions`. The spec still
describes the old shape, so a reader cannot tell whether a recorded hidden value is conforming.

## What Changes

- New requirement **Hidden input values follow input masking**: a hidden input's value is masked
  whenever broad input masking is on, in the initial snapshot and in later value updates; the
  type-specific masking option covers `hidden`, and an explicit `hidden` entry decides the
  outcome either way; a custom input masking callback receives hidden values like any other
  input value. `file` inputs stay the only exemption.
- The browser `maskInputOptions` signature in the overview lists `hidden`.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `session-replay-privacy`: adds the **Hidden input values follow input masking** requirement.

## Impact

- **posthog-js (browser)**: conforms (PostHog/posthog-js#5561).
- **Mobile/native replay SDKs** (posthog-ios, posthog-android, posthog-react-native,
  posthog-flutter): not applicable — there is no hidden input concept in a native view tree.
- No change to default configuration values: `maskAllInputs` keeps its default and simply covers
  one more input type.
