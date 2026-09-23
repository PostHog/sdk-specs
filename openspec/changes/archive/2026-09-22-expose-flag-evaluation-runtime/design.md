## Context

`/local_evaluation` reports `evaluation_runtime` per flag definition. `/flags` does not. A server SDK that evaluates locally therefore knows the runtime for every flag it has a definition for, including one whose value it could not resolve locally and fetched from `/flags` instead. posthog-server's `getEvaluationRuntime(key)` is the shipped behavior this change records.

## Goals / Non-Goals

Goals: give callers the runtime so they can decide which flags to forward to a client, and pin down when the value is present, absent and silent.

Non-goals: have the SDK filter flags by runtime, declare the runtime on `/flags` requests (a separate wire concern already shipped in posthog-node), or require every server SDK to add the accessor now.

## Decisions

- **Pass-through, not policy.** The SDK returns the server's string and does no filtering. Which runtimes are safe to forward is the caller's decision, and hardcoding it in the SDK would need a release to change.
- **Optional accessor with a mandatory contract.** Only one SDK ships it, so the requirement is MAY for exposure and SHALL for behavior once exposed, following the `@payload_default_capable` precedent.
- **Local definition wins over remote absence.** A flag that fell back to `/flags` keeps its local definition's runtime. Otherwise a `"client"` flag whose value needed one missing person property would look unknown, and a bootstrap filter would drop it.
- **Absent is unknown, never a default.** `null` is not `"all"`. Treating it as client-safe would forward server-only flags on an older deployment that does not report the field.
- **Silent read.** Same rules as the payload accessor: reading the runtime is bookkeeping, not use of the flag's value.
- **Filter on the snapshot, not on `evaluateFlags`.** The server still branches on and captures with the full snapshot, so a runtime-scoped evaluation would mean evaluating twice per request. The runtime is a definition property, not an input to `/flags`, so the SDK would evaluate everything and drop keys afterwards anyway. A criterion on the existing in-memory filter does that without a second evaluation, and composes with the key filter. It excludes unknown runtimes; the accessor remains for callers who want them.

## Risks / Trade-offs

- A caller may read absent as "safe" anyway. The spec states the meaning; SDK docs should repeat it.
- The value is only as fresh as the loaded definitions. A runtime changed in PostHog is picked up on the next definitions refresh, like every other definition field.

## Validation

Strict OpenSpec validation and Gherkin parsing of the acceptance feature. No SDK runtime behavior is verified in this repository.
