## Why

PostHog's replay settings can now ship as **trigger groups** (`version: 2`, a `triggerGroups`
array) instead of the flat V1 fields. The server sends the groups to every platform
(`posthog/models/remote_config.py:231-243` at posthog `origin/master` `0280b22a`), and posthog-js
has evaluated them since `V2TriggerGroupStrategy` landed
(`packages/browser/src/extensions/replay/external/recording-strategies.ts:356` at posthog-js
`origin/main` `480395c443`). Each group carries its own AND/OR legs, sample rate and minimum
duration, and groups combine as a union, so V2 changes the combination model rather than adding a
field to it. The mobile SDKs are picking it up now (posthog-ios on `feat/replay-v2-trigger-groups`
`23ffc5a905`, posthog-android and posthog-react-native in flight), and cross-SDK decisions had to
settle where the ports differed (the mobile local sample-rate cap, `null` group rate, the
pending-conditions debug value).

`session-replay-ingestion-controls` covers V1 only. Its scope note (`spec.md:9`) calls V2 a
"web-only extension ... specified separately" but names no spec, and its Purpose says mobile SDKs
implement "only the restrictive (AND) combination", which stops being true once a mobile SDK
evaluates groups. No capability states the V2 contract, so the ports have nothing to converge on.

## What Changes

- **New capability `session-replay-trigger-groups`:** the version-selection rule (`version: 2`
  with a non-empty `triggerGroups` selects groups; anything else is V1), which V1 fields stop
  applying, the group shape, how a group's legs combine, the event, URL, screen and flag legs,
  group-level and per-event property filters, per-session activation, per-group sampling with the
  pinned hash and string-rate coercion, the union across groups, the effective minimum duration
  and its re-check on every flush, the global URL blocklist, interaction-hold release, the
  trigger-group debug properties, the explicit stop/start latch, and the hybrid split.
- **Modify `session-replay-ingestion-controls`:** scope the minimum-duration gate to V1 and name
  the group minimum as its V2 replacement; add the trigger-group bullet and scenario to the hybrid
  requirement; say that an event-leg group activation releases the interaction hold while URL and
  flag legs do not. Hand edits to the Purpose, the scope note and the `version` comment point at
  the new capability instead of calling V2 web-only.
- **Modify `session-replay-debug-properties`:** the three trigger-group keys stop being
  browser-only and become "SDKs that implement trigger groups"; the pending-conditions key gains
  its V2 value `trigger group "<name>": <condition>`; the out-of-scope list hands those keys to the
  new spec.
- **Provenance.** Every requirement cites posthog-js `origin/main` `480395c443` file:line and the
  covering test (the cited files are byte-identical at `f216d94acb`). Three rules have no web
  analog and come from the cross-SDK contract, not from posthog-js source: the screen leg (R9,
  C9), the `$snapshot` skip (R23, C8) and the hybrid split (R25, C2, C3); the spec says so where
  it states them. Fourteen requirements have no posthog-js test on `origin/main` and are marked
  decision-based with a one-line reason each: the V1 fallback on an empty group list (R1), the
  ignored V1 fields (R2), the local sample rate (R3), the screen leg (R9), the `{flag, variant}`
  form in a group (R10), group-level filters on the URL leg (R11), re-arming on a new session
  (R13), the hash input and `Math.abs` (R14), string rates (R15), the lowest of several minimums
  (R17), release on a lowered minimum (R18), `$snapshot` (R23), the stop latch across a reload
  (R24) and the hybrid split (R25). Adding posthog-js tests for the web-testable ones is a
  posthog-js follow-up, not a prerequisite for this change.

## Capabilities

### New Capabilities

- `session-replay-trigger-groups`: the V2 trigger-group contract — selection over the V1 fields,
  group shape and legs, property filters, per-group sampling, union, effective minimum, debug keys,
  explicit stop, and the hybrid split.

### Modified Capabilities

- `session-replay-ingestion-controls`: minimum-duration gate scoped to V1 with the group minimum
  as its V2 counterpart; hybrid requirement gains the trigger-group bullet; interaction hold
  defines an event-leg group activation as an event trigger.
- `session-replay-debug-properties`: the trigger-group keys apply to every SDK that implements
  trigger groups; the pending-conditions key gains its V2 value; the out-of-scope list no longer
  calls those keys browser-only.

## Impact

- `openspec/specs/session-replay-trigger-groups/spec.md` — created on archive from this change's
  delta; the Purpose, Applicability, Public signature and Behavior sections are added by hand at
  archive time, as `2026-10-29-add-emails` did.
- `openspec/specs/session-replay-ingestion-controls/spec.md` — three MODIFIED requirements synced
  on archive, plus hand edits to lines 7, 9 and 31 outside the Requirements section.
- `openspec/specs/session-replay-debug-properties/spec.md` — three MODIFIED requirements synced
  on archive.
- `README.md` — one new capability row.
- `acceptance/private/session-replay-trigger-groups.feature` — new, descriptive scenarios with no
  `@sdk:` tags; `acceptance/private/session-replay-ingestion-controls.feature` — a V1 comment on
  the minimum-duration block and one `@hybrid` scenario.
- `compliance/*.md` — untouched; the weekly audit adds the new row. posthog-js would be the first
  SDK to pass it.
- No SDK code. Reference implementation: posthog-js (web). Mobile model: posthog-ios
  `feat/replay-v2-trigger-groups` `23ffc5a905`, cited only where the spec records a mobile
  adaptation or a divergence to fix.
