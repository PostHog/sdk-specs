## Why

The canonical `$exception_source` table lists three Rails capture boundaries: `rails.middleware`, `rails.error_reporter`, and `rails.active_job`. [posthog-ruby #338](https://github.com/PostHog/posthog-ruby/pull/338) added two more. Streaming failures escape after the response headers are sent, so the exception middleware never sees them; the integration now captures them from Rails' own `log_error` paths and tags them `rails.live` and `rails.streaming_template`.

The convention clause already permits an unlisted integration to coin a `<technology>.<stable_hook>` value, so the shipped behavior is not a violation. The table is nonetheless out of date: it is where first-party values are fixed, and leaving two shipped Rails sources off it invites a second SDK to pick different names for the same boundaries.

## What Changes

- Record `rails.live` and `rails.streaming_template` as canonical first-party `$exception_source` values in the capture-source table.
- Add a scenario fixing the category for a streaming boundary: the capture is still `mechanism.type` `middleware` with `mechanism.handled` false, because the failure escaped application streaming work.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `exception-event-metadata`: extend the canonical first-party capture-source table with the two Rails streaming boundaries and pin their capture category.

## Impact

Only `openspec/specs/exception-event-metadata/spec.md` changes. No public SDK API, event shape, mechanism vocabulary, or acceptance-harness change. The Ruby implementation already ships this; no other SDK is required to add streaming capture, and an SDK without a streaming boundary stays conformant.
