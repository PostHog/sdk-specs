## Why

[posthog-js#4493](https://github.com/PostHog/posthog-js/pull/4493) (merged 2026-08-12, closing
posthog-js#862) changed the browser SDK's `reset()` signature from a plain boolean
(`reset(resetDeviceId?: boolean)`) to also accept an options object
(`reset(options?: boolean | ResetOptions)`), where `ResetOptions` carries `resetDeviceID` plus a
`bootstrap` object (`distinctID` / `isIdentifiedID`, `featureFlags`, `featureFlagPayloads`,
`sessionID`) applied immediately after the reset completes. This lets an app that manages its own
anonymous IDs (or has server-rendered flag values for the next anonymous user) hand them to
`reset()` directly instead of reloading the page.

Two places in sdk-specs are now stale:

1. `openspec/specs/reset/spec.md`'s "Surface variants" section documents the browser signature as
   the old `reset(resetDeviceId?: boolean): void` only — missing the new options-object form
   entirely.
2. `openspec/specs/bootstrap/spec.md`'s Purpose statement says bootstrap is "applied once when
   identity is first established, ... and dropped on `reset()`" — which is no longer categorically
   true. A plain `reset()` still drops the *original* setup-time bootstrap (unchanged, still
   covered by the existing "Bootstrapped flags are not resurrected after reset" scenario), but a
   caller can now pass a **new** bootstrap explicitly to `reset()` itself, which is honored.

## What Changes

- **New requirement** on `reset`: `Reset MAY accept bootstrap options to seed the next identity`,
  documenting the optional `bootstrap` (and `resetDeviceID`) reset-options surface as an allowed,
  SDK-specific extension — mirroring how `bootstrap/spec.md` already documents its own optional
  `sessionID` extension as "an allowed variation applicable to SDKs with a client-side session
  manager." Two scenarios: applying a custom anonymous distinct id after reset, and a plain reset
  (no bootstrap option) continuing to behave as before.
- Prose-only corrections (no other requirement/scenario changes):
  - `reset/spec.md` "Surface variants": add the browser `options?: boolean | ResetOptions` form
    alongside the still-accurate legacy boolean form.
  - `bootstrap/spec.md` Purpose statement: qualify "dropped on `reset()`" to note the SDK-specific
    exception where a caller supplies a fresh bootstrap to `reset()` itself.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `reset`: gains one new, explicitly optional requirement (`Reset MAY accept bootstrap options to
  seed the next identity`) with two scenarios, plus a "Surface variants" documentation fix. All
  existing requirements and scenarios are unchanged and continue to hold for SDKs without this
  extension.
- `bootstrap`: Purpose prose corrected to acknowledge the reset-time bootstrap escape hatch. No
  requirement or scenario changes — the existing "Bootstrapped flags are not resurrected after
  reset" scenario still holds for a *plain* reset with no bootstrap option supplied.

## Impact

- `openspec/specs/reset/spec.md` — source of truth, updated via this change's delta plus a direct
  prose fix to "Surface variants".
- `openspec/specs/bootstrap/spec.md` — direct prose fix to the Purpose statement only.
- Source: [posthog-js#4493](https://github.com/PostHog/posthog-js/pull/4493).
- **Confirmed browser-only so far.** The PR's own "Sub-libraries affected" checklist marks only
  `posthog-js (web)` and `@posthog/types`, not `posthog-node`, `posthog-react-native`, or
  `@posthog/react-native-plugin`. The new requirement is phrased as a MAY/optional extension (like
  bootstrap's own `sessionID` extension) precisely because no other SDK has shipped it yet — this
  is not asserted as a cross-SDK requirement.
- **Low-confidence / flagged for reviewer attention:** the interaction between reset-time bootstrap
  and cookieless mode, session-ID validation/clock-skew tolerance, and "a later plain reset restores
  the original init-time bootstrap metadata" are all real behaviors in the PR but are deliberately
  *not* encoded as separate scenarios here to keep this change small — a reviewer may want a
  follow-up change to cover them if they're judged contractual rather than incidental.
