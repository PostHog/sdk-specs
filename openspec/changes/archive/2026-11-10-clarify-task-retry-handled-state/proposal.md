## Why

Review of [posthog-ruby#336](https://github.com/PostHog/posthog-ruby/pull/336#discussion_r4513813559) exposed an ambiguity in exception handled state for background job retries. The exception escapes the job's `perform` method, but Active Job's `retry_on` handler consumes it and schedules another execution.

## What Changes

- Clarify that retry reports use the framework's job execution boundary, including its retry handler, rather than the job method alone.
- Mark a failure consumed by a framework retry handler as handled when the handler schedules another execution without letting the exception escape.
- Keep failures that escape job execution unhandled, including failures after retry exhaustion without a consuming handler.
- Do not require integrations to report retry failures or change reporting defaults.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `exception-event-metadata`: Clarify the existing handled-state requirement for framework-consumed job retries and escaping terminal failures.

## Impact

This adds no public API or dependency. It makes the existing framework-consumption rule explicit for job integrations. The associated Ruby SDK fix changes only opted-in retry metadata and preserves terminal metadata, scheduling and deduplication. SDKs that do not report retry failures need no new reporting path.
