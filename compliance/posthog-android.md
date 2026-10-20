# posthog-android — SDK Compliance

**Repo:** [PostHog/posthog-android](https://github.com/PostHog/posthog-android)
**Audited commit:** `c5e788bd603d3bdda77ac4d213538b9db637299a` ([commit](https://github.com/PostHog/posthog-android/commit/c5e788bd603d3bdda77ac4d213538b9db637299a)) — audited on 2026-10-19
**Audited against sdk-specs commit:** `c72e367`
**Summary:** 35 ✅ · 18 🟡 · 5 ❌ · 6 ➖ · 0 ❓ (64 rows; previous audit 2026-08-10 at `8659a7b4` scored 31/16/9/3/0 on 59 rows)

**Why this run:** rotation priority 3 — the pointer was ten weeks old, and android carries the
mobile reference for Session Replay Debug Properties. It was also the cheapest third slot available:
this run already had the repository cloned to resolve posthog-flutter's Unknown cells, since Flutter
embeds this SDK on Android.

**Scope — this was a targeted re-audit, not a full 64-row re-derivation.** The five contracts missing
from the previous 59-row file were audited from scratch, every previously ❌ or 🟡 row was re-read
against current code at `c5e788bd`, and the rows that merged spec text touches (PRs #103, #108, #110)
were re-checked. Rows that were ✅ at the last audit, whose code is unchanged, and which no merged
spec text affects were **not** independently re-derived; they carry forward. The matrix is also
re-sorted alphabetically this run to match the other per-SDK files, so **note numbers have been
reassigned** — a reference to "posthog-android nX" in an older document may point at a different row.

**Row-count note:** this file previously appended five contracts out of order at the bottom of the
matrix. It is now a single alphabetical 64-row table.

## Movement this run

This is the largest net improvement of any SDK in the matrix so far: ✅ rows **31→35** while the row
count grew by five, and ❌ rows **9→5**.

**Four rows cleared (❌/🟡 → ✅):**

- **Screen ❌→✅.** The previous finding was that a caller-supplied `$screen_name` silently overrode
  the explicit `screenTitle` argument, with the SDK's own doc comment documenting the wrong
  precedence. Fixed: `screen()` now spreads the caller's properties first and then assigns
  `props["$screen_name"] = trimmedTitle` with the comment "The title wins over a caller-supplied
  `$screen_name`, matching the cached value" (`posthog/src/main/java/com/posthog/PostHog.kt:1305-1311`).
  An empty/blank title is also now rejected early (`:1294-1297`). The separate auto-attach of the
  *cached* screen name on later events is deliberately stamped **before** the caller merge
  (`stampCachedScreenName`, `:834-844`), so a caller can still override the ambient value — which is
  the correct split.
- **Shutdown ❌→✅.** The previous finding was that `close()` never flushed and stranded queued
  events on disk. Fixed: `PostHog.close()` now calls `flush()` before tearing down
  (`PostHog.kt:536-545`, "flush pending events before tearing down so queued data isn't lost") and
  `PostHogStateless.close()` calls `queue?.flushForShutdown()` (`PostHogStateless.kt:115-126`). This
  also fixes the native half of posthog-flutter's Shutdown finding — see
  [posthog-flutter.md#n32](posthog-flutter.md#n32).
- **HTTP Client 🟡→✅.** The previous 🟡 was explicitly provisional: it recorded that
  [posthog-android#828](https://github.com/PostHog/posthog-android/pull/828) was approved but not
  merged, and said the row stays 🟡 until it ships. **It has shipped.** `isRetryableFlagsError`
  (`internal/PostHogApi.kt:305-316`) now retries `SocketTimeoutException`, `EOFException`,
  `UnknownHostException` (DNS), `SSLException` (TLS), and a reset `SocketException`.
  `ConnectException` (connection refused) still falls through, which is correct: since
  [#110](https://github.com/PostHog/sdk-specs/pull/110) the spec says a connection refused by the
  destination is not retried and is surfaced as the flag error immediately, so the requirement
  keeps connection refused fail-fast. Retry delay is genuinely exponential from a 300 ms base,
  capped at 30 s (`:344-352`, `FLAGS_INITIAL_RETRY_DELAY_MS = 300L`). That satisfies both the
  http-client spec's transport-failure language **and**, on first contact, PR
  [#110](https://github.com/PostHog/sdk-specs/pull/110)'s refused-connection rule — and it is the
  only SDK in the matrix that gets the 300 ms→600 ms backoff schedule right, where posthog-js,
  posthog-node, and posthog-react-native all use a fixed delay.
- **Capture Exception ❌→✅.** The previous finding was "no top-level
  `$exception_type`/`$exception_message`, only nested `$exception_list`" — exactly the requirement
  sdk-specs PR [#103](https://github.com/PostHog/sdk-specs/pull/103) retired. The 2026-10-12 run
  predicted this would most likely clear at android's next audit; it does. Same clearance as
  posthog-python and posthog-react-native.

**One row improved (❌→🟡):** **Autocapture** ([n2](#n2)) — `$autocapture` now genuinely exists.

**New rows (5):** Capture AI ➖, Evaluate Flags ➖, MCP Analytics ➖ (all `server`-scoped; android
appears in none of their applicability tables), **Exception Event Metadata 🟡** ([n7](#n7)),
**Session Replay Debug Properties 🟡** ([n17](#n17)) — and android turns out to have by far the most
complete implementation of that contract outside the browser.

## Matrix

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Alias | ❌ | [n1] |
| 2 | Application Lifecycle | ✅ |  |
| 3 | Autocapture | 🟡 | [n2] |
| 4 | Before Send Hook | 🟡 | [n3] |
| 5 | Bootstrap | 🟡 | [n4] |
| 6 | Capture | ✅ |  |
| 7 | Capture AI | ➖ |  |
| 8 | Capture Exception | ✅ |  |
| 9 | Consent Gating | 🟡 | [n5] |
| 10 | Create Person Profile | ➖ |  |
| 11 | Debug | ✅ |  |
| 12 | Device ID Generator | ✅ |  |
| 13 | Evaluate Flags | ➖ |  |
| 14 | Event Batcher | 🟡 | [n6] |
| 15 | Exception Event Metadata | 🟡 | [n7] |
| 16 | Exception Steps | ✅ |  |
| 17 | Feature Flag Cache | ✅ |  |
| 18 | Feature Flag Called Tracker | 🟡 | [n8] |
| 19 | Flag Definition Loader | ➖ |  |
| 20 | Flush | ✅ |  |
| 21 | Get Anonymous ID | ✅ |  |
| 22 | Get Distinct ID | ✅ |  |
| 23 | Get Feature Flag | ✅ |  |
| 24 | Get Feature Flag Payload | ✅ |  |
| 25 | Get Feature Flag Result | ✅ |  |
| 26 | Get Feature Flags | ❌ | [n9] |
| 27 | Get Feature Flags And Payloads | ❌ | [n10] |
| 28 | Get Session ID | ✅ |  |
| 29 | Group | 🟡 | [n11] |
| 30 | Group Identify | 🟡 | [n12] |
| 31 | HTTP Client | ✅ |  |
| 32 | Identify | ✅ |  |
| 33 | Is Feature Enabled | ✅ |  |
| 34 | Is Opt Out | ✅ |  |
| 35 | Is Session Replay Active | ✅ |  |
| 36 | Local Feature Flag Evaluator | ➖ |  |
| 37 | Logs | ✅ |  |
| 38 | MCP Analytics | ➖ |  |
| 39 | On Feature Flags | 🟡 | [n13] |
| 40 | Opt In | 🟡 | [n14] |
| 41 | Persistent Storage | 🟡 | [n15] |
| 42 | Register | 🟡 | [n16] |
| 43 | Reload Feature Flags | ✅ |  |
| 44 | Remote Config | ✅ |  |
| 45 | Reset | ✅ |  |
| 46 | Reset Group Properties For Flags | ✅ |  |
| 47 | Reset Person Properties For Flags | ✅ |  |
| 48 | Retry Queue | ✅ |  |
| 49 | Screen | ✅ |  |
| 50 | Session Manager | ✅ |  |
| 51 | Session Replay Debug Properties | 🟡 | [n17] |
| 52 | Session Replay Ingestion Controls | 🟡 | [n18] |
| 53 | Session Replay Privacy | 🟡 | [n19] |
| 54 | Set Group Properties For Flags | ✅ |  |
| 55 | Set Person Properties | ✅ |  |
| 56 | Set Person Properties For Flags | ✅ |  |
| 57 | Setup | ✅ |  |
| 58 | Shutdown | ✅ |  |
| 59 | Start Session Recording | ❌ | [n20] |
| 60 | Stop Session Recording | 🟡 | [n21] |
| 61 | Surveys | 🟡 | [n22] |
| 62 | Traces | ❌ | [n23] |
| 63 | Tracing Headers | ✅ |  |
| 64 | Unregister | ✅ |  |

## Notes

Note numbers were reassigned this run when the matrix was re-sorted alphabetically. Notes carried
forward from the 2026-08-10 audit keep their original analysis, re-checked for existence at
`c5e788bd`; notes [n2](#n2), [n7](#n7), and [n17](#n17) are new or rewritten this run. A reference
to "posthog-android nX" in a document written before 2026-10-19 refers to the old numbering.

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

### n2 — Autocapture (🟡 Partial)
- **Spec requires:** Walk element ancestry on a UI interaction, build a sanitized `$elements` array, emit `$autocapture` with an `$event_type` and screen context; respect no-capture markers; never capture sensitive control values.
- **SDK currently:** **Improved from ❌ Fail — `$autocapture` now genuinely exists.** The previous audit found no generic UI-interaction autocapture at all. `PostHogElementInteractionIntegration` (`posthog-android/src/main/java/com/posthog/android/internal/PostHogElementInteractionIntegration.kt:186`) now captures `$autocapture` for actionable View and Compose taps, carries `$touch_x`/`$touch_y`, and additionally detects and emits `$rageclick` (`:178-182`). A no-capture marker is honoured per subtree via the `com.posthog.android.R.id.posthog_autocapture_no_capture` tag (`internal/InteractionTarget.kt:179`), documented at `PostHogAndroidConfig.kt:77-82`. **Why 🟡 rather than ✅:** the feature is **off by default** — `captureElementInteractions` defaults to `false` (`PostHogAndroidConfig.kt:77`, "Default: false"), so an app that does nothing gets no autocapture, unlike the browser SDK where it is the default-on behaviour the contract describes.
- **Backwards compatibility:** Backward-compatible for everything except the default. Flipping `captureElementInteractions` to `true` would start sending a new event family for every existing app on upgrade, which is a volume and billing change; it should be a deliberate, announced default change in a minor or major release rather than a quiet flip.
- **Remediation:** Confirm the `$elements` shape and `$event_type` vocabulary match the cross-SDK contract, then decide the default deliberately — either flip `captureElementInteractions` to `true` with a release note, or record a spec carve-out that mobile autocapture is opt-in.

### n3 — Before Send Hook (🟡 Partial)
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

### n4 — Bootstrap (🟡 Partial)
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

### n5 — Consent Gating (🟡 Partial) — *downgraded from ✅ Pass this cycle*
- **Spec requires:** opt-out state gates capture across all product surfaces the spec's
  "Interactions" section lists, explicitly including session replay (which "may be stopped,
  skipped, or restarted based on consent state").
- **SDK currently:** Core capture-path gating is solid — `capture()` (`PostHog.kt:722`,
  `isOptedOut()` check at line 735), `group()`, `alias()`, `captureException`,
  `captureLogInternal` all gate on `isOptedOut()` directly or transitively via `capture()`.
  However, re-examining this cycle in light of the session-replay findings (now [n20](#n20)/[n21](#n21)) surfaced a
  cross-cutting gap previously missed: `startSessionReplay()`/`stopSessionReplay()` never check
  `isOptedOut()`, and `optOut()` (`PostHog.kt:1101-1115`) never proactively stops an
  already-active replay session. Since session replay is explicitly named in this spec's own
  scope, this is a legitimate consent-gating gap, not merely a start/stop-session-recording-only
  issue — hence the downgrade from the prior audit's ✅ Pass.
- **Backwards compatibility:** Backward-compatible — the same fix as n13/n14 (add `isOptedOut()`
  guards) closes this gap; optionally also make `optOut()` call `stopSessionReplay()`.
- **Remediation:** Extend opt-out gating to the session-replay start/stop surface.

### n6 — Event Batcher (🟡 Partial)
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

### n7 — Exception Event Metadata (🟡 Partial)
- **Spec requires:** Every entry in `$exception_list` carries a `mechanism`; the outermost entry's `mechanism.exception_id` SHALL equal `0` and every entry SHALL have a unique non-negative `exception_id`; nested entries SHALL carry `parent_id`, `mechanism.type` of `chained`, and a `mechanism.source` naming the parent edge. A producer SHALL **omit** any optional common field it cannot determine and **MUST NOT represent unknown with `false`**, an empty string, or `null`. `handled` describes disposition at the relevant boundary and MUST NOT be invented for a nested entry. At most 50 entries with cycle detection. Application property bags MUST NOT override SDK-owned `$exception_list`, `$exception_level`, or `$exception_source` (spec line 300).
- **SDK currently:** Audited from scratch against `posthog/src/main/java/com/posthog/internal/errortracking/ThrowableCoercer.kt`. **Much of this is already right**, and the implementation is visibly spec-aware: `exception_id` and `parent_id` are emitted into the mechanism (`:214-220`); derived entries get `mechanism.type` of `"chained"` for cause-chain members and `"suppressed"` for suppressed exceptions, with the first entry keeping the primary mechanism (`:285-299`); `MAX_EXCEPTION_LIST_SIZE = 50` (`:391`) matches the spec's bound exactly and traversal is cycle-guarded with a `seen` set (`:381`); `thread_id` is populated; and a code comment at `:189-191` shows the author knowingly emitting the linkage fields "for parity with the other SDKs" even though ingestion currently drops them. **Four gaps:** (1) **`"synthetic" to false` is a hardcoded literal** on every entry (`:212`) — this is exactly the "MUST NOT represent unknown with `false`" prohibition; the field should be omitted when undetermined; (2) **nested entries inherit the outermost `handled`** — the same `handled` value is threaded into every item (`:328`, and `:211` writes it unconditionally), which is invented capture-boundary metadata for a cause; (3) **no `mechanism.source`** — the parent edge is encoded in `mechanism.type` (`chained`/`suppressed`) rather than in the dedicated `source` field the spec defines, and **no `$exception_source` property is emitted** anywhere; (4) **`exception_id` is omitted entirely for a single-item list** (`:215-217`, "null for a single-item list, where the ids carry no information") — but the spec requires the outermost entry's `exception_id` to equal `0` unconditionally, because the canonical tree linkage depends on it. Separately, `PostHogStateless.kt:701` documents that "callers can override reserved keys such as `$exception_level`", which is the application-property-bag override spec line 300 forbids.
- **Backwards compatibility:** Backward-compatible for (1), (3), and (4) — omitting a field, adding `source`/`$exception_source`, and always emitting `exception_id: 0` are additive or strictly more correct wire changes. **Needs deprecation path** for the `$exception_level` caller override, which is currently documented behaviour: a typed override parameter should ship before the generic property-bag path stops winning. Gap (2) is backward-compatible.
- **Remediation:** Omit `synthetic` unless determined rather than writing `false`; stop threading the boundary `handled` onto derived items; add `mechanism.source` alongside the existing `type` and emit `$exception_source` from the capture boundary; always assign `exception_id`, including on a single-item list. Then add a typed `level` override and stop honouring `$exception_level` from the generic property map.

### n8 — Feature Flag Called Tracker (🟡 Partial)
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

### n9 — Get Feature Flags (❌ Fail)
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

### n10 — Get Feature Flags And Payloads (❌ Fail)
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

### n11 — Group (🟡 Partial)
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

### n12 — Group Identify (🟡 Partial)
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

### n13 — On Feature Flags (🟡 Partial)
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

### n14 — Opt In (🟡 Partial)
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

### n15 — Persistent Storage (🟡 Partial)
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

### n16 — Register (🟡 Partial)
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

### n17 — Session Replay Debug Properties (🟡 Partial)
- **Spec requires:** `client`. Four required keys on **every** captured event except `$snapshot` — `$recording_status`, `$sdk_debug_replay_event_trigger_status`, `$sdk_debug_replay_linked_flag_trigger_status`, `$sdk_debug_replay_internal_buffer_length`. Everything else is an **optional bundle** that goes **only on SDK events** (names starting with `$`, excluding `$feature_flag_called`, `$snapshot`, and the browser's `$$heatmap`) and **at most once every 30 seconds per SDK instance**. The queue-depth key sits outside both tiers and stays on every non-`$snapshot` event. `$snapshot` carries none of them. An SDK with no replay integration produces only `$recording_status: disabled`. **On mobile, a crash-time `$exception` reported on a later launch is stamped from a crash-context snapshot that always carries the full bundle.**
- **SDK currently:** Audited from scratch, and this is the most complete implementation of the contract outside `posthog-js`. `PostHogReplayIntegration.debugProperties()` (`posthog-android/src/main/java/com/posthog/android/replay/PostHogReplayIntegration.kt:2591-2643`) produces all three cross-platform `$sdk_debug_replay_*` required keys plus a genuine tri-state `$recording_status` (`disabled`/`buffering`/`active`) derived from a real buffering snapshot, and adds a thoughtful optional set: `$sdk_debug_replay_flush_hold_reason` (distinguishing `awaiting_remote_config` from `below_minimum_duration`), `$sdk_debug_replay_pending_trigger_conditions`, `$sdk_debug_replay_capture_mode`, and `$sdk_debug_replay_throttle_delay_ms`. The trigger statuses use a shared `triggerStatus()` helper with a correct `trigger_disabled`/`trigger_pending`/`trigger_activated` vocabulary. The wiring in `PostHog.sdkDebugProperties()` (`PostHog.kt:782-810`) is careful: it is applied only inside the `appendSharedProps` block, which `$snapshot` events skip (`:918-919`), so **the `$snapshot` exclusion is correct**; it is merged **after** the caller's properties so SDK-computed values win, with a comment citing posthog-js's `extend(properties, sdkDebugProperties)` as the model; the replay handler's contribution is guarded separately from the session and queue keys so a throwing handler cannot suppress them, surfacing `$sdk_debug_error_capturing_properties` instead; and it falls back to `$recording_status: disabled` when no replay handler is installed, exactly as the spec's no-integration case requires. `$sdk_debug_pending_queue_size` is attached as the queue-depth key.
  **Two real deviations.** (1) **No tiering and no throttle.** The spec puts everything beyond the four required keys into an optional bundle restricted to SDK events and rate-limited to once per 30 seconds per instance. Android attaches the *entire* set — `$sdk_debug_replay_capture_mode`, `$sdk_debug_replay_throttle_delay_ms`, `$sdk_debug_replay_pending_trigger_conditions`, `$sdk_debug_replay_flush_hold_reason`, `$sdk_debug_session_start`, `$sdk_debug_current_session_duration` — to **every** event with shared props, including custom (non-`$`) events, with no throttle window anywhere. There is no `REQUIRED_REPLAY_PROPERTIES`-equivalent split. That is a per-event payload cost on every customer event, which is the cost the tiering exists to avoid.
  (2) **The crash-context case does the opposite of what the spec says.** `sdkDebugProperties()` opens with an early return of an **empty** map when an explicit timestamp predates the current session start (`PostHog.kt:787-791`, "An explicit timestamp from before this session started (a previous-process crash reported on this launch) did not occur here"). That is precisely the mobile crash-time `$exception` the spec singles out — and the spec says it SHALL be stamped from a crash-context snapshot carrying the full bundle, not left bare. The code's reasoning is sound in isolation (today's live state is not the crash's state), but the spec's answer is to persist the snapshot at crash time and replay it, not to omit the keys.
- **Backwards compatibility:** Backward-compatible both ways. (1) removes properties from events, which only shrinks payloads — a consumer reading an optional key off a custom event would lose it, so it warrants a changelog note. (2) requires persisting a small snapshot at crash time and reading it back on the next launch; it is additive on the wire.
- **Remediation:** Introduce the required/optional split — keep the four required keys plus the queue-depth key on every non-`$snapshot` event, and gate the rest behind an SDK-event check and a 30-second per-instance throttle, mirroring `packages/browser/src/posthog-core.ts`'s `REQUIRED_REPLAY_PROPERTIES`. Then persist a crash-context debug snapshot alongside the crash record and stamp the deferred `$exception` from it instead of returning an empty map. Because `posthog-flutter` and `posthog-react-native` embed this SDK, fixing the tiering here improves all three.

### n18 — Session Replay Ingestion Controls (🟡 Partial)
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

### n19 — Session Replay Privacy (🟡 Partial)
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

### n20 — Start Session Recording (❌ Fail)
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

### n21 — Stop Session Recording (🟡 Partial)
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

### n22 — Surveys (🟡 Partial)
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

### n23 — Traces (❌ Fail)
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
