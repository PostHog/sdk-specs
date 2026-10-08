## 1. Verification (grounding checks against the references)

- [x] 1.1 Read posthog-js `origin/main` `928990ded` (contains #5144, merged as `bd66ceef9`) with
  `git show 928990ded:<path>`: `REQUIRED_REPLAY_PROPERTIES`, the event denylist, and the interval
  (`packages/browser/src/posthog-core.ts:190-204`); the paused flag (`:545`); `before_send` and
  arming (`:1948-1962`); the tiered merge (`:2166-2178`); the recorder getter
  (`lazy-loaded-session-recorder.ts:2767-2781`); the persisted keys read back
  (`session-recording.ts:51-61`, `:487-499`) and their `hidden` exposure
  (`persistence-key-policy.ts:192-200`); the four drop counters
  (`lazy-loaded-session-recorder.ts:531-536`, `:1618-1621`, `:1715-1719`, `:2380-2403`,
  `:2954-2968`; `mutation-throttler.ts:140`, `:159`)
- [x] 1.2 Read posthog-ios `origin/main` `88f4b6b56` for the mobile behavior the spec keeps: the
  integration's `debugProperties()` and `captureMode(config:)`
  (`PostHog/Replay/PostHogReplayIntegration.swift:1862-1864`, `:1899-1956`); the no-integration
  fallback and the debug-map merge (`PostHog/PostHogSDK.swift:703-714`); the queue-depth key
  (`:638-640`); the `$snapshot` exclusion (`:1552`, `:666`); the minimal-envelope allowlist
  (`:1561-1562`, `:2612-2617`); the crash-context snapshot (`:3251-3290`)
- [x] 1.3 Confirm the covering tests exist and assert what the delta cites:
  `posthog-core-also.test.ts:102`, `:188`, `:806`; `featureflags.test.ts.snap:72`, `:103`; the
  drop-counter tests `lazy-sessionrecording.test.ts:4455` and
  `lazy-sessionrecording-compression.test.ts:394`, `:427`; posthog-ios
  `PostHogSDKTest.swift:407`, `:441`, `:457`, `:474`, `:695`, `:783`;
  `PostHogSessionReplayRemoteConfigBufferTest.swift:486`, `:512`, `:536`, `:580`;
  `PostHogSessionReplayEventTriggersTest.swift:235`
- [x] 1.4 Record where posthog-js and the mobile contract differ: posthog-js lets an event captured
  inside `before_send` also carry the optional bundle, and the spec asks mobile SDKs to hold at
  most one outstanding claim (design decision 4)
- [x] 1.5 Confirm posthog-ios has no analog of the drop counters (`git grep _dropped` at
  `origin/main` `88f4b6b56` finds nothing)

## 2. Spec delta

- [x] 2.1 MODIFIED the every-event attach requirement to cover the required keys only; ADDED the
  eligible-event gate for the optional bundle, the 30-second window that starts at acceptance, the
  ungated queue-depth key, and the `$snapshot` drop-counter requirement; MODIFIED the value set,
  key list (tier per key, capture-mode classification, two removed keys), error-capture citation,
  exception/identify/set, unconfigured-replay, stop/uninstall, event-time, and out-of-scope
  requirements. Each requirement has at least one scenario
- [x] 2.2 Every touched requirement cites posthog-js `928990ded` `file:line` plus the covering
  test where posthog-js implements it, cites posthog-ios `origin/main` `88f4b6b56` only for
  behavior already there, and marks mobile tests that do not exist yet as planned
- [x] 2.3 Run `openspec validate pare-down-replay-debug-properties --strict` and, after archive,
  `openspec validate --specs --strict --no-interactive`; resolve any errors

## 3. Downstream follow-up (separate changes, not this one)

- [ ] 3.1 posthog-ios: port the required/optional split, the eligible-event gate, the
  acceptance-started wall-clock window with one outstanding claim, the crash-context snapshot
  rules, and the capture-mode classification; drop `$sdk_debug_current_session_duration` and
  `$sdk_debug_replay_throttle_delay_ms`; one test per scenario in this spec
- [ ] 3.2 posthog-android: the same port, plus Android's previous-process-crash and no-handler
  tests
- [ ] 3.3 posthog-flutter: inherits the native `buildProperties` path once both native SDKs
  release; the earlier `throttleDelay`-forwarding follow-up is moot now that the key is gone
- [ ] 3.4 Both mobile SDKs: the planned scenarios — session start derived from a caller-supplied
  UUIDv7 `$session_id`, `$identify` / `$set` assertions, and the `close()` window reset. The
  drop counters are not required of either
- [ ] 3.5 Unity: its own edit site in `AddSdkProperties`, emitting `disabled | active | paused`
  (unchanged from the original change)
- [ ] 3.6 React Native: a JS-side change for the JS-buildable subset plus a native bridge pull for
  the native-only keys (unchanged from the original change)
- [ ] 3.7 posthog-js: consider holding one outstanding claim across `before_send` so a nested
  capture does not also carry the optional bundle (design decision 4)
