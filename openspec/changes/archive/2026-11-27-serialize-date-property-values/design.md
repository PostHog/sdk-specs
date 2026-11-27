## Context

Date and date-time property values reach the wire either through a normalization step the SDK runs
before encoding (posthog-js, posthog-ios, posthog-android, posthog-flutter, posthog-ruby) or
straight through the runtime's JSON encoder (posthog-python, posthog-go, posthog-dotnet). The two
groups disagree on one thing: whether the string keeps the caller's UTC offset.

The adjacent spec text is `openspec/specs/capture/spec.md` step 5, which requires the envelope
`timestamp` to be "serialized in ISO 8601 and normalized to its equivalent UTC instant regardless
of the input's original timezone/offset". Nothing extends that to property values.

Each repo was read at `origin/main` on 2026-11-27. The reading is from source, not from running
the SDKs end to end.

| SDK | Date-time property value today | Status under this change | Where |
|---|---|---|---|
| posthog-js (browser, node, react-native) | UTC, `Z`, 3 fractional digits | conforms | `packages/core/src/utils/json-utils.ts`: `toJsonSafeValue` maps a `Date` through `Date.prototype.toISOString`. |
| posthog-ios | UTC, `Z`, no fractional digits | conforms | `PostHog/Utils/DictUtils.swift`: `ISO8601DateFormatter().string(from:)`, whose default time zone is GMT. |
| posthog-android | UTC, `Z`, 3 fractional digits | conforms | `internal/PostHogDateUtils.kt`: `ISO8601Utils.format(date, true)`, via `GsonDateTypeAdapter`. |
| posthog-flutter | UTC, `Z` | conforms | `posthog_flutter/lib/src/core/utils/utils.dart`: `date.toUtc().toIso8601String()`. |
| posthog-ruby | UTC, `Z`, 3 fractional digits | conforms at the top level; nested values are untouched | `lib/posthog/utils.rb`: `datetime_in_iso8601` after PostHog/posthog-ruby#372. `isoify_dates` uses `transform_values`, so it only walks the top level. |
| posthog-python | keeps the caller's offset, microsecond precision | follow-up | `posthog/request.py`: `DatetimeSerializer.default` returns `obj.isoformat()`. |
| posthog-go | keeps the caller's offset (RFC 3339 from `encoding/json`) | follow-up | `properties.go` holds values as-is; `makeTimestamp` in `message.go` normalizes only the envelope. |
| posthog-dotnet | keeps the caller's offset (`System.Text.Json` round-trip form) | follow-up | `src/PostHog/Json/JsonSerializerHelper.cs` registers no date converter. |

Not surveyed: posthog-php, posthog-elixir, posthog-rs, posthog-unity, posthog-kmp, posthog-godot,
posthog-java, posthog-unreal.

## Goals / Non-Goals

- **Goal**: one wire format for date-time property values across SDKs, matching the envelope
  `timestamp` rule that already exists.
- **Non-goal**: fractional-second precision. The SDKs write zero, three or six digits; the spec
  leaves the count open rather than forcing a change nobody has asked for.
- **Non-goal**: date and time types the runtime does not represent as an instant or a calendar date
  (a bare time of day, a duration, a zone-less "local date-time"). Those stay unspecified.
- **Non-goal**: parsing. This covers what the SDK writes, not what it accepts.

## Decisions

### Decision: UTC with `Z` wins

Options considered:

- **A. UTC with `Z` (chosen).** Matches the envelope `timestamp` rule, matches the five SDKs that
  normalize today, and makes the string independent of the host's `TZ` and of framework settings
  such as `ActiveSupport.to_time_preserves_timezone`.
- **B. Keep the caller's offset.** Preserves more information, and is what three SDKs do. Rejected:
  it makes the same instant produce different strings on different hosts, and it contradicts the
  envelope rule the same SDKs already follow for `timestamp`.
- **C. Leave it unspecified.** Rejected: it is the status quo, and PostHog/posthog-ruby#372 shows
  the cost — an SDK had to pick a format with nothing to point at.

The instant is identical either way and PostHog parses both forms, so filters, breakdowns and
cohorts behave the same under A and B. What changes is the raw string a `beforeSend` hook, a
downstream export, or an email template variable sees.

### Decision: calendar dates are not instants

A value that carries a calendar date and no time of day serializes as `YYYY-MM-DD`. Normalizing it
through an instant would move it to the previous or next day for some offsets. posthog-ruby already
treats `Date` separately from `Time` and `DateTime` for this reason.

## Risks / Trade-offs

- The follow-ups in posthog-python, posthog-go and posthog-dotnet are a visible change to the
  string customers see. Each should ship with a changeset that says so, as posthog-ruby did.
- `System.Text.Json` and `encoding/json` write dates from the encoder, so the .NET and Go
  follow-ups need a converter rather than a one-line change.
