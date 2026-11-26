## 1. Spec delta

- [x] 1.1 Verify every posthog-js citation against `origin/main` `480395c443` (cited files byte-identical at `f216d94acb`), the server payload against posthog `0280b22a`, and the mobile model against posthog-ios `23ffc5a905`
- [x] 1.2 Write the `session-replay-trigger-groups` delta: 25 requirements, each with the js source, the covering test and at least one scenario
- [x] 1.3 Mark the 14 untested-in-reference requirements decision-based with a one-line reason: R1 fallback on an empty group list, R2 ignored V1 fields, R3 local sample rate, R9 screen leg, R10 `{flag, variant}` in a group, R11 group-level filters on the URL leg, R13 re-arm on a new session, R14 hash input and `Math.abs`, R15 string rates, R17 lowest of several minimums, R18 release on a lowered minimum, R23 `$snapshot`, R24 stop latch across a reload, R25 hybrid split
- [x] 1.4 Modify `session-replay-ingestion-controls`: minimum-duration gate scoped to V1, hybrid trigger-group bullet and scenario, interaction-hold event-leg rule, as full copied-and-edited blocks
- [x] 1.5 Modify `session-replay-debug-properties`: trigger-group keys for every SDK that implements trigger groups, the V2 pending-conditions value, the out-of-scope hand-off, as full copied-and-edited blocks
- [x] 1.6 Add the README capability row after Session Replay Ingestion Controls

## 2. Acceptance

- [x] 2.1 Add `acceptance/private/session-replay-trigger-groups.feature` with descriptive scenarios for R1, R2, R5, R6, R7, R9, R11, R13, R15, R16, R17, R18, R19 and R20, no `@sdk:` tags
- [x] 2.2 Comment the V1 minimum-duration block and add the `@hybrid` trigger-group scenario in `acceptance/private/session-replay-ingestion-controls.feature`

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict` before and after archive and compare against `origin/main` (69 passed, 0 failed before this change)
- [x] 3.2 Run `posthog-test-harness-v2 discover --specs <specs> --feature acceptance/private/session-replay-trigger-groups.feature --report <path>` and record the unbound step count as a gap
- [x] 3.3 Run `git diff --check`
- [x] 3.4 Archive the change with `openspec archive add-session-replay-trigger-groups`, then add the Purpose, Applicability, Public signature and Behavior sections to `openspec/specs/session-replay-trigger-groups/spec.md` and hand-edit `openspec/specs/session-replay-ingestion-controls/spec.md` lines 7, 9 and 31, as `2026-10-29-add-emails/tasks.md` 4.1 did

Validation: `openspec validate --specs --strict` (CLI 1.6.0) reports 69 passed, 0 failed on `origin/main` and 70 passed, 0 failed after archive. `posthog-test-harness-v2 discover` at harness `003d416` parses both features: `session-replay-trigger-groups.feature` 22 cases, `session-replay-ingestion-controls.feature` 31 cases, 0 harness-ready in each. No step is bound yet, so these are specification checks, not executed SDK conformance tests.
