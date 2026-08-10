# posthog-android — SDK Compliance

**Repo:** [PostHog/posthog-android](https://github.com/PostHog/posthog-android)
**Audited commit:** `8659a7b4d931ff9a84c38f5d77a69e40b8a43855` ([commit](https://github.com/PostHog/posthog-android/commit/8659a7b4d931ff9a84c38f5d77a69e40b8a43855)) — audited on 2026-08-10
**Audited against sdk-specs commit:** `2036abde806bc6598c100f8c5d25ba7c608e0eea`
**Summary:** 31 ✅ · 16 🟡 · 9 ❌ · 3 ➖ · 0 ❓

Note on repo layout: `posthog-android` is a monorepo. The shared cross-platform core (used by
both the Android SDK and the JVM/server SDK) lives at `posthog/src/main/java/com/posthog/`
(`PostHog.kt`, `PostHogStateless.kt`, `PostHogConfig.kt`, `PostHogInterface.kt`,
`internal/*` — queue, feature flags, session manager, replay wire model, logs OTLP, error
tracking). Android-specific integrations live at
`posthog-android/src/main/java/com/posthog/android/` (`PostHogAndroid.kt`,
`PostHogAndroidConfig.kt`, lifecycle/replay/surveys integrations). A separate
`posthog-server/` module holds JVM-server-only features (local flag evaluation, tracing
headers server-side context) that Android does not depend on — confirmed this cycle by
re-reading `posthog-android/build.gradle.kts` (single project dependency: `api(project(":posthog"))`)
and `settings.gradle.kts` (no back-reference from `:posthog-android` to `:posthog-server`).
This cycle's investigated drift (`PostHogMemoryQueue.kt`'s `add(event)`→`add(record)` parameter
rename) was traced to `posthog-server/src/main/java/com/posthog/server/internal/PostHogMemoryQueue.kt`
— a file that exists *only* in the server module and is unreachable from Android; it has zero
effect on the Android SDK's actual event batcher (`posthog/src/main/java/com/posthog/internal/PostHogQueue.kt`,
shared core, audited fresh below). All file paths below are relative to
`/tmp/audit/posthog-android/` unless noted.

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Alias | ❌ | [n1] |
| 2 | Capture | ✅ | |
| 3 | Capture Exception | ❌ | [n2] |
| 4 | Create Person Profile | ➖ | [n3] |
| 5 | Debug | ✅ | |
| 6 | Exception Steps | ✅ | |
| 7 | Flush | ✅ | |
| 8 | Get Anonymous ID | ✅ | |
| 9 | Get Distinct ID | ✅ | |
| 10 | Get Feature Flag | ✅ | |
| 11 | Get Feature Flag Payload | ✅ | |
| 12 | Get Feature Flag Result | ✅ | |
| 13 | Get Feature Flags | ❌ | [n4] |
| 14 | Get Feature Flags And Payloads | ❌ | [n5] |
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
| 29 | Screen | ❌ | [n11] |
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
| 42 | Consent Gating | 🟡 | [n18] |
| 43 | Device ID Generator | ✅ | |
| 44 | Event Batcher | 🟡 | [n19] |
| 45 | Feature Flag Cache | ✅ | |
| 46 | Feature Flag Called Tracker | 🟡 | [n20] |
| 47 | Flag Definition Loader | ➖ | [n21] |
| 48 | HTTP Client | 🟡 | [n22] |
| 49 | Local Feature Flag Evaluator | ➖ | [n23] |
| 50 | Persistent Storage | 🟡 | [n24] |
| 51 | Remote Config | ✅ | |
| 52 | Retry Queue | ✅ | |
| 53 | Session Manager | ✅ | |
| 54 | Session Replay Ingestion Controls | 🟡 | [n25] |
| 55 | Session Replay Privacy | 🟡 | [n26] |
| 56 | Surveys | 🟡 | [n27] |
| 57 | Logs | ✅ | |
| 58 | Traces | ❌ | [n28] |
| 59 | Tracing Headers | ✅ | |

## Notes

### n1 — Alias (❌ Fail)
- **Spec requires:** `acceptance/public/alias.feature:12-21` (tagged `@both`, applies to client
  SDKs) requires the enqueued `$create_alias` event's properties to include both `alias` and
  `distinct_id`.
- **SDK currently:** `alias(alias: String)` (`posthog/src/main/java/com/posthog/PostHog.kt:1164-1178`)
  builds `props["alias"] = alias` and calls `capture(PostHogEventName.CREATE_ALIAS.event,
  properties = props)` but never sets `props["distinct_id"]`. Confirmed by direct read of the
  current method body this cycle. `buildProperties()` also does not inject `distinct_id` for
  `$create_alias` events. Re-scored from 🟡 Partial (prior audit) to ❌ Fail this cycle: the
  required property is entirely absent, not partially present, and the acceptance scenario is
  tagged `@both` (applies to client), not just server — there is no ambiguity carve-out.
- **Backwards compatibility:** Backward-compatible — adding `props["distinct_id"] = distinctId` at
  `PostHog.kt:~1176` is purely additive to the event payload.
- **Remediation:** Set `distinct_id` alongside `alias` in the `$create_alias` properties map.

### n2 — Capture Exception (❌ Fail)
- **Spec requires:** `acceptance/public/capture-exception.feature` (`@both`) requires top-level
  `$exception_type` / `$exception_message` properties on the captured event, in addition to the
  nested `$exception_list`.
- **SDK currently:** `captureException()` (`PostHog.kt:843-875`, `PostHogStateless.kt:642-679`)
  delegates to `ThrowableCoercer.fromThrowableToPostHogProperties`
  (`posthog/src/main/java/com/posthog/internal/errortracking/ThrowableCoercer.kt:104-141`), which
  builds only a nested `exceptions` list (`type`/`value`/`mechanism`/`stacktrace` per entry) and
  returns `{$exception_level, $exception_list}` — no top-level `$exception_type`/
  `$exception_message` keys anywhere. Confirmed via repo-wide grep (zero matches in
  `posthog/src/main/`) and direct read of the current method body. Re-scored from 🟡 Partial to
  ❌ Fail: the properties are wholly absent rather than partially implemented.
- **Backwards compatibility:** Backward-compatible — additively stamp
  `exceptionProperties["$exception_type"]` / `["$exception_message"]` derived from the first
  entry in `exceptions`.
- **Remediation:** Add the two top-level convenience properties alongside the existing
  `$exception_list`.

### n3 — Create Person Profile (➖ N/A)
- **Spec requires:** a `createPersonProfile()`-style method to force person-profile creation.
- **SDK currently:** No such method exists anywhere in `posthog/src/main/java/com/posthog/` or
  `posthog-android/src/main/java/com/posthog/android/` (confirmed via exhaustive grep this cycle —
  zero matches for `createPersonProfile`). The closest analog, the `PersonProfiles` config enum
  (`PersonProfiles.kt:6-15`, `PostHogConfig.kt:203`), is a processing-mode setting, not an
  imperative create method, and `setPersonProperties()` early-returns as a no-op with no
  properties, so it cannot substitute either. The spec's **Applicability** section scopes this API
  to the `posthog-js` family only.
- **Backwards compatibility:** N/A — no remediation required per spec scope.

### n4 — Get Feature Flags (❌ Fail)
- **Spec requires:** a public bulk getter returning a flat key→value map (`Record<string,
  boolean|string>`), cache-only (no network I/O), no `$feature_flag_called` side effect.
- **SDK currently:** Full read of `PostHogInterface.kt`'s public surface confirms the only public
  bulk getter is `getAllFeatureFlags(): List<FeatureFlagResult>?` (`PostHogInterface.kt:164`, impl
  `PostHog.kt:1772-1781`) — a list of `{key, enabled, variant, payload}` objects, not a flat map.
  A same-named method exists only internally (`internal/PostHogFeatureFlagsInterface.kt:16`, impl
  `internal/PostHogRemoteConfig.kt:1149-1160`, correctly cache-only) but is not exposed publicly.
  Re-scored from 🟡 Partial to ❌ Fail this cycle: there is no partial/degraded implementation to
  point to — the contracted public API simply does not exist.
- **Backwards compatibility:** Backward-compatible — expose the existing internal
  `PostHogRemoteConfig.getFeatureFlags()` map via a new public
  `PostHogInterface.getFeatureFlags(): Map<String, Any>?`; purely additive alongside
  `getAllFeatureFlags()`.
- **Remediation:** Add the new public method; keep `getAllFeatureFlags()` unchanged for
  compatibility.

### n5 — Get Feature Flags And Payloads (❌ Fail)
- **Spec requires:** a bulk getter returning a `{flags, payloads}` pair of maps, with empty maps
  (not `null`) when no flags are known.
- **SDK currently:** Repo-wide grep for `getFeatureFlagsAndPayloads` returns zero matches anywhere
  — no such method, public or internal. `getAllFeatureFlags()` bundles payload per-flag inside
  each `FeatureFlagResult` but callers must manually rebuild two maps. Confirmed
  `PostHogRemoteConfig.kt:76` (`featureFlags: Map<String, Any>? = null`) and
  `PostHog.kt:1772-1781` return `null`, not empty maps, on cold/empty cache. Additional defect
  found this cycle: the internal `PostHogRemoteConfig.getFeatureFlags()`
  (`PostHogRemoteConfig.kt:1149-1160`) never calls `loadFeatureFlagsFromCacheIfNeeded()` (unlike
  sibling accessors at lines 1254/1266/1273/1281), so it can spuriously return `null` on cold start
  even with a valid disk cache. Re-scored from 🟡 Partial to ❌ Fail — no partial implementation
  exists.
- **Backwards compatibility:** Backward-compatible — add a new method deriving
  `{flags: Map, payloads: Map}` from the same underlying `remoteConfig` data, returning empty maps
  on cold cache; keep `getAllFeatureFlags()` unchanged.
- **Remediation:** Add the new public method returning empty (not null) maps when no flags are
  known; fix the internal getter's missing lazy-cache-load call as a side benefit.

### n6 — Group (🟡 Partial)
- **Spec requires:** `group(type, key, properties)` MUST reject blank/empty `type`/`key` (context
  unchanged, warning logged), per `openspec/specs/group/spec.md:128-136` and
  `acceptance/public/group.feature:29-33` (`@client`).
- **SDK currently:** `group(type, key, groupProperties)` (`PostHog.kt:1543-1601`) has no
  `type.isBlank()`/`key.isBlank()` guard — unconditionally writes `newGroups[type] = key` (line
  1587) and forwards to `groupStateless(...)`. Contrast with `identify()`'s blank-id guard
  (`PostHog.kt:1279-1282`). Confirmed unchanged from prior audit via direct read this cycle.
- **Backwards compatibility:** Backward-compatible — add an early-return blank-check guard at the
  top of `group()`/`groupStateless()`; only affects currently-malformed (blank) input.
- **Remediation:** Add shared blank `type`/`key` validation, matching `identify()`'s pattern.

### n7 — Group Identify (🟡 Partial)
- **Spec requires:** same blank-`type`/`key` rejection as Group (Android has no standalone public
  `groupIdentify` method — `group()` internally emits `$groupidentify`, matching the spec's
  documented Android variant).
- **SDK currently:** Same root cause as Group — `groupStateless()`
  (`PostHogStateless.kt:395-413`) never validates blank `type`/`key` before enqueuing
  `$groupidentify`, contrasted directly with the `identify()` guard immediately above it
  (`PostHogStateless.kt:379-382`). Confirmed unchanged via direct read this cycle. Event shape
  (`$group_type`, `$group_key`, `$group_set`) otherwise correct.
- **Backwards compatibility:** Backward-compatible — same fix as Group.
- **Remediation:** Add the same blank-check guard used for `group()`.

### n8 — On Feature Flags (🟡 Partial)
- **Spec requires:** a listener mechanism supporting multiple independent subscribers, with
  late-registered listeners immediately invoked with current values if flags are already loaded.
- **SDK currently:** `PostHogConfig.onFeatureFlags: PostHogOnFeatureFlags? = null`
  (`PostHogConfig.kt:155`) remains a single mutable `var`, not a registry — no add/remove
  semantics, no `addOnFeatureFlagsListener` API anywhere in `PostHogInterface.kt`. Confirmed this
  cycle there IS a bootstrap-driven immediate-fire path (`PostHog.kt:328-344` fires
  `config.onFeatureFlags` synchronously at `setup()` if bootstrap flags are present), but this only
  covers the callback set before/during `setup()`, not true late registration at arbitrary
  runtime — reassigning `config.onFeatureFlags` post-setup has no immediate-fire side effect.
- **Backwards compatibility:** Needs deprecation path — a true multi-listener registry with
  add/remove and fire-on-late-registration changes the current last-write-wins single-slot
  contract.
- **Remediation:** Add `addOnFeatureFlagsListener`/`removeOnFeatureFlagsListener` APIs alongside
  the existing `config.onFeatureFlags` field (retained for compatibility), firing synchronously on
  registration if flags are already loaded.

### n9 — Opt In (🟡 Partial)
- **Spec requires:** (optional, per spec's permissive language) opt-out MAY also clear local
  persistence (distinct id, anonymous id, super properties) when configured.
- **SDK currently:** `optIn()`/`optOut()` (`PostHog.kt:1088-1099`, `1101-1115`) — both zero-parameter
  (`PostHogCoreInterface.kt:36,41`) — correctly gate capture across all surfaces and persist
  immediately; core required scenarios (block+persist, re-enable+persist) pass. `optOut()`'s only
  cleanup is the exception-steps buffer and push-token cache, not `distinctId`/`anonymousId`/super
  properties; `reset()` is a separate, non-equivalent API. Confirmed unchanged via direct read.
- **Backwards compatibility:** Backward-compatible — this capability is explicitly optional per
  spec language. Add an optional parameter (e.g. `optOut(clearLocalStorage: Boolean = false)`).
- **Remediation:** Add the optional clear-on-opt-out parameter, mirroring the browser SDK pattern.

### n10 — Register (🟡 Partial)
- **Spec requires:** (permissive — "MAY reject") blank/empty keys should not silently persist as
  stray super properties.
- **SDK currently:** `register(key, value)` / `unregister(key)` (`PostHog.kt:1925-1944`) correctly
  reject reserved internal keys (`ALL_INTERNAL_KEYS` denylist,
  `internal/PostHogPreferences.kt:63-89`) but have no blank/empty-key check — confirmed via direct
  read this cycle; an empty-string key is written to/removed from `SharedPreferences` directly with
  no guard.
- **Backwards compatibility:** Backward-compatible — add a blank-key guard mirroring the existing
  reserved-key check; spec's validation language here is permissive, so this is a minor gap.
- **Remediation:** Add blank-key rejection to `register()`/`unregister()`.

### n11 — Screen (❌ Fail)
- **Spec requires:** the explicit `screenTitle`/`name` argument MUST win over any conflicting
  `$screen_name` supplied via the `properties` map.
- **SDK currently:** `screen(screenTitle, properties)` (`PostHog.kt:1139-1164`) sets
  `props["$screen_name"] = trimmedTitle` and then does `properties?.let { props.putAll(it) }`
  immediately after — a caller-supplied `$screen_name` inside `properties` silently overwrites the
  explicit `screenTitle` argument, the opposite of the spec's precedence rule. Confirmed by direct
  read of the current method body this cycle; the method's own doc comment even instructs callers
  to pass `$screen_name` in `properties` to "override" — i.e., the behavior is knowingly documented,
  not accidental, but it still directly contradicts the spec's MUST-level precedence requirement.
  Re-scored from 🟡 Partial to ❌ Fail — this is a direct contradiction of an explicit MUST
  scenario, not a stylistic gap. Auto-tracking via
  `PostHogActivityLifecycleCallbackIntegration.onActivityStarted`, gated by
  `PostHogAndroidConfig.captureScreenViews` (default true), is otherwise correct.
- **Backwards compatibility:** Needs deprecation path — the correct fix (apply title-derived
  `$screen_name` after merging caller `properties`) is safe for the vast majority of callers, but
  the SDK's own doc comment currently instructs the opposite usage pattern; changing this is a
  documented, user-visible behavior change that needs a changelog note.
- **Remediation:** Apply `props["$screen_name"] = trimmedTitle` after merging caller `properties`,
  not before, and update the doc comment accordingly.

### n12 — Shutdown (❌ Fail)
- **Spec requires:** shutdown (`close()`) SHALL flush pending events before tearing down so queued
  data is not lost.
- **SDK currently:** `PostHog.close()` (`PostHog.kt:479-524`) never calls `flush()` — reconfirmed
  by reading the full current method body this cycle: it proceeds straight to `queue?.stop();
  replayQueue?.stop(); logsQueue?.stop()` (lines 507-509) without invoking `flush()`.
  `PostHogQueue.stop()` (`internal/PostHogQueue.kt:462-468`) only cancels the flush timer
  (`stopTimer()`) and unregisters the network-status listener — it never drains the deque or
  force-uploads cached/queued events. The identical gap exists in `PostHogStateless.close()`
  (`PostHogStateless.kt:106-135`, `queue?.stop()` at line 128, no flush). Events remain cached on
  disk until a future `queue.start()`/`flush()` (e.g. next app launch).
- **Backwards compatibility:** Backward-compatible — adding a `flush()` call at the top of
  `close()`/`PostHogStateless.close()` is purely additive; no signature change, only makes
  shutdown actually deliver pending events as specified.
- **Remediation:** Call `flush()` (bounded by a reasonable timeout) at the start of `close()`.

### n13 — Start Session Recording (❌ Fail)
- **Spec requires:** session recording MUST remain inactive (or refuse to start) while the user is
  opted out.
- **SDK currently:** `startSessionReplay(resumeCurrent: Boolean = true)`
  (`PostHog.kt:2126-2163`) only guards on `isEnabled()` (line 2127) and
  `isSessionReplayFlagEnabled()` (remote-config gating, line 2131) — reconfirmed this cycle that
  `isOptedOut()` is never referenced anywhere in the method or its helpers
  (`shouldRecordSession()`, `isSessionReplayFlagEnabled()`). A caller who has opted out can still
  successfully start recording. Idempotency, remote-config/linked-flag gating, and sampling gating
  are otherwise correctly implemented.
- **Backwards compatibility:** Backward-compatible — adding an `isOptedOut()` guard at the top of
  `startSessionReplay` is additive; no legitimate caller depends on replay starting while opted
  out.
- **Remediation:** Add an `isOptedOut()` check to `startSessionReplay()`.

### n14 — Stop Session Recording (🟡 Partial)
- **Spec requires:** stopping session recording should finalize/flush pending replay data, and
  (for symmetry with start) should be opt-out aware.
- **SDK currently:** `stopSessionReplay()` (`PostHog.kt:2165-2180`) correctly no-ops if already
  inactive, but (1) does not flush the replay queue before deactivating —
  `PostHogReplayIntegration.stop()` only sets `isSessionReplayActive = false` and resets draw-state
  tracking, no `replayQueue.flush()` call; pending snapshot data relies on the normal timer-driven
  flush, not an explicit finalize-before-stop; (2) has the same `isOptedOut()` asymmetry as
  start-session-recording (only `isEnabled()` guard), lower-impact since stopping while opted out
  is a benign outcome. Both points reconfirmed via direct read this cycle.
- **Backwards compatibility:** Backward-compatible — explicitly flushing the replay queue inside
  `stop()` is additive/clarifying, no signature or common-case behavior change.
- **Remediation:** Flush the replay queue synchronously inside `stopSessionReplay()`.

### n15 — Bootstrap (🟡 Partial)
- **Spec requires:** (optional — "MAY") a client SDK that owns a session id MAY accept a
  `sessionID` in the bootstrap config (UUIDv7) and adopt it as the current session id.
- **SDK currently:** All spec-mandated (MUST) bootstrap fields — identity seeding/reconciliation,
  feature-flag/payload bootstrap — are fully implemented and correct
  (`applyBootstrapIfNeeded()` `PostHog.kt:397-437`, `reconcileBootstrapIdentityIfNeeded()`
  `PostHog.kt:439-477`). `PostHogBootstrapConfig`
  (`posthog/src/main/java/com/posthog/PostHogBootstrapConfig.kt:24-59`) still has exactly
  `distinctId`, `isIdentifiedId`, `featureFlags`, `featureFlagPayloads` — no `sessionID` field,
  confirmed via direct read this cycle. Android owns a client-side session manager
  (`PostHogSessionManager.kt`) that could consume a bootstrap session id but doesn't — sessions are
  always freshly generated. Since the spec phrases this as "MAY," this is a spec-permitted
  omission, not a strict violation.
- **Backwards compatibility:** Backward-compatible — adding an optional `sessionID` field is
  purely additive.
- **Remediation:** Add optional `sessionID` bootstrap support if product wants full parity with
  SDKs that implement this optional capability.

### n16 — Autocapture (❌ Fail)
- **Spec requires:** generic UI-interaction autocapture — `$autocapture` events with
  `$elements_chain`/`$elements` metadata for taps/clicks on interactive views, with no-capture
  markers and sensitive-field filtering, OR an explicit documented carve-out if intentionally
  unsupported.
- **SDK currently:** Repo-wide grep this cycle for `autocapture`/`elements_chain`/`elementsChain`/
  `$autocapture` returns matches only in the unrelated **exception** autocapture subsystem
  (`posthog/src/main/java/com/posthog/errortracking/PostHogErrorTrackingAutoCaptureIntegration.kt`),
  which the spec explicitly scopes out as a separate component.
  `posthog-android/src/main/java/com/posthog/android/internal/PostHogTouchActivityIntegration.kt`
  (99 lines, re-read in full this cycle) exists solely to call
  `PostHogSessionManager.touchSession()` on every `MotionEvent` for session-idle/rotation timing —
  it never inspects the touched view, builds element metadata, or calls `capture()`. No
  `captureTouches`/`captureElementInteractions` config exists in `PostHogAndroidConfig.kt`. No
  documented carve-out exists (README/CHANGELOG/comments) for this being intentionally
  unsupported.
- **Backwards compatibility:** Backward-compatible — this is a net-new feature gap, not a
  behavioral regression; building it would not break existing consumers.
- **Remediation:** Either build a tap/click autocapture pipeline, or explicitly document the
  carve-out per the spec's allowance.

### n17 — Before Send Hook (🟡 Partial)
- **Spec requires:** multiple registered hooks run in a chain, each receiving the **previous**
  hook's mutated output; an exception in one hook should not silently drop the event (fall back to
  original/last-good value).
- **SDK currently:** Multi-hook support is real (`PostHogBeforeSend.kt:8-16`,
  `PostHogConfig.kt:484-516` stores hooks in a lock-guarded `MutableList`). Two bugs reconfirmed by
  direct read this cycle in `posthog/src/main/java/com/posthog/PostHogStateless.kt`, method
  `buildEvent` (lines 289-322): (1) **line 310** — `eventChecked = beforeSend.run(postHogEvent)`
  passes the original, pristine `postHogEvent` to every hook in the loop, never the previous hook's
  output — hook #2 never sees hook #1's mutation, for chains of 2+ hooks; (2) **lines 315-317** —
  `catch (e: Throwable) { config?.logger?.log(...); return null }` drops the event entirely on any
  hook exception rather than falling back to the original/last-good value.
- **Backwards compatibility:** Backward-compatible for both — (1) only changes behavior for
  callers with 2+ hooks where an earlier hook mutates the event (untested case today); (2)
  returning the last-good value on exception is strictly less destructive than the current drop.
- **Remediation:** Fix the chain-passing bug at `PostHogStateless.kt:310` and change the exception
  branch to return the last-good value instead of `null`.

### n18 — Consent Gating (🟡 Partial) — *downgraded from ✅ Pass this cycle*
- **Spec requires:** opt-out state gates capture across all product surfaces the spec's
  "Interactions" section lists, explicitly including session replay (which "may be stopped,
  skipped, or restarted based on consent state").
- **SDK currently:** Core capture-path gating is solid — `capture()` (`PostHog.kt:722`,
  `isOptedOut()` check at line 735), `group()`, `alias()`, `captureException`,
  `captureLogInternal` all gate on `isOptedOut()` directly or transitively via `capture()`.
  However, re-examining this cycle in light of the session-replay findings (n13/n14) surfaced a
  cross-cutting gap previously missed: `startSessionReplay()`/`stopSessionReplay()` never check
  `isOptedOut()`, and `optOut()` (`PostHog.kt:1101-1115`) never proactively stops an
  already-active replay session. Since session replay is explicitly named in this spec's own
  scope, this is a legitimate consent-gating gap, not merely a start/stop-session-recording-only
  issue — hence the downgrade from the prior audit's ✅ Pass.
- **Backwards compatibility:** Backward-compatible — the same fix as n13/n14 (add `isOptedOut()`
  guards) closes this gap; optionally also make `optOut()` call `stopSessionReplay()`.
- **Remediation:** Extend opt-out gating to the session-replay start/stop surface.

### n19 — Event Batcher (🟡 Partial)
- **Spec requires:** periodic flush driven by the SDK's injectable clock abstraction (so tests can
  simulate elapsed time without a real wall-clock wait).
- **SDK currently:** `internal/PostHogQueue.kt` (the Android/shared-core batcher — re-verified this
  cycle to be the one Android actually depends on; see repo-layout note above re: the
  `PostHogMemoryQueue.kt` rename being confined to the unreachable `posthog-server` module)
  correctly implements FIFO accumulation (`takeFiles()` lines 174-180), threshold flush
  (`isAboveThreshold`, lines 155-163), a distinct `maxBatchSize` cap (`BatchLimits.cap`, lines
  34-35), explicit `flush()`, single-thread executor, single-flush-in-flight guard, and
  413-triggered batch halving (`BatchLimits.halve()`, lines 499-510) — matching the spec. However,
  `start()` (lines 378-400) schedules the periodic flush via `java.util.Timer(true)` (line 381,
  real wall-clock scheduling) rather than the SDK's own injectable `config.dateProvider`
  abstraction, which is a real, distinct abstraction present in `PostHogConfig.kt:475` and used
  elsewhere in this same file (e.g., `pausedUntil` retry-backoff calc) — production behavior is
  correct, but the mechanism can't be driven by a mocked/fake clock as the acceptance scenario's
  literal test setup implies. The `PostHogMemoryQueue.kt` `add(event)`→`add(record)` rename this
  drift's commit log flagged is confirmed immaterial: that file lives only at
  `posthog-server/src/main/java/com/posthog/server/internal/PostHogMemoryQueue.kt`, unreachable
  from `:posthog-android` per the module dependency graph, and the shared-core
  `PostHogQueueInterface.add(record: Record)` (used by Android) already used the parameter name
  `record` prior to this drift — a cosmetic-only match, zero behavioral change either way.
- **Backwards compatibility:** Backward-compatible — swap to a `dateProvider`-driven scheduled
  executor internally; no public API change, default real-time behavior unchanged.
- **Remediation:** Route the periodic-flush timer through `config.dateProvider` for testability.

### n20 — Feature Flag Called Tracker (🟡 Partial)
- **Spec requires:** dedup semantics for `$feature_flag_called` (per spec.md/acceptance for this
  specific contract — duplicate values suppressed, value changes re-tracked, cleared on
  reset/close).
- **SDK currently:** Core dedup-tracker contract passes: dedup key is per-flag-key with a value
  list (`PostHog.kt:1710-1717`, `featureFlagsCalled: MutableMap<String, MutableList<Any?>>` at line
  122); duplicate values suppressed, value changes re-tracked; tracker clears on `reset()`
  (`PostHog.kt:1896`) and `close()` (`PostHog.kt:513`) as required. No bounded/LRU eviction exists
  (unbounded growth), which the spec marks optional ("where needed"), not mandatory — minor gap,
  not a failure. Note: re-examining this cycle, the previously-cited `MINIMAL_FEATURE_FLAG_CALLED_PROPERTIES`
  allowlist gap (`PostHogStateless.kt:693-711`, missing UTM/`$referring_domain`/`gclid`/`fbclid`
  session-attribution and static platform/OS identity properties) is confirmed accurate as a
  factual code observation, but on closer reading `feature-flag-called-tracker.feature` contains no
  scenarios about property minimization/allowlists — that spec is purely about dedup-key
  semantics, so this allowlist gap is scored here for continuity with the prior audit's framing,
  while noting it may be more accurately an unscoped/undocumented-elsewhere observability gap
  (the SDK has no UTM/gclid/fbclid/`$referring_domain` capture mechanism at all, repo-wide).
- **Backwards compatibility:** Backward-compatible — expanding the allowlist or adding
  attribution-property capture is purely additive.
- **Remediation:** Port the missing allowlist categories if minimal-event mode should retain
  session-attribution/platform-identity properties; separately consider whether UTM/click-id
  capture belongs in this SDK's scope at all.

### n21 — Flag Definition Loader (➖ N/A)
- **Spec requires:** ETag-based polling of flag definitions for local evaluation, requiring a
  personal/admin API key.
- **SDK currently:** `LocalEvaluationPoller.kt` exists only at
  `posthog-server/src/main/java/com/posthog/server/internal/LocalEvaluationPoller.kt` — reconfirmed
  via repo-wide grep this cycle (zero hits under `posthog/` or `posthog-android/`).
  `posthog-android/build.gradle.kts` declares a dependency only on `:posthog`, not
  `:posthog-server`. Correction to the prior audit's stated justification: the acceptance
  `.feature` file for this capability is tagged `@server`, but the spec.md's own Applicability
  section states `both` — the correct N/A basis is spec.md's explicit carve-out for client
  wrappers with no privileged local-evaluation surface (citing Flutter as precedent), which applies
  equally to Android, not a literal `@server`-only scope in spec.md itself. Verdict unchanged;
  reasoning refined.
- **Backwards compatibility:** N/A — a mobile app cannot safely hold a personal/admin API key.

### n22 — HTTP Client (🟡 Partial) — *downgraded from ✅ Pass this cycle*
- **Spec requires:** transport-layer retry classification treats transient network failures
  (timeouts, connection resets, DNS/TLS transient failures) as retryable.
- **SDK currently:** Core ingestion transport (`/batch` POST, gzip, `User-Agent`,
  `Retry-After`-aware `PostHogApiError`) is solid and correctly implemented. However, the
  feature-flags request retry classifier (`internal/PostHogApi.kt:291-297`,
  `isRetryableFlagsError`) only treats `SocketTimeoutException`, `EOFException`, and
  `SocketException` messages containing "reset" as retryable transient-transport failures —
  confirmed by direct read this cycle:
  ```kotlin
  is IOException ->
      error is SocketTimeoutException ||
          error is EOFException ||
          (error is SocketException && error.message?.contains("reset", ignoreCase = true) == true)
  ```
  `UnknownHostException` (DNS), `SSLException`/`SSLHandshakeException` (TLS), and generic
  `ConnectException` (connection refused) fall through unretried, despite the http-client spec's
  broader "transport failure or equivalent" language. This is a real but narrowly-scoped gap
  (limited to one specific retry path, not the core batch-transport path), hence 🟡 Partial rather
  than ❌ Fail.
- **Backwards compatibility:** Backward-compatible — widening this `IOException` branch only
  grants extra bounded retries to previously-unretried cases; no signature/config change.
- **Remediation:** Broaden `isRetryableFlagsError` to cover `UnknownHostException`,
  `SSLException`, and `ConnectException`.

### n23 — Local Feature Flag Evaluator (➖ N/A) — *includes new starts_with/ends_with sub-check*
- **Spec requires:** local (in-process) rule-based flag evaluation using flag definitions fetched
  via a personal/admin API key. New sub-requirement added since last audit (sdk-specs commit
  `2036abd`): "String prefix/suffix property filter operators" — `starts_with`/`ends_with`
  support (`local-feature-flag-evaluator/spec.md` lines 145-181, `@server`-tagged scenarios).
- **SDK currently:** `FlagEvaluator.kt`/`PostHogFeatureFlagEvaluations.kt` (the rule-matching
  engine) live exclusively at `posthog-server/src/main/java/com/posthog/server/internal/`.
  `posthog-android/build.gradle.kts` depends only on `:posthog`, confirmed this cycle by reading
  both `build.gradle.kts` files and `settings.gradle.kts` (dependency direction runs
  `posthog-server → posthog`, never the reverse). The shared `posthog` core module contains only
  data models, no evaluator logic. `PostHogStateless.kt:691-692` still comments that
  `locally_evaluated` is "set only by posthog-server." No `personalApiKey`/local-evaluation config
  option exists in `PostHogConfig.kt` (reconfirmed via grep this cycle). **New-operator check:**
  repo-wide grep for `starts_with`/`STARTS_WITH`/`ends_with`/`ENDS_WITH` returns **zero matches
  anywhere in the entire repo**, including `posthog-server/` itself — `FlagEvaluator.kt`'s
  operator dispatch (`when (propertyOperator)`) has no `STARTS_WITH`/`ENDS_WITH` branch and falls
  to `else -> throw InconclusiveMatchException(...)`; the shared `PropertyOperator` enum
  (`internal/PostHogLocalEvaluationModels.kt`) has no such constants either. This means the new
  operators are not yet implemented even in the server module the spec scopes them to — but
  regardless of that implementation timeline, the module-isolation analysis above confirms that
  whenever/if implemented, they would remain confined to `posthog-server` and stay unreachable
  from Android. The N/A verdict is unaffected by the new sub-requirement.
- **Backwards compatibility:** N/A — a mobile SDK cannot safely hold a personal/admin API key;
  local rule evaluation (including its new operators) is confined to the server module.
- **Out-of-scope observation:** the `starts_with`/`ends_with` requirement appears unimplemented
  even in `posthog-server` as of this commit, and the corresponding acceptance `.feature` file has
  not been updated with matching scenarios — flagged for visibility, not scored against Android.

### n24 — Persistent Storage (🟡 Partial)
- **Spec requires:** storage failures MUST NOT crash SDK calls, and the SDK SHALL record a storage
  warning when a write fails.
- **SDK currently:** `posthog-android/src/main/java/com/posthog/android/internal/PostHogSharedPreferences.kt`,
  `setValue()` (lines 118-159): the `is Boolean/String/Float/Long/Int` branches (lines 127-146) and
  the trailing `edit.apply()` (line 158) sit outside any try/catch — only the
  `else -> serializeObject(...)` branch is defensive. Reconfirmed this cycle that call sites
  (`PostHog.kt:1936` for `register()`, plus all other `setValue` callers at lines 562, 573, 601,
  1095, 1108, 1538, 1589, 1973) invoke `getPreferences().setValue(...)` with no surrounding
  try/catch either — an exception from the unguarded branches propagates to application code,
  directly contradicting the "storage failures do not crash SDK calls" requirement. No dedicated
  "storage warning" log signal exists anywhere (`PostHogLogger.kt` exposes only a single
  `log(message)` method, no distinct warning level; grep for "storage warning"/"StorageWarning"
  returns zero hits).
- **Backwards compatibility:** Backward-compatible — wrap the primitive-write branches (and
  `edit.apply()`) in try/catch and emit a distinct warning log; purely additive, no change to the
  success path.
- **Remediation:** Guard the primitive-write branches of `PostHogSharedPreferences.setValue` and
  emit a storage-warning log on failure.

### n25 — Session Replay Ingestion Controls (🟡 Partial)
- **Spec requires:** event-trigger gating for session replay must observe the final (post-
  `beforeSend`) event name, since a hook may rename an event.
- **SDK currently:** Enablement gating, deterministic session-keyed sampling, and minimum-duration
  buffering are all correctly implemented. However, `PostHog.kt:836` passes the **pre-before-send**
  `event` name (not `postHogEvent.event`) into `sessionReplayHandler?.onEvent(...)` — reconfirmed
  by direct read this cycle. Notably, the sibling snapshot-detection code at line 814 was
  deliberately fixed to use `postHogEvent.event` (comment: "event might have been updated by the
  beforeSend hook"), but line 836 (and line 834, surveys) were not updated to match — an
  inconsistency within the same method. A `beforeSend` hook that renames (not drops) an event would
  cause trigger matching to see the stale name.
- **Backwards compatibility:** Backward-compatible — one-line swap to `postHogEvent.event` at both
  call sites, no API/wire change.
- **Remediation:** Pass `postHogEvent.event` instead of the pre-hook `event` variable at
  `PostHog.kt:834` and `836`.

### n26 — Session Replay Privacy (🟡 Partial)
- **Spec requires:** elements explicitly tagged no-capture MUST be excluded from replay wireframes
  in all capture modes (not just screenshot mode); unmask/password precedence should be consistent
  across UI frameworks.
- **SDK currently:** Default text/image masking, password special-casing, and fail-closed
  screenshot-mode masking are all correctly implemented
  (`posthog-android/src/main/java/com/posthog/android/replay/PostHogReplayIntegration.kt`). Both
  prior findings reconfirmed via direct read this cycle: (1) `isNoCapture()` is consulted only in
  the screenshot-mode masking path (`findMaskableWidgets()`, line 1021) — never inside
  `toWireframe()` (lines 1356-1654), Android's **default** capture mode (`screenshot = false` per
  `PostHogSessionReplayConfig.kt:38`); a view tagged `ph-no-capture` is still emitted as a full
  wireframe node in default mode. (2) Unmask-vs-password precedence differs between the View path
  (`shouldMaskTextView()`, lines 990-993 — password always wins) and the Compose path (lines
  1130-1146 — `isUnmaskEnabled` checked first, short-circuits before password detection) — same
  developer intent, different security-relevant outcome depending on UI framework.
- **Backwards compatibility:** Needs deprecation path for (1) — adding an early-return `null` in
  `toWireframe()` for tagged nodes changes what data leaves the device for tagged views in the
  default capture mode, so should ship with a changelog note. (2) is Backward-compatible — align
  Compose to match View's more conservative precedence.
- **Remediation:** Honor `isNoCapture()` inside `toWireframe()`, not just the screenshot path;
  align Compose's unmask/password precedence with the View path.

### n27 — Surveys (🟡 Partial)
- **Spec requires:** (acceptance scenario, `@client`, `surveys.feature:126-135`) non-web/native
  SDKs MUST exclude surveys whose only display-targeting conditions are web-only (`url`/
  `selector`).
- **SDK currently:** Rich, otherwise-correct implementation
  (`posthog-android/src/main/java/com/posthog/android/surveys/PostHogSurveysIntegration.kt`)
  covering active/date-window filtering, device-type matching, seen state, wait period,
  linked/targeting/multi feature-flag gating, event-based activation, all 5 question types, and
  opt-out-gated event emission. `getActiveMatchingSurveys()` (lines 226-277) never reads
  `survey.conditions?.url` or `survey.conditions?.selector` anywhere, reconfirmed via exhaustive
  grep this cycle — zero matches for `conditions?.url`, `conditions?.selector`, despite
  `SurveyConditions.kt` deserializing those fields. A survey whose only targeting condition is a
  CSS selector or URL match passes all Android eligibility checks and is shown natively with an
  inert, non-functional targeting condition.
- **Backwards compatibility:** Needs deprecation path — the fix is additive (a new exclusion check
  tightens eligibility, no public API change) but is a user-visible behavior change (some
  currently-shown surveys would stop displaying), so ship with a changelog note.
- **Remediation:** Add a filter step in `getActiveMatchingSurveys()` excluding surveys where
  `url`/`selector` are the *only* configured display-targeting condition.

### n28 — Traces (❌ Fail)
- **Spec requires:** OpenTelemetry-shaped span/trace capture (`startSpan`/`withSpan`/
  `getActiveSpan`/`beforeSpanSend`, `resourceSpans`/`scopeSpans` OTLP payload) shipped to
  `POST {host}/i/v1/traces`. Spec text explicitly discusses mobile ports throughout, so mobile is
  in scope, not exempt.
- **SDK currently:** Zero implementation anywhere in the repo, reconfirmed this cycle via fresh
  repo-wide grep (including `posthog-server/`, which Android doesn't depend on) for `startSpan`,
  `withSpan`, `getActiveSpan`, `beforeSpanSend`, `resourceSpans`, `scopeSpans`, and any `Span`
  type — no matches. `EndpointSpec.kt` defines only `logs()`/`batch()`/`snapshot()` endpoint
  factories, no `traces()` companion; no `/i/v1/traces` endpoint string exists anywhere. OTel-flavored
  code exists only for the logs pipeline (`PostHogLogsOTLP.kt`) and the distinct `tracing-headers`
  capability (`PostHogOkHttpInterceptor.kt`, a different capability per its own purpose statement).
  This capability is unimplemented on every platform in this repo, not exempted specifically for
  Android.
- **Backwards compatibility:** Backward-compatible — the spec itself states tracing SHALL be off
  until the `traces` config is provided, so the entire public API surface is wholly new; nothing
  existing needs to change or deprecate.
- **Remediation:** Implement the traces capability net-new, likely reusing the logs pipeline's
  OTLP/queue machinery as a template.
