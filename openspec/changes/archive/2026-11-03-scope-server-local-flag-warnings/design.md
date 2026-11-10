## Context

The warning scan is separate from flag evaluation. A server can hold client-only definitions for browser bootstrapping without ever evaluating the flags that need a remote fallback. The current warning requirement does not distinguish those definitions.

The user approved making the warning scope from [posthog-js #5532](https://github.com/PostHog/posthog-js/pull/5532) the canonical server contract. The SDK audit records implementation follow-ups separately from this specification change.

## Goals / Non-Goals

**Goals:** Exclude client-only definitions from server definition-load warnings, preserve warning deduplication, and keep client definitions usable locally.

**Non-Goals:** Change flag evaluation, snapshot runtime filtering, SDK public APIs, client SDK behavior, or implement other SDK and harness fixes in this repository.

## Decisions

- Filter only the warning scan. Dropping definitions globally would break server-side evaluation for browser bootstrapping.
- Exclude only the explicit string `"client"`. A server or shared runtime, null, and a missing field remain eligible for the warning. This is warning eligibility, not a new default for snapshot runtime filtering, which still treats missing metadata as unknown.
- Rebuild warning deduplication from eligible definitions. A flag changed to client-only stops warning, and its return to a server-applicable definition warns again.
- Keep the acceptance scenarios descriptive under the existing warning capability tag. The audited harness revision has no warning-observation or definition-runtime bindings. Do not add `@sdk:server` tags or claim SDK execution until those bindings and real adapters are verified.

## Risks / Trade-offs

- Other SDKs may still warn for client-only definitions. Record immutable audit evidence and follow-up owners in the PR comment rather than treating the specification PR as an SDK rollout.
- Eager warnings no longer mention a client-only flag even if an application later explicitly evaluates it. Evaluation outcomes and fallback eligibility remain unchanged.
- Harness discovery cannot execute the warning contract yet. Record missing bindings and rely on the linked Node PR's focused regression tests and standalone before/after example for current implementation evidence.
