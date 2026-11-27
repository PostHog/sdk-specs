## Why

No spec says what a capture property value of a date or date-time type becomes on the wire. The
envelope `timestamp` is specified (`capture/spec.md`, step 5 and "Timestamps on capture v1"): ISO
8601, normalized to the equivalent UTC instant. Property values inside `properties` have no such
rule, and the SDKs disagree about the offset they write.

PostHog/posthog-ruby#372 (merged 2026-11-24) changed posthog-ruby to write every date-time
property value as UTC with a `Z` suffix, because the old string depended on the Rails version,
`ActiveSupport.to_time_preserves_timezone` and the server's `TZ`. Its description says plainly
that this follows posthog-js and that "no spec requires it". That is the drift this change closes:
a customer-visible wire format that five SDKs already agree on and three write differently.

## What Changes

- **Capture**: a new requirement, "Capture serializes date and time property values as ISO 8601
  strings in UTC".
  - A value that names an instant serializes as ISO 8601 normalized to its equivalent UTC instant,
    with the `Z` suffix — the same normalization the envelope `timestamp` already follows.
  - A calendar-date value with no time of day serializes as `YYYY-MM-DD` and is never shifted into
    another day.
  - The rule applies recursively, and to the person and group property payloads the SDK sends.
  - The number of fractional-second digits stays unspecified: the SDKs write none, three or six
    today, and nothing downstream depends on the count.
- Three scenarios.
- **BREAKING** serialized-output change for the SDKs that keep the caller's offset today
  (posthog-python, posthog-go, posthog-dotnet). The instant is unchanged and PostHog parses both
  forms, so filters and breakdowns are unaffected; anything reading the raw string sees a
  different value.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture`: define how date and date-time property values serialize.

## Impact

Specifications only. No SDK changes in this PR. Already conformant: posthog-js, posthog-ios,
posthog-android, posthog-flutter and posthog-ruby (from #372). Need a follow-up: posthog-python,
posthog-go and posthog-dotnet, plus posthog-ruby for nested values. Not surveyed in this change:
posthog-php, posthog-elixir, posthog-rs, posthog-unity, posthog-kmp, posthog-godot, posthog-java
and posthog-unreal.
