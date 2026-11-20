## Why

`session-replay-privacy` lists the browser replay redaction options an SDK exposes
(`maskAllInputs`, `maskTextSelector`, `blockSelector`, `maskInputOptions`, the network capture
hooks) and states that custom masking callbacks run before serialization and fail closed. It says
nothing about `<select>` elements, whose recorded data is not only the displayed text but the
identity of the chosen options.

PostHog/posthog-js#5709 (merged 2026-11-19 as `1016d81c3`) ships an opt-in public option,
`session_recording.selectMaskingFn`, for exactly that gap. A `maskInputFn` callback receives text
and cannot express whether a select's chosen option identities are private, and reinterpreting it
would change existing multiselect recordings, so the SDK added a separate per-select policy rather
than changing the old callback. The PR description says the spec "does not define this per-select
API".

The option is a public privacy contract — what a `'masked'` answer actually withholds, what an
invalid answer or a throwing callback does, and when the recorder refuses to start — so it belongs
in the spec, where another DOM-recording SDK would read it before adding the same surface.

## What Changes

- **`session-replay-privacy`**: a new requirement, **Explicit per-select masking policy**. It is
  conditional: an SDK that records a DOM and offers a per-select masking policy follows it. No SDK
  is required to add the option, and omitting it keeps the existing category/callback behavior.
- The requirement records the decision values (`'masked'` / `'unmasked'`, with only an exact
  unmasked answer permitting option identities), what masking withholds versus what stays visible
  (static option labels, replacement text from the input callback, pointer events on listbox-style
  selects), fail-closed handling of invalid returns and exceptions, consistent application across
  snapshots, input events and select-subtree mutations, and the refusal to start when the loaded
  recorder does not support the policy.
- The browser option block in the spec's "Public signature(s)" section gains `selectMaskingFn`.
- Four scenarios.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `session-replay-privacy`: specify the per-select masking policy contract.

## Impact

Specifications only. posthog-js browser conforms as merged. No other SDK exposes the option; the
requirement does not oblige them to. Mobile SDKs have no DOM `<select>` and are out of scope.

Flagged for review: the requirement is written from one implementation, so it states posthog-js's
choices as the contract for any SDK that adds this surface. The spec's existing fail-closed and
mask-before-serialization rules already point the same way, but a maintainer should confirm that
the narrower details — reusing the input-masking callback for a masked select's replacement text,
and leaving option clicks in listbox-style selects uncovered — are the contract rather than
posthog-js implementation detail.
