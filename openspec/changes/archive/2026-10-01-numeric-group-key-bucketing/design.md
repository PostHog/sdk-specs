## Context

Group keys arrive through an untyped map (`map[string]interface{}`, `dict`, `Record<string, unknown>`), so the SDK cannot assume a string. The flags service already defines the answer for the types JSON can carry, and the spec should follow it rather than leave each SDK to guess.

## Goals / Non-Goals

Goals: one rendering rule for group keys, and a safe outcome for a key the rule does not cover.

Non-goals: redefine the bucketing hash, or restrict what a caller may put in the groups map.

## Decisions

- **Numbers follow the service's JSON encoding.** Bucketing a numeric id locally the way `/flags` buckets it keeps local and remote evaluation in agreement, which is the whole point of local evaluation. Falling back to the API for every numeric key would be safe but would make a common shape un-evaluable locally.
- **Unsupported types are inconclusive, not a guess.** Booleans, arrays, objects and null have host spellings that do not agree across languages (`True` vs `true`), so rendering them would produce an answer that disagrees with the server. Inconclusive keeps remote evaluation eligible, which is the existing recovery path for context the evaluator cannot resolve.
- **Never crash, never silently decide.** The two failure modes posthog-go had are both called out: a panic on the caller's goroutine, and a condition quietly skipped so the flag answered `false` without a fallback.

## Risks / Trade-offs

- An SDK whose runtime cannot distinguish an integer from a float inherits the ambiguity already described by the backend-compatible stringification requirement; this change does not add a new one, it points at the same rule.

## Validation

`openspec validate --specs --strict`.
