## Context

#74 shipped the accessor as the headline and the filter as an optional add-on. The review asked for one surface and for the filter to be `SHALL` if it must exist. This change keeps the filter and removes the accessor from the contract.

## Goals / Non-Goals

Goals: one mandatory shape for the runtime feature, so SDKs converge and conformance loops can check it.

Non-goals: change the presence, absence or silence rules, or make the runtime feature mandatory for every server SDK.

## Decisions

- **Filter only.** Bootstrapping a client is the use case, and `only(filter)` does it in one call on the existing filter API. A per-key accessor answers the same question one key at a time and would be a second shape to keep in step.
- **Unknown never matches, and there is no way to read it.** Without the accessor a caller cannot tell an unknown runtime from `"server"`; both are absent from a runtime-filtered snapshot. That is the intended default: unknown is not client-safe. A caller that wants those flags anyway filters by explicit key. A criterion that opts unknown runtimes in is left for a later change if a deployment that does not report the field needs it.
- **Outer `MAY` stays.** Only one SDK ships the feature. Requiring it everywhere would make every other server SDK non-conformant today.
- **Scenarios keep their fixtures.** The accessor scenarios become filter scenarios over the same definitions, so an SDK that implemented #74 re-targets its steps without new setup.

## Risks / Trade-offs

- Debugging why a flag was not forwarded needs the definitions, not the snapshot. The runtime is a definition field, so the definitions are where it is inspected.

## Validation

Strict OpenSpec validation. The acceptance feature file is updated to match the scenarios.
