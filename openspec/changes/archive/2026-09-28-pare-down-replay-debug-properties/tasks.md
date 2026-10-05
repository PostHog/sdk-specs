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
- [x] 1.2 Read posthog-ios#859 at head `fda0e238c` (local checkout confirmed at that SHA): required
  keys, eligibility, claim/commit/release (`PostHog/PostHogSDK.swift:596-656`); the tiered merge
  and ungated queue depth (`:714-741`); `buildEvent` / `queueEvent` (`:1898-1974`); the `close()`
  reset (`:2757-2760`); the crash-context snapshot (`:3265-3294`);
  `PostHogEvent.carriesReplayDebugBundle` (`PostHog/Models/PostHogEvent.swift:37`);
  `captureMode(config:)` and `debugProperties()`
  (`PostHog/Replay/PostHogReplayIntegration.swift:1803-1805`, `:1829-1884`)
- [x] 1.3 Confirm the covering tests exist and assert what the delta cites:
  `posthog-core-also.test.ts:102`, `:188`, `:806`; `featureflags.test.ts.snap:72`, `:103`;
  `PostHogSessionManagerTest.swift:282`, `:316`, `:342`, `:375`, `:401`, `:441`, `:469`, `:506`,
  `:541`, `:566`, `:594`, `:625`, `:656`, `:684`, `:709`; `PostHogSDKTest.swift:383`, `:415`,
  `:444`, `:460`, `:477`, `:633`, `:705`, `:793`;
  `PostHogSessionReplayRemoteConfigBufferTest.swift:474`, `:500`, `:523`, `:566`, `:627`, `:659`;
  the drop-counter tests `lazy-sessionrecording.test.ts:4455` and
  `lazy-sessionrecording-compression.test.ts:394`, `:427`
- [x] 1.4 Record where the references differ observably: posthog-js lets an event captured inside
  `before_send` also carry the optional bundle, and iOS does not (design decision 4)
- [x] 1.5 Confirm iOS has no analog of the drop counters (`git grep _dropped` at posthog-ios#859
  head `b9bfa38fa` finds nothing) and that the debug-property code is unchanged between
  `fda0e238c` and `b9bfa38fa`
- [ ] 1.6 **Re-pin the iOS citations once posthog-ios#859 merges.** Re-verify every
  posthog-ios `file:line` and test name in `openspec/specs/session-replay-debug-properties/spec.md`
  against the merged SHA, and replace the `fda0e238c` pins. If #859 changes shape before merging,
  open a follow-up change to reconcile the spec.

## 2. Spec delta

- [x] 2.1 MODIFIED the every-event attach requirement to cover the required keys only; ADDED the
  eligible-event gate for the optional bundle, the 30-second window that starts at acceptance, the
  ungated queue-depth key, and the `$snapshot` drop-counter requirement; MODIFIED the value set,
  key list (tier per key, capture-mode classification, two removed keys), error-capture citation,
  exception/identify/set, unconfigured-replay, stop/uninstall, event-time, and out-of-scope
  requirements. Each requirement has at least one scenario
- [x] 2.2 Every touched requirement cites posthog-js `928990ded` and/or posthog-ios#859
  `fda0e238c` `file:line` plus the covering test, or says the test is planned
- [x] 2.3 Run `openspec validate pare-down-replay-debug-properties --strict` and, after archive,
  `openspec validate --specs --strict --no-interactive`; resolve any errors

## 3. Per-SDK implementation (tracked in their own repos, not this change)

- [x] 3.1 posthog-js: #5144 merged
- [ ] 3.2 posthog-ios: land #859
- [ ] 3.3 posthog-android: port the required/optional split, the eligible-event gate, the
  acceptance-started wall-clock window with one outstanding claim, the crash-context snapshot, and
  the capture-mode classification; the drop counters are not required; drop
  `$sdk_debug_current_session_duration` and
  `$sdk_debug_replay_throttle_delay_ms`; one test per scenario in this spec
- [ ] 3.4 posthog-flutter: inherits the native `buildProperties` path once both native SDKs
  release; the earlier `throttleDelay`-forwarding follow-up is moot now that the key is gone
- [ ] 3.5 Both mobile SDKs: the still-planned scenarios — session start derived from a
  caller-supplied UUIDv7 `$session_id`, `$identify` / `$set` assertions, the `close()` window
  reset, Android's previous-process-crash and no-handler tests

## 4. Downstream follow-up (separate changes, not this one)

- [ ] 4.1 Unity: its own edit site in `AddSdkProperties`, emitting `disabled | active | paused`
  (unchanged from the original change)
- [ ] 4.2 React Native: a JS-side change for the JS-buildable subset plus a native bridge pull
  for the native-only keys (unchanged from the original change)
- [ ] 4.3 posthog-js: consider holding one outstanding claim across `before_send` so a nested
  capture does not also carry the optional bundle (design decision 4)
