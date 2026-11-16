## Context

The backend's detailed `/flags` response distinguishes a failed evaluation from a successful boolean false using `flags[key].failed`. Existing getter specs describe no result on evaluation failure and partial bulk results, but do not connect those rules to this wire field. The experiment-exposure and config-version-2 attribution specs already mention failed records; they do not define direct getter values.

Reference evidence, inspected at immutable revisions:

- [Backend `FlagDetails`](https://github.com/PostHog/posthog/blob/b0558549cf700f9ae9cc640ccf05ead533951834/rust/feature-flags/src/api/types.rs#L459-L472) serializes the failure marker only when true. [`create_error`](https://github.com/PostHog/posthog/blob/b0558549cf700f9ae9cc640ccf05ead533951834/rust/feature-flags/src/api/types.rs#L749-L769) sets `enabled: false`, no variant/payload, and `failed: true`.
- [Go's remote-only getter](https://github.com/PostHog/posthog-go/blob/86e57623afc6382e2e8403855dc1c269a3f13ee8/posthog.go#L2096-L2105) already treats failed details as no value. Its [error classification](https://github.com/PostHog/posthog-go/blob/86e57623afc6382e2e8403855dc1c269a3f13ee8/feature_flag_errors.go#L150-L178) reports `evaluation_failed`. This is the single-flag reference, not the poller/bulk implementation on that revision.
- [Go PR #434](https://github.com/PostHog/posthog-go/pull/434), [commit 023c983](https://github.com/PostHog/posthog-go/commit/023c9832b4bb39c3c63204bcb0fb0edd42e6fadb), adds poller and bulk/capture filtering and tests preservation of a local true value. It is an implementation in progress, not evidence of a released cross-SDK contract.

Source-level audit of known divergences, not a runtime conformance result:

| SDK and inspected revision | Evidence | Required correction |
| --- | --- | --- |
| Node, `d2e010e5e40636cde886f7abf1e44914c8cf04cf` | [Direct getter](https://github.com/PostHog/posthog-js/blob/d2e010e5e40636cde886f7abf1e44914c8cf04cf/packages/node/src/client.ts#L1837-L1867) constructs a result from enabled/variant without checking failed; [core value conversion](https://github.com/PostHog/posthog-js/blob/d2e010e5e40636cde886f7abf1e44914c8cf04cf/packages/core/src/featureFlagUtils.ts#L76-L108) also copies failed placeholders. | Return no structured result for failure without a fallback, omit failed bulk values, and classify failed tracked reads. Separate SDK changes required. |
| Python, `9d154daecc9330b806d052a631547447df941941` | [Result conversion](https://github.com/PostHog/posthog-python/blob/9d154daecc9330b806d052a631547447df941941/posthog/types.py#L613-L648) copies enabled/variant; [bulk conversion](https://github.com/PostHog/posthog-python/blob/9d154daecc9330b806d052a631547447df941941/posthog/types.py#L702-L711) includes every parsed flag. The private failure marker does not make these legacy conversions omit the result. | Check per-record failure before legacy result/bulk conversion and preserve its error classification. Separate SDK changes required. |

## Goals / Non-Goals

**Goals:**

- Make the agreed no-decision interpretation explicit for direct getters and bulk/capture merges.
- Preserve healthy boolean false and variant values, including in partial-error responses.
- Keep successful local decisions for the same evaluation context when another flag triggers remote fallback.
- Distinguish a present-but-failed remote flag from an absent key in direct getter tracking.

**Non-Goals:**

- Change public signatures, legacy scalar/boolean missing-result sentinels, retries, persistent-cache fallback policy, or cohort evaluation.
- Redesign snapshot record inclusion, unresolved reasons, filtering, or lazy access tracking in `evaluate-flags`.
- Implement SDK fixes or change acceptance-harness bindings, integration tags, or compliance claims.

## Decisions

### Interpret the per-record marker, not the response-wide error bit

Only a record explicitly marked `failed: true` establishes this per-flag failure. A response-wide `errorsWhileComputingFlags` bit can accompany successful siblings and is not a reason to drop every flag. Conversely, a failed detail remains failed even if that response-wide bit is absent or false.

Treating `enabled: false` as authoritative despite the marker was rejected: it collapses evaluation failure into a real disabled decision. Treating every partial response as a total failure was rejected because it discards healthy siblings.

### Preserve a successful local value without treating failure as a tombstone

A failed remote detail supplies no replacement value. During a single bulk evaluation it must neither overwrite nor delete an already resolved local true, false, or variant for the same identity/context. This does not authorize reuse across users or introduce a stale-result retention policy. Successful remote values keep each API's existing precedence.

### Keep getter results separate from telemetry diagnostics

A direct getter with no successful value returns its idiomatic no-result outcome rather than manufacturing a disabled structured result. Existing scalar and boolean APIs may still map that outcome to their documented sentinel/default. If the read emits `$feature_flag_called`, its error identifies `evaluation_failed`; normal dedupe, event controls, response-level errors, and unavailable-value event sentinels remain in force.

### Add normative scenarios without claiming harness execution

The change adds scenarios to the three OpenSpec capabilities through delta specs and CLI archive/sync. It does not add executable `acceptance/` cases: shared-harness binding work and real-adapter execution are separate follow-ups, not implied by OpenSpec validation.

## Risks / Trade-offs

- Existing callers may observe a no-result outcome or a missing bulk key instead of false. → Document the distinction and retain legacy public sentinel/error conventions.
- Current SDKs differ. → Record inspected source revisions and leave implementation/conformance claims to SDK-specific follow-ups.
- Reusing a local value from another context would be unsafe. → Limit merge preservation to a successful local decision for the same evaluation context.
- Snapshot missing/unresolved tracking has its own precedence rules. → Keep this clarification scoped to direct getters and bulk/capture merging rather than silently changing that separate contract.

## Migration Plan

Sync and archive this spec change on the same branch. Implement the Node/Python corrections and finish the Go fix in their SDK repositories; add executable cross-SDK coverage separately. No dependency, release pin, or SDK code changes belong in this branch.

## Open Questions

None for the agreed direct-getter and bulk/capture contract. Snapshot-specific failed-record behavior remains outside this change.
