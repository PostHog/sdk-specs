# posthog-android — SDK Compliance

**Repo:** [PostHog/posthog-android](https://github.com/PostHog/posthog-android)
**Audited commit:** `0d2b16b02d5f34a4464dc3ccc0005c64a9d962a8` ([commit](https://github.com/PostHog/posthog-android/commit/0d2b16b02d5f34a4464dc3ccc0005c64a9d962a8)) — audited on 2026-08-06
**Audited against sdk-specs commit:** `b59e8b430c83c5549fc396c8b092615b79d08dd4`
**Summary:** 33 ✅ · 19 🟡 · 4 ❌ · 3 ➖ · 0 ❓

Note on repo layout: `posthog-android` is a monorepo. The shared cross-platform core (used by
both the Android SDK and the JVM/server SDK) lives at `posthog/src/main/java/com/posthog/`
(`PostHog.kt`, `PostHogStateless.kt`, `PostHogConfig.kt`, `PostHogInterface.kt`,
`internal/*` — queue, feature flags, session manager, replay wire model, logs OTLP, error
tracking). Android-specific integrations live at
`posthog-android/src/main/java/com/posthog/android/` (`PostHogAndroid.kt`,
`PostHogAndroidConfig.kt`, lifecycle/replay/surveys integrations). A separate
`posthog-server/` module holds JVM-server-only features (local flag evaluation, tracing
headers server-side context) that Android does not depend on. All file paths below are
relative to `/tmp/audit-posthog-android/` unless noted.

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Alias | 🟡 | [n1] |
| 2 | Capture | ✅ | |
| 3 | Capture Exception | 🟡 | [n2] |
| 4 | Create Person Profile | ➖ | [n3] |
| 5 | Debug | ✅ | |
| 6 | Exception Steps | ✅ | |
| 7 | Flush | ✅ | |
| 8 | Get Anonymous ID | ✅ | |
| 9 | Get Distinct ID | ✅ | |
| 10 | Get Feature Flag | ✅ | |
| 11 | Get Feature Flag Payload | ✅ | |
| 12 | Get Feature Flag Result | ✅ | |
| 13 | Get Feature Flags | 🟡 | [n4] |
| 14 | Get Feature Flags And Payloads | 🟡 | [n5] |
| 15 | Get Session ID | ✅ | |
| 16 | Group | 🟡 | [n6] |
| 17 | Group Identify | 🟡 | [n7] |
| 18 | Identify | ✅ | |
| 19 | Is Feature Enabled | ✅ | |
| 20 | Is Opt Out | ✅ | |
| 21 | Is Session Replay Active | ✅ | |
| 22 | On Feature Flags | 🟡 | [n8] |
| 23 | Opt In | 🟡 | [n9] |
| 24 | Register | 🟡 | [n10] |
| 25 | Reload Feature Flags | ✅ | |
| 26 | Reset | ✅ | |
| 27 | Reset Group Properties For Flags | ✅ | |
| 28 | Reset Person Properties For Flags | ✅ | |
| 29 | Screen | 🟡 | [n11] |
| 30 | Set Group Properties For Flags | ✅ | |
| 31 | Set Person Properties | ✅ | |
| 32 | Set Person Properties For Flags | ✅ | |
| 33 | Setup | ✅ | |
| 34 | Shutdown | ❌ | [n12] |
| 35 | Start Session Recording | ❌ | [n13] |
| 36 | Stop Session Recording | 🟡 | [n14] |
| 37 | Unregister | ✅ | |
| 38 | Bootstrap | 🟡 | [n15] |
| 39 | Application Lifecycle | ✅ | |
| 40 | Autocapture | ❌ | [n16] |
| 41 | Before Send Hook | 🟡 | [n17] |
| 42 | Consent Gating | ✅ | |
| 43 | Device ID Generator | ✅ | |
| 44 | Event Batcher | 🟡 | [n18] |
| 45 | Feature Flag Cache | ✅ | |
| 46 | Feature Flag Called Tracker | 🟡 | [n19] |
| 47 | Flag Definition Loader | ➖ | [n20] |
| 48 | HTTP Client | ✅ | |
| 49 | Local Feature Flag Evaluator | ➖ | [n21] |
| 50 | Persistent Storage | 🟡 | [n22] |
| 51 | Remote Config | ✅ | |
| 52 | Retry Queue | ✅ | |
| 53 | Session Manager | ✅ | |
| 54 | Session Replay Ingestion Controls | 🟡 | [n23] |
| 55 | Session Replay Privacy | 🟡 | [n24] |
| 56 | Surveys | 🟡 | [n25] |
| 57 | Logs | ✅ | |
| 58 | Traces | ❌ | [n26] |
| 59 | Tracing Headers | ✅ | |

## Notes

### n1 — Alias (🟡 Partial)
- **Spec requires:** the `acceptance/public/alias.feature` scenario (tagged `@client`) requires
  the enqueued `$create_alias` event's properties to include both `alias` and `distinct_id`.
- **SDK currently:** `alias(alias: String)` (`posthog/src/main/java/com/posthog/PostHog.kt:1166-1179`)
  builds `props["alias"] = alias` and calls `capture(PostHogEventName.CREATE_ALIAS.event, properties = props)`
  but never sets `props["distinct_id"]`. Confirmed against the SDK's own unit test
  (`PostHogTest.kt:1875-1899`), which only asserts `properties["alias"]`. (Spec prose itself notes
  "audited mobile client helpers do not require that duplication", creating tension between prose
  and the literal `@client` acceptance scenario — hence Partial rather than Fail.)
- **Backwards compatibility:** Backward-compatible — adding `props["distinct_id"] = distinctId` at
  `PostHog.kt:1176` is purely additive to the event payload.
- **Remediation:** Set `distinct_id` alongside `alias` in the `$create_alias` properties map.

### n2 — Capture Exception (🟡 Partial)
- **Spec requires:** acceptance scenario `capture-exception.feature:12-21` ("Capturing a handled
  exception emits an exception event") requires top-level `$exception_type` / `$exception_message`
  properties on the captured event, in addition to the nested `$exception_list`.
- **SDK currently:** `captureException()` (`PostHog.kt:843-875`, `PostHogStateless.kt:642-679`)
  delegates to `ThrowableCoercer.fromThrowableToPostHogProperties`
  (`posthog/src/main/java/com/posthog/internal/errortracking/ThrowableCoercer.kt:28-143`), which
  only produces nested `$exception_list[].type` / `.value` (lines 108, 119). A repo-wide grep
  confirms zero SDK-generated top-level `$exception_type`/`$exception_message` occurrences.
- **Backwards compatibility:** Backward-compatible — additively stamp
  `exceptionProperties["$exception_type"]` / `["$exception_message"]` from
  `throwableList.first()` around `ThrowableCoercer.kt:133-142`.
- **Remediation:** Add the two top-level convenience properties alongside the existing
  `$exception_list`.

### n3 — Create Person Profile (➖ N/A)
- **Spec requires:** a `createPersonProfile()`-style method to force person-profile creation.
- **SDK currently:** No such method exists anywhere in `posthog/src/main/java/com/posthog/` or
  `posthog-android/src/main/java/com/posthog/android/` (confirmed via exhaustive grep and full
  enumeration of `PostHogInterface.kt`'s public surface). The spec's own **Applicability** section
  states this API is present only in the `posthog-js` family and that "other audited client SDKs
  do not expose an equivalent public method" — explicitly scoping Android out.
- **Backwards compatibility:** N/A — no remediation required per spec scope.

### n4 — Get Feature Flags (🟡 Partial)
- **Spec requires:** a public bulk getter returning a flat key→value map (`Record<string,
  boolean|string>`), cache-only (no network I/O), no `$feature_flag_called` side effect.
- **SDK currently:** No public method named `getFeatureFlags()` exists on `PostHogInterface`/
  `PostHogCoreInterface`. A same-named method exists only internally
  (`internal/PostHogFeatureFlagsInterface.kt:16`, impl `internal/PostHogRemoteConfig.kt:1149-1160`,
  correctly cache-only and side-effect-free) but is not exposed publicly. The only public bulk
  getter is `getAllFeatureFlags(): List<FeatureFlagResult>?` (`PostHogInterface.kt:164`, impl
  `PostHog.kt:1772-1781`), a list of `{key, enabled, variant, payload}` objects rather than a flat
  map — callers must transform it themselves to get the spec's shape.
- **Backwards compatibility:** Backward-compatible — expose the existing internal
  `PostHogRemoteConfig.getFeatureFlags()` map via a new public
  `PostHogInterface.getFeatureFlags(): Map<String, Any>?`; purely additive alongside
  `getAllFeatureFlags()`.
- **Remediation:** Add the new public method; keep `getAllFeatureFlags()` unchanged for
  compatibility.

### n5 — Get Feature Flags And Payloads (🟡 Partial)
- **Spec requires:** a bulk getter returning a `{flags, payloads}` pair of maps, with empty maps
  (not `null`) when no flags are known.
- **SDK currently:** No API named `getFeatureFlagsAndPayloads` or returning a two-map
  `{flags, payloads}` shape exists (grep for "AndPayloads"/"FeatureFlagPayloads" finds no bulk-
  combined match). `getAllFeatureFlags(): List<FeatureFlagResult>?` (`PostHogInterface.kt:159-164`,
  impl `PostHog.kt:1772-1781`) does carry both values and payloads (test `PostHogTest.kt:912-943`)
  but as a `List<FeatureFlagResult>`, and returns `null` rather than empty maps when
  disabled/empty (`PostHog.kt:1773`), diverging from the "empty when no flags known" acceptance
  scenario.
- **Backwards compatibility:** Backward-compatible — add a new method deriving
  `{flags: Map, payloads: Map}` from the same underlying `remoteConfig` data; keep
  `getAllFeatureFlags()` unchanged.
- **Remediation:** Add the new public method returning empty (not null) maps when no flags are
  known.

### n6 — Group (🟡 Partial)
- **Spec requires:** `group(type, key, properties)` MUST reject blank/empty `type`/`key` (context
  unchanged, warning logged), per `openspec/specs/group/spec.md:128-131`.
- **SDK currently:** `group(type, key, groupProperties)` (`PostHog.kt:1543-1601`) guards on
  `isEnabled()`/`isOptedOut()`/`requirePersonProcessing("group")`, but neither `group()` nor
  `groupStateless()` (`PostHogStateless.kt:395-413`) validates blank `type`/`key` before persisting
  and emitting `$groupidentify` — confirmed by full read of both method bodies (no such check,
  unlike `identify()`'s blank-id guard at `PostHog.kt:1279-1282`).
- **Backwards compatibility:** Backward-compatible — add an early-return blank-check guard at the
  top of `group()`/`groupStateless()`; only affects currently-malformed (blank) input.
- **Remediation:** Add shared blank `type`/`key` validation, matching `identify()`'s pattern.

### n7 — Group Identify (🟡 Partial)
- **Spec requires:** same blank-`type`/`key` rejection as Group (Android has no standalone public
  `groupIdentify` method, which matches the spec's documented Android variant — `group()`
  internally emits `$groupidentify`).
- **SDK currently:** Same root cause as Group — `groupStateless()`
  (`PostHogStateless.kt:395-413`) never validates blank `type`/`key` before enqueuing
  `$groupidentify`, failing the "Group identify requires type and key" acceptance scenario
  (expects zero events + warning). Event shape (`$group_type`, `$group_key`, `$group_set`)
  otherwise verified correct via `PostHogTest.kt:1901-1923`.
- **Backwards compatibility:** Backward-compatible — same fix as Group (shared validation helper);
  no new public surface needed since Android has no separate `groupIdentify` entry point.
- **Remediation:** Add the same blank-check guard used for `group()`.

### n8 — On Feature Flags (🟡 Partial)
- **Spec requires:** a listener mechanism supporting multiple independent subscribers, with
  late-registered listeners immediately invoked with current values if flags are already loaded.
- **SDK currently:** `PostHogConfig.onFeatureFlags: PostHogOnFeatureFlags? = null`
  (`PostHogConfig.kt:155`) is a single mutable `var`, not a registry — a second registration
  silently clobbers the first (no add/remove semantics), and a listener registered after flags are
  already loaded is not invoked until the next load cycle (no immediate-fire-on-late-registration).
  Correctly invoked on startup/bootstrap/`reloadFeatureFlags()`/`identify()`
  (`PostHog.kt:1342, 1371`)/`group()` (`PostHog.kt:1599`), with exceptions caught and logged
  (`PostHog.kt:1604-1610`).
- **Backwards compatibility:** Needs deprecation path — a true multi-listener registry with
  add/remove and fire-on-late-registration changes the current last-write-wins single-slot
  contract.
- **Remediation:** Add `addOnFeatureFlagsListener`/`removeOnFeatureFlagsListener` APIs alongside
  the existing `config.onFeatureFlags` field (retained for compatibility), firing synchronously on
  registration if flags are already loaded.

### n9 — Opt In (🟡 Partial)
- **Spec requires:** (optional, per spec's permissive language) opt-out MAY also clear local
  persistence (distinct id, anonymous id, super properties) when configured.
- **SDK currently:** `optIn()`/`optOut()` (`PostHog.kt:1088-1099`, `1101-1115`) correctly gate
  capture across all surfaces and persist immediately; core opt-out/opt-in acceptance scenarios
  pass. `optOut()` takes zero parameters (`PostHogCoreInterface.kt:41`) and no
  `clearPersistedProperties`-style option/overload exists (grep for `clearPersisted`/
  `ClearOnOptOut` returns nothing) — its only cleanup is the exception-steps buffer and push-token
  cache, not `distinctId`/`anonymousId`/super properties.
- **Backwards compatibility:** Backward-compatible — this capability is explicitly optional per
  spec language ("some SDKs also clear... if needed"). Add an optional parameter (e.g.
  `optOut(clearLocalStorage: Boolean = false)`).
- **Remediation:** Add the optional clear-on-opt-out parameter, mirroring the browser SDK pattern.

### n10 — Register (🟡 Partial)
- **Spec requires:** (permissive — "MAY reject") blank/empty keys should not silently persist as
  stray super properties.
- **SDK currently:** `register(key, value)` / `unregister(key)` (`PostHogInterface.kt:241-250`,
  impl `PostHog.kt:1925-1944`) match the spec's documented Android key/value surface variant and
  correctly reject reserved internal keys (`PostHog.kt:1932-1935`), but there is no check for
  blank/empty keys (no such test exists in `PostHogTest.kt:1992-2001`) — an empty-string key would
  silently persist.
- **Backwards compatibility:** Backward-compatible — add a blank-key guard mirroring the existing
  reserved-key check; spec's validation language here is permissive, so this is a minor gap.
- **Remediation:** Add blank-key rejection to `register()`.

### n11 — Screen (🟡 Partial)
- **Spec requires:** the explicit `screenTitle`/`name` argument MUST win over any conflicting
  `$screen_name` supplied via the `properties` map.
- **SDK currently:** `screen(screenTitle, properties)` (`PostHog.kt:1139-1164`) sets
  `props["$screen_name"] = trimmedTitle` and then does `properties?.let { props.putAll(it) }`
  (`PostHog.kt:1156-1161`) — a caller-supplied `$screen_name` inside `properties` silently
  overwrites the explicit `screenTitle` argument, the opposite of the spec's precedence rule.
  Auto-tracking via `PostHogActivityLifecycleCallbackIntegration.onActivityStarted`
  (`posthog-android/src/main/java/com/posthog/android/internal/PostHogActivityLifecycleCallbackIntegration.kt:110-118`)
  gated by `PostHogAndroidConfig.captureScreenViews` (default true) is otherwise correct.
- **Backwards compatibility:** Needs deprecation path — correct fix (apply title-derived
  `$screen_name` last) is safe for the vast majority of callers, but any caller relying on the
  current override behavior would see a silent change; call out in changelog.
- **Remediation:** Apply `props["$screen_name"] = trimmedTitle` after merging caller `properties`,
  not before.

### n12 — Shutdown (❌ Fail)
- **Spec requires:** shutdown (`close()`) SHALL flush pending events before tearing down so queued
  data is not lost.
- **SDK currently:** `PostHog.close()` (`PostHog.kt:479-524`) never calls `flush()` — verified
  directly: the close body proceeds straight to `queue?.stop(); replayQueue?.stop();
  logsQueue?.stop()` (lines 507-509) without invoking `flush()` (a distinct method defined
  separately at `PostHog.kt:1809`). `PostHogQueue.stop()` only cancels the flush timer and
  unregisters network status; it does not drain the deque or force-upload cached/queued events.
  The same gap exists in `PostHogStateless.close()` (`PostHogStateless.kt:106-135`). Events remain
  cached on disk until a future `queue.start()`/`flush()` (e.g. next app launch via
  `PostHogSendCachedEventsIntegration`).
- **Backwards compatibility:** Backward-compatible — adding a `flush()` call at the top of
  `close()`/`PostHogStateless.close()` is purely additive; no signature change, only makes
  shutdown actually deliver pending events as specified.
- **Remediation:** Call `flush()` (bounded by a reasonable timeout) at the start of `close()`.

### n13 — Start Session Recording (❌ Fail)
- **Spec requires:** session recording MUST remain inactive (or refuse to start) while the user is
  opted out.
- **SDK currently:** `startSessionReplay(resumeCurrent: Boolean = true)`
  (`PostHog.kt:2126-2163`, interface `PostHogInterface.kt:318`) only guards on `isEnabled()`
  (`PostHog.kt:2127`) — verified directly that `isOptedOut()` is never called in
  `startSessionReplay`/`stopSessionReplay`/`isSessionReplayActive` (lines 2108-2180), unlike
  sibling opt-out-respecting APIs at `PostHog.kt:2014, 2038, 2055`. Calling `startSessionReplay()`
  while opted out sets `isSessionReplayActive = true` and starts the replay integration lifecycle
  regardless. Idempotency, remote-config/linked-flag gating, and sampling gating are otherwise
  correctly implemented.
- **Backwards compatibility:** Backward-compatible — adding an `isOptedOut()` guard at the top of
  `startSessionReplay` (mirroring `capture()`/push-token methods) is additive; no legitimate caller
  depends on replay starting while opted out.
- **Remediation:** Add an `isOptedOut()` check to `startSessionReplay()`.

### n14 — Stop Session Recording (🟡 Partial)
- **Spec requires:** stopping session recording should finalize/flush pending replay data, and
  (for symmetry with start) should be opt-out aware.
- **SDK currently:** `stopSessionReplay()` (`PostHog.kt:2165-2180`) correctly no-ops if already
  inactive, but (1) does not flush the replay queue before deactivating — flushing is only
  reachable via the separate `PostHog.flush()` API, so pending snapshot data isn't guaranteed to
  be finalized synchronously at stop time; (2) has the same `isOptedOut()` asymmetry as
  start-session-recording (only `isEnabled()` guard at line 2166), lower-impact since stopping
  while opted out is a benign outcome.
- **Backwards compatibility:** Backward-compatible — explicitly flushing the replay queue inside
  `stop()` is additive/clarifying, no signature or common-case behavior change.
- **Remediation:** Flush the replay queue synchronously inside `stopSessionReplay()`.

### n15 — Bootstrap (🟡 Partial)
- **Spec requires:** (optional — "MAY") a client SDK that owns a session id MAY accept a
  `sessionID` in the bootstrap config (UUIDv7) and adopt it as the current session id, deriving
  the session start timestamp from it.
- **SDK currently:** Identity seeding/reconciliation and feature-flag/payload bootstrap are fully
  implemented and correct (`applyBootstrapIfNeeded()` `PostHog.kt:397-437`,
  `reconcileBootstrapIdentityIfNeeded()` `PostHog.kt:439-477`, pre-network flag seeding in
  `internal/PostHogRemoteConfig.kt:84-89`, `$feature_flag_bootstrapped_response` etc. via
  `getBootstrapCalledValues()` `PostHogRemoteConfig.kt:1389-1406`). However,
  `PostHogBootstrapConfig` (`posthog/src/main/java/com/posthog/PostHogBootstrapConfig.kt:24-59`)
  has zero `sessionID`/`sessionId` field, confirmed via grep — session ids are always freshly
  generated by `internal/PostHogSessionManager.kt` (`TimeBasedEpochGenerator.generate()`, lines
  75, 132), never seeded from bootstrap config. Since the spec phrases this as "MAY," it is a
  spec-permitted omission rather than a strict violation, but Android does own a client-side
  session manager, making it a strong candidate for the optional feature.
- **Backwards compatibility:** Backward-compatible — adding an optional `sessionID` field to
  `PostHogBootstrapConfig` and wiring it into `PostHogSessionManager.startSession()` (validate
  UUIDv7, else fall back to generated id) is purely additive.
- **Remediation:** Add optional `sessionID` bootstrap support if product wants full parity with
  SDKs that implement this optional capability.

### n16 — Autocapture (❌ Fail)
- **Spec requires:** generic UI-interaction autocapture — `$autocapture` events with
  `$elements_chain`/`$elements` metadata for taps/clicks on interactive views, with no-capture
  markers and sensitive-field filtering, OR an explicit documented carve-out if intentionally
  unsupported.
- **SDK currently:** No `$autocapture` event, `$elements_chain`/`$elements` metadata, or generic
  UI-interaction-capture pipeline exists anywhere in either module (verified via direct grep — zero
  hits outside unrelated **exception** autocapture,
  `posthog/src/main/java/com/posthog/errortracking/PostHogErrorTrackingConfig.kt`/
  `PostHogErrorTrackingAutoCaptureIntegration.kt`, which the spec explicitly scopes out as a
  separate component).
  `posthog-android/src/main/java/com/posthog/android/internal/PostHogTouchActivityIntegration.kt`
  is not an autocapture implementation: its `touchInterceptor` (lines 32-40) exists solely to call
  `PostHogSessionManager.touchSession()` on every `MotionEvent` for session-idle/rotation timing —
  it never inspects the touched view, builds element metadata, or calls `capture()`. No
  `captureTouches`/`captureElementInteractions` config exists in `PostHogAndroidConfig.kt` (only
  `captureApplicationLifecycleEvents`, `captureDeepLinks`, `captureScreenViews`, push flags). The
  SDK also does not document that generic interaction autocapture is unsupported, as the spec
  requires when intentionally out of scope.
- **Backwards compatibility:** Backward-compatible — this is a net-new feature gap (an entire
  touch/view-hierarchy capture pipeline), not a behavioral regression; building it would not break
  existing consumers.
- **Remediation:** Either build a tap/click autocapture pipeline (view-hierarchy walk +
  `$elements_chain` construction + no-capture/sensitive-field filtering, likely reusing masking
  primitives already built for session replay), or explicitly document the carve-out per the
  spec's allowance.

### n17 — Before Send Hook (🟡 Partial)
- **Spec requires:** multiple registered hooks run in a chain, each receiving the **previous**
  hook's mutated output; an exception in one hook should not silently drop the event (fall back to
  original/last-good value).
- **SDK currently:** Multi-hook support is real (`PostHogBeforeSend.kt:8-16`,
  `PostHogConfig.kt:484-516` stores hooks in a lock-guarded `MutableList`), and the pipeline
  position (after full event assembly, before enqueue) and drop-on-`null` semantics are correct.
  Two verified bugs in `posthog/src/main/java/com/posthog/PostHogStateless.kt`: (1) **line 310** —
  `eventChecked = beforeSend.run(postHogEvent)` passes the original, pristine `postHogEvent` to
  every hook in the loop, never the previous hook's output — hook #2 never sees hook #1's
  mutation, for chains of 2+ hooks; (2) **lines 315-317** —
  `catch (e: Throwable) { config?.logger?.log(...); return null }` drops the event entirely on any
  hook exception rather than falling back to the original/last-good value.
- **Backwards compatibility:** Backward-compatible for both — (1) passing `eventChecked` instead of
  `postHogEvent` into each iteration only changes behavior for callers with 2+ hooks where an
  earlier hook mutates the event (untested case today); (2) returning `eventChecked` (last-good
  value) on exception is strictly less destructive than the current drop.
- **Remediation:** Fix the chain-passing bug at `PostHogStateless.kt:310` and change the exception
  branch to return the last-good value instead of `null`.

### n18 — Event Batcher (🟡 Partial)
- **Spec requires:** periodic flush driven by the SDK's injectable clock abstraction (so tests can
  simulate elapsed time without a real wall-clock wait).
- **SDK currently:** `internal/PostHogQueue.kt` correctly implements FIFO accumulation, threshold
  flush (`flushAt`, default 20), a distinct `maxBatchSize` cap (default 50), explicit `flush()`,
  single-thread executor, single-flush-in-flight guard, and 413-triggered batch halving — matching
  the spec. However, the periodic timer uses `java.util.Timer(true)` with real wall-clock
  scheduling rather than the SDK's own injectable `config.dateProvider` abstraction used elsewhere
  in the same file (e.g., retry backoff) — production behavior is correct, but the mechanism can't
  be driven by a mocked/fake clock as the acceptance scenario's literal test setup implies.
- **Backwards compatibility:** Backward-compatible — swap to a `dateProvider`-driven scheduled
  executor internally; no public API change, default real-time behavior unchanged.
- **Remediation:** Route the periodic-flush timer through `config.dateProvider` for testability.

### n19 — Feature Flag Called Tracker (🟡 Partial)
- **Spec requires:** when the server signals `minimalFlagCalledEvents` (minimal-event mode), the
  minimized `$feature_flag_called` event MUST still retain an allowlist of session-attribution
  properties (`$referring_domain`, UTM params, `gclid`/`fbclid`) and static platform/OS identity
  properties.
- **SDK currently:** Core dedup semantics (two trackers: `PostHog.kt`'s `featureFlagsCalled` map
  and `internal/PostHogFeatureFlagCalledCache.kt` LRU) and minimal-event gate mechanics
  (`minimalFlagCalledEvents` parsing, `has_experiment` wiring, fail-safe-to-full-event defaults)
  are all correct. But the allowlist itself
  (`MINIMAL_FEATURE_FLAG_CALLED_PROPERTIES`, `PostHogStateless.kt` ~lines 693-711) is missing two
  full spec-mandated categories: (1) session-attribution properties (`$referring_domain`,
  `utm_source`/`utm_medium`/`utm_campaign`/`utm_content`/`utm_term`/`gad_source`/`mc_cid`,
  `gclid`/`fbclid`) — the exact category this sdk-specs repo added in commit `b59e8b4` after
  finding the same gap in posthog-js/-node; (2) static platform/OS identity properties
  (`$app_version`, `$os_name`, `$os_version`, `$device_manufacturer`, `$device_model`, etc., set by
  `posthog-android/src/main/java/com/posthog/android/internal/PostHogAndroidContext.kt:42-57`) —
  every minimized event on Android today unconditionally loses all OS/device identity whenever the
  server gate is on.
- **Backwards compatibility:** Backward-compatible — adding the missing keys to
  `MINIMAL_FEATURE_FLAG_CALLED_PROPERTIES` only widens what a minimized event includes; strictly
  additive.
- **Remediation:** Port the same allowlist fix applied to posthog-js/-node (commit `b59e8b4`) to
  Android's `MINIMAL_FEATURE_FLAG_CALLED_PROPERTIES`, adding both the UTM/session-attribution and
  platform-identity categories.

### n20 — Flag Definition Loader (➖ N/A)
- **Spec requires:** ETag-based polling of flag definitions for local evaluation, requiring a
  personal/admin API key.
- **SDK currently:** Acceptance feature is tagged `@private @canonical_behavior @acceptance
  @flag_definition_loader @server` — explicitly `@server`, not `@both`/`@client`. The matching
  implementation, `LocalEvaluationPoller.kt`, lives only at
  `posthog-server/src/main/java/com/posthog/server/internal/LocalEvaluationPoller.kt`.
  `posthog-android/build.gradle.kts` declares a dependency only on `:posthog` (the shared core),
  not `:posthog-server` — confirmed no ETag polling loop, personal-API-key config, or external
  cache-provider extension point exists in any module Android depends on.
- **Backwards compatibility:** N/A — justified by the feature file's own `@server` tag and the
  module dependency graph; a mobile app cannot safely hold a personal/admin API key.

### n21 — Local Feature Flag Evaluator (➖ N/A)
- **Spec requires:** local (in-process) rule-based flag evaluation using flag definitions fetched
  via a personal/admin API key, avoiding network round-trips per evaluation. Spec text notes this
  is "most prominent in server SDKs."
- **SDK currently:** `FlagEvaluator.kt` and `PostHogFeatureFlagEvaluations.kt` (the rule-matching
  engine) live exclusively at `posthog-server/src/main/java/com/posthog/server/internal/` — the
  JVM server module. `posthog-android/build.gradle.kts:102` depends only on `:posthog`. The shared
  `posthog` core module contains only data models
  (`internal/PostHogLocalEvaluationModels.kt`, `internal/LocalEvaluationApiResponse.kt`), no
  evaluator logic. `PostHogStateless.kt:691-692` explicitly comments that the `locally_evaluated`
  property is "set only by posthog-server." No `personalApiKey`/local-evaluation config option
  exists in `PostHogConfig.kt`.
- **Backwards compatibility:** N/A — a mobile SDK cannot safely hold a personal/admin API key;
  local rule evaluation is confined to the server module, which Android does not depend on.

### n22 — Persistent Storage (🟡 Partial)
- **Spec requires:** storage failures MUST NOT crash SDK calls, and the SDK SHALL record a storage
  warning when a write fails.
- **SDK currently:** `posthog-android/src/main/java/com/posthog/android/internal/PostHogSharedPreferences.kt`
  is a correct, lock-synchronized, per-API-key-namespaced Android store with selective
  `clear(except)` and Direct-Boot write buffering. However, `PostHog.register()`
  (`posthog/src/main/java/com/posthog/PostHog.kt:1936`) calls `getPreferences().setValue(key,
  value)` with no try/catch, and inside `PostHogSharedPreferences.setValue` (lines 119-173) only
  the `serializeObject` branch is guarded — the primitive `putBoolean`/`putString`/`putFloat`/
  `putLong`/`putInt` branches and `edit.apply()` are unguarded, and there is no dedicated "storage
  warning" log signal anywhere (grep returns zero hits).
- **Backwards compatibility:** Backward-compatible — wrap `setValue` call sites (or the method
  itself) in try/catch and log a distinct warning; purely additive, no change to the success path.
- **Remediation:** Guard the primitive-write branches of `PostHogSharedPreferences.setValue` and
  emit a storage-warning log on failure.

### n23 — Session Replay Ingestion Controls (🟡 Partial)
- **Spec requires:** event-trigger gating for session replay must observe the final (post-
  `beforeSend`) event name, since a hook may rename an event.
- **SDK currently:** Enablement gating (local config + remote linked-flag with fail-closed
  default), deterministic session-keyed sampling, and minimum-duration buffering are all correctly
  implemented (`PostHog.kt:2098-2136`, `internal/PostHogRemoteConfig.kt:180-233, 1206-1219,
  454-466`). However, `PostHog.kt:836` passes the **pre-before-send** `event` name (not
  `postHogEvent.event`) into `sessionReplayHandler?.onEvent(...)`, even though the same function's
  comment at line 813 acknowledges the event may be renamed by a `beforeSend` hook — event-trigger
  matching would see the stale name if a hook renames (not drops) an event.
- **Backwards compatibility:** Backward-compatible — one-line swap to `postHogEvent.event`, no
  API/wire change.
- **Remediation:** Pass `postHogEvent.event` instead of the pre-hook `event` variable at
  `PostHog.kt:836`.

### n24 — Session Replay Privacy (🟡 Partial)
- **Spec requires:** elements explicitly tagged no-capture MUST be excluded from replay wireframes
  in all capture modes (not just screenshot mode); unmask/password precedence should be consistent
  across UI frameworks.
- **SDK currently:** Default text/image masking, password special-casing, and fail-closed
  screenshot-mode masking are all correctly implemented
  (`posthog-android/src/main/java/com/posthog/android/replay/PostHogReplayIntegration.kt`). But (1)
  `isNoCapture()` (lines 1858-1861) is consulted only in the screenshot-mode masking path (lines
  1021-1025) — never inside `toWireframe()` (lines 1356-1654), which is Android's **default**
  capture mode (`screenshot = false` per `PostHogSessionReplayConfig.kt:38`); a view tagged
  `ph-no-capture` is still emitted as a full wireframe node with children in default mode. (2)
  Unmask-vs-password precedence differs between the View path (password always wins,
  lines 990-993) and the Compose path (`postHogUnmask()` wins over password detection, lines
  1130-1152) — same developer intent, different security-relevant outcome depending on UI
  framework.
- **Backwards compatibility:** Needs deprecation path for (1) — adding an early-return `null` in
  `toWireframe()` for tagged nodes changes what data leaves the device for tagged views in the
  default capture mode, so should ship with a changelog note. (2) is Backward-compatible — align
  Compose to match View's more conservative precedence.
- **Remediation:** Honor `isNoCapture()` inside `toWireframe()`, not just the screenshot path; align
  Compose's unmask/password precedence with the View path.

### n25 — Surveys (🟡 Partial)
- **Spec requires:** (acceptance scenario, `@client`, surveys.feature:126-135) non-web/native SDKs
  MUST exclude surveys whose only display-targeting conditions are web-only (`url`/`selector`).
- **SDK currently:** Rich, otherwise-correct implementation
  (`posthog-android/src/main/java/com/posthog/android/surveys/PostHogSurveysIntegration.kt`, 1047
  lines) covering active/date-window filtering, device-type matching, seen state, wait period,
  linked/targeting/multi feature-flag gating, event-based activation, all 5 question types, and
  opt-out-gated event emission. But `getActiveMatchingSurveys()` (lines 226-277) never reads
  `survey.conditions?.url` or `survey.conditions?.selector` anywhere (confirmed via exhaustive grep
  across both modules — zero matches for `conditions?.url`, `conditions?.selector`,
  `doesSurveyUrlMatch`, `doesSurveySelectorMatch`), even though `SurveyConditions.kt:3-11`
  deserializes those fields. A survey whose only targeting condition is a CSS selector or URL match
  passes all Android eligibility checks and is shown natively with an inert, non-functional
  targeting condition — the exact failure mode the acceptance scenario is designed to prevent. No
  existing test covers this exclusion.
- **Backwards compatibility:** Needs deprecation path — the fix is additive (a new exclusion check
  tightens eligibility, no public API change) but is a user-visible behavior change (some
  currently-shown surveys would stop displaying), so ship with a changelog note.
- **Remediation:** Add a filter step in `getActiveMatchingSurveys()` excluding surveys where
  `url`/`selector` are the *only* configured display-targeting condition.

### n26 — Traces (❌ Fail)
- **Spec requires:** OpenTelemetry-shaped span/trace capture (`startSpan`/`withSpan`/
  `getActiveSpan`/`beforeSpanSend`, `resourceSpans`/`scopeSpans` OTLP payload) shipped to
  `POST {host}/i/v1/traces`. Spec text explicitly discusses mobile ports throughout (e.g. "mobile
  ports SHOULD use their structured-concurrency context primitive," "mobile ports MAY choose a
  larger default"), so mobile is in scope, not exempt.
- **SDK currently:** Zero implementation anywhere in the repo. `grep -rin
  "startSpan|withSpan|getActiveSpan|beforeSpanSend|resourceSpans|scopeSpans|maxLiveSpans|
  maxSpanAgeMs|maxExportBatchSize"` across all `.kt` files returns no matches. No `/i/v1/traces`
  endpoint string exists anywhere (`PostHogApiEndpoint` enum only has `BATCH, SNAPSHOT`;
  `EndpointSpec.kt` only has `batch()`/`snapshot()`/`logs()` factories, no `traces()`). The only
  trace/span-adjacent code is (a) the unrelated `tracing-headers` capability
  (`PostHogOkHttpInterceptor.kt`, W3C-style distinct-id/session-id header propagation — a distinct
  capability per the traces spec's own purpose statement) and (b) `traceId`/`spanId`/`traceFlags`
  correlation fields on `captureLog`, which are pass-through metadata, not a tracing API. `git log
  --all --oneline | grep -i "trace|span"` returns nothing; no other branches exist.
- **Backwards compatibility:** Backward-compatible — the spec itself states tracing SHALL be off
  until the `traces` config is provided while the product is pre-GA, so the entire public API
  surface (`startSpan`, `withSpan`, `getActiveSpan`, `beforeSpanSend`, `traces` config block) is
  wholly new; nothing existing needs to change or deprecate.
- **Remediation:** Implement the traces capability net-new: span data model, OTLP
  `resourceSpans`/`scopeSpans` builder, bounded live-span tracking, dedicated queue, and the
  `/i/v1/traces` transport — likely reusing much of the logs pipeline's OTLP/queue machinery
  (`internal/logs/PostHogLogsOTLP.kt`, `internal/PostHogQueue.kt`) as a template.
