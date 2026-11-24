## Why

The canonical `$exception_source` table fixes the first-party value for each capture boundary, so two SDKs cannot name the same boundary differently. posthog-ruby shipped four more boundaries that the table does not list:

- [posthog-ruby#335](https://github.com/PostHog/posthog-ruby/pull/335) captures Action Cable connection and channel failures as `rails.action_cable`.
- [posthog-ruby#341](https://github.com/PostHog/posthog-ruby/pull/341) captures a terminating `rails runner` failure in the exit hook as `rails.runner`.
- [posthog-ruby#346](https://github.com/PostHog/posthog-ruby/pull/346) reports Sidekiq job failures as `sidekiq.error_handler` (per failed attempt, through Sidekiq's error handler) and `sidekiq.death_handler` (terminal failure, through Sidekiq's death handler).

The convention clause already permits an unlisted integration to coin a `<technology>.<stable_hook>` value, so none of these violates the contract. The registry is nonetheless out of date, and a worker integration in another SDK has nothing to copy.

## What Changes

- Record `rails.action_cable`, `rails.runner`, `sidekiq.error_handler`, and `sidekiq.death_handler` as canonical first-party `$exception_source` values.
- Add a scenario fixing the category for a worker's terminal failure handler: `mechanism.type` `task` with `mechanism.handled` false, and the concrete worker hook in `$exception_source` rather than in `mechanism.type`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `exception-event-metadata`: extend the canonical first-party capture-source table with the Action Cable, Rails runner, and Sidekiq boundaries, and pin the worker-handler category.

## Impact

Only `openspec/specs/exception-event-metadata/spec.md` changes. No public SDK API, event shape, mechanism vocabulary, level vocabulary, or acceptance-harness change. The Ruby implementation already ships these values; no other SDK is required to add Action Cable, runner, or Sidekiq capture, and an SDK without those boundaries stays conformant.
