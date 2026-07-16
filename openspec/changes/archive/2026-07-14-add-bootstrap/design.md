## Context

`bootstrap` is a shipped feature in `posthog-js`. The browser package implements the richest form (identity, flags, payloads, session id, plus init-time identity reconciliation); the shared core package that powers React Native and Node implements a subset (identity, flags, payloads). `posthog-android`, `posthog-ios`, and `posthog-flutter` have no bootstrap support. This spec describes the canonical target from the two JS implementations so the mobile SDKs have a contract to converge on.

The two JS surfaces disagree on two visible points, which the spec handles differently:
- Field casing: browser uses `distinctID` / `isIdentifiedID`; core uses `distinctId` / `isIdentifiedId`. The spec treats field names as semantic and lets each SDK spell them per platform convention.
- Scope: `sessionID` bootstrap exists only in the browser and is marked as allowed variation. Anonymous-to-identified reconciliation also originates in the browser but is specified as the canonical identity behavior, with the non-overwrite-only rule as the fallback for SDKs that cannot merge at init.

## Goals / Non-Goals

**Goals:**
- Define the bootstrap config surface and the identity / feature-flag / session semantics both JS implementations share.
- Pin the precedence rules that make bootstrap safe: never overwrite persisted identity, and let a fresh `/flags` response win over bootstrapped flag values.
- Specify the `$feature_flag_called` enrichment (`$feature_flag_bootstrapped_response`, `$feature_flag_bootstrapped_payload`, `$used_bootstrap_value`) so bootstrap use is observable downstream.
- Make identity reconciliation the canonical identity behavior (with non-overwrite as the fallback for SDKs that cannot merge at init), and mark session bootstrap as allowed variation rather than forcing it on SDKs without a matching session model.

**Non-Goals:**
- Implementing bootstrap in any SDK — this change is spec-only.
- Changing `feature-flag-cache`, `remote-config`, or `setup` requirements; they already reference bootstrap as an external layer and stay as-is.
- Specifying the browser `identity_distinct_id` convenience config, which is a browser-local alias that promotes into `bootstrap` and carries no cross-SDK contract.

## Decisions

- **Field names are semantic; casing follows each platform's convention.** The two shipped surfaces already disagree — browser uses `distinctID`, the shared core uses `distinctId` — and native SDKs will follow their own language idioms (Swift and Kotlin favor `distinctID`). Declaring one spelling canonical would make a shipped SDK retroactively wrong for no benefit, so the spec fixes the field semantics and lets each SDK spell them idiomatically. The reference names `distinctId` / `isIdentifiedId` in the spec text are for readability only.
- **Non-overwrite seeds a fresh install; reconciliation handles a differing identified bootstrap.** When no identity is persisted, the SDK seeds the bootstrap identity directly. When an identified bootstrap meets an *existing* local identity, the SDK reconciles as the browser does — merging an anonymous local user into the identified id via `identify()`, or preserving a different already-identified user with a warning. The non-overwrite-only rule (ignore the bootstrap whenever any identity is persisted) remains a documented fallback for an SDK that structurally cannot merge at init.
- **An identified bootstrap never becomes the device id.** Both JS surfaces keep the device/anonymous id independent of an identified bootstrap — the browser derives `$device_id` from a fresh `uuidv7()` when `isIdentifiedID` is set (`deviceID = isIdentifiedID ? uuid : bootstrapDistinctId`), and the core sets only the distinct id for an identified bootstrap. So the spec requires that only an anonymous bootstrap seeds the anonymous/device id; an identified bootstrap seeds the distinct id and identified state only. Reusing the identified id as `$device_id` would leak the person's id (often PII) into a device-scoped, reset-surviving field used for bucketing.
- **Bootstrapped flags are a base layer, not an authority.** The core merges `{...bootstrap, ...loaded}` so loaded values win; the browser replaces on load. Both converge on "loaded beats bootstrap," which is what the requirement states. Bootstrapped-only keys surviving a partial load is called out explicitly because it is easy to get wrong.
- **Bootstrap is first-session only and is dropped on reset.** Both JS surfaces apply bootstrap once when identity is first established and discard it on `reset()` — the browser re-seeds nothing on reset and flips its `_flagsLoadedFromRemote` back to false, and the core nulls the persisted bootstrap details alongside all other state. The spec therefore requires the base layer to be dropped on reset so a new user is never served the previous user's bootstrapped values, rather than a permanent layer re-merged on every load.
- **Session bootstrap is scoped to SDKs with a session manager.** Only the browser owns a client-side session id today, so `sessionID` is specified as an allowed variation keyed on UUIDv7 validity rather than a universal MUST.
- **Falsy-flag handling is left as allowed variation.** The browser filters bootstrapped flags to truthy/"active" values and keeps payloads only for active keys; the core stores all. The spec requires that provided flags be served and does not force either filtering behavior, avoiding a contract that contradicts a shipped SDK.

## Risks / Trade-offs

- **Browser vs. core divergence encoded as allowed variation** → A future cross-SDK alignment may want stricter uniformity (e.g. one field casing). Mitigation: the divergences are documented in the requirements, so a later change can tighten them deliberately rather than discovering them.
- **`$used_bootstrap_value` depends on a "flags endpoint was hit" signal** → SDKs track this differently (`FlagsEndpointWasHit` persisted property in core, `_flagsLoadedFromRemote` in browser). Mitigation: the requirement specifies the observable semantics (true until a `/flags` response arrives), not the internal flag, leaving implementations free.
- **Spec derived from two SDKs, not all** → Mobile SDKs may surface platform constraints (identity storage, session model) once they implement. Mitigation: the spec frames session bootstrap as allowed variation and gives reconciliation a non-overwrite fallback, covering the areas most likely to need platform-specific latitude.

## Open Questions

None.
