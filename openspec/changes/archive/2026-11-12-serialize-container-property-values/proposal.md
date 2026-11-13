## Why

No spec says what a capture property value of a container type becomes on the wire. SDKs disagree,
and most of the outcomes lose the data. A `Set` in posthog-js serializes as `{}`. A Ruby `Set`
serializes as the string `"#<Set: {1}>"`. posthog-ios drops a Swift `Set` property, and Godot
drops the whole event for a Packed array. posthog-python turned `frozenset` and `deque` into
`None` until PostHog/posthog-python#1230 (merged 2026-11-12, not yet released) put them on the same
array path as `set`, `list` and `tuple`. The review of that PR asked whether sdk-specs should cover
container values:
https://github.com/PostHog/posthog-python/pull/1230#issuecomment-6805509099

## What Changes

- **Capture**: a new requirement, "Capture serializes set-like and listed sequence property values
  as arrays". Two categories serialize as JSON arrays, recursively, after the same cleanup as other
  values:
  1. Set-like values (the runtime's built-in set types). Element order is not specified.
  2. Listed ordered sequences: a closed per-runtime table of finite built-in sequence types. Order
     is kept.
- Out of scope, named explicitly: keyed containers other than plain objects/maps (JavaScript
  `Map`), byte containers, lazy or one-shot iterables, order-defined collections not in the table
  (.NET `Stack<T>`), and containers represented as plain tuples (Erlang `:queue`).
- Four scenarios.
- **BREAKING** serialized-output change for the SDKs that do not conform today (see design.md).
  Every old outcome loses the elements as structured data.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture`: define how set-like and listed sequence property values serialize.

## Impact

Specifications only. No SDK changes in this PR. Already conformant: posthog-python (on main),
posthog-android, posthog-dotnet, posthog-rs, posthog-go and posthog-unreal. Need a small follow-up:
posthog-js, posthog-ruby, posthog-ios, posthog-unity, posthog-elixir, posthog-flutter, posthog-kmp
and posthog-godot. posthog-php needs a medium one.
