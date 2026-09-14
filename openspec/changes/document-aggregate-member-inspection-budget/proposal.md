## Why

The exception metadata spec limits output to 50 entries but does not bound inspections of duplicate or cyclic aggregate members. PostHog/posthog-js#4941 adds a separate 1,000-member inspection budget, and reviewers requested a shared contract before other SDKs port it.

## What Changes

- Define a capture-wide limit of 1,000 aggregate member inspections, including skipped duplicates, cycles, and unreadable members.
- Clarify that this budget can stop member traversal before 50 exceptions are emitted.
- Preserve the existing traversal order, relationship metadata, and 50-entry output limit.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `exception-event-metadata`: Bound aggregate member inspection work independently of the serialized entry count.

## Impact

This proposal records the behavior implemented in https://github.com/PostHog/posthog-js/pull/4941 for agreement across SDK ports. It does not change SDK code, public APIs, or backend fields. Canonical specs will be synced by archiving on this branch after review approves the proposal.
