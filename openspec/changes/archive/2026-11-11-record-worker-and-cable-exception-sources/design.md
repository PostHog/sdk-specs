## Context

`$exception_source` names the concrete integration that captured an event; `mechanism.type` names the semantic boundary category. The table of first-party values is the registry that keeps the two from drifting apart across SDKs. Ruby now captures at four boundaries that no other SDK has reached yet: a WebSocket connection/channel dispatch, a terminating CLI runner, and the two distinct Sidekiq callbacks (per-attempt error handler and terminal death handler).

## Goals / Non-Goals

**Goals:** Register the four shipped values and state the capture category a worker's terminal failure handler carries.

**Non-Goals:** Requiring any SDK to add these integrations, adding configuration, extending the mechanism category vocabulary, or changing how `$exception_source` is derived.

## Decisions

- Two Sidekiq values, not one. The error handler fires on every failed attempt and the death handler fires once a job is terminal; they answer different questions and the Ruby integration selects between them by policy, so collapsing them would lose the distinction the wire already carries.
- `rails.action_cable` is one value for connection callbacks and channel actions. Both run in the same Action Cable dispatch boundary, and the channel and action are already carried as ordinary properties, so splitting the source would duplicate information with no analytical gain.
- `rails.runner` stays a Rails value rather than a generic `ruby.at_exit`. The boundary exists because Rails converts a runner failure into a process exit; a plain Ruby `at_exit` hook is a different boundary and may be registered later.
- The worker-handler scenario pins only category and handled state. Level is already covered by the capture-boundary metadata table, and this change does not alter it.
- Existing non-conforming Ruby values (`rails`, `rails_error_reporter`, and the non-retry `active_job`) are out of scope. They predate this registry and reconciling them is an SDK-visible change, not a table extension.

## Risks / Trade-offs

- A later SDK may capture worker failures at a callback that is neither of Sidekiq's. The convention clause still covers that case and the table can grow again.
- Naming the Sidekiq values after Sidekiq's own callbacks ties them to that library's vocabulary. That is deliberate: the callbacks are the stable hooks, and a queue-agnostic name would hide which one fired.

## Migration Plan

Sync and archive this change in the same PR. The Ruby SDK already emits these values, so no SDK migration follows.

## Open Questions

None for this registry extension.
