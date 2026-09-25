## Context

PostHog/sdk-specs#74 recorded the evaluation runtime contract with an accessor as the headline and the filter as an optional add-on. The review asked to prefer the filter and to make it `SHALL` if it is meant to exist. This change resolves that without dropping the accessor.

## Goals / Non-Goals

Goals: one mandatory shape for the runtime feature, so SDKs converge and conformance loops can check it.

Non-goals: change the presence, absence or silence rules, change the acceptance scenarios, or make the runtime feature itself mandatory for every server SDK.

## Decisions

- **Filter is mandatory, and first.** Bootstrapping a client is the use case, and `only(filter)` does it in one call on the existing filter API. An SDK that exposes the runtime SHALL expose the criterion.
- **Accessor stays, as the primitive.** The filter is specified in terms of the value the accessor returns. The filter drops unknown runtimes by design, so the accessor is the only way to see "unknown" and to keep those flags. It is a map lookup on data the snapshot already holds, so keeping it costs nothing.
- **Outer `MAY` stays.** Only one SDK ships the feature. Requiring it everywhere would make every other server SDK non-conformant today, the same reason `@payload_default_capable` is optional. The `SHALL` binds the shape once the feature exists.
- **No new scenarios.** The filter scenario already exists under `@evaluation_runtime_capable`. The change is in the requirement prose.

## Risks / Trade-offs

- An SDK author reading only the accessor paragraph could still ship it alone. The requirement now opens with both surfaces to make that harder to miss.

## Validation

Strict OpenSpec validation. The acceptance feature file is unchanged.
