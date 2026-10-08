## Context

The existing `event-batcher` spec covers thresholds, timers, caps, and FIFO slicing but not replay attribution boundaries. Replay requests differ from analytics batches: ingestion combines their snapshots under request-level metadata.

Verified backend source at [`c3bd9605588b`](https://github.com/PostHog/posthog/blob/c3bd9605588b4ae479dd3c1d2b7e5aed739578c1/rust/capture/src/events/recordings.rs#L379-L402) extracts distinct ID and session ID from the first event. [The later-event loop](https://github.com/PostHog/posthog/blob/c3bd9605588b4ae479dd3c1d2b7e5aed739578c1/rust/capture/src/events/recordings.rs#L502-L522) reads only snapshot data, and [publication](https://github.com/PostHog/posthog/blob/c3bd9605588b4ae479dd3c1d2b7e5aed739578c1/rust/capture/src/events/recordings.rs#L572-L607) emits one combined message. This is source evidence, not a deployed-version assertion.

## Goals / Non-Goals

**Goals:** Define session and identity homogeneity for replay requests; preserve the identifiers captured on queued snapshots through restart and retry; make the constraint testable through received traffic.

**Non-Goals:** Change session rotation, identity resolution, flush cadence, transport retry guarantees, or ingestion; introduce public APIs or executable compliance-harness bindings.

## Decisions

- Add a requirement to `event-batcher`, since this is a constraint on batch construction rather than a separate capability or a replay enablement control.
- Use the pair `(session ID, distinct ID)` as the minimum request boundary. Session-only grouping is insufficient when identity changes within a session. Existing limits and additional metadata boundaries remain valid.
- Specify the observable request contents, not a queue implementation. Native SDKs can send FIFO prefixes; other SDKs can organize compatible records differently without changing their recorded attribution.
- Keep analytics batching unchanged: analytics records carry their attribution independently.

### Audited implementation gaps

- **iOS 3.83.0:** [`PostHogQueue.take()`](https://github.com/PostHog/posthog-ios/blob/3.83.0/PostHog/PostHogQueue.swift#L413-L459) decodes the next queued entries without either boundary. A simulator reproduction using published React Native 4.78.0/plugin 2.12.0 captured mixed-session uploads. [iOS #895](https://github.com/PostHog/posthog-ios/pull/895) supplies the separate implementation change.
- **Android 3.71.1:** [`PostHogQueue.batchRecords()`](https://github.com/PostHog/posthog-android/blob/android-v3.71.1/posthog/src/main/java/com/posthog/internal/PostHogQueue.kt#L247-L296) sends the decoded file batch without either boundary. A separate SDK change is needed; Android was source-inspected, not runtime-reproduced.
- **Browser:** [#4897](https://github.com/PostHog/posthog-js/pull/4897) adds session isolation and [#4846](https://github.com/PostHog/posthog-js/pull/4846) adds window isolation. Neither change establishes identity-only isolation; this change does not claim browser conformance to the distinct-ID requirement.

## Risks / Trade-offs

- More requests at attribution boundaries → retain existing batch caps and permit compatible snapshots to share a request.
- Existing SDK versions diverge → record this as a canonical specification correction; implementation rollout is separate.
- A future ingestion change might support heterogeneous requests → revise the contract only after verifying the new attribution behavior, rather than relying on an unmerged backend proposal.

## Migration Plan

Apply and archive the delta in this branch. SDK changes and runnable cross-SDK acceptance coverage follow in their own repositories. No publication or deployment is part of this documentation change.
