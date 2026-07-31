## Why

Three SDKs independently shipped the same bug fix within days of each other:

- posthog-js#4328 "identify anonymous users with matching IDs"
- posthog-ios#742 "identify anonymous user when id already matches persisted distinct id"
- posthog-android#666 "identify anonymous user when id already matches persisted distinct id"

The bug: when `identify(id)` is called with an `id` that already equals the persisted
distinct id, but the SDK still considers the user **anonymous** (e.g. the distinct id was
seeded by a bootstrap or a device/anonymous id that happens to equal the id the caller now
passes to `identify`), the old code fell into the "same distinct id" branch, which only acts
when properties are supplied. With no properties, the call was dropped entirely: no event,
and — critically — the ambient identified-state flag was never set to `true`. The person
profile stayed anonymous indefinitely, even though the caller explicitly called `identify`.

All three SDKs converge on the same fix: treat "same distinct id, still anonymous" as an
identity-state transition in its own right — mark the user identified and emit exactly one
person-processed `$set` event (not `$identify`, since there is no anonymous id to merge),
carrying any supplied properties (or empty `$set`/`$set_once` if none were supplied). The
transition fires regardless of whether properties were supplied. Feature flags are reloaded
only if properties were supplied, since the identified-state flag itself isn't part of the
`/flags` request.

`openspec/specs/identify/spec.md` currently documents the **old, buggy** behavior as
canonical: line 112 says "Same distinct id, no properties → log 'already identified', drop,"
with no distinction for the anonymous case. This is the exact defect the three PRs fixed —
the spec is not merely silent, it names the wrong winner.

## What Changes

- **Requirement prose** (`Canonical identify behavior`): adds a new scenario for the
  matching-id-while-anonymous transition.
- **Behavior section** (client-side flow, step 3 "Decide the emission path"): splits the old
  "Same distinct id" bullets into three cases — (a) still anonymous → identity-state
  transition emitting `$set` regardless of properties, (b) already identified with
  properties → `$set` as before, (c) already identified with no properties → drop as before.
- **Summary table** ("Duplicate-call suppression" row): notes that the suppression rule only
  applies once already identified; the anonymous case transitions instead of suppressing.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `identify`: the single `Canonical identify behavior` requirement gains one new `@client`
  scenario. The three existing scenarios are unchanged. Behavior-section prose (outside the
  requirement delta) is corrected to match, per this repo's convention of aligning prose at
  archive time.

## Impact

- `openspec/specs/identify/spec.md` — source of truth, updated via this change's delta plus a
  prose correction applied at archive.
- Implementations: posthog-js, posthog-ios, and posthog-android already conform
  (PostHog/posthog-js#4328, PostHog/posthog-ios#742, PostHog/posthog-android#666). Other SDKs
  not checked in this pass.
- No acceptance-harness changes in this proposal; the new scenario is written so a future
  harness port can implement it directly (fresh harness, "SDK has not yet identified a user",
  `identify` called with the current distinct id, no properties, assert one `$set` and zero
  `$identify` events).
- **Low-confidence detail, flagged for human review:** this pass only verified posthog-js,
  posthog-ios, and posthog-android. Server SDKs are out of scope (no anonymous-id concept per
  this spec's existing client/server table). Other client SDKs (Flutter, React Native) were
  not checked for the same fix and may still have the old behavior — worth a follow-up audit.
