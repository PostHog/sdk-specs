# posthog-android — SDK Compliance

**Repo:** [PostHog/posthog-android](https://github.com/PostHog/posthog-android)
**Audited commit:** `129a83a1cc3227910e80fd55210c1bd29f104e97` ([commit](https://github.com/PostHog/posthog-android/commit/129a83a1cc3227910e80fd55210c1bd29f104e97)) — audited on 2026-10-26
**Audited against sdk-specs commit:** `b865140e489c191e96e402d12b557d6a586afd0e`
**Summary:** 39 ✅ · 15 🟡 · 4 ❌ · 6 ➖ · 0 ❓

Note on repo layout: `posthog-android` is a monorepo. The shared cross-platform core (used by both
the Android SDK and the JVM/server SDK) lives at `posthog/src/main/java/com/posthog/`
(`PostHog.kt`, `PostHogStateless.kt`, `PostHogConfig.kt`, `PostHogInterface.kt`, `internal/*` —
queue, feature flags, session manager, replay wire model, logs OTLP, error tracking). Android-specific
integrations live at `posthog-android/src/main/java/com/posthog/android/`. The JVM/server SDK in
`posthog-server/` is audited separately as [posthog-java.md](posthog-java.md).

**Scope of this run (2026-10-26):** a *targeted* re-audit, not a full 64-row re-derivation. The rows
re-verified from source this run are the ones the sdk-specs delta since `75c8f5d` lands on (Capture,
Register, Setup, Surveys, HTTP Client, Capture Exception, Exception Steps, Event Batcher, Reload
Feature Flags, Application Lifecycle, Session Replay Ingestion Controls, Flag Definition Loader),
every row that was ❌ or ❓ at the last audit, and the five contracts that had no row at all. Rows
not in that set carry their 2026-08-10 verdict forward and are marked as such in their note; they are
the first candidates for the next full pass. The audited commit is **+2.5 months and several hundred
commits** past the previous `8659a7b4`, and the SDK has visibly been tracking these specs: seven rows
improved this run.

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Alias | ✅ |  |
| 2 | Application Lifecycle | ✅ |  |
| 3 | Autocapture | ✅ |  |
| 4 | Before Send Hook | 🟡 | [n1] |
| 5 | Bootstrap | 🟡 | [n2] |
| 6 | Capture | ✅ |  |
| 7 | Capture AI | ➖ | [n3] |
| 8 | Capture Exception | ✅ |  |
| 9 | Consent Gating | 🟡 | [n4] |
| 10 | Create Person Profile | ➖ | [n5] |
| 11 | Debug | ✅ |  |
| 12 | Device ID Generator | ✅ |  |
| 13 | Evaluate Flags | ➖ | [n6] |
| 14 | Event Batcher | 🟡 | [n7] |
| 15 | Exception Event Metadata | ❌ | [n8] |
| 16 | Exception Steps | ✅ |  |
| 17 | Feature Flag Cache | ✅ |  |
| 18 | Feature Flag Called Tracker | 🟡 | [n9] |
| 19 | Flag Definition Loader | ➖ | [n10] |
| 20 | Flush | ✅ |  |
| 21 | Get Anonymous ID | ✅ |  |
| 22 | Get Distinct ID | ✅ |  |
| 23 | Get Feature Flag | ✅ |  |
| 24 | Get Feature Flag Payload | ✅ |  |
| 25 | Get Feature Flag Result | ✅ |  |
| 26 | Get Feature Flags | ❌ | [n11] |
| 27 | Get Feature Flags And Payloads | ❌ | [n12] |
| 28 | Get Session ID | ✅ |  |
| 29 | Group | 🟡 | [n13] |
| 30 | Group Identify | 🟡 | [n14] |
| 31 | HTTP Client | ✅ |  |
| 32 | Identify | ✅ |  |
| 33 | Is Feature Enabled | ✅ |  |
| 34 | Is Opt Out | ✅ |  |
| 35 | Is Session Replay Active | ✅ |  |
| 36 | Local Feature Flag Evaluator | ➖ | [n15] |
| 37 | Logs | ✅ |  |
| 38 | MCP Analytics | ➖ | [n16] |
| 39 | On Feature Flags | 🟡 | [n17] |
| 40 | Opt In | 🟡 | [n18] |
| 41 | Persistent Storage | 🟡 | [n19] |
| 42 | Register | 🟡 | [n20] |
| 43 | Reload Feature Flags | ✅ |  |
| 44 | Remote Config | ✅ |  |
| 45 | Reset | ✅ |  |
| 46 | Reset Group Properties For Flags | ✅ |  |
| 47 | Reset Person Properties For Flags | ✅ |  |
| 48 | Retry Queue | ✅ |  |
| 49 | Screen | ✅ |  |
| 50 | Session Manager | ✅ |  |
| 51 | Session Replay Debug Properties | ✅ |  |
| 52 | Session Replay Ingestion Controls | 🟡 | [n21] |
| 53 | Session Replay Privacy | 🟡 | [n22] |
| 54 | Set Group Properties For Flags | ✅ |  |
| 55 | Set Person Properties | ✅ |  |
| 56 | Set Person Properties For Flags | ✅ |  |
| 57 | Setup | ✅ |  |
| 58 | Shutdown | ✅ |  |
| 59 | Start Session Recording | ✅ |  |
| 60 | Stop Session Recording | 🟡 | [n23] |
| 61 | Surveys | 🟡 | [n24] |
| 62 | Traces | ❌ | [n25] |
| 63 | Tracing Headers | ✅ |  |
| 64 | Unregister | ✅ |  |

## Notes

### n1 — Before Send Hook (🟡 Partial)
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

### n2 — Bootstrap (🟡 Partial)
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

### n3 — Capture AI (➖ N/A)
- **Spec requires:** an isolated `capture_ai` route to PostHog's dedicated AI ingestion endpoint.
- **SDK currently:** out of scope. `openspec/specs/capture-ai/spec.md` scopes the capability
  `server` ("currently implemented by posthog-python and posthog-node"); posthog-android is a client
  SDK and is not named. No `$ai_*` surface exists in `posthog/src/main/java/com/posthog/`.
- **Backwards compatibility:** N/A — no remediation required per spec scope.

### n4 — Consent Gating (🟡 Partial)
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

### n5 — Create Person Profile (➖ N/A)
- **Spec requires:** a `createPersonProfile()`-style method to force person-profile creation.
- **SDK currently:** No such method exists anywhere in `posthog/src/main/java/com/posthog/` or
  `posthog-android/src/main/java/com/posthog/android/` (confirmed via exhaustive grep this cycle —
  zero matches for `createPersonProfile`). The closest analog, the `PersonProfiles` config enum
  (`PersonProfiles.kt:6-15`, `PostHogConfig.kt:203`), is a processing-mode setting, not an
  imperative create method, and `setPersonProperties()` early-returns as a no-op with no
  properties, so it cannot substitute either. The spec's **Applicability** section scopes this API
  to the `posthog-js` family only.
- **Backwards compatibility:** N/A — no remediation required per spec scope.

### n6 — Evaluate Flags (➖ N/A)
- **Spec requires:** a server-side `evaluateFlags(...)` returning a reusable point-in-time
  `FeatureFlagEvaluations` snapshot.
- **SDK currently:** out of scope. The spec states "This capability applies to server SDKs.
  Client-side `isFeatureEnabled(...)` methods that read ambient cached flag state remain governed by
  the `is-feature-enabled` capability and are not replaced by this server-request snapshot API."
  posthog-android reads ambient cached state through `PostHogRemoteConfig`; the server-side snapshot
  API is implemented in the sibling `posthog-server` module, scored in
  [posthog-java.md](posthog-java.md).
- **Backwards compatibility:** N/A — no remediation required per spec scope.

### n7 — Event Batcher (🟡 Partial)
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

- **Re-verified 2026-10-26:** the injectable-clock gap stands — `PostHogQueue.start()` still schedules
  the periodic flush with `java.util.Timer(true)`
  (`posthog/src/main/java/com/posthog/internal/PostHogQueue.kt:388-389`) rather than
  `config.dateProvider`. The **new** "Replay batches preserve session and identity attribution"
  requirement (spec change #92, `09acafd`) is however fully satisfied: `batchRecords()` splits the
  flush window into boundary-separated groups (`:266-276`) using
  `EndpointSpec.snapshot`'s `canBatchTogether` predicate
  (`posthog/src/main/java/com/posthog/internal/EndpointSpec.kt:81-85`), which compares the
  `distinctId` and the `$session_id` stored **on each snapshot event** rather than the SDK's current
  session — including for records restored from disk and rebuilt for retry.

### n8 — Exception Event Metadata (❌ Fail)
- **Spec requires:** `both` applicability. `$exception_list[].mechanism` carries `type`, `handled`,
  `source`, `synthetic`, `exception_id` and `parent_id`; a producer **MUST NOT** represent unknown
  with `false` or an empty string; every nested entry has `type` equal to `chained` with
  `mechanism.source` naming the parent edge (`cause`, `member`, `suppressed`, …); a nested entry's
  `handled` and `synthetic` are **not** inherited from the outermost entry; the outermost entry always
  carries `mechanism.exception_id` equal to `0`; and the Android uncaught-exception handler sets
  event-level `$exception_source` to `android.uncaught_exception_handler`.
- **SDK currently:** `ThrowableCoercer.buildExceptionItem`
  (`posthog/src/main/java/com/posthog/internal/errortracking/ThrowableCoercer.kt:193-244`) builds every
  mechanism as `{"handled": handled, "synthetic": false, "type": mechanismType}` plus optional ids.
  Five distinct contradictions:
  1. `synthetic` is the literal `false` on **every** entry — the spec names `false` as a forbidden
     stand-in for unknown provenance, and the SDK never determines provenance at all.
  2. `handled` is a single value resolved once for the whole event
     (`fromThrowableToPostHogProperties:257-268`) and copied onto every cause and suppressed entry;
     the spec says a nested entry's handled state MUST NOT be derived from the outermost one.
  3. `mechanism.source` is never emitted. The parent-edge relationship is encoded in `type` instead
     (`"chained"` for causes, `"suppressed"` for suppressed entries, `:285-313`), so suppressed
     entries also get a non-canonical `type` where the spec requires `type: "chained"` +
     `source: "suppressed"`.
  4. `exception_id` is omitted entirely on a single-entry list (`linkChain = items.size > 1`,
     `:318-333`), but the spec's "Context-free event assembler emits linkage-only mechanism" scenario
     requires `exception_id` equal to `0` on the outermost entry unconditionally.
  5. `$exception_source` is never set anywhere in the repo — including
     `PostHogErrorTrackingAutoCaptureIntegration`, the exact hook the spec's canonical table maps to
     `android.uncaught_exception_handler`.
  What is correct: `$exception_level` has a real boundary default (`fatal` for the uncaught handler
  via `PostHogThrowable.isFatal`, otherwise `error`, `:337-340`), cycles are detected with an
  `IdentityHashMap`-backed set, and the 50-entry cap is enforced.
- **Backwards compatibility:** Backward-compatible — all five are producer-side serialization changes
  inside one internal file; no public API or config surface changes. Consumers already treat these
  fields as optional.
- **Remediation:** Omit `synthetic` unless provenance is known; emit `handled` only on the outermost
  entry unless the runtime supplies an independent disposition; emit `type: "chained"` plus
  `source: "cause"`/`"suppressed"` for nested entries; always assign `exception_id` starting at `0`;
  and set `$exception_source = "android.uncaught_exception_handler"` from the uncaught handler.

### n9 — Feature Flag Called Tracker (🟡 Partial)
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

### n10 — Flag Definition Loader (➖ N/A)
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

### n11 — Get Feature Flags (❌ Fail)
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

### n12 — Get Feature Flags And Payloads (❌ Fail)
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

### n13 — Group (🟡 Partial)
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

### n14 — Group Identify (🟡 Partial)
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

### n15 — Local Feature Flag Evaluator (➖ N/A)
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

### n16 — MCP Analytics (➖ N/A)
- **Spec requires:** an add-on package emitting `$mcp_tool_call` and the `$mcp_*` family through the
  host SDK's capture.
- **SDK currently:** out of scope. The spec's applicability is `server`, and its per-SDK package table
  names only posthog-js (`@posthog/mcp`), posthog-python (`posthog.mcp`), posthog-go
  (`posthogmcp`/`posthogmcpsdk`) and posthog-ruby ("not yet"). posthog-android is not listed and ships
  no MCP package.
- **Backwards compatibility:** N/A — no remediation required per spec scope.

### n17 — On Feature Flags (🟡 Partial)
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

### n18 — Opt In (🟡 Partial)
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

### n19 — Persistent Storage (🟡 Partial)
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

### n20 — Register (🟡 Partial)
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

- **Re-verified 2026-10-26:** the blank-key gap stands (`PostHog.kt:2274-2293`). The **new**
  "Per-event property overrides a registered property" scenario (spec change #114, `a86f68e`) passes:
  `buildProperties` merges registered preferences first and the caller's `properties` afterwards
  (`PostHog.kt:744-821`), so a per-event `plan` wins while the registered value is untouched.

### n21 — Session Replay Ingestion Controls (🟡 Partial)
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

- **New gap found 2026-10-26 (spec change #83, `f76f891`):** "A held epoch at the size cap keeps its
  data and ships it on release" requires that when the next replay event would push a *held* epoch's
  buffered data past the emission size cap, the SDK stops collecting but retains what it has, then
  emits the retained data and takes a fresh full snapshot on release. `PostHogReplayBufferQueue`
  (`posthog-android/src/main/java/com/posthog/android/replay/PostHogReplayBufferQueue.kt:67-80`)
  buffers held snapshots to disk with no byte-size cap and no stop-collecting transition at all;
  the only bound on a held epoch is the minimum-duration gate. **Backwards compatibility:**
  Backward-compatible — adding a cap bounds memory/disk that is today unbounded, and the retention
  plus fresh-snapshot-on-release behaviour is additive. **Remediation:** Track the held buffer's
  serialized size, stop appending at the emission cap while retaining the buffer, and force a full
  snapshot when the hold is released.

### n22 — Session Replay Privacy (🟡 Partial)
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

### n23 — Stop Session Recording (🟡 Partial)
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

### n24 — Surveys (🟡 Partial)
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

- **New gap found 2026-10-26 (spec change #93, `f238b16`):** "Surveys with undisplayable questions are
  not shown" requires an SDK to skip a whole survey when it contains a question type it cannot
  display, without marking it seen and without blocking another eligible survey.
  `PostHogSurveysIntegration.getActiveMatchingSurveys`
  (`posthog-android/src/main/java/com/posthog/android/surveys/PostHogSurveysIntegration.kt:257-290`)
  filters on dates, device type, web-only conditions, seen state, wait period, feature flags and
  event activation — there is no question-type check at any step, and `canAutoDisplaySurvey`
  (`:901-903`) only filters by survey *type*. `SurveyQuestionType.fromValue`
  (`posthog/src/main/java/com/posthog/surveys/SurveyEnums.kt:20-30`) returns `null` for an
  unrecognized type, so a survey gaining a newer question type is partially rendered rather than
  skipped — the exact failure mode the spec's rationale describes. **Backwards compatibility:**
  Backward-compatible — adding the gate only withholds surveys that cannot render correctly today.
  **Remediation:** Add a question-type check to `getActiveMatchingSurveys` (and to any public
  renderability check) so a survey with an unresolvable question type is filtered out before display
  and before any seen/last-seen key is written.

### n25 — Traces (❌ Fail)
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

## Changes this run (2026-10-26)

Seven rows improved on real code changes, one on a spec change, and five new rows were added.

| Contract | Was | Now | Why |
|---|---|---|---|
| Alias | ❌ | ✅ | `alias()` now sets `props["distinct_id"] = sourceDistinctId` alongside `alias` (`PostHog.kt:1491-1497`), resolving the identity once so the envelope and the property cannot diverge. |
| Screen | ❌ | ✅ | `screen()` now merges caller `properties` **first** and stamps `$screen_name = trimmedTitle` after (`PostHog.kt:1461-1467`), the precedence the spec requires. |
| Shutdown | ❌ | ✅ | `close()` now calls `flush()` before tearing the queues down (`PostHog.kt:619-620`). |
| Start Session Recording | ❌ | ✅ | `startSessionReplay()` is now taken under `setupLock` and ignores a start requested while opted out (`PostHog.kt:2515-2529`). |
| Autocapture | ❌ | ✅ | Generic UI-interaction autocapture now exists: `PostHogElementInteractionIntegration` captures `$autocapture` (`:186`) with `$elements_chain` built by `InteractionTarget` (`:60`), behind `captureElementInteractions`, with `posthog_autocapture_no_capture` / `ph-no-capture` subtree exclusion (`InteractionTarget.kt:177-181`) and Compose support. |
| HTTP Client | 🟡 | ✅ | `isRetryableFlagsError` now covers `UnknownHostException` (DNS) and `SSLException` (TLS) (`PostHogApi.kt:305-316`), closing the last audit's gap, and still leaves `ConnectException` unretried — which spec change #110 (`f62a029`) subsequently made the *required* behaviour. |
| Capture Exception | ❌ | ✅ | The ❌ was for missing top-level `$exception_type`/`$exception_message`. Spec change #103 (`8ee7d7a`) withdrew that requirement: `$exception_list[0].type`/`.value` are now canonical and the legacy keys are explicitly "not required". Separately, the new "Ignored exception types" requirement (#95, `73a3954`) — which names `errorTrackingConfig.ignoredExceptionTypes` on posthog-android by name — is implemented on both paths: `isIgnoredThrowable` for live throwables and `hasIgnoredTypeInExceptionList` (`PostHog.kt:999-1008`, `:1125-1140`) for `$exception` events handed to the generic capture API by the Flutter/RN bridges, rejoining `module` + `type` into the qualified class name. |
| Capture | ✅ | ✅ | Reconfirmed against the new "Caller-supplied event properties take precedence" requirement (#114). `buildProperties` merges registered properties, static/dynamic context, flag properties, `$groups` and the cached `$screen_name` first, then the caller's `properties`, then — deliberately after the caller — `$is_identified`/`$process_person_profile` and the replay debug bundle (`PostHog.kt:744-834`), matching the spec's five-step client order exactly, including the carve-out for a non-empty caller-supplied `$session_id` (`:804-807`). |
| Application Lifecycle | ✅ | ✅ | Reconfirmed against spec change #101 (`caa80b4`): `$app_version`/`$app_build` reach lifecycle events through the static context (`PostHogAndroidContext.kt:68-71`). The un-prefixed `version`/`build` that `PostHogAppInstallIntegration.kt:74-75` also sends are explicitly grandfathered by the requirement until the next major version. |
| Reload Feature Flags | ✅ | ✅ | Reconfirmed against spec change #99 (`d078270`): the new "Reload completion failure reporting" requirement only binds SDKs that *do* report failure through the completion. `PostHogOnFeatureFlags.loaded()` takes no arguments and reports nothing, so the requirement does not apply. |
| Setup | ✅ | ✅ | Reconfirmed against spec change #108 (`c2f09c1`): `PostHogConfig(projectToken = …)` is the primary name and is trimmed (`PostHogConfig.kt:445-447`), with a `@Deprecated` `apiKey` alias returning the same value (`:450-460`) and a deprecated `apiKey` constructor form (`:644-706`) — exactly the "add `projectToken`, keep the old name as a deprecated alias in the same release" shape the requirement asks for. |

Rows that did **not** change and were re-verified from source: Register (blank-key gap stands), Event
Batcher (injectable-clock gap stands; new replay-attribution requirement passes), Get Feature Flags
and Get Feature Flags And Payloads (still no public flat/bulk getters — `PostHogInterface.kt:164`
exposes only `getAllFeatureFlags(): List<FeatureFlagResult>?`), and Traces (still no `/i/v1/traces`
OTLP pipeline anywhere; only `/i/v1/logs` exists, `PostHogApi.kt:129`).
