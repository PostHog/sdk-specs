> **DRAFT: decision pending.** The SHALL lines below are the recommended option (C in design.md),
> not a final call. posthog-js does not conform to them today. Do not apply or archive until the
> option is chosen.

## Why

No spec says what a capture property value of a container type becomes on the wire. SDKs disagree,
and most of the outcomes lose the data. A `Set` in posthog-js serializes as `{}`. A Ruby `Set`
serializes as the string `"#<Set: {1}>"`. posthog-python turns `set`, `list` and `tuple` into
arrays, but a `frozenset` or `deque` becomes `None`. PostHog/posthog-python#1230 adds `frozenset`
and `deque` to the array path, and its review asked whether sdk-specs should cover container values:
https://github.com/PostHog/posthog-python/pull/1230#issuecomment-6805509099

## What Changes

- **Capture**: a new requirement, "Capture serializes set-like and sequence property values as
  arrays". Built-in set-like and ordered sequence values in custom properties serialize as JSON
  arrays, recursively, after the same cleanup as other values. Sequence order is kept. Set element
  order is not specified. Four scenarios.
- Keyed containers other than plain objects (JavaScript `Map`, for example) and lazy or one-shot
  iterables (generators, iterators, `range`) are out of scope.
- **BREAKING** serialized-output change for posthog-js (`Set` was `{}`) and posthog-ruby (`Set` was
  a debug string). No caller can query either of the old values.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture`: define how set-like and sequence property values serialize.

## Impact

Specifications only. No SDK changes in this PR. posthog-js and posthog-ruby need follow-up changes.
posthog-python needs #1230 for `frozenset` and `deque`.
