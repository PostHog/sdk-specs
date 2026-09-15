## Context

PostHog/posthog-js#4941 uses independent counters for emitted exceptions and aggregate member inspections. Duplicate and cyclic references do not consume output slots, so a 50-entry output limit alone can still scan arbitrarily large collections.

## Goals / Non-Goals

**Goals:** Agree on the existing 1,000-inspection limit and its observable truncation behavior for SDK ports.

**Non-Goals:** Change the wire format, add telemetry fields, change cause traversal, or alter the implementation in posthog-js.

## Decisions

Use one capture-wide counter shared by nested aggregate collections. Increment it before reading each member, including reads that throw and members skipped as duplicates or cycles. Do not reset it when descending into another aggregate. Stop inspecting members after 1,000 attempts, while allowing the already-inspected member and its cause chain to finish within the 50-entry limit.

A per-aggregate budget would multiply work in nested graphs. An output-only budget does not bound duplicate scans. A time-based budget would produce nondeterministic output across SDKs. The fixed limit matches the JavaScript reference implementation and its regression tests.

## Risks / Trade-offs

- Valid members after a long duplicate prefix can be omitted even when fewer than 50 entries are emitted. Explicit scenarios document this deliberate work bound.
- Ports could count only emitted children or reset the counter per group. Shared-budget and duplicate-prefix scenarios distinguish these implementations.

## Migration Plan

Archive this change on the same branch to sync the canonical spec. SDK ports can use the JavaScript tests as reference cases. No SDK deployment is part of this documentation PR.

## Open Questions

None. The maintainer approved finalizing the 1,000-inspection budget as the shared target.
