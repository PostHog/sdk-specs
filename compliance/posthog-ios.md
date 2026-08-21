# posthog-ios — SDK Compliance

**Repo:** [PostHog/posthog-ios](https://github.com/PostHog/posthog-ios)
**Audited commit:** `c0218386c49115cce6b05a50b41f4f60bc995acb` ([commit](https://github.com/PostHog/posthog-ios/commit/c0218386c49115cce6b05a50b41f4f60bc995acb)) — audited on 2026-08-17
**Audited against sdk-specs commit:** `0ea0aba45170a56a8778197a3e3bd9c6e9b3dd79`
**Summary:** 32 ✅ · 18 🟡 · 7 ❌ · 5 ➖ · 0 ❓

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
N/A for platform reasons (e.g. local flag evaluation, flag-definition polling, capture-ai,
evaluate-flags) is N/A because the capability requires a personal/admin API key a mobile app cannot
safely hold, or is an explicitly server-only capability per its spec's Applicability line, not
because of a build-target split. All file paths below are relative to `/tmp/audit-posthog-ios/`
unless noted.

This audit re-verified all 62 rows against current code rather than carrying forward the previous
audit's (`057f4d6`, 2026-08-06) verdicts. Three brand-new contracts (Capture AI, Evaluate Flags,
Exception Event Metadata) were evaluated from scratch. Net changes vs. the previous audit: Surveys
moved ✅ → ❌ (new intro-screen requirement not implemented); all other previously-tracked rows are
unchanged in verdict, though several notes were refreshed with current line numbers and a couple of
findings were confirmed fixed/not-reproducible (see notes).

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Logs | 🟡 | [n1] |
| 2 | Traces | ❌ | [n2] |
| 3 | Tracing Headers | ✅ | |
| 4 | Alias | 🟡 | [n3] |
| 5 | Capture | ✅ | |
| 6 | Capture AI | ➖ | Server-only capability per spec Applicability ("currently implemented by posthog-python and posthog-node... other server SDKs adopt this spec if and when they add AI support"); acceptance/public/capture-ai.feature is tagged `@server` throughout. iOS has no `captureAi`/`$ai_generation`-equivalent (confirmed via repo-wide grep). |
| 7 | Capture Exception | 🟡 | [n4] |
| 8 | Create Person Profile | ➖ | [n5] |
| 9 | Debug | ✅ | |
| 10 | Exception Steps | ✅ | |
| 11 | Flush | ✅ | |
| 12 | Get Anonymous ID | ✅ | |
| 13 | Get Distinct ID | ✅ | |
| 14 | Get Feature Flag | ✅ | |
| 15 | Get Feature Flag Payload | 🟡 | [n6] |
| 16 | Get Feature Flag Result | ✅ | |
| 17 | Get Feature Flags | ❌ | [n7] |
| 18 | Get Feature Flags And Payloads | ❌ | [n8] |
| 19 | Evaluate Flags | ➖ | Server-side snapshot API per spec Applicability, which explicitly states client-side `isFeatureEnabled(...)` reading ambient cached flag state remains governed by `is-feature-enabled` and is not replaced by this capability. acceptance/public/evaluate-flags.feature is tagged `@server` throughout. No `evaluateFlags`-equivalent exists in iOS. |
| 20 | Get Session ID | ✅ | |
| 21 | Group | 🟡 | [n9] |
| 22 | Group Identify | 🟡 | [n10] |
| 23 | Identify | ✅ | |
| 24 | Is Feature Enabled | ✅ | |
| 25 | Is Opt Out | ✅ | |
| 26 | Is Session Replay Active | ✅ | |
| 27 | On Feature Flags | ❌ | [n11] |
| 28 | Opt In | 🟡 | [n12] |
| 29 | Register | ✅ | |
| 30 | Reload Feature Flags | ✅ | |
| 31 | Reset | 🟡 | [n13] |
| 32 | Reset Group Properties For Flags | ✅ | |
| 33 | Reset Person Properties For Flags | ✅ | |
| 34 | Screen | 🟡 | [n14] |
| 35 | Set Group Properties For Flags | ✅ | |
| 36 | Set Person Properties | 🟡 | [n15] |
| 37 | Set Person Properties For Flags | ✅ | |
| 38 | Setup | ✅ | |
| 39 | Shutdown | ❌ | [n16] |
| 40 | Start Session Recording | ✅ | |
| 41 | Stop Session Recording | 🟡 | [n17] |
| 42 | Unregister | ✅ | |
| 43 | Application Lifecycle | ✅ | |
| 44 | Autocapture | ✅ | |
| 45 | Before Send Hook | 🟡 | [n18] |
| 46 | Consent Gating | 🟡 | [n19] |
| 47 | Device ID Generator | ✅ | |
| 48 | Event Batcher | 🟡 | [n20] |
| 49 | Exception Event Metadata | 🟡 | [n21] |
| 50 | Feature Flag Cache | ✅ | |
| 51 | Feature Flag Called Tracker | 🟡 | [n22] |
| 52 | Flag Definition Loader | ➖ | [n23] |
| 53 | HTTP Client | ✅ | |
| 54 | Local Feature Flag Evaluator | ➖ | [n24] |
| 55 | Persistent Storage | 🟡 | [n25] |
| 56 | Remote Config | ✅ | |
| 57 | Retry Queue | ✅ | |
| 58 | Session Manager | ✅ | |
| 59 | Session Replay Ingestion Controls | ✅ | |
| 60 | Session Replay Privacy | ❌ | [n26] |
| 61 | Surveys | ❌ | [n27] |
| 62 | Bootstrap | 🟡 | [n28] |

## Notes

### n1 — Logs (🟡 Partial)
- **Spec requires:** correct OTel severity mapping and OTLP log record model with monotonic-
  within-millisecond ordering; `AnyValue` attribute encoding where non-finite floats are encoded as
  strings (not dropped); a bounded shutdown flush; a `beforeSend` hook chain whose throwing/crashing
  hooks are caught and swallowed rather than propagated.
- **SDK currently:** Four confirmed deviations, re-verified against current code: (1)
  `Utils/DateUtils.swift:71-79` (`nanosNow()`) derives `timeUnixNano` purely from wall-clock `Date()`
  with no monotonic tie-breaker/counter — two logs in the same millisecond can produce identical
  timestamps; (2) `close()` (`PostHogSDK.swift:2484-2499`) calls `queue?.stop(); replayQueue?.stop();
  logsQueue?.stop()` then nils all three, with no call to `flush()`/`logsQueue?.flush()` anywhere —
  `PostHogQueue.stop()` (`PostHogQueue.swift:305-320`) only invalidates the timer/reachability
  subscription, it never sends; (3) non-finite floats (NaN/Infinity) in log attributes are dropped
  entirely before reaching the OTLP encoder: `sanitizeDictionary`/`isValidObject`
  (`Utils/DictUtils.swift:68-75`) strips any `Double` that isn't `.isFinite`, invoked from
  `PostHogLogRecord.toStorageJSON` upstream of the encoder. Notably, `PostHogLogsOTLP.swift:72-77`
  now *does* correctly encode non-finite doubles as `{"stringValue": "NaN"/"Infinity"/"-Infinity"}`
  — this appears to be a partial fix added since the last audit — but it is dead code for real input
  because the upstream sanitizer already deleted the key; net wire behavior is unchanged (still
  dropped, not stringified); (4) the `beforeSend` chain (`Utils/BeforeSendChain.swift`, now shared
  across events and logs) has no throw/crash containment — `PostHogBeforeSendLogBlock` is a
  non-throwing closure type and no `try`/`catch` or `NSException` bridge wraps invocation.
- **Backwards compatibility:** Backward-compatible for all four — a monotonic counter, a shutdown
  flush call, moving NaN/Infinity handling to the reachable path (encoding as a string instead of
  dropping the key), and adding a crash-safe guard around the beforeSend chain are all additive/
  internal changes with no wire-format break. Care needed on (3): `sanitizeDictionary` is shared with
  other subsystems (events, replay), so the fix should be scoped to the logs attribute path
  specifically rather than changed globally.
- **Remediation:** Add a monotonic intra-millisecond counter to `nanosNow()`; call
  `logsQueue?.flush()` (bounded by a timeout) before `.stop()` in `close()`; make the logs-specific
  attribute sanitizer stringify non-finite floats instead of routing them through the generic
  drop-on-non-finite `sanitizeDictionary`; wrap the `beforeSend` chain invocation in an
  exception-safe bridge for logs (as for events).

### n2 — Traces (❌ Fail)
- **Spec requires:** a manual `startSpan` API plus a scoped `withSpan` helper, no-op span handles
  when tracing is unconfigured, exception recording, W3C traceparent propagation, an in-memory
  buffered queue batched and shipped as OTLP Traces JSON to `POST {host}/i/v1/traces`. The spec
  explicitly discusses "mobile ports" throughout, so mobile is squarely in scope, not exempt.
- **SDK currently:** Completely unimplemented, reconfirmed. Exhaustive search of `PostHog/` for
  `startSpan`, `withSpan`, `getActiveSpan`, `beforeSpanSend`, `resourceSpans`, `scopeSpans`,
  `traceparent`, `PostHogSpan`/`PostHogTrace`/`OTLPSpan`, and `i/v1/traces` returns zero matches
  anywhere in the tree, including `CHANGELOG.md` and example apps. A `Tracing/` folder exists but
  contains only `PostHogTracingHeadersIntegration.swift` — the unrelated `tracing-headers` capability
  (HTTP correlation headers, not OTLP spans), which the spec itself explicitly distinguishes from
  `traces`. No acceptance feature file (`traces.feature`) exists yet under `acceptance/` either,
  consistent with the spec's own note that it precedes the first SDK implementation.
- **Backwards compatibility:** Backward-compatible — this is a net-new, additive feature (a new
  public API surface plus a new opt-in pipeline that stays off until a `traces` config object is
  supplied); adding it cannot break any existing integration.
- **Remediation:** Implement the `traces` capability net-new: span handle type
  (`setAttribute`/`addEvent`/`setStatus`/`recordException`/`updateName`/`end`), no-op-handle
  fallback, `startSpan`/`withSpan` public API, an OTLP-traces buffered queue/transport mirroring the
  existing `logs` pipeline's structure, and `screen.name`/`app.state` mobile context enrichment.

### n3 — Alias (🟡 Partial)
- **Spec requires:** the `acceptance/public/alias.feature` scenario (tagged `@client`) requires the
  enqueued `$create_alias` event's properties to include both `alias` and `distinct_id`; the spec
  also implies a guard against an empty/blank alias.
- **SDK currently:** `alias(alias:)` (`PostHog/PostHogSDK.swift:1645-1673`) builds `let props =
  ["alias": alias]` without ever setting `distinct_id`. No guard against an empty `alias` argument
  exists — unlike `identify()`, which explicitly checks `distinctId.isEmpty` and drops with a log,
  `alias("")` proceeds to enqueue an event. Unchanged from previous audit.
- **Backwards compatibility:** Backward-compatible — adding `props["distinct_id"] = distinctId` and
  an empty-alias guard are both purely additive; no existing field is removed or renamed.
- **Remediation:** Set `distinct_id` alongside `alias` in the `$create_alias` properties dict; add
  an early return for a blank `alias` argument, mirroring `identify()`'s pattern.

### n4 — Capture Exception (🟡 Partial)
- **Spec requires:** acceptance scenario `capture-exception.feature` ("Capturing a handled
  exception emits an exception event") requires top-level `$exception_type`/`$exception_message`
  properties on the captured event, in addition to the nested `$exception_list`. Also: outermost-
  first/root-cause-last exception-list ordering, entry-first-crash-site-last frame ordering, and
  preference for a real stack trace over a synthesized one.
- **SDK currently:** Frame ordering (`buildStacktrace`/`buildStacktraceFromAddresses`,
  `ErrorTracking/PostHogExceptionProcessor.swift:372-412`, both call `.reversed()` on the top-down
  `callStackReturnAddresses`) and exception-list/cause-chain ordering (outermost appended first, then
  each `NSUnderlyingErrorKey` walk appends the next level) are correctly implemented. Real-stack
  preservation is also correct: `buildException(from: NSException, ...)` prefers
  `exception.callStackReturnAddresses` when non-empty, only synthesizing a current-stack capture as
  fallback (`PostHogExceptionProcessor.swift:269-277`). However, a repo-wide grep confirms
  `$exception_type`/`$exception_message` are **still never written as top-level event properties** —
  type/value only exist nested inside `$exception_list[].type`/`.value`
  (`PostHogExceptionProcessor.swift` `buildProperties`, ~lines 102-108). Reconfirmed unchanged from
  the previous audit (and matches the parallel posthog-android finding).
- **Backwards compatibility:** Backward-compatible — adding flat `$exception_type`/
  `$exception_message` properties (mirrored from `$exception_list[0]`) is purely additive.
- **Remediation:** Stamp `$exception_type`/`$exception_message` onto the outer event properties
  from the first (outermost) entry of `$exception_list` in `buildProperties`.

### n5 — Create Person Profile (➖ N/A)
- **Spec requires (Applicability, quoted):** "`client` — this is a client-side identity/profile-
  control API. In the audited implementations, this API is present in the posthog-js family (shared
  core, browser, React Native). Other audited client SDKs do not expose an equivalent public
  method."
- **SDK currently:** No `createPersonProfile()` or equivalent public method exists anywhere in the
  repo (verified via full-repo grep, including `PostHogTests/`). iOS only exposes person-profile mode
  via the `PostHogConfig.personProfiles` enum (`never`/`always`/`identifiedOnly`) and an
  internal-only `requirePersonProcessing()` (private). Per the spec's own applicability language
  naming "other audited client SDKs" as lacking this method, this is a legitimate N/A.
- **Backwards compatibility:** N/A — no remediation required per spec scope.

### n6 — Get Feature Flag Payload (🟡 Partial)
- **Spec requires:** a canonical payload getter, cache-only read, no `$feature_flag_called`
  emission by default.
- **SDK currently:** `getFeatureFlagPayload(_:)` (`PostHogSDK.swift:2272`) is still marked
  `@available(*, deprecated, message: "Use getFeatureFlagResult(_:) instead which properly tracks
  feature flag usage")`. Behavior is fully correct — it delegates to `getFeatureFlagResult(key,
  sendEvent: false)` with an explicit "Don't send event to maintain backwards compatibility" comment,
  never emits the event, and returns the cached payload. The deviation is purely a naming/lifecycle
  variance: the spec's canonical payload API is exposed to callers as deprecated in favor of a
  broader `getFeatureFlagResult` API. Unchanged from previous audit.
- **Backwards compatibility:** Backward-compatible — the method still exists and behaves per spec;
  only its deprecation annotation is the deviation.
- **Remediation:** None required for spec compliance today; this is a style/naming choice, not a
  behavioral defect.

### n7 — Get Feature Flags (❌ Fail)
- **Spec requires:** a public bulk getter `getFeatureFlags(): Record<string, boolean|string>`
  returning a flat key→value map, cache-only.
- **SDK currently:** No such public method exists (`grep -n "func getFeatureFlags\b"
  PostHog/PostHogSDK.swift` → no match). An internal, non-public `PostHogRemoteConfig.getFeatureFlags()
  -> [String: Any]?` exists (`PostHogRemoteConfig.swift:696`) but `PostHogRemoteConfig` is not public
  and is unreachable from outside the module. The only public bulk getter is `getAllFeatureFlags() ->
  [PostHogFeatureFlagResult]?` (`PostHogSDK.swift:2258`), a structured array of objects rather than
  the spec's flat map. Unchanged from previous audit.
- **Backwards compatibility:** Backward-compatible — add a new public method surfacing the existing
  internal map; purely additive alongside `getAllFeatureFlags()`.
- **Remediation:** Add a public `getFeatureFlags() -> [String: Any]?` on `PostHogSDK` that exposes
  `remoteConfig.getFeatureFlags()`.

### n8 — Get Feature Flags And Payloads (❌ Fail)
- **Spec requires:** a combined getter returning both a flags map and a payloads map in one call.
- **SDK currently:** No such method exists (`grep -rn "getFeatureFlagsAndPayloads"
  PostHog/` → no matches). `getAllFeatureFlags()` (`PostHogSDK.swift:2258`) embeds a payload per-
  result inside `PostHogFeatureFlagResult` objects, so a caller could manually reconstruct both maps
  by iterating, but this is not the canonical paired-map shape the spec describes. Unchanged from
  previous audit.
- **Backwards compatibility:** Backward-compatible — purely additive.
- **Remediation:** Add a public method exposing both the flags map and payloads map together (e.g.
  a struct with `flags`/`payloads` properties).

### n9 — Group (🟡 Partial)
- **Spec requires:** persist `groupType → groupKey`, attach `$groups` to future events, enqueue
  `$groupidentify` when properties supplied, reload flags on group change — and reject/log blank or
  empty `groupType`/`groupKey` without mutating group state.
- **SDK currently:** Storage, merge/overwrite, persistence, and flag-reload-on-change are all
  correctly implemented (`group(type:key:groupProperties:)`, `PostHogSDK.swift:1788-1807`, calling
  `groups(...)` then `groupIdentify(...)`; `$groups` attached via `dynamicContext()`). No validation
  guard exists for blank/empty `type` or `key` — the method only guards `isEnabled()`,
  `isOptOutState()`, `requirePersonProcessing()`; an empty string for either parameter is silently
  accepted, persisted, and forwarded into a `$groupidentify` event with no warning logged. Unchanged
  from previous audit.
- **Backwards compatibility:** Backward-compatible — adding validation only changes behavior for
  already-invalid (blank) inputs; no signature change.
- **Remediation:** Add an early `guard !type.isEmpty, !key.isEmpty else { hedgeLog(...); return }`
  at the top of `group(type:key:groupProperties:)`.

### n10 — Group Identify (🟡 Partial)
- **Spec requires:** `$groupidentify` event with `$group_type`/`$group_key`/`$group_set`; reject
  blank type/key with a validation warning; client SDKs may omit a standalone public
  `groupIdentify` (iOS is explicitly named as such an SDK in the spec's surface-variant table).
- **SDK currently:** No standalone public `groupIdentify` exists — only a `private func
  groupIdentify(type:key:groupProperties:)` (`PostHogSDK.swift:1703`), called solely from `group()`,
  matching the spec's explicitly-permitted iOS variant. Event shape is correct (`$group_type`/
  `$group_key`/conditional `$group_set`). Same validation gap as Group: the private `groupIdentify`
  has no blank-check either, so an empty-type/key call from `group()` flows through to enqueue an
  invalid `$groupidentify` event. Unchanged from previous audit.
- **Backwards compatibility:** Backward-compatible — same reasoning as Group; fixing the guard at
  the single `group()` call site covers both contracts.
- **Remediation:** Same fix as Group — one guard covers both since `groupIdentify` has no other
  caller.

### n11 — On Feature Flags (❌ Fail)
- **Spec requires (Applicability: `client`):** a public listener/callback registration API invoked
  on flags-ready/updated, supporting multiple independent subscribers, late-registration immediate
  fire, and unsubscription.
- **SDK currently:** No public registration API exists on `PostHogSDK`. Internally,
  `PostHogRemoteConfig.swift:66` has `let onFeatureFlagsLoaded = PostHogMulticastCallback<[String:
  Any]?>()` (internal, no access modifier), and `PostHogRemoteConfig` is not public — unreachable
  from outside the module. The only externally observable signal is a bare `NotificationCenter` post
  (`PostHogExtensions.swift:27`, `didReceiveFeatureFlags`, posted at `PostHogRemoteConfig.swift:664`),
  which carries no flags/variants payload and has no documented late-registration/fire-immediately
  contract — a consumer must manually wire `NotificationCenter` observation with no SDK-provided
  subscribe/unsubscribe helper, and there is no `PostHogConfig.onFeatureFlags`-style callback field
  either (unlike Android). Unchanged from previous audit.
- **Backwards compatibility:** Backward-compatible — the internal `PostHogMulticastCallback` already
  supports multi-subscriber, tokenized subscribe/unsubscribe and could be exposed publicly with
  minimal new code.
- **Remediation:** Add a public `PostHogSDK.onFeatureFlags(_:) -> RegistrationToken` (or a
  `PostHogConfig.onFeatureFlags` callback field) wired to the existing `onFeatureFlagsLoaded`
  multicast callback, firing immediately for late subscribers if flags are already loaded.

### n12 — Opt In (🟡 Partial)
- **Spec requires:** (optional, per spec's permissive language) opt-out MAY also clear local
  persistence (distinct id, super properties, etc.) when configured.
- **SDK currently:** `optIn()`/`optOut()` (`PostHogSDK.swift:2410-2468`) correctly guard on
  `isEnabled()`, no-op when already in the target state, persist immediately, and (un)install
  integrations (Replay, Surveys) on transition. Gap: `optOut()` takes no parameter to also clear
  persisted distinct-id/super-properties — no "clear local storage" option exists. Unchanged from
  previous audit.
- **Backwards compatibility:** Backward-compatible — an optional `clearLocalStorage: Bool = false`
  parameter preserves current default behavior.
- **Remediation:** Add an optional clear-local-storage parameter to `optOut()` that purges persisted
  identity/super-properties from `PostHogStorage`.

### n13 — Reset (🟡 Partial)
- **Spec requires:** clears user-scoped state including opt-out state; spec explicitly notes reset
  clears *persisted* opt-out state and warns it "should not be treated as a privacy-preserving
  alternative to opt-out" (implying the live gate should actually clear, not just the on-disk copy).
  A new optional (MAY) extension lets `reset()` accept bootstrap options to seed the next identity —
  confirmed browser-only so far per the sdk-specs commit history; not implementing this optional
  extension does not cause a Fail.
- **SDK currently:** `reset()` (`PostHogSDK.swift:646-688`) correctly clears identity, super
  properties, groups, flag caches/dedupe (`flagCallReportedLock.withLock {
  flagCallReported.removeAll() }`), rotates session (`sessionManager.reset()`), preserves the
  outbound queue, and reloads flags (`remoteConfig?.reloadFeatureFlags()`). It calls
  `storage?.reset(...)`, which deletes the on-disk `.optOut` key (`PostHogStorage.swift:413`), but
  never resets the in-memory `config.optOut` flag that every gating check (`isOptOutState()`,
  `isOptOut()`) actually reads — confirmed no `config.optOut = false` appears anywhere in `reset()`,
  contrasted with `optIn()` which explicitly does this under `optOutLock`. Consequence: an opted-out
  user who calls `reset()` remains fully opted out for the rest of that process's lifetime; the flag
  only clears on the next app launch. Unchanged from previous audit. iOS's argument-less `reset()`
  otherwise satisfies "Reset without bootstrap options behaves as the canonical reset"; the optional
  bootstrap-seeding MAY-extension is simply unimplemented (not a gap, since it's browser-only so
  far).
- **Backwards compatibility:** Backward-compatible — a bug fix with no signature change, though it
  changes observable runtime behavior for opted-out users calling `reset()` without restarting, so
  worth a release-notes callout.
- **Remediation:** In `reset()`, add `config.optOut = false` (under `optOutLock`, mirroring
  `optIn()`) alongside the existing `storage?.reset(...)` call.

### n14 — Screen (🟡 Partial)
- **Spec requires:** the explicit `name`/`screenTitle` argument MUST win over any conflicting
  caller-supplied `$screen_name` property (`openspec/specs/screen/spec.md`, Behavior step 3: "In the
  canonical shape, the explicit `name` argument wins over any conflicting caller-supplied
  `$screen_name` property").
- **SDK currently:** Event name, `$screen_name` property, opt-out guard, and current-screen caching
  are all correct. Precedence is inverted: `PostHogSDK.swift:1542-1544` builds
  `["$screen_name": cleaned].merging(sanitizeDictionary(properties) ?? [:]) { _, new in new }` — the
  merge closure means the caller-supplied `properties["$screen_name"]` (the "new" operand) wins on
  collision, overriding the explicit `screenTitle` argument, the opposite of the spec's required
  precedence. This is deliberate, documented, and tested behavior — a regression test
  (`PostHogTests/PostHogScreenNameTest.swift:81-87`) explicitly asserts the override direction, and a
  doc comment describes it as an intentional override mechanism — but it still contradicts the spec
  text. Unchanged from previous audit.
- **Backwards compatibility:** Needs deprecation path — this override mechanism is publicly
  documented and has a passing regression test asserting the current (spec-contradicting) direction;
  flipping it changes behavior for any caller currently relying on it, so it warrants a changelog/
  release note even though no signature changes.
- **Remediation:** Reverse the merge direction so the explicit `cleaned` title always wins on key
  collision; update `PostHogScreenNameTest.swift` to assert the corrected precedence.

### n15 — Set Person Properties (🟡 Partial)
- **Spec requires:** dedup cache for repeated identical `$set` calls should be part of state cleared
  by `reset()` (per the spec's note that audited browser/Android implementations clear this cache on
  reset).
- **SDK currently:** Public API, guards, recursive-key-sorted dedup hashing
  (`cachedPersonPropertiesHash`, `PostHogSDK.swift:48`, written/read in `setPersonProperties`), and
  `$set` emission are all correctly implemented and match the spec's iOS-specific notes precisely.
  `reset()` (`PostHogSDK.swift:646-688`) does not clear `cachedPersonPropertiesHash` — confirmed by
  direct read, no occurrence anywhere in the function body. In practice this is masked because
  `distinct_id` is part of the hash and `reset()` normally rotates to a new anonymous id
  (`reuseAnonymousId` defaults to `false`), so it only becomes observable when `reuseAnonymousId =
  true` and the exact same properties are set again immediately after a reset, wrongly deduplicating
  that call. Unchanged from previous audit.
- **Backwards compatibility:** Backward-compatible — clearing the hash cache in `reset()` only
  narrows the no-op window; purely internal state.
- **Remediation:** Add `cachedPersonPropertiesLock.withLock { cachedPersonPropertiesHash = nil }`
  inside `reset()` for parity with browser/Android.

### n16 — Shutdown (❌ Fail)
- **Spec requires:** shutdown SHALL flush pending events before tearing down workers/queues, per
  spec.md's explicit Behavior step 2 ("Flush pending events. Attempt to send queued events
  immediately before tearing down workers/queues") and the `@both`-tagged acceptance scenario
  "Shutdown flushes queued events and disables future work."
- **SDK currently:** `close()` (`PostHogSDK.swift:2484-2529`), confirmed directly: inside
  `setupLock.withLock`, the body proceeds straight to `queue?.stop(); replayQueue?.stop();
  logsQueue?.stop()` (then nils all three) with no call to `flush()` (a distinct method at
  `PostHogSDK.swift:630-639`) anywhere before or during teardown. `PostHogQueue.stop()`
  (`PostHogQueue.swift:305-320`) only invalidates the flush timer and unsubscribes reachability — it
  performs no network send and does not drain the queue. Net effect: queued-but-unsent events are
  abandoned without an attempt to deliver them before teardown (they persist to the on-disk
  file-backed queue and could flush on a future SDK instance's setup, but `close()` itself never
  attempts delivery). What does match: idempotency (`isEnabled()` guard at the top returns early on
  a second call), stopping timers/workers (`reachability?.stopNotifier()`, `sessionManager.endSession()`),
  disabling future capture (`enabled = false`), and clearing feature-flag-called tracker state
  (`flagCallReportedLock.withLock { flagCallReported.removeAll() }`). Unchanged from previous audit.
- **Backwards compatibility:** Backward-compatible — adding a flush call before `queue?.stop()` is
  purely additive; no public signature change, and the current `close()` doc comment makes no
  promise that queued events are dropped.
- **Remediation:** In `close()`, before `queue?.stop()`, invoke `queue?.flush(); replayQueue?.flush();
  logsQueue?.flush()` as a best-effort, bounded-time final send, before nulling references and
  stopping timers. Add a regression test asserting the mock server receives previously-queued events
  after `close()`.

### n17 — Stop Session Recording (🟡 Partial)
- **Spec requires:** per the acceptance scenario "Stop session recording finalizes pending replay
  data" (`acceptance/public/stop-session-recording.feature`, tagged `@client`): "pending replay data
  should be finalized before the recorder stops... and no new replay snapshots should be captured."
- **SDK currently:** New-capture cessation is correct, but finalization is not: `stopSessionRecording()`
  (`PostHogSDK.swift:2606-2616`) calls only `replayIntegration.stop()`.
  `PostHogReplayIntegration.stop()` (`Replay/PostHogReplayIntegration.swift:316-340`) deactivates
  listeners/plugins but never calls `replayQueue.flush()` — contrast with `PostHogSDK.flush()`, which
  explicitly flushes `queue`/`replayQueue`/`logsQueue`. Buffered `$snapshot` events are durably
  persisted to disk (not lost) but sit until the next periodic/background flush trigger rather than
  being finalized at stop time, contradicting the explicit acceptance-scenario wording. Unchanged
  from previous audit.
- **Backwards compatibility:** Backward-compatible — adding `replayQueue?.flush()` inside
  `stopSessionRecording()` is purely additive, no signature/behavior-contract change for existing
  callers.
- **Remediation:** Call `replayQueue?.flush()` after `replayIntegration.stop()` in
  `PostHogSDK.swift:2606-2616`.

### n18 — Before Send Hook (🟡 Partial)
- **Spec requires:** hooks run in a chain, each receiving the previous hook's mutated output
  (`nil` from any hook drops the event); an exception/crash inside a hook must not crash the host
  app.
- **SDK currently:** Chain composition is correct — `Utils/BeforeSendChain.swift` (now shared across
  events and logs; `reduce`+`flatMap` pattern) correctly threads each block's output into the next
  and short-circuits on `nil`. However, `BeforeSendBlock` is a **non-throwing** closure type
  (`PostHogConfig.swift:16`) and no `try`/`catch` (or Objective-C `@try`/`@catch`) wraps the
  invocation site — a Swift runtime trap (force-unwrap, index-out-of-bounds, `fatalError`) inside a
  hook crashes the host process uncaught, with no fallback to the last-good event value. Unchanged
  from previous audit (chain logic was refactored into a shared file, but crash-containment is still
  absent).
- **Backwards compatibility:** Needs deprecation path — the public `BeforeSendBlock` typealias is
  non-throwing today; wrapping invocation in an Objective-C exception-safe bridge is additive and
  does not require a signature change, but should ship with a changelog note since it changes crash
  behavior for buggy hooks.
- **Remediation:** Wrap hook invocation in an `NSException`-catching bridge, log a distinct
  before-send warning on catch, and fall back to the input event rather than letting the trap
  propagate. Note Swift-level traps (force-unwrap, `fatalError`) remain uncatchable by any mechanism
  and should be documented as a residual risk.

### n19 — Consent Gating (🟡 Partial)
- **Spec requires:** all event-producing/network-triggering operations must be blocked while opted
  out.
- **SDK currently:** The private gate `isOptOutState()` is checked consistently before
  `captureInternal`, `identify`, `alias`/`group`, log capture, exception capture,
  `startSessionRecording`, exception-steps, and push registration/capture (~15 verified call sites).
  `optOut()` also uninstalls integrations (Replay, Surveys) as part of its gating. However,
  `reloadFeatureFlags(_ callback:)` (`PostHogSDK.swift:2060-2074`) checks only `isEnabled()`, not
  opt-out state, and `PostHogRemoteConfig.swift` has zero references to opt-out anywhere — so an app
  explicitly calling `reloadFeatureFlags()` while opted out still issues a `/flags` network request
  carrying the distinct id and groups. Unchanged from previous audit.
- **Backwards compatibility:** Backward-compatible — adding an opt-out guard tightens internal
  behavior with no signature change.
- **Remediation:** Change `PostHogSDK.swift:2061` to `if !isEnabled() || isOptOutState() {` (or
  equivalent), suppressing the `/flags` call while opted out.

### n20 — Event Batcher (🟡 Partial)
- **Spec requires:** periodic flush after `flushInterval` elapses, ideally driven by an injectable/
  fake clock so tests can simulate elapsed time deterministically, alongside threshold and explicit
  flush.
- **SDK currently:** Threshold flush (`flushIfOverThreshold`), `maxBatchSize`, and 413-triggered batch
  halving (`BatchLimits.halve`) are all correctly implemented (`PostHogQueue.swift`). The periodic
  timer (`start()`) uses `Timer.scheduledTimer(withTimeInterval:...)` — real wall-clock — rather than
  the codebase's own injectable clock abstraction (`Utils/DateUtils.swift`, `var now: () -> Date`)
  used elsewhere (queue rate-cap window, session manager, event timestamps). Tests work around this
  via `config.disableQueueTimerForTesting` plus real sleeps rather than deterministic clock
  advancement. Unchanged from previous audit.
- **Backwards compatibility:** Needs deprecation path — an injectable scheduler is an internal,
  non-breaking refactor, but must preserve real-world timer semantics exactly to avoid subtly
  changing production flush cadence.
- **Remediation:** Introduce an injectable scheduler/clock abstraction for the periodic flush timer,
  defaulting to `Timer` in production but swappable in tests.

### n21 — Exception Event Metadata (🟡 Partial)
- **Spec requires:** a full canonical `$exception` envelope with a non-empty `$exception_list`, each
  entry carrying a `mechanism` object with `type`/`handled`/`source`/`synthetic`/`exception_id`/
  `parent_id`, `handled` never fabricated to `false` when actually unknown, canonical
  `$exception_source` naming (iOS's native-crash source should be `ios.crash_reporter`), nested-
  exception tree linkage with a 50-entry truncation cap and `mechanism.type = "chained"` for non-root
  entries, `$exception_level` normalization, strict producer-metadata precedence (application
  property bags MUST NOT override SDK-owned `$exception_list`/`$exception_level`/`$exception_source`/
  `$debug_images`), and native `$debug_images` with mandatory `debug_id`/`image_addr`.
- **SDK currently (this is the first audit of this brand-new, previously-untracked contract):** The
  envelope, frame ordering, and chain-walking mechanics are solid, but several concrete gaps exist:
  - **Mechanism linkage fields never emitted.** `grep -n "exception_id\|parent_id"
    PostHog/ErrorTracking/*.swift PostHog/*.swift` → zero hits. Every mechanism object omits
    `exception_id`/`parent_id` entirely (not just when legitimately unknown), and `mechanism.source`
    is never set anywhere in the mechanism-building code
    (`ErrorTracking/PostHogExceptionProcessor.swift`, `ErrorTracking/PostHogCrashReportProcessor.swift`).
  - **Nested exceptions don't get `mechanism.type = "chained"`.** `buildExceptionList` (both the
    `NSError` and `NSException` overloads in `PostHogExceptionProcessor.swift`) passes the *same*
    `mechanismType` to every entry in the chain — underlying/nested errors inherit whatever the
    outermost got (typically `"generic"`), never `"chained"`.
  - **`$exception_source` is never emitted.** `grep -rn "exception_source" PostHog/` → zero hits, on
    both the manual-capture and native-crash paths. The spec's canonical `ios.crash_reporter` value
    for native crashes is absent entirely.
  - **No 50-entry truncation.** No cap exists on the underlying-error chain walk (only cycle
    protection via an `ObjectIdentifier` `Set`); an arbitrarily long non-cyclic chain serializes in
    full.
  - **`handled` is not independently determined per nested entry.** Every entry in a chain inherits
    the same `handled` value from the outermost/top-level call, rather than each entry preserving its
    own independently-known handled state (the spec's "MUST NOT ... derive the value solely from the
    outermost entry"). In practice `handled` is never fabricated to `false` for a truly *unknown*
    state (iOS always has a concrete `true`/`false` to hand down), so the specific "never default
    unknown to false" clause is satisfied, but the broader per-entry-independence requirement is not.
  - **Typed-override vs. property-bag precedence is backwards on the manual-capture path.**
    `captureExceptionEvent` merges caller-supplied `additionalProperties` over SDK-generated
    properties with a plain dictionary overwrite (`PostHogSDK.swift`, `captureExceptionEvent`,
    ~lines 2878-2887) — caller properties can silently override `$exception_list`/`$exception_level`.
    Notably, the **native-crash path gets this right**: `PostHogErrorTrackingAutoCaptureIntegration.swift`
    (~line 234) does `crashEventProperties.merging(exceptionProperties) { _, new in new }` where
    `exceptionProperties` (crash-derived, SDK-owned) is the "new"/winning operand — the correct
    direction. This is an inconsistency between the two capture paths, not a uniform gap.
  - **`$debug_images` exist but can omit the mandatory `debug_id` filter.** Present for native crash
    frames (`PostHogCrashReportProcessor.swift`, `buildDebugImages`) with hex-string `image_addr`
    (`PostHogBinaryImageInfo.toDictionary`) and `debug_id` when available, and correctly deduplicated
    by `image_addr`. Gap: images whose `uuid` is `nil` are still included in the array rather than
    being omitted, contradicting "Images without an authoritative `debug_id` SHALL be omitted." Same
    gap exists in the manual-capture live-process image path (`PostHogDebugImageProvider.swift`).
  - **What is correct:** the envelope itself (non-empty `$exception_list`, `type`/`value` on every
    entry), outermost-first/root-cause-last chain ordering, `mechanism.type`/`handled`/`synthetic`
    populated (just not fully spec-conformant per above), `$exception_level` emitting only valid
    canonical values (`"error"`/`"fatal"`), and no processor-owned properties being synthesized
    incorrectly by the SDK itself.
- **Backwards compatibility:** Backward-compatible for all remediations. Adding
  `mechanism.exception_id`/`parent_id`/`chained`/`source`, `$exception_source`, truncation, and
  precedence fixes are additive/corrective changes to a wire format that downstream ingestion already
  tolerates missing fields for. Fixing the property-bag precedence bug changes behavior only for
  callers currently (ab)using `properties:` to override `$exception_list`/`$exception_level`, which
  is the exact bug the spec forbids — safe to ship without a deprecation path. Filtering UUID-less
  debug images is a pure reduction in over-emission.
- **Remediation:** (1) In `buildExceptionList` (both overloads), assign incrementing
  `exception_id`/matching `parent_id` and set `mechanism.type = "chained"` + `mechanism.source =
  "cause"` for every entry after the first. (2) Cap the chain walk at 50 entries. (3) Add
  `$exception_source = "ios.crash_reporter"` to the native-crash properties output. (4) Fix
  `captureExceptionEvent` in `PostHogSDK.swift` to strip reserved keys (`$exception_list`,
  `$exception_level`, `$exception_source`, `$debug_images`) from `additionalProperties` before
  merging, so SDK-generated values always win — matching what the crash-reporter path already does
  correctly. (5) Skip images with `uuid == nil` in `buildDebugImages`/`PostHogDebugImageProvider`
  before appending to the result array. (6) Give nested/underlying exceptions their own
  independently-determined `handled` value instead of inheriting the top-level parameter.

### n22 — Feature Flag Called Tracker (🟡 Partial)
- **Spec requires:** core dedup semantics for `$feature_flag_called` (suppress repeat events for an
  unchanged outcome, re-emit on change, clear on reset/shutdown); when the server signals
  `minimalFlagCalledEvents` (minimal-event mode) AND the flag's `has_experiment` is exactly `false`,
  the minimized event must still retain an allowlist including session-attribution properties
  (`$referring_domain`, UTM params, `gclid`/`fbclid`) and static platform/OS identity properties.
- **SDK currently:** Core dedup tracker (`flagCallReported` dict, checked/updated in
  `reportFeatureFlagCalled`, cleared on both `reset()` and `close()`) and the minimal-event gate
  mechanics are all correct. `minimalFeatureFlagCalledProperties` (`PostHogSDK.swift:2295-2321`) has
  grown since the last audit to include static platform/breakdown fields (`$os_name`, `$os_version`,
  `$app_version` — explicitly commented as mobile's analog to python's `$os`/browser's
  `$current_url`), but still contains **zero** session-attribution properties: no
  `$referring_domain`, no `utm_source`/`utm_medium`/`utm_campaign`/`utm_content`/`utm_term`, no
  `gad_source`/`mc_cid`, no `gclid`/`fbclid`. iOS has no super-property registration mechanism for
  UTM/click-id params at all today (grep across the whole SDK returns zero hits for these param
  names as persisted properties) — the only related property, `$referring_domain`, is a one-off
  property on a single deep-link capture event (`AppLifeCycle/PostHogDeepLinkHelper.swift`), not a
  persisted super property that would ride along on an unrelated `$feature_flag_called` call — so the
  literal allowlist gap is real, but currently moot in practice since iOS doesn't populate these
  properties anywhere they'd need preserving.
- **Backwards compatibility:** Backward-compatible — adding entries to a `Set<String>` allowlist is
  additive; it only ever adds properties back into minimized events, and is future-proofing against
  any later addition of UTM/click-id capture to iOS.
- **Remediation:** Add the UTM/session-attribution keys to `minimalFeatureFlagCalledProperties`,
  following the same forward-looking allowlist pattern already used there, so the contract matches
  the cross-SDK allowlist regardless of whether iOS currently populates those keys.

### n23 — Flag Definition Loader (➖ N/A)
- **Spec requires (Applicability, quoted):** "`both` — audited implementations are especially
  important for server-side SDKs that support local evaluation... Some client wrappers, such as
  Flutter, expose ordinary feature-flag preload settings without owning a separate local-evaluation
  definition loader."
- **SDK currently:** No trace of any ETag-polling/personal-API-key component exists (`grep -rniE
  "etag|personalApiKey|flagDefinition" PostHog/` → zero hits, aside from unrelated substring false-
  positives). iOS only has `config.preloadFeatureFlags`, precisely the "ordinary preload setting" the
  spec's own text names as the client-wrapper alternative. Unchanged from previous audit.
- **Backwards compatibility:** N/A — justified by the spec's own Applicability text; a mobile app
  cannot safely hold a personal/admin API key.

### n24 — Local Feature Flag Evaluator (➖ N/A)
- **Spec requires (Applicability, quoted):** "`both` — local evaluation exists in both client-style
  and server-style SDKs, though it is most prominent in server SDKs... Some client wrappers, such as
  Flutter, do not own a separate evaluator and instead delegate evaluation to underlying native/
  browser SDKs."
- **SDK currently:** No local rule-evaluation engine exists (`grep -rniE
  "onlyEvaluateLocally|localEvaluation|personalApiKey"` in `PostHog/` → zero hits). All flag values
  originate directly from the `/flags` HTTP response (`PostHogRemoteConfig.swift`); every read method
  is a direct cache lookup with no local computation of rollout percentages, property filters, or
  cohorts — iOS delegates evaluation entirely to the PostHog server, matching the spec's own
  description of client wrappers (Flutter) that delegate elsewhere. Unchanged from previous audit.
- **Backwards compatibility:** N/A — a mobile SDK cannot safely hold a personal/admin API key; local
  rule evaluation would require one.

### n25 — Persistent Storage (🟡 Partial)
- **Spec requires:** storage read/write failures must be caught and logged as recoverable, with the
  SDK recording a distinguishable storage warning on write failure.
- **SDK currently:** `PostHogStorage.swift` I/O methods all wrap operations in `do`/`catch` and call
  `hedgeLog` rather than crashing; missing/corrupt reads fall back to sane defaults. However,
  `hedgeLog` (`Utils/Hedgelog.swift`) is a plain `print()` gated by a disabled-by-default debug flag
  — not a structured, observable warning signal distinct from ordinary debug logging. Unchanged from
  previous audit.
- **Backwards compatibility:** Backward-compatible — adding a distinct structured warning channel is
  additive.
- **Remediation:** Introduce a dedicated warning/error mechanism for storage write failures (counter,
  delegate hook, or distinct log level) separate from the general debug-only `hedgeLog`.

### n26 — Session Replay Privacy (❌ Fail)
- **Spec requires:** elements/views tagged with no-capture markers (`ph-no-capture`) MUST be treated
  as masked/excluded even when broad category masking is disabled; native wireframe replay MUST
  replace sensitive text values with masked strings and omit/placeholder sensitive image content;
  mask discovery MUST traverse the full matched subtree, not skip nodes via traversal shortcuts.
  Password/secure-entry masking should take precedence over an explicit no-mask override.
- **SDK currently:** **No-capture leak in default wireframe mode, reconfirmed still present.**
  `toWireframe` (`Replay/PostHogReplayIntegration.swift:1250-1385`) has no generic
  `view.isNoCapture()` check for arbitrary `UIView`s — `isNoCapture()` is only consulted inside typed-
  widget sensitivity helpers (`isTextInputSensitive`, `isImageViewSensitive`, etc.) that mask only
  text/image *content* on specific widget types; the final block unconditionally recurses into every
  subview regardless of any no-capture tag on the parent `UIView`. A plain `UIView` tagged
  `ph-no-capture` still has its child content captured in wireframe mode — the SDK's **default**
  capture mode (`screenshot = false`) — while the same view is correctly masked as an opaque rect in
  screenshot mode (`findMaskableWidgets`: `if view.isNoCapture() || maskChildren`). This is the same
  bug class independently found in posthog-android, and SwiftUI's `.postHogMask()`/`.postHogNoMask()`
  modifiers likewise only affect screenshot mode, not wireframe mode. The previously-reported
  **password/secure-field precedence bug in screenshot mode** (secure-entry checks running
  independently of the `postHogNoMask` short-circuit) was re-checked against current code and is
  **no longer reproducible** — `isTextFieldSensitive`/`isTextViewSensitive` now detect secure-text/
  sensitive-content-type independently of `maskAllTextInputs`, so a `postHogNoMask`-tagged secure
  field is still masked. Net: contract remains ❌ Fail overall due to the still-unresolved wireframe-
  mode no-capture leak, which is a real, silent data-privacy leak in the SDK's default capture mode.
- **Backwards compatibility:** Needs deprecation path for the fix mechanics — the change itself is
  additive (no signature changes) — but ship with a clear changelog/security-advisory note since apps
  relying on `ph-no-capture` on container views today are unknowingly leaking content in wireframe
  mode.
- **Remediation:** Add a generic `isNoCapture()`/mask-registry guard to `toWireframe` (mirroring the
  screenshot-mode fallback in `findMaskableWidgets`) that replaces the tagged element and its subtree
  with an opaque placeholder and skips recursion; extend the SwiftUI `.postHogMask()`/
  `.postHogNoMask()` modifier registry so it also applies in wireframe mode; add regression tests for
  both gaps.

### n27 — Surveys (❌ Fail)
- **Spec requires (new "Survey intro screen" requirement):** `SurveyAppearance` must expose
  `displayIntroScreen` (default off), `introScreenHeader`, `introScreenDescription`,
  `introScreenDescriptionContentType`, `introScreenButtonText`; the intro screen must show before
  question 1, not count as a response/event, be skipped when resuming in-progress or already-
  completed surveys, and its copy must be translatable via the existing per-language mechanism;
  dismissing it must emit `survey dismissed`.
- **SDK currently:** Confirmed absent end-to-end. `Surveys/Models/PostHogDisplaySurveyAppearance.swift`
  contains a complete trailing "thank you" implementation (`displayThankYouMessage`,
  `thankYouMessageHeader`, `thankYouMessageDescription`, `thankYouMessageDescriptionContentType`,
  `thankYouMessageCloseButtonText`) but zero `introScreen*`/`displayIntroScreen` fields anywhere in
  the model or its `init`. `grep -rn "introScreen\|IntroScreen\|intro_screen" PostHog/` returns no
  matches anywhere in the SDK source. `SurveyDisplayController.swift`'s `currentQuestionIndex`
  initializes straight to `0` with no intermediate "intro" state, and `isSurveyCompleted` gates only
  the trailing thank-you branch — there's no analogous leading-state check. `SurveySheet.swift` only
  has an `if isSurveyCompleted && displayThankYouMessage { ConfirmationMessage(...) }` branch, no
  counterpart intro-screen branch before the question flow. `SurveyTranslationResolver.swift`'s
  translation-diffing only checks `name`/`thankYouMessage*` fields — no `introScreen*` fields exist to
  translate. Since none of the required fields exist, none of the new acceptance scenarios (shown-
  when-enabled, off-by-default, no-event-on-advance, skip-when-resumed, dismiss-emits-survey-
  dismissed) can currently pass. This is a brand-new requirement (previously the whole Surveys
  contract was rated ✅ Pass before this requirement existed) — the rest of the Surveys contract
  (targeting/eligibility via `Utils/PostHogSurveyMatching.swift`, display-condition matching, response
  capture via `QuestionTypes.swift`/`MultipleChoiceOptions.swift`/etc., i18n) appears structurally
  intact based on directory/module presence, consistent with the previous Pass rating for those parts.
- **Backwards compatibility:** Backward-compatible to add — `displayIntroScreen` defaults to
  off/false per spec, so adding the new optional fields to `PostHogDisplaySurveyAppearance` (and
  whatever raw-survey-JSON → model mapping feeds it) is purely additive; existing surveys without the
  field continue to render exactly as today.
- **Remediation:** Add `displayIntroScreen`/`introScreenHeader`/`introScreenDescription`/
  `introScreenDescriptionContentType`/`introScreenButtonText` to `PostHogDisplaySurveyAppearance`
  (mirroring the existing `thankYouMessage*` fields) and thread them through the raw-survey decoding
  path; add intro-screen state to `SurveyDisplayController` (shown only when enabled AND no in-
  progress/completed response exists) and a corresponding view before the first question in
  `SurveySheet`; ensure advancing past the intro screen emits no event/response write; wire the new
  copy fields into `SurveyTranslationResolver`.

### n28 — Bootstrap (🟡 Partial)
- **Spec requires:** (optional — "MAY") a client SDK that owns a session id MAY accept a
  `sessionID` in the bootstrap config (UUIDv7), adopting it as the current session id and deriving
  the session start timestamp from its embedded timestamp; on an invalid value, SHALL log an error
  and fall back to generating a new id.
- **SDK currently:** Identity seeding and feature-flag/payload bootstrap are fully implemented and
  correct (`PostHogBootstrapConfig.swift`, `reconcileBootstrapIdentityIfNeeded` in `PostHogSDK.swift`,
  `$feature_flag_bootstrapped_response`/`_payload` enrichment). However,
  `PostHogBootstrapConfig.swift` declares only 4 fields (`distinctId`, `isIdentifiedId`,
  `featureFlags`, `featureFlagPayloads`) — no `sessionID`/`sessionId` field at all — and
  `PostHogSessionManager.swift` has zero references to "bootstrap" anywhere, always generating its
  own id via `rotateSession()` → `UUID.v7String()`. Since the spec phrases this as "MAY," this is a
  spec-permitted omission, not a violation — but iOS does own a client-side session manager, making
  it a natural candidate for the optional feature (as also flagged for posthog-android). Unchanged
  from previous audit.
- **Backwards compatibility:** Backward-compatible — adding an optional `sessionID` field to
  `PostHogBootstrapConfig` and a consumption path in `PostHogSessionManager` is purely additive;
  default (absent) behavior is unchanged.
- **Remediation:** Add optional `sessionID` bootstrap support if product wants full parity with SDKs
  that implement this optional capability.
