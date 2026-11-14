## Context

posthog-js selects the V2 strategy when `config.version === 2` and `triggerGroups` is a non-empty
array (`lazy-loaded-session-recorder.ts:1247-1268` at `origin/main` `480395c443`) and otherwise
runs the V1 strategy, so the V1 fields the server still sends for old SDKs are ignored on web
once groups exist. The server emits both shapes side by side
(`posthog/models/remote_config.py:231-243` at `0280b22a`). `session-replay-ingestion-controls`
promises a separate V2 spec at `spec.md:9` but none exists, and its Purpose (`:7`) and `version`
comment (`:31`) call V2 web-only. Three mobile ports are in flight and already disagree with web on
small points, so the contract is being written now, from the web source and the user's cross-SDK
decisions of 2026-11-13 and 2026-11-14.

## Goals / Non-Goals

**Goals:** one place that states the V2 contract with a posthog-js `file:line` and covering test
per requirement; make the V1 spec stop claiming V2 is web-only; keep the shared gates (enablement,
URL blocklist, interaction hold, hybrid) in `session-replay-ingestion-controls` and reference them;
record where mobile deliberately differs and where it changes.

**Non-goals:** the V1 sampling hash, the wording of `stop-session-recording/spec.md:59`, any
compliance row, the React Native minimum-duration hook signature (C3, a stacked SDK follow-up),
and posthog-js tests for the untested requirements.

## Decisions

- **A new capability, not a V2 section of ingestion-controls.** The scope note already promises a
  separate spec and only lacks a target. V2 changes the combination model — a union of groups,
  each with its own AND/OR, sampling and minimum — so a section would split sampling (`:169`),
  event triggers (`:201`), minimum duration (`:281`), AND (`:299`), OR (`:327`) and the state read
  (`:57-60`) into V1 and V2 branches. `session-replay-debug-properties` set the precedent of a
  sibling capability next to `is-session-replay-active`. Compliance tracks one row per README
  capability, so a separate row lets an SDK pass V1 and still show V2 as missing, which is the
  state of Unity and older mobile versions. The shared gates stay in ingestion-controls
  (`:105`, `:262`, `:354`, `:381`) and the new spec references them without restating them.
- **The version-selection rule lives in the new spec.** The ingestion-controls scope note points to
  it, so the rule is stated once.
- **R3, local sample rate.** posthog-js folds its local `session_recording.sampleRate` into the
  same `sampleRate` the V1 strategy reads (`session-recording.ts:267-275` → `_sampleRate`,
  `lazy-loaded-session-recorder.ts:626-629`), and the V2 status function never reads it
  (`triggerMatching.ts:799-861`), so web ignores the local rate under groups. posthog-ios caps the
  group result with its local `sessionReplayConfig.sampleRate`
  (`PostHogReplayIntegration.swift:495-500` at `23ffc5a905`). The spec states the web rule and
  allows a mobile-only local cap as an explicit variation: it is an app-level knob, not a V1 remote
  field, so it is not one of the fields R2 switches off.
- **R15, a `null` group rate is 0.** Web computes `null * 100 = 0` in `sampleOnProperty`
  (`sampling.ts:25`) and samples the group out. posthog-ios reads `NSNull` as no rate and samples
  in (`PostHogTriggerGroups.swift:99-106`); it changes. The UI always sends a number, so the case is
  defensive.
- **R23, `$snapshot` never activates a group, mobile-only and decision-based (C8).** posthog-js
  emits `eventCaptured` for every capture (`posthog-core.ts:2106`) and matches by name only
  (`triggerMatching.ts:550`), so web would let a group match `$snapshot`; the UI cannot pick that
  event, so the difference is benign and the spec does not ask web to change.
- **R24, explicit stop, stays in the new spec.** `stopSessionRecording()` SHALL hold across a
  remote config reload and `startSessionRecording()` SHALL clear it (C6;
  `posthog-core.ts:4509`, `:4526-4528`). `stop-session-recording/spec.md:59` ("resumed ... by
  config/remote-config-driven replay enablement") is not modified in this change; its wording
  conflicts with C6 and is flagged as a follow-up change on that spec.
- **R25, hybrid split, decision-based (C2, C3).** The managed layer that owns event capture
  evaluates the groups; the native SDK keeps only the V1 gates for that host; the managed layer
  hands the effective minimum to native. No merged reference exhibits it, so the spec names the
  hand-off and not its signature.
- **Pending-conditions debug value.** Every V2 SDK writes
  `trigger group "<name>": <condition>` per pending group, as web does
  (`recording-strategies.ts:649-658`). posthog-ios appends a bare `trigger_groups`
  (`PostHogReplayIntegration.swift:2120-2122`); it changes.
- **The V1 sampling hash is not pinned here.** R14 pins `simpleHash` with `Math.abs` for group
  sampling. The V1 requirement (`session-replay-ingestion-controls/spec.md:169-171`) names no hash;
  C5 applies `Math.abs` to V1 in the SDKs, and pinning it in the V1 spec is a follow-up.
- **Two feature files.** The new scenarios go in `session-replay-trigger-groups.feature`; the
  ingestion-controls feature gets a V1 comment and one `@hybrid` scenario.
- **Untested requirements are marked decision-based, tests come later.** R1 fallback, R2, R11 URL
  leg, R14 hash input, R15 strings, R17 and R18 are web-testable and listed for a posthog-js
  follow-up; R3, R9, R10 variant, R13, R23, R24 and R25 rest on source or on a decision.

## Risks / Trade-offs

- Fourteen of twenty-five requirements have no posthog-js test on `origin/main` → accepted; each
  is marked decision-based with its source line, and the web-testable ones are a posthog-js
  follow-up.
- R25 has no merged reference, so the spec states a rule no SDK on main implements → accepted; it
  records the user's contract for the hybrid ports in flight.
- The new compliance row starts unaudited for every SDK, and posthog-ios is ✅ for ingestion
  controls (`compliance/posthog-ios.md:198`) → accepted; the weekly audit adds the row.
- The debug-properties edit touches a 1,144-line spec at three places → the MODIFIED blocks copy
  the originals exactly and change only the sentences named above.
- Open sdk-specs PRs #195 and #182 touch `session-replay-privacy` only → no conflict expected.

## Migration Plan

Spec-only. Archive on this branch. SDK work follows in posthog-ios, posthog-android,
posthog-react-native and posthog-flutter PRs that cite this capability.
