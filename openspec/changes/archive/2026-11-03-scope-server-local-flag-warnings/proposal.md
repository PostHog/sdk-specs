## Why

Server SDKs warn about client-only flags as soon as local definitions load, even when the application never evaluates those flags. This canonical specification correction follows [posthog-js #5532](https://github.com/PostHog/posthog-js/pull/5532), which fixes the warning without removing definitions used for browser bootstrapping.

## What Changes

- Exclude definitions with `evaluation_runtime: "client"` from server SDKs' definition-load warnings for experience continuity and unsupported definitions.
- Keep warnings for server/shared definitions and definitions with a null or absent runtime. Preserve the existing once-per-definition rule when a flag changes runtime.
- Retain client-only definitions and local evaluation behavior.
- Add matching acceptance scenarios without claiming harness or SDK execution support.
- Audit all SDK repositories requested by the maintainer and post the affected SDKs and harness gaps as a comment on the specification PR.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `evaluate-flags`: scope definition-load warnings to server-applicable definitions without changing snapshot filtering or evaluation.

## Impact

The canonical warning requirement and `acceptance/public/evaluate-flags.feature` change. SDK implementations remain in their own repositories. The Node implementation is tracked in posthog-js #5532. Other SDK follow-ups and the audited revisions are recorded in the PR comment.

No public SDK API, evaluation result, dependency, or harness implementation changes are part of this PR.
