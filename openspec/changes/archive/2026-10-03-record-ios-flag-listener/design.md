## Overview

A surface-list and scenario update to an existing capability. No new capability, no signature
change.

## Key Decisions

- **Pin "invoked on a failed load", not a uniform payload shape.** The canonical signature already
  describes `errorsLoading`; what was never stated is that a failed load still notifies at all. An
  app that blocks its UI until the listener fires hangs forever otherwise, which is the failure the
  iOS implementation and browser failed-load path address. Payload and error-context assertions are
  scoped to SDKs that expose a payload-carrying listener.
- **Last known flags, not an empty set.** Clearing on failure would make every listener treat a
  transient network error as "all flags off", which is a worse default than stale values. Both
  implementations keep the cached values.
- **Leave quota-limited responses out.** iOS notifies with the cached flags and `errorsLoading:
  false`; browser currently does not notify at all, and the fix for it is unmerged. Two SDKs
  disagreeing with one side still in review is not a settled contract, so the failed-load scenario
  excludes quota limiting explicitly.
- **Record iOS in the narrative rather than restructuring the variant list.** The existing split
  between payload-carrying and readiness-only surfaces still describes the field accurately; iOS
  joins the payload-carrying side.

## Alternatives Considered

- **Also require that `reset()` never replays the previous identity's flags.** Correct, and
  posthog-ios tests it, but no other SDK's behavior was audited for this change, so it is left for a
  change that can state the winner across SDKs.
- **Require `errorsLoading` to be a boolean on every invocation.** That is posthog-js#5045's
  contract, not yet merged. Deferred to avoid writing an unreleased behavior into the spec.

## Open Questions

- Whether a quota-limited flags response should notify listeners, and with what `errorsLoading`,
  needs a decision across iOS and browser. Not settled here.
