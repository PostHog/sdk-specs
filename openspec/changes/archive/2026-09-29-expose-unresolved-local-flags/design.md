## Context

The local evaluator already raises an inconclusive signal per flag. The snapshot layer uses it to decide on a remote fallback and then discards it. In local-only mode, or when the fallback fails, the caller is left with an absent key and a `flag_missing` error.

## Goals / Non-Goals

Goals: let a caller detect that a flag with a loaded definition has no value, and why, without changing what existing accessors return.

Non-goals: evaluate experience continuity locally, narrow when the evaluator treats experience continuity as inconclusive, or change the rule that unresolved flags are absent from the snapshot.

## Decisions

- **A separate channel, not a third flag state.** Unresolved flags stay out of the snapshot's flags. Accessors, the key list and capture enrichment keep their contract, so the change is additive and an unresolved flag can never be attached to an event as a value.
- **Any inconclusive cause, not only experience continuity.** A missing property or an unavailable cohort is dropped the same way. One channel with a reason covers every cause.
- **Reasons are stable strings with a small defined set.** `experience_continuity` is the case callers ask about, and `inconclusive` covers the rest. An SDK MAY add more specific reasons, so the set can grow without a spec change per cause.
- **Unresolved means no value in the final snapshot.** A flag that a remote fallback resolved is not unresolved. The same rule then covers local-only mode, a failed fallback, and a fallback that did not return the key.
- **The reason describes the flag's own definition.** A flag that is inconclusive because a dependency has experience continuity reports `inconclusive`, so `experience_continuity` always points at the flag to change.
- **Inactive flags and out-of-scope flags are never unresolved.** An inactive flag resolves to `false`. A flag outside the requested keys was not asked for, even when the evaluator inspects it as a dependency.
- **A key without a local definition is never unresolved.** It stays `flag_missing`. This keeps the distinction the change exists to draw.
- **A dedicated error value.** `local_evaluation_inconclusive` replaces `flag_missing` for an unresolved key, so the event data separates the two cases without code changes on the caller's side.
- **Optional, behind a capability tag.** No SDK ships this today. `MAY` follows the `@evaluation_runtime_capable` precedent.
- **Filtered snapshots do not carry the entries.** They scope capture enrichment, and the filters already define what happens to a key that is absent from the source snapshot. One rule for every SDK is simpler than an optional carry-over with its own scoping and error rules. The original snapshot is where unresolved flags are inspected.

## Risks / Trade-offs

- A caller that does not read the unresolved flags sees no change in return values. The new error value in `$feature_flag_called` is the only signal that needs no code.
- Dashboards that count `flag_missing` see fewer events from SDKs that adopt this, because unresolved keys move to the new value.

## Validation

Strict OpenSpec validation. The acceptance feature file gains the scenarios of the delta.
