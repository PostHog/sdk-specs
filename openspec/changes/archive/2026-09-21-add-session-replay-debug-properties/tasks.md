## 1. Verification (grounding checks before this change is approved)

- [x] 1.1 Verify the attach site, `$snapshot` exclusion, and error-capture fallback by reading
  `packages/browser/src/posthog-core.ts:1989-2000`, `:2024`, `:2026`, `:2027-2028` on posthog-js
  `origin/main`, re-pinned to `d6df4f496` (verified unchanged at those lines from the earlier
  `f902b705e` pin)
- [x] 1.2 Verify the minimal `$feature_flag_called` allowlist strips these keys via
  `packages/core/src/featureFlagUtils.ts:263` and the two
  `__tests__/__snapshots__/featureflags.test.ts.snap` snapshots (minimal vs full shape)
- [x] 1.3 Verify the `$recording_status` value set via
  `packages/browser/src/extensions/replay/external/triggerMatching.ts:85-96`, and the
  trigger-status value set (`trigger_activated` / `trigger_pending` / `trigger_disabled`) via
  `triggerMatching.ts:54-59`
- [x] 1.4 Verify the getter/fallback merge points (`lazy-loaded-session-recorder.ts:2636`,
  `:2740` `sdkDebugProperties` getter, `:2749` `flush_hold_reason` emission, `:1588`
  stale-hold-reason fix; `session-recording.ts:463` fallback) and the trigger-caching
  `register_for_session` sites (`triggerMatching.ts:304`, `:416`, `:530`)
- [x] 1.5 Cross-check every requirement against the two repo plans
  (`posthog-ios/.claude/plans/replay-debug-properties.md`,
  `posthog-android/.claude/plans/replay-debug-properties.md`) so the spec states the contract
  both PRs already implement, not a divergent one

## 2. Spec delta

- [x] 2.1 Write the `specs/session-replay-debug-properties/spec.md` delta: attach rule,
  `$recording_status` value set with the mobile subset, session/queue/hold-reason/trigger/mode
  keys, always-attach-when-unconfigured, stop/uninstall reset, out-of-scope boundary — each
  requirement has ≥1 scenario
- [x] 2.2 Confirm every requirement cites a posthog-js `file:line` or states "no covering test
  in posthog-js; covered by <native test>" for the mobile-only surface, per this repo's
  descriptive-not-aspirational convention
- [x] 2.4 Settle the two defects found on posthog-android#782 / posthog-ios#825 in the spec rather
  than per-SDK: session keys follow the event's `$session_id` (derived from the UUIDv7 when a caller
  supplied it), and an event timestamped before the current session carries none of the keys unless
  a snapshot was persisted at that time (design decisions 5 and 6)
- [x] 2.3 Run `openspec validate add-session-replay-debug-properties` (or
  `openspec validate --specs --strict` after apply) and resolve any errors

## 3. Per-SDK implementation (tracked in their own repos, not this change)

- [ ] 3.1 posthog-ios: implement per
  `~/Projects/PostHog/posthog-ios/.claude/plans/replay-debug-properties.md` (issue #726)
- [ ] 3.2 posthog-android: implement per
  `~/Projects/PostHog/posthog-android/.claude/plans/replay-debug-properties.md` (issue #640)
- [ ] 3.3 posthog-js: add a covering test, `recording-status-coverage.test.ts`, that pins down
  today's undertested behavior in one place — the "Validated on `origin/main` `60644f71`"
  manual run in the repo plans (9 vitest cases, throwaway worktree, not committed) found that
  custom, `$pageview`, `$identify`, `$set`, `$exception`, and `$feature_flag_called` all carry
  `$recording_status` and `$sdk_debug_retry_queue_size`; `$snapshot` carries neither; with
  replay started, status is non-`disabled` and `$sdk_debug_replay_internal_buffer_length` is
  present; and a cookieless-mode event drops `$recording_status`. Deferred, local-only — not
  required for this change to merge; posthog-js's own test suite already covers the individual
  requirements above via `posthog-core-also.test.ts` and the `featureflags.test.ts.snap`
  snapshots.
- [ ] 3.4 Both SDKs SHALL add one native test per spec scenario, each test naming the scenario it
  covers (by the scenario's heading text) in its test name or a comment, so the mapping from
  spec scenario to native test is auditable without re-deriving it:
  - posthog-ios (Swift/XCTest, e.g. `PostHogSDKTest.swift`,
    `PostHogSessionReplayRemoteConfigBufferTest.swift`): one test per scenario in
    `specs/session-replay-debug-properties/spec.md` — attach/strip (4 scenarios), value set (3),
    session/queue/hold-reason/trigger/mode (12), consistent-snapshot (1), error-capturing (2),
    exception/identify/set (2), unconfigured (1), stop/uninstall (3), cross-spec reconciliation
    (2), session-id/previous-process rules (5) — 31 scenarios total as of this change
  - posthog-android (Kotlin/JUnit, e.g. `PostHogTest.kt`, `PostHogReplayIntegrationTest.kt`):
    the same 31 scenarios, one test each
- [ ] 3.5 (Optional) e2e task: run the posthog-ios and posthog-android example apps against the
  `posthog-mock-server` skill's mock server and assert, on the `/batch` events it captured, that
  `$recording_status` and the applicable `$sdk_debug_*` keys from this spec are present with the
  expected values for at least one event per `$recording_status` value the platform can emit
  (`disabled`, `buffering`, `active`)

## 4. Downstream follow-up (separate changes, not this one)

- [ ] 4.1 `session-replay-debug-counters`: the deferred Tier-2 counter keys (buffer size/length
  in bytes, flushed size, full-snapshot counts, throttled/oversized-mutation drops,
  last-snapshot metadata), once at least one platform ships the underlying counters
- [ ] 4.2 Unity: its own edit site in `AddSdkProperties`
  (`com.posthog.unity/Runtime/PostHogSDK.cs:453`), emitting `disabled | active | paused`
- [ ] 4.3 React Native: a JS-side change in `getCommonEventProperties()`
  (`posthog-rn.ts:651`) for the JS-buildable subset, plus a native bridge pull method for the
  native-only keys (queue depth, hold reason, trigger status)
- [ ] 4.4 posthog-flutter: forward `throttleDelay` into the native replay config and raise the
  native dependency floors, once posthog-ios and posthog-android release (tracked in
  `~/Projects/PostHog/.claude/plans/replay-debug-properties-followups.md`)
