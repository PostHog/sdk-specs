## Why

Nine SDKs merged the same fix within a day of each other (2026-08-13/14): caller-supplied
`timestamp` overrides (and, on posthog-php, the parsed default) were being serialized in their
original local/offset timezone instead of being converted to the equivalent UTC instant, and
sub-second precision was sometimes truncated. Confirmed source changes:

- [posthog-js#4521](https://github.com/PostHog/posthog-js/pull/4521) — `@posthog/core` /
  posthog-node / browser: "Normalize capture timestamp overrides to equivalent UTC ISO strings."
  A `Date` built from `2023-11-15T03:43:20.000+05:30` now serializes as
  `2023-11-14T22:13:20.000Z`, not with the `+05:30` offset preserved.
- [posthog-python#872](https://github.com/PostHog/posthog-python/pull/872) — "Normalize SDK event
  timestamps to UTC, including datetime values and parseable ISO timestamp strings."
- [posthog-php#223](https://github.com/PostHog/posthog-php/pull/223) /
  [#224](https://github.com/PostHog/posthog-php/pull/224) — preserves fractional seconds
  (previously `date("c", ...)` truncated to whole seconds) and converts to UTC before formatting.
- [posthog-go#284](https://github.com/PostHog/posthog-go/pull/284),
  [posthog-android#698](https://github.com/PostHog/posthog-android/pull/698),
  [posthog-ios#764](https://github.com/PostHog/posthog-ios/pull/764) (test coverage for the same
  behavior), [posthog-flutter#531](https://github.com/PostHog/posthog-flutter/pull/531),
  [posthog-ruby#248](https://github.com/PostHog/posthog-ruby/pull/248),
  [posthog-dotnet#289](https://github.com/PostHog/posthog-dotnet/pull/289) — same normalization,
  each converting the timestamp to its equivalent UTC instant (e.g. Go's `msg.Timestamp.UTC()`)
  immediately before assigning it to the outgoing envelope field.

`openspec/specs/capture/spec.md`'s "Attach envelope fields" step only said timestamps are
serialized "in ISO 8601 with timezone" — true but incomplete, since it doesn't say the timezone
is always UTC, and doesn't mention that fractional-second precision must survive. A reader
implementing a new SDK (or reviewing an existing one) from this spec alone would have produced
the exact bug these nine PRs just independently fixed: preserving the caller's original UTC
offset instead of normalizing to `Z`/`+00:00`.

## What Changes

Prose-only fix to the "Attach envelope fields" bullet (step 5) of `capture/spec.md`'s Behavior
section — no requirement or scenario text changes. The existing scenarios don't assert timezone
behavior one way or the other, so no scenario contradicts the corrected prose.

- State explicitly that the timestamp is normalized to its equivalent UTC instant before
  serialization, regardless of the timezone/offset of the caller-supplied value, and that
  sub-second precision (when present on the input) is preserved rather than truncated.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `capture`: "Attach envelope fields" prose corrected to state UTC normalization and
  fractional-second preservation for the `timestamp` field. No requirement or scenario changes.

## Impact

- `openspec/specs/capture/spec.md` — source of truth, corrected directly (prose-only).
- Not investigated: whether posthog-java (posthog-server, in the posthog-android monorepo) has
  the same fix — its compliance audit predates this cross-SDK rollout and none of the repos
  reviewed this run showed a java-specific timestamp PR. Worth a follow-up compliance check.
