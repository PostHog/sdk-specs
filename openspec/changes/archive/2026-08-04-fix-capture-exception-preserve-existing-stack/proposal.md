## Why

[posthog-js#4235](https://github.com/PostHog/posthog-js/pull/4235) ("preserve browser error
stacks") fixed a data-loss bug in `@posthog/core`'s error coercers
(`error-coercer.ts`, `error-event-coercer.ts`, `object-coercer.ts`): when the input to
`captureException`/exception autocapture was an error-like object or `ErrorEvent` that already
carried a real `stack`/`stacktrace` string, the coercers discarded it and built a synthetic
one-frame stack from other metadata (message, or `filename`/`lineno`/`colno`) instead. This
silently degraded genuine multi-frame stack traces to a single synthetic frame whenever the
coercion path picked the wrong source.

`openspec/specs/capture-exception/spec.md` documents *ordering* rules for the frames the SDK
sends (`Stack frame ordering`, `Source context line ordering`) but never states which source of
stack information should win when more than one is available on the input. That's a real gap:
"synthesize a stack from whatever's available" is a plausible, spec-compliant-looking
implementation that this bug fell into, silently downgrading the payload's accuracy.

This proposal adds the narrow, platform-agnostic principle the fix encodes — prefer an
already-present stack over synthesizing one — without pulling in the browser-specific
implementation details (cross-realm `Error` detection, `window.onerror` positional-argument
synthesis, multiline-message-vs-frame disambiguation), which are JS-runtime-specific mechanics
below this spec's abstraction level, not a cross-SDK contract point.

## What Changes

- **Requirement prose** (`Canonical capture-exception behavior`, Behavior item 3): adds that
  normalization SHALL preserve stack information already present on the input rather than
  discarding it for a synthesized stack.
- **New requirement**: `Stack trace preservation over synthesis`, with one scenario asserting an
  existing stack is preserved and not overwritten by a synthesized one.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `capture-exception`: Behavior item 3 gains a preservation clause; the requirements section
  gains one new requirement (`Stack trace preservation over synthesis`) with one scenario. All
  existing requirements and scenarios are unchanged.

## Impact

- `openspec/specs/capture-exception/spec.md` — source of truth, updated via this change's delta.
- Implementations: `@posthog/core` and its consumers (`posthog-js` browser/node,
  `posthog-react-native`) already conform after posthog-js#4235. Native iOS/Android/Flutter/Unity
  coercers were not independently re-audited for the same stack-discarding defect class in this
  pass — worth a follow-up per-SDK check (see `tasks.md` §4).
- No acceptance-harness changes in this proposal; the new scenario is written for a future
  harness port that can construct an error-like input with a pre-existing stack string.
