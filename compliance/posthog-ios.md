# posthog-ios — SDK Compliance

**Repo:** [PostHog/posthog-ios](https://github.com/PostHog/posthog-ios)
**Audited commit:** `057f4d6d0d06a928da7020c4b58ffb0858239e05` ([commit](https://github.com/PostHog/posthog-ios/commit/057f4d6d0d06a928da7020c4b58ffb0858239e05)) — audited on 2026-08-06
**Audited against sdk-specs commit:** `b59e8b430c83c5549fc396c8b092615b79d08dd4`
**Summary:** 33 ✅ · 17 🟡 · 6 ❌ · 3 ➖ · 0 ❓

Note on repo layout: `posthog-ios` is a single-package repo. Core SDK logic lives at
`PostHog/` (flat files: `PostHogSDK.swift` — the main public API surface (capture, identify,
alias, group, feature flags, session recording controls, shutdown); `PostHogConfig.swift`;
`PostHogRemoteConfig.swift` — `/flags` fetch, feature-flag/payload cache, remote replay/error-
tracking config; `PostHogStorage.swift`/`PostHogStorageManager.swift` — persistence;
`PostHogQueue.swift`/`PostHogFileBackedQueue.swift`/`PostHogLegacyQueue.swift` — batching/retry;
`PostHogApi.swift` — HTTP transport; `PostHogSessionManager.swift`; `PostHogBootstrapConfig.swift`).
Platform-specific integrations live in subfolders: `AppLifeCycle/`, `Autocapture/`, `ErrorTracking/`,
`Logs/`, `Replay/` (session replay — masking, wireframes, screenshot capture), `ScreenViews/`,
`Surveys/`, `SwiftUI/` (SwiftUI-specific modifiers), `Tracing/` (tracing-headers only — no OTLP
traces implementation exists), `PushNotifications/`. Unlike posthog-android, posthog-ios is not a
monorepo with a separate server module — there is exactly one SDK target, so any capability judged
N/A for platform reasons (e.g. local flag evaluation, flag-definition polling) is N/A because the
capability requires a personal/admin API key a mobile app cannot safely hold, not because of a
build-target split. All file paths below are relative to `/tmp/audit-posthog-ios/` unless noted.

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Alias | 🟡 | [n1] |
| 2 | Application Lifecycle | ✅ | |
| 3 | Autocapture | ✅ | |
| 4 | Before Send Hook | 🟡 | [n2] |
| 5 | Bootstrap | 🟡 | [n3] |
| 6 | Capture | ✅ | |
| 7 | Capture Exception | 🟡 | [n4] |
| 8 | Consent Gating | 🟡 | [n5] |
| 9 | Create Person Profile | ➖ | [n6] |
| 10 | Debug | ✅ | |
| 11 | Device ID Generator | ✅ | |
| 12 | Event Batcher | 🟡 | [n7] |
| 13 | Exception Steps | ✅ | |
| 14 | Feature Flag Cache | ✅ | |
| 15 | Feature Flag Called Tracker | 🟡 | [n8] |
| 16 | Flag Definition Loader | ➖ | [n9] |
| 17 | Flush | ✅ | |
| 18 | Get Anonymous ID | ✅ | |
| 19 | Get Distinct ID | ✅ | |
| 20 | Get Feature Flag | ✅ | |
| 21 | Get Feature Flag Payload | 🟡 | [n10] |
| 22 | Get Feature Flag Result | ✅ | |
| 23 | Get Feature Flags | ❌ | [n11] |
| 24 | Get Feature Flags And Payloads | ❌ | [n12] |
| 25 | Get Session ID | ✅ | |
| 26 | Group | 🟡 | [n13] |
| 27 | Group Identify | 🟡 | [n14] |
| 28 | HTTP Client | ✅ | |
| 29 | Identify | ✅ | |
| 30 | Is Feature Enabled | ✅ | |
| 31 | Is Opt Out | ✅ | |
| 32 | Is Session Replay Active | ✅ | |
| 33 | Local Feature Flag Evaluator | ➖ | [n15] |
| 34 | Logs | 🟡 | [n16] |
| 35 | On Feature Flags | ❌ | [n17] |
| 36 | Opt In | 🟡 | [n18] |
| 37 | Persistent Storage | 🟡 | [n19] |
| 38 | Register | ✅ | |
| 39 | Reload Feature Flags | ✅ | |
| 40 | Remote Config | ✅ | |
| 41 | Reset | 🟡 | [n20] |
| 42 | Reset Group Properties For Flags | ✅ | |
| 43 | Reset Person Properties For Flags | ✅ | |
| 44 | Retry Queue | ✅ | |
| 45 | Screen | 🟡 | [n21] |
| 46 | Session Manager | ✅ | |
| 47 | Session Replay Ingestion Controls | ✅ | |
| 48 | Session Replay Privacy | ❌ | [n22] |
| 49 | Set Group Properties For Flags | ✅ | |
| 50 | Set Person Properties | 🟡 | [n23] |
| 51 | Set Person Properties For Flags | ✅ | |
| 52 | Setup | ✅ | |
| 53 | Shutdown | ❌ | [n24] |
| 54 | Start Session Recording | ✅ | |
| 55 | Stop Session Recording | 🟡 | [n25] |
| 56 | Surveys | ✅ | |
| 57 | Traces | ❌ | [n26] |
| 58 | Tracing Headers | ✅ | |
| 59 | Unregister | ✅ | |

## Notes

### n1 — Alias (🟡 Partial)
- **Spec requires:** the `acceptance/public/alias.feature` scenario (tagged `@client`) requires
  the enqueued `$create_alias` event's properties to include both `alias` and `distinct_id`; the
  spec also implies a guard against an empty/blank alias.
- **SDK currently:** `alias(alias:)` (`PostHog/PostHogSDK.swift:1643-1671`) guards `isEnabled()`,
  `isOptOutState()`, and `requirePersonProcessing("alias")` correctly, but builds
  `let props = ["alias": alias]` (line ~1660) without ever setting `distinct_id`. There is also no
  guard against an empty `alias` argument — unlike `identify()`, which explicitly checks
  `distinctId.isEmpty` and drops with a log, `alias("")` proceeds to enqueue an event.
- **Backwards compatibility:** Backward-compatible — adding `props["distinct_id"] = distinctId` and
  an empty-alias guard are both purely additive; no existing field is removed or renamed.
- **Remediation:** Set `distinct_id` alongside `alias` in the `$create_alias` properties dict; add
  an early return for a blank `alias` argument, mirroring `identify()`'s pattern.

### n2 — Before Send Hook (🟡 Partial)
- **Spec requires:** hooks run in a chain, each receiving the previous hook's mutated output
  (`nil` from any hook drops the event); an exception/crash inside a hook must not crash the host
  app.
- **SDK currently:** Chain composition is correct — `Utils/BeforeSendChain.swift:17-24`
  (`blocks.reduce(value) { acc, block in acc.flatMap(block) }`) correctly threads each block's
  output into the next and short-circuits on `nil`. However, `BeforeSendBlock` is a **non-throwing**
  closure type (`PostHogConfig.swift:16`) and no `try`/`catch` (or Objective-C `@try`/`@catch`)
  wraps the invocation site (`Utils/BeforeSendChain.swift:26-29`, `PostHogConfig.swift:611-613`) —
  a Swift runtime trap (force-unwrap, index-out-of-bounds, `fatalError`) inside a hook crashes the
  host process uncaught, with no fallback to the last-good event value.
- **Backwards compatibility:** Needs deprecation path — the public `BeforeSendBlock` typealias is
  non-throwing today; wrapping invocation in an Objective-C exception-safe bridge (matching the
  existing `PHURLSessionTaskSafeAccess.m` pattern elsewhere in the repo) is additive and does not
  require a signature change, but should ship with a changelog note since it changes crash behavior
  for buggy hooks.
- **Remediation:** Wrap hook invocation in an `NSException`-catching bridge, log a distinct
  before-send warning on catch, and fall back to the input event rather than letting the trap
  propagate.

### n3 — Bootstrap (🟡 Partial)
- **Spec requires:** (optional — "MAY") a client SDK that owns a session id MAY accept a
  `sessionID` in the bootstrap config (UUIDv7), adopting it as the current session id and deriving
  the session start timestamp from its embedded timestamp; on an invalid value, SHALL log an error
  and fall back to generating a new id.
- **SDK currently:** Identity seeding (`PostHogBootstrapConfig.swift:21-95`,
  `reconcileBootstrapIdentityIfNeeded` `PostHogSDK.swift:282-321`) and feature-flag/payload
  bootstrap (`PostHogRemoteConfig.swift:105-138`, `$feature_flag_bootstrapped_response`/`_payload`
  enrichment at `PostHogSDK.swift:2375-2382`) are fully implemented and correct. However,
  `PostHogBootstrapConfig.swift` has no `sessionID`/`sessionId` field at all (confirmed via full
  read — zero matches for "session"), and `PostHogSessionManager.swift` never reads
  `config.bootstrap`, always generating its own id via `rotateSession()` → `UUID.v7String()` (line
  219). Since the spec phrases this as "MAY," this is a spec-permitted omission, not a violation —
  but iOS does own a client-side session manager, making it a natural candidate for the optional
  feature (as also flagged for posthog-android).
- **Backwards compatibility:** Backward-compatible — adding an optional `sessionId` field to
  `PostHogBootstrapConfig` and a consumption path in `PostHogSessionManager` is purely additive;
  default (absent) behavior is unchanged.
- **Remediation:** Add optional `sessionID` bootstrap support if product wants full parity with
  SDKs that implement this optional capability.

### n4 — Capture Exception (🟡 Partial)
- **Spec requires:** acceptance scenario `capture-exception.feature` ("Capturing a handled
  exception emits an exception event") requires top-level `$exception_type`/`$exception_message`
  properties on the captured event, in addition to the nested `$exception_list`.
- **SDK currently:** Frame ordering (outermost first, crash site last), exception-list/cause-chain
  ordering, and real-stack-trace preservation are all correctly implemented
  (`ErrorTracking/PostHogExceptionProcessor.swift:122-157, 171-207, 264-277, 377-379, 402-404`;
  `ErrorTracking/PostHogCrashReportProcessor.swift:69-71, 128-133`). A repo-wide grep confirms
  `$exception_type`/`$exception_message` are never written as top-level event properties — type/
  value only exist nested inside `$exception_list[].type`/`.value`
  (`PostHogExceptionProcessor.swift:218-222, 257-261`). This is the same gap independently found in
  the parallel posthog-android audit.
- **Backwards compatibility:** Backward-compatible — adding flat `$exception_type`/
  `$exception_message` properties (mirrored from `$exception_list[0]`) is purely additive.
- **Remediation:** Stamp `$exception_type`/`$exception_message` onto the outer event properties
  from the first (outermost) entry of `$exception_list`.

### n5 — Consent Gating (🟡 Partial)
- **Spec requires:** all event-producing/network-triggering operations must be blocked while opted
  out.
- **SDK currently:** The private gate `isOptOutState()` (`PostHogSDK.swift:1042-1048`) is checked
  consistently before `captureInternal`, `identify`, `alias`/`group`, log capture, exception
  capture, `startSessionRecording`, exception-steps, and push registration/capture (~10 verified
  call sites). `optOut()` also uninstalls integrations (Replay, Surveys) as part of its gating.
  However, `reloadFeatureFlags(_ callback:)` (`PostHogSDK.swift:2058-2069`) checks only
  `isEnabled()`, not opt-out state, and `PostHogRemoteConfig.swift` has zero references to opt-out
  anywhere (confirmed via grep) — so an app explicitly calling `reloadFeatureFlags()` while opted
  out still issues a `/flags` network request carrying the distinct id and groups.
- **Backwards compatibility:** Backward-compatible — adding an opt-out guard tightens internal
  behavior with no signature change.
- **Remediation:** Add an `isOptOutState()` check at the top of `PostHogSDK.reloadFeatureFlags`
  (and/or inside `PostHogRemoteConfig`'s reload path) to suppress the `/flags` call while opted out.

### n6 — Create Person Profile (➖ N/A)
- **Spec requires (Applicability, quoted):** "`client` — this is a client-side identity/profile-
  control API. In the audited implementations, this API is present in the posthog-js family (shared
  core, browser, React Native). Other audited client SDKs do not expose an equivalent public
  method."
- **SDK currently:** No `createPersonProfile()` or equivalent public method exists anywhere in the
  repo (verified via full-repo grep). iOS only exposes person-profile mode via the
  `PostHogConfig.personProfiles` enum (`never`/`always`/`identifiedOnly`, default `.identifiedOnly`)
  and an internal-only `requirePersonProcessing()` (`PostHogSDK.swift:523-531`, `private`). Per the
  spec's own applicability language naming "other audited client SDKs" as lacking this method, this
  is a legitimate N/A.
- **Backwards compatibility:** N/A — no remediation required per spec scope.

### n7 — Event Batcher (🟡 Partial)
- **Spec requires:** periodic flush after `flushInterval` elapses, ideally driven by an injectable/
  fake clock so tests can simulate elapsed time deterministically, alongside threshold and explicit
  flush.
- **SDK currently:** Threshold flush, `maxBatchSize`, and 413-triggered batch halving are all
  correctly implemented (`PostHogQueue.swift` `add()` 369-389, `flushIfOverThreshold()` 352-357,
  `handleResult()` 177-213). The periodic timer (`start()`, lines 274-288) uses
  `Timer.scheduledTimer(withTimeInterval:...)` — real wall-clock — rather than the codebase's own
  injectable clock abstraction (`Utils/DateUtils.swift:67`, `var now: () -> Date`) used elsewhere
  (queue rate-cap window, session manager, event timestamps). Tests work around this via
  `config.disableQueueTimerForTesting` plus real sleeps rather than deterministic clock advancement.
- **Backwards compatibility:** Needs deprecation path — an injectable scheduler is an internal,
  non-breaking refactor, but must preserve real-world timer semantics exactly to avoid subtly
  changing production flush cadence.
- **Remediation:** Introduce an injectable scheduler/clock abstraction for the periodic flush timer,
  defaulting to `Timer` in production but swappable in tests.

### n8 — Feature Flag Called Tracker (🟡 Partial)
- **Spec requires:** core dedup semantics for `$feature_flag_called` (suppress repeat events for an
  unchanged outcome, re-emit on change, clear on reset/shutdown); when the server signals
  `minimalFlagCalledEvents` (minimal-event mode) AND the flag's `has_experiment` is exactly `false`,
  the minimized event must still retain an allowlist including session-attribution properties
  (`$referring_domain`, UTM params, `gclid`/`fbclid`) and static platform/OS identity properties.
- **SDK currently:** Core dedup tracker (`flagCallReported` dict, `PostHogSDK.swift:75`, checked/
  updated in `reportFeatureFlagCalled` lines 2321-2341, cleared on `reset()` line 662-664 and
  `close()` lines 2501-2503) and the minimal-event gate mechanics (`sendMinimalFlagCalledEvents`
  sourced from `/flags` response, fail-safe-to-full-event default when `has_experiment` is unknown)
  are all correct. But `minimalFeatureFlagCalledProperties`
  (`PostHogSDK.swift:2293-2319`) — while it does include static platform fields (`$os_name`,
  `$os_version`, `$app_version`) — contains **zero** session-attribution properties: no
  `$referring_domain`, no `utm_source`/`utm_medium`/`utm_campaign`/`utm_content`/`utm_term`, no
  `gad_source`/`mc_cid`, no `gclid`/`fbclid`. This is the exact gap category the sdk-specs repo's
  most recent commit (`b59e8b4`) was written to catch after finding it in posthog-js/-node. Note:
  iOS has no super-property registration mechanism for UTM/click-id params at all today (grep for
  `utm_`/`gclid`/`fbclid`/`gad_source`/`mc_cid` across the whole SDK returns zero hits) — the only
  related property, `$referring_domain`, is a one-off property on a single deep-link capture event
  (`AppLifeCycle/PostHogDeepLinkHelper.swift:16-29`), not a persisted super property that would ride
  along on an unrelated `$feature_flag_called` call — so the gap is real but not currently causing
  observable data loss the way it would on a browser/server SDK.
- **Backwards compatibility:** Backward-compatible — adding entries to a `Set<String>` allowlist is
  additive; it only ever adds properties back into minimized events.
- **Remediation:** Add the UTM/session-attribution keys to `minimalFeatureFlagCalledProperties`
  (`PostHogSDK.swift:2293-2319`), following the same forward-looking allowlist pattern already used
  there, so the contract matches the cross-SDK allowlist regardless of whether iOS currently
  populates those keys.

### n9 — Flag Definition Loader (➖ N/A)
- **Spec requires (Applicability, quoted):** "`both` — audited implementations are especially
  important for server-side SDKs that support local evaluation... Some client wrappers, such as
  Flutter, expose ordinary feature-flag preload settings without owning a separate local-evaluation
  definition loader." The acceptance file (`acceptance/private/flag-definition-loader.feature`) is
  tagged `@server` only.
- **SDK currently:** No trace of any ETag-polling/personal-API-key component exists — `grep -rniE
  "etag|poll|personalApiKey|personal_api_key|local.?evaluation|flagDefinition" PostHog/` returns
  zero hits. iOS only has `config.preloadFeatureFlags` (`PostHogConfig.swift:116`), precisely the
  "ordinary preload setting" the spec's own text names as the client-wrapper alternative.
- **Backwards compatibility:** N/A — justified by the spec's own Applicability text and the feature
  file's `@server` tag; a mobile app cannot safely hold a personal/admin API key.

### n10 — Get Feature Flag Payload (🟡 Partial)
- **Spec requires:** a canonical payload getter, cache-only read, no `$feature_flag_called`
  emission by default.
- **SDK currently:** `getFeatureFlagPayload(_:)` (`PostHogSDK.swift:2270`) is marked
  `@available(*, deprecated, message: "Use getFeatureFlagResult(_:) instead...")` (line 2269).
  Behavior is fully correct — it delegates to `getFeatureFlagResult(key, sendEvent: false)` (line
  2272), never emits the event, and returns `result?.payload`. The deviation is purely a naming/
  lifecycle variance: the spec's canonical payload API is exposed to callers as deprecated in favor
  of a broader `getFeatureFlagResult` API.
- **Backwards compatibility:** Backward-compatible — the method still exists and behaves per spec;
  only its deprecation annotation changed.
- **Remediation:** None required for spec compliance today; if the method is ever removed, that
  removal needs its own deprecation path (already underway via the `@available` annotation).

### n11 — Get Feature Flags (❌ Fail)
- **Spec requires:** a public bulk getter `getFeatureFlags(): Record<string, boolean|string>`
  returning a flat key→value map, cache-only.
- **SDK currently:** No such public method exists (`grep -n "func getFeatureFlags"
  PostHog/PostHogSDK.swift` → no match). An internal, non-public `PostHogRemoteConfig.getFeatureFlags()
  -> [String: Any]?` exists (`PostHogRemoteConfig.swift:646-648`) but is used only internally
  (`PostHogSDK.swift:484, 1340`); `PostHogRemoteConfig` itself is not `public`. The only public bulk
  getter is `getAllFeatureFlags() -> [PostHogFeatureFlagResult]?` (`PostHogSDK.swift:2256`), an array
  of structured objects rather than the spec's flat map.
- **Backwards compatibility:** Backward-compatible — add a new public method surfacing the existing
  internal map; purely additive alongside `getAllFeatureFlags()`.
- **Remediation:** Add a public `getFeatureFlags() -> [String: Any]?` on `PostHogSDK` that exposes
  `remoteConfig.getFeatureFlags()`.

### n12 — Get Feature Flags And Payloads (❌ Fail)
- **Spec requires:** a combined getter returning both a flags map and a payloads map in one call.
- **SDK currently:** No such method exists (`grep -rn "getFeatureFlagsAndPayloads" PostHog/` → no
  matches). `getAllFeatureFlags()` (`PostHogSDK.swift:2256`) embeds payloads per-result inside
  `PostHogFeatureFlagResult` objects, so a caller could manually reconstruct both maps by iterating,
  but this is not the canonical paired-map shape the spec describes.
- **Backwards compatibility:** Backward-compatible — purely additive.
- **Remediation:** Add a public method exposing both the flags map and payloads map together (e.g.
  a struct with `flags`/`payloads` properties).

### n13 — Group (🟡 Partial)
- **Spec requires:** persist `groupType → groupKey`, attach `$groups` to future events, enqueue
  `$groupidentify` when properties supplied, reload flags on group change — and reject/log blank or
  empty `groupType`/`groupKey` without mutating group state.
- **SDK currently:** Storage, merge/overwrite, persistence, and flag-reload-on-change are all
  correctly implemented: `group(type:key:groupProperties:)` (`PostHogSDK.swift:1786-1804`) calls
  `groups([type: key])` (merges into persisted dict, `PostHogSDK.swift:1673-1699`) then
  `groupIdentify(...)` (line 1801); `$groups` attached via `dynamicContext()` (lines 473-482). No
  validation guard exists for blank/empty `type` or `key` — the method only guards `isEnabled()`,
  `isOptOutState()`, `requirePersonProcessing()`; an empty string for either parameter is silently
  accepted, persisted, and forwarded into a `$groupidentify` event with no warning logged.
- **Backwards compatibility:** Backward-compatible — adding validation only changes behavior for
  already-invalid (blank) inputs; no signature change.
- **Remediation:** Add an early `guard !type.isEmpty, !key.isEmpty else { hedgeLog(...); return }`
  at the top of `group(type:key:groupProperties:)` (`PostHogSDK.swift:1786`).

### n14 — Group Identify (🟡 Partial)
- **Spec requires:** `$groupidentify` event with `$group_type`/`$group_key`/`$group_set`; reject
  blank type/key with a validation warning; client SDKs may omit a standalone public
  `groupIdentify` (iOS is explicitly named as such an SDK in the spec's surface-variant table).
- **SDK currently:** No standalone public `groupIdentify` exists — only a `private func
  groupIdentify(type:key:groupProperties:)` (`PostHogSDK.swift:1701-1736`), called solely from
  `group()` (line 1801), matching the spec's explicitly-permitted iOS variant. Event shape is
  correct (`$group_type`/`$group_key`/conditional `$group_set`, lines 1714-1721). Same validation
  gap as Group: the private `groupIdentify` has no blank-check either, so an empty-type/key call
  from `group()` flows through to enqueue an invalid `$groupidentify` event.
- **Backwards compatibility:** Backward-compatible — same reasoning as Group; fixing the guard at
  the single `group()` call site closes both gaps.
- **Remediation:** Same fix as Group — one guard at `PostHogSDK.swift:1786` covers both contracts
  since `groupIdentify` has no other caller.

### n15 — Local Feature Flag Evaluator (➖ N/A)
- **Spec requires (Applicability, quoted):** "`both` — local evaluation exists in both client-style
  and server-style SDKs, though it is most prominent in server SDKs... Some client wrappers, such as
  Flutter, do not own a separate evaluator and instead delegate evaluation to underlying native/
  browser SDKs."
- **SDK currently:** No local rule-evaluation engine exists (`grep -rniE
  "onlyEvaluateLocally|localEvaluation"` in `PostHog/` → zero hits). All flag values originate
  directly from the `/flags` HTTP response (`PostHogRemoteConfig.swift:354-495`); every read method
  is a direct cache lookup with no local computation of rollout percentages, property filters, or
  cohorts — iOS delegates evaluation entirely to the PostHog server, matching the spec's own
  description of client wrappers that delegate elsewhere. Although the acceptance file is tagged
  `@both`, every scenario presupposes a local-evaluator object iOS does not possess.
- **Backwards compatibility:** N/A — a mobile SDK cannot safely hold a personal/admin API key;
  local rule evaluation would require one.

### n16 — Logs (🟡 Partial)
- **Spec requires:** correct OTel severity mapping and OTLP log record model with monotonic-
  within-millisecond ordering; `AnyValue` attribute encoding where non-finite floats are encoded as
  strings (not dropped); a bounded shutdown flush; a `beforeSend` hook chain whose throwing/crashing
  hooks are caught and swallowed rather than propagated.
- **SDK currently:** The broader pipeline (`Logs/PostHogLogRecord.swift`, `PostHogLogSeverity.swift`,
  `PostHogLogger.swift`, `PostHogLogsConfig.swift`, `PostHogLogsOTLP.swift`) is correctly built, with
  four confirmed deviations: (1) `Utils/DateUtils.swift:71-79` (`nanosNow()`) derives
  `timeUnixNano` purely from wall-clock `Date()` with no monotonic tie-breaker, so two logs in the
  same millisecond aren't guaranteed strictly increasing (spec: SHOULD, so a soft deviation); (2)
  `close()` (`PostHogSDK.swift:2470-2503`) calls `logsQueue?.stop()`, and `PostHogQueue.stop()`
  (`PostHogQueue.swift:305-334`) only invalidates the timer/reachability subscription — it never
  calls `flush()`, so buffered-but-unsent logs at shutdown are abandoned; (3) non-finite floats
  (NaN/Infinity) in log attributes are dropped entirely by `sanitizeDictionary`'s `isValidObject`
  (`Utils/DictUtils.swift:73-81`) before ever reaching the OTLP encoder, rather than being encoded as
  `{"stringValue": "NaN"}` per spec; (4) the `beforeSend` chain (`Utils/BeforeSendChain.swift:11-30`)
  has no throw/crash containment — the block type itself isn't `throws`, so a hook trap cannot be
  caught and swallowed as the spec requires.
- **Backwards compatibility:** Backward-compatible for all four — a monotonic counter, a shutdown
  flush call, preserving NaN/Infinity as strings instead of dropping the key, and adding a
  try/catch-style guard around the beforeSend chain are all additive/internal changes with no wire-
  format break (encoding NaN as a string is a strict addition to what's currently omitted).
- **Remediation:** Add a monotonic intra-millisecond counter to `nanosNow()`; call
  `logsQueue?.flush()` (bounded by a timeout) before `stop()` in `close()`; rewrite non-finite float
  attributes to string form instead of dropping the key; wrap the `beforeSend` chain invocation in
  an exception-safe bridge.

### n17 — On Feature Flags (❌ Fail)
- **Spec requires (Applicability: `client`):** a public listener/callback registration API invoked
  on flags-ready/updated, supporting multiple independent subscribers, late-registration immediate
  fire, and unsubscription.
- **SDK currently:** No public registration API exists on `PostHogSDK` at all. Internally,
  `PostHogRemoteConfig.swift:63` has `let onFeatureFlagsLoaded = PostHogMulticastCallback<[String:
  Any]?>()`, invoked at line 620, but `PostHogRemoteConfig` is not public and `PostHogSDK.
  remoteConfig` is `private(set)` (`PostHogSDK.swift:76`) — unreachable from outside the module. The
  only externally observable signal is a bare `NotificationCenter` post
  (`PostHogRemoteConfig.swift:621`, `NotificationCenter.default.post(name:
  PostHogSDK.didReceiveFeatureFlags, ...)`, backed by `PostHogExtensions.swift:27`), which carries no
  flags/variants payload and has no documented late-registration/fire-immediately contract — a
  consumer must manually wire `NotificationCenter` observation with no SDK-provided subscribe/
  unsubscribe helper. This is materially short of the spec's `onFeatureFlags(callback)` contract.
- **Backwards compatibility:** Backward-compatible — the internal `PostHogMulticastCallback`
  (`Utils/PostHogMulticastCallback.swift`) already supports multi-subscriber, tokenized subscribe/
  unsubscribe and could be exposed publicly with minimal new code.
- **Remediation:** Add a public `PostHogSDK.onFeatureFlags(_:) -> RegistrationToken` (or a
  `PostHogConfig.onFeatureFlags` callback field) wired to the existing `onFeatureFlagsLoaded`
  multicast callback, firing immediately for late subscribers if flags are already loaded.

### n18 — Opt In (🟡 Partial)
- **Spec requires:** (optional, per spec's permissive language) opt-out MAY also clear local
  persistence (distinct id, super properties, etc.) when configured.
- **SDK currently:** `optIn()`/`optOut()` (`PostHogSDK.swift:2408-2454`) correctly guard on
  `isEnabled()`, no-op when already in the target state, persist immediately, and (un)install
  integrations (Replay, Surveys) on transition. No event is emitted on transition, which the spec
  treats as optional. Gap: `optOut()` takes no parameter to also clear persisted distinct-id/super-
  properties — no "clear local storage" option exists.
- **Backwards compatibility:** Backward-compatible — an optional `clearLocalStorage: Bool = false`
  parameter preserves current default behavior.
- **Remediation:** Add an optional clear-local-storage parameter to `optOut()` that purges persisted
  identity/super-properties from `PostHogStorage`.

### n19 — Persistent Storage (🟡 Partial)
- **Spec requires:** storage read/write failures must be caught and logged as recoverable, with the
  SDK recording a distinguishable storage warning on write failure.
- **SDK currently:** `PostHogStorage.swift` (`getData` 277-288, `setData` 290-307, `getJson`
  309-318, `setJson` 320-339) all wrap operations in `do`/`catch` and call `hedgeLog` rather than
  crashing; missing/corrupt reads fall back to sane defaults. However, `hedgeLog`
  (`Utils/Hedgelog.swift:10-20`) is a plain `print()` gated by a disabled-by-default debug flag —
  not a structured, observable warning signal distinct from ordinary debug logging.
- **Backwards compatibility:** Backward-compatible — adding a distinct structured warning channel
  is additive.
- **Remediation:** Introduce a dedicated warning/error mechanism for storage write failures (counter,
  delegate hook, or distinct log level) separate from the general debug-only `hedgeLog`.

### n20 — Reset (🟡 Partial)
- **Spec requires:** clears user-scoped state including opt-out state; spec explicitly notes reset
  clears *persisted* opt-out state and warns it "should not be treated as a privacy-preserving
  alternative to opt-out" (implying the live gate should actually clear, not just the on-disk copy).
- **SDK currently:** `reset()` (`PostHogSDK.swift:645-687`) correctly clears identity, super
  properties, groups, flag caches/dedupe, rotates session, preserves the outbound queue, and
  reloads flags. It calls `storage?.reset(...)`, which deletes the on-disk `.optOut` key
  (`PostHogStorage.swift:413`), but never resets the in-memory `config.optOut` flag that every
  gating check (`isOptOutState()` line 1042, `isOptOut()` line 2462) actually reads — confirmed no
  `config.optOut = false` appears anywhere in `reset()`, contrasted with `optIn()` (lines 2417-2419)
  which explicitly does this under `optOutLock`. Consequence: an opted-out user who calls `reset()`
  remains fully opted out for the rest of that process's lifetime; the flag only clears on the next
  app launch. No concrete Gherkin scenario in `reset.feature` directly tests this interaction — the
  finding rests on the spec's prose Behavior/State/Interactions sections.
- **Backwards compatibility:** Backward-compatible — a bug fix with no signature change, though it
  changes observable runtime behavior for opted-out users calling `reset()` without restarting, so
  worth a release-notes callout.
- **Remediation:** In `reset()`, add `config.optOut = false` (under `optOutLock`, mirroring
  `optIn()`) alongside the existing `storage?.reset(...)` call.

### n21 — Screen (🟡 Partial)
- **Spec requires:** the explicit `name`/`screenTitle` argument MUST win over any conflicting
  caller-supplied `$screen_name` property.
- **SDK currently:** Event name, `$screen_name` property, opt-out guard, and current-screen caching
  are all correct. Precedence is inverted: `PostHogSDK.swift:1540-1542` builds
  `["$screen_name": cleaned].merging(sanitizeDictionary(properties) ?? [:]) { _, new in new }` — the
  merge closure means the caller-supplied `properties["$screen_name"]` (the "new" operand) wins on
  collision, overriding the explicit `screenTitle` argument, the opposite of the spec's required
  precedence. This is deliberate, documented behavior (doc comment at lines 1503-1504 describes it
  as an intentional override mechanism), but it contradicts the spec.
- **Backwards compatibility:** Needs deprecation path — this override mechanism is publicly
  documented; flipping it changes behavior for any caller currently relying on it, so it warrants a
  changelog/release note even though no signature changes.
- **Remediation:** Reverse the merge direction so the explicit `cleaned` title always wins on key
  collision; add a regression test asserting `screen("ExplicitTitle", properties: ["$screen_name":
  "Other"])` yields `$screen_name == "ExplicitTitle"`.

### n22 — Session Replay Privacy (❌ Fail)
- **Spec requires:** elements/views tagged with no-capture markers (`ph-no-capture`) MUST be treated
  as masked/excluded even when broad category masking is disabled; native wireframe replay MUST
  replace sensitive text values with masked strings and omit/placeholder sensitive image content;
  mask discovery MUST traverse the full matched subtree, not skip nodes via traversal shortcuts.
  Password/secure-entry masking should take precedence over an explicit no-mask override.
- **SDK currently:** Two independent code paths diverge on privacy semantics. (1) **No-capture leak
  in default wireframe mode** (confirmed directly by reading the code): `toWireframe`
  (`Replay/PostHogReplayIntegration.swift:1250-1385`) has no generic `view.isNoCapture()` check for
  arbitrary `UIView`s — `isNoCapture()` is only consulted inside typed-widget sensitivity helpers
  (`isTextInputSensitive`, `isImageViewSensitive`, etc., lines 1181, 1225, 1233) that mask only
  text/image *content* on specific widget types (`UILabel`, `UITextField`, `UIImageView`, etc.); the
  final block (lines 1372-1382) unconditionally recurses into every subview regardless of any
  no-capture tag on the parent `UIView`. A plain `UIView` tagged `ph-no-capture` (e.g. the SDK's own
  example app, `PostHogExample/Views/UIViewExample.swift:12-26`) still has its child `UILabel` text
  captured in plaintext in wireframe mode — the SDK's **default** capture mode (`screenshot = false`
  per `PostHogSessionReplayConfig.swift`) — while the same view is correctly masked as an opaque
  rect in screenshot mode (`findMaskableWidgets`, line 966: `if view.isNoCapture() || maskChildren`).
  This is the same bug class independently found in posthog-android. (2) **Password/secure-field
  precedence bug in screenshot mode:** `findMaskableWidgets` returns immediately on
  `view.postHogNoMask` (lines 833-836) *before* the secure-entry check (`isSensitiveText()`, lines
  838-851) — a `SecureField`/secure `UITextField` inside a `.postHogNoMask()`-tagged SwiftUI
  container is not masked, contradicting the spec's password-precedence guarantee.
- **Backwards compatibility:** Needs deprecation path for the fix mechanics — the change itself is
  additive (no signature changes) — but the underlying issue is a real, silent data-privacy leak in
  the SDK's default capture mode; ship with a clear changelog/security-advisory note since apps
  relying on `ph-no-capture` on container views today are unknowingly leaking content in wireframe
  mode.
- **Remediation:** Add a generic `isNoCapture()` guard to `toWireframe` (mirroring the screenshot-
  mode fallback at line 966) that replaces the tagged element and its subtree with an opaque
  placeholder and skips recursion; reorder `findMaskableWidgets` so secure-entry checks run before/
  override the `postHogNoMask` short-circuit; add regression tests for both gaps (none currently
  exist in `PostHogTests/`).

### n23 — Set Person Properties (🟡 Partial)
- **Spec requires:** dedup cache for repeated identical `$set` calls should be part of state cleared
  by `reset()` (per the spec's note that audited browser/Android implementations clear this cache on
  reset).
- **SDK currently:** Public API (`setPersonProperties(userPropertiesToSet:)` /
  `setPersonProperties(userPropertiesToSet:userPropertiesToSetOnce:)`,
  `PostHogSDK.swift:925-990`), guards, recursive-key-sorted dedup hashing
  (`getPersonPropertiesHash`, lines 996-1040), flags-cache mirroring without forcing reload (lines
  972-982), and `$set` emission are all correctly implemented and match the spec's iOS-specific
  notes precisely. `reset()` (`PostHogSDK.swift:645-669`) does not clear `cachedPersonPropertiesHash`
  — in practice this is masked because `distinct_id` is part of the hash and `reset()` normally
  rotates to a new anonymous id (`reuseAnonymousId` defaults to `false`), so it only becomes
  observable when `reuseAnonymousId = true` and the exact same properties are set again immediately
  after a reset, wrongly deduplicating that call.
- **Backwards compatibility:** Backward-compatible — clearing the hash cache in `reset()` only
  narrows the no-op window; purely internal state.
- **Remediation:** Add `cachedPersonPropertiesLock.withLock { cachedPersonPropertiesHash = nil }`
  inside `reset()` for parity with browser/Android.

### n24 — Shutdown (❌ Fail)
- **Spec requires:** shutdown SHALL flush pending events before tearing down workers/queues, per
  spec.md's explicit Behavior step 2 ("Flush pending events. Attempt to send queued events
  immediately before tearing down workers/queues") and the `@both`-tagged acceptance scenario
  "Shutdown flushes queued events and disables future work."
- **SDK currently:** `close()` (`PostHogSDK.swift:2470-2515`), confirmed directly: inside
  `setupLock.withLock`, the body proceeds straight to `queue?.stop(); replayQueue?.stop();
  logsQueue?.stop()` with no call to `flush()` (a distinct method at `PostHogSDK.swift:629-638`)
  anywhere before or during teardown. `PostHogQueue.stop()` (`PostHogQueue.swift:305-334`) only
  invalidates the flush timer and unsubscribes reachability — it performs no network send and does
  not drain the queue. Net effect: queued-but-unsent events are abandoned without an attempt to
  deliver them before teardown. What does match: idempotency (`if !isEnabled() { return }` guard),
  stopping timers/workers, and disabling future capture (`enabled = false`).
- **Backwards compatibility:** Backward-compatible — adding a flush call before `queue?.stop()` is
  purely additive; no public signature change, and the current `close()` doc comment makes no
  promise that queued events are dropped.
- **Remediation:** In `close()`, before `queue?.stop()` (line ~2479), invoke `flush()` (or the
  per-queue flush calls) bounded by a reasonable timeout, before nulling references and stopping
  timers. Add a regression test asserting the mock server receives previously-queued events after
  `close()`.

### n25 — Stop Session Recording (🟡 Partial)
- **Spec requires:** per `stop-session-recording.feature` ("Stop session recording finalizes
  pending replay data"), pending replay data should be finalized as part of the stop call.
- **SDK currently:** New-capture cessation is correct, but finalization is not: `stopSessionRecording()`
  (`PostHogSDK.swift:2592-2602`) calls only `replayIntegration.stop()`.
  `PostHogReplayIntegration.stop()` (`Replay/PostHogReplayIntegration.swift:316-340`) deactivates
  listeners/plugins but never calls `replayQueue.flush()` — contrast with `PostHogSDK.flush()`
  (lines 628-637), which explicitly does `queue?.flush(); replayQueue?.flush(); logsQueue?.flush()`.
  Buffered `$snapshot` events are durably persisted to disk (not lost) but sit until the next
  periodic/background flush trigger rather than being finalized at stop time.
- **Backwards compatibility:** Backward-compatible — adding `replayQueue?.flush()` inside
  `stopSessionRecording()` is purely additive, no signature/behavior-contract change for existing
  callers.
- **Remediation:** Call `replayQueue?.flush()` after `replayIntegration.stop()` in
  `PostHogSDK.swift:2592-2602`.

### n26 — Traces (❌ Fail)
- **Spec requires:** a manual `startSpan` API plus a scoped `withSpan` helper, no-op span handles
  when tracing is unconfigured, exception recording, W3C traceparent propagation, an in-memory
  buffered queue batched and shipped as OTLP Traces JSON to `POST {host}/i/v1/traces`. The spec
  explicitly discusses "mobile ports" throughout (clock behavior during device sleep, `screen.name`/
  `app.state` context keys, mobile-appropriate flush triggers), so mobile is squarely in scope, not
  exempt.
- **SDK currently:** Completely unimplemented. Exhaustive search of `PostHog/` for `startSpan`,
  `withSpan`, `getActiveSpan`, `beforeSpanSend`, `resourceSpans`, `scopeSpans`, `traceparent`, and
  `i/v1/traces` returns zero matches anywhere in the tree. A `Tracing/` folder exists but contains
  only `PostHogTracingHeadersIntegration.swift` — the unrelated `tracing-headers` capability (HTTP
  correlation headers, not OTLP spans), which the spec itself explicitly distinguishes from `traces`
  in its Purpose section. No span data model, span queue, or `/i/v1/traces` transport exists.
- **Backwards compatibility:** Backward-compatible — this is a net-new, additive feature (a new
  public API surface plus a new opt-in pipeline that stays off until a `traces` config object is
  supplied); adding it cannot break any existing integration.
- **Remediation:** Implement the `traces` capability net-new: span handle type
  (`setAttribute`/`addEvent`/`setStatus`/`recordException`/`updateName`/`end`), no-op-handle
  fallback, `startSpan`/`withSpan` public API, an OTLP-traces buffered queue/transport mirroring the
  existing `logs` pipeline's structure (explicitly named in the spec as the structural template),
  and `screen.name`/`app.state` mobile context enrichment.
