## Context

The canonical identify spec says a server distinct id is required, while the tracing-header spec describes explicit/context/generated identity for server capture. The current `@both` identify negative scenario conflates client identity-state behavior with server event delivery. The v2 harness currently enforces `@sdk:server` / `@sdk:client`, but `@server` / `@client` are the established acceptance and OpenSpec vocabulary. Node's existing adapter maps `distinct_id` to the public `distinctId` field; it should not manufacture context or an id.

## Goals / Non-Goals

**Goals:** Specify server identify identity precedence and personless generated-id delivery; preserve the existing client contract and explicit-id cases; test the no-context path through public identify and flush; keep native throws visible as failures.

**Non-Goals:** Decide `alias` source/target semantics, modify SDK production behavior, emulate tracing context in an adapter, select every acceptance case, or change CI/image pins. The context-precedence and explicit-over-context scenarios need a future faithful request-context binding before being selected in the harness.

## Decisions

- Use `@server` and `@client` as the sole scope tags on new/updated acceptance scenarios, rather than duplicating `@sdk:server` / `@sdk:client`. Teach the harness to apply these tags to native case applicability, with scenario-specific scope taking precedence over a feature-level `@both`. Preserve support for existing migration-only `@sdk:` tags until that corpus can be migrated independently; selection by case ID remains separate from applicability.
- Observe the received `$identify` event after public flush. Check a UUID-shaped root distinct id and typed `$process_person_profile: false`; do not inspect queues or invent a stable UUID. Use the public SDK call without `distinct_id` in the Node adapter.
- Keep the no-context case isolated from tracing middleware; the context-precedence rule belongs in the OpenSpec delta now, but acceptance coverage for it is deferred until the adapter can exercise the SDK's public request-context helper faithfully.
- Archive and sync the OpenSpec delta on the specs branch before the PR merges. Reconcile the identify spec's non-requirement prose (signature, flow, error handling) with the synced requirement in the same workflow and validate the resulting spec. No direct canonical edit before the delta is prepared.

## Risks / Trade-offs

- **Previously divergent SDKs fail a newly selected test** → Report which public methods drop, return an error, or throw and identify separate SDK work; do not weaken the assertion or silently change production code.
- **Historical v2 migration tags have a different spelling** → Retain their applicability behavior while the acceptance corpus uses `@server` / `@client`; test both corpora for unintended selection changes.
- **An explicit context test without a public context binding could create a false pass** → Keep it normative in OpenSpec but not selected as a v2 acceptance test yet.
- **The Gherkin scenario is only a draft before apply** → Complete the delta and OpenSpec validation before applying it to canonical files.

## Migration Plan

Apply the approved OpenSpec change in this specs worktree, archive it with the CLI workflow, validate canonical specs, then validate harness and real Node adapter on their corresponding follow-on branches. Existing PRs and image pins remain as they are until reviewed stacked changes are ready for separate rollout.

Audited implementation follow-ups, separate from this spec change:

- **Go:** `Identify.Validate()` in `identify.go` requires `DistinctId`, and the `Identify` branch of `EnqueueWithContext` in `posthog.go` validates before resolving request context. Resolve explicit/context/generated identity before validation and emit a personless marker for a generated id; preserve the `error` return for other errors.
- **Ruby:** `FieldParser.parse_for_identify` calls `parse_common_fields`, which raises in `check_presence!` when `distinct_id` is absent. Resolve identity before parsing or make identify-specific parsing use request context / a generated UUID; do not raise to the application.
- **.NET:** `PostHogClient.IdentifyAsync` calls `PostHogApiClientExtensions.IdentifyAsync`, which passes its required `distinctId` directly to `SendEventAsync`. Unlike capture, this path does not call `PostHogContextHelper.ResolveCaptureContext`; the public catch filter excludes argument errors. Add context/generated identity resolution and the personless property to identify, and handle invalid input without rejecting callers.
- **Node:** `PostHog.identify` calls `_sendPreparedEvent`, whose `_prepareEventMessage` resolves explicit/context/UUID and sets `$process_person_profile = false` on generated ids. Keep the adapter faithful to omitted inputs; validate through the real wire path before claiming conformance.
