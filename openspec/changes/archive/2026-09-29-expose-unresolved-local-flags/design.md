## Context

The local evaluator already raises an inconclusive signal per flag. The snapshot layer uses it to decide on a remote fallback and then discards it. In local-only mode, or when the fallback fails, the caller is left with an absent key and a `flag_missing` error.

## Goals / Non-Goals

Goals: let a caller detect that a flag with a loaded definition has no value, and why, without changing what existing accessors return.

Non-goals: evaluate experience continuity locally, or change the rule that unresolved flags are absent from the snapshot.

## Decisions

- **A separate channel, not a third flag state.** Unresolved flags stay out of the snapshot's flags. Accessors, the key list and capture enrichment keep their contract, so the change is additive and an unresolved flag can never be attached to an event as a value.
- **Any inconclusive cause, not only experience continuity.** A missing property or an unavailable cohort is dropped the same way. One channel with a reason covers every cause.
- **Reasons form a closed set, split by what the caller can do.** A definition-side cause (`experience_continuity`, `unsupported_definition`) never resolves in local-only mode, so the fix is the flag or the SDK version. A call-side cause (`missing_context`) is fixed by the caller. `unresolved_dependency` points at another entry. SDK-specific reasons would let two SDKs pick different strings for one cause, so a new reason lands here first.
- **Unresolved means no value in the final snapshot.** A flag that a remote fallback resolved is not unresolved. The same rule then covers local-only mode, a failed fallback, and a fallback that did not return the key.
- **One reason per flag, in a fixed precedence.** A flag can be inconclusive for several causes at once. The evaluator spec defines no order for the filters in a group and continues past an inconclusive group, so "the first cause found" would let two SDKs report different reasons for one flag and call. The order `experience_continuity`, `unsupported_definition`, `unresolved_dependency`, `missing_context` gives every SDK the same answer and puts the causes a caller cannot fix by passing context first.
- **An unloaded dependency is a definition problem.** A dependency with no loaded definition can never have its own entry, so `unresolved_dependency` would point at nothing. It reports `unsupported_definition`. A circular dependency is a definition problem too and reports the same reason.
- **The reason describes the flag's own definition and call.** A flag that is inconclusive because a dependency has experience continuity reports `unresolved_dependency`, so `experience_continuity` always points at the flag to change.
- **Inactive flags and out-of-scope flags are never unresolved.** An inactive flag resolves to `false`. A flag outside the requested keys was not asked for, even when the evaluator inspects it as a dependency.
- **Check `active` before experience continuity.** An inactive flag with experience continuity must resolve to `false`. SDKs that check experience continuity first (posthog-python, posthog-go, posthog-ruby, posthog-php and posthog-dotnet) need to reorder, as posthog-node did in PostHog/posthog-js#3623. The reorder also reaches the older single-flag APIs: with remote fallback they return the same `false` without a request, and in local-only mode they return `false` instead of null.
- **A key without a local definition is never unresolved.** It stays `flag_missing`. This keeps the distinction the change exists to draw.
- **A dedicated error value, for every SDK that evaluates locally.** `local_evaluation_inconclusive` replaces `flag_missing` for such a key, so the event data separates the two cases without code changes on the caller's side. It is a `SHOULD` on its own, not tied to the optional snapshot member, because it is the part that helps without any new API.
- **A load-time warning as well, not instead.** A definition-side cause (`experience_continuity`, `unsupported_definition`) is known as soon as definitions load, so a one-time warning surfaces it early with no new API. It cannot replace the snapshot member: a log line is not something code can check, and `missing_context` only shows up per call.
- **The warning is its own requirement.** It applies to every SDK that evaluates locally, so it has its own requirement and capability tag (`@unresolvable_flag_warning_capable`) instead of sitting inside the optional snapshot member. A maintainer who skips the snapshot member still sees it.
- **Older single-flag APIs are out of scope.** `getFeatureFlag` and `isFeatureEnabled` return one value and have no snapshot to carry the list. Extending the error value to them is a separate change.
- **Optional, behind capability tags.** No SDK ships this today. `MAY` follows the `@evaluation_runtime_capable` precedent. The snapshot member uses `@unresolved_flags_capable` and the warning uses `@unresolvable_flag_warning_capable`.
- **Filtered snapshots do not carry the entries.** They scope capture enrichment, and the filters already define what happens to a key that is absent from the source snapshot. One rule for every SDK is simpler than an optional carry-over with its own scoping and error rules. The original snapshot is where unresolved flags are inspected.

## Risks / Trade-offs

- A caller that does not read the unresolved flags sees no change in return values. The new error value in `$feature_flag_called` is the only signal that needs no code.
- Dashboards that count `flag_missing` see fewer events from SDKs that adopt this, because unresolved keys move to the new value.

## Validation

Strict OpenSpec validation. The acceptance feature file gains the scenarios of the delta.
