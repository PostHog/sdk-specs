# posthog-java — SDK Compliance

**Repo:** [PostHog/posthog-android](https://github.com/PostHog/posthog-android) — `posthog-server/` subdirectory (the standalone `PostHog/posthog-java` repo is archived; its Java/Kotlin server SDK now lives here, package `com.posthog.server`)
**Audited commit:** `8309f837` ([tree](https://github.com/PostHog/posthog-android/commits/main)) — audited on 2026-11-02
**Audited against sdk-specs commit:** `be25182`
**Summary:** 12 ✅ · 14 🟡 · 9 ❌ · 33 ➖ · 0 ❓ (68 rows)

**Previous audit:** 2026-08-10 at `8659a7b4` (59 rows, 12 ✅ · 13 🟡 · 6 ❌ · 28 ➖ · 0 ❓). That pointer
was 12 weeks old and the last one in the matrix still short of the full contract list — posthog-java
led the queue on every priority rule at once.

**Scope of this run — row completion plus a targeted re-audit.** `posthog-server/src/main` advanced
by +2,099/−345 lines across 21 files, and the contract list grew from 59 to 68. This run:
(a) **added the nine missing rows** — Capture AI, Evaluate Flags, Exception Event Metadata, Session
Replay Debug Properties and MCP Analytics (outstanding since the matrix's 64-row expansion), plus the
four new server-scope contracts Emails, AI Datasets, AI Scorers and Offline Evaluations;
(b) re-derived the rows the code drift and spec delta land on — Alias, Local Feature Flag Evaluator,
Retry Queue, HTTP Client, Traces, Logs and the four `*_for_flags` rows; and (c) re-confirmed every
pre-existing ❌. The remaining rows carry forward from 2026-08-10 and are **not** re-evidenced here;
a full 64-row re-derivation did not fit this run's budget and is the one thing to spend the next
posthog-java slot on. Note ids are stable across audits; the new rows take ids n26 onward.

**Two findings worth leading with.**

**posthog-java is the first SDK in this matrix to implement feature-flag negative knowledge.**
`PostHogFeatureFlags.kt` now carries a capacity-bounded `knownMissingFlagKeys` map, a
`missingFlagKeysGeneration` counter invalidated on every successful definitions refresh, and an
`inFlightMissingFlagProbes` map that coordinates concurrent probes for the same key. Six server SDKs
have been checked against that requirement and recorded as lacking it; posthog-java is the seventh
checked and the first to have it. See [n27].

**Its exception envelope is the worst row added this run.** `ThrowableCoercer` — shared core, so this
is the same defect family posthog-android carries — violates four separate `exception-event-metadata`
rules at once, including the explicit "MUST NOT default unknown synthetic state to `false`". See [n29].

**A note on repo layout:** The standalone `PostHog/posthog-java` GitHub repository is archived; its README redirects to `posthog-android`, at `posthog-android/tree/main/posthog-server`. This audit clones the `posthog-android` monorepo (commit above) and inspects `posthog-server/src/main/java/com/posthog/server/` alongside its declared Gradle dependency `api(project(":posthog"))` — a shared core module at `posthog/src/main/java/com/posthog/` also used by `posthog-android` (the mobile client SDK, audited separately in this matrix). `posthog-server`'s `PostHog` class extends the core's `PostHogStateless` base class rather than the richer client-only `PostHog` base class used by `posthog-android` — so most client-only ambient-identity/session/replay/consent primitives simply aren't exposed on the server class at all. Since the last audit it has grown a `PostHogUncaughtExceptionCapture` integration, an `otel/` package holding a `PostHogContextSpanProcessor`, a `PostHogFeatureFlagFilter`, and a substantially rebuilt `PostHogMemoryQueue` (+251 lines) and `FlagEvaluator` (+459 lines). **`posthog-java` and `posthog-android` no longer share an audited commit** and have not since 2026-10-19.

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Alias | ❌ | [n1] |
| 2 | Application Lifecycle | ➖ | mobile/native app install/foreground/background lifecycle; spec explicitly excludes server SDKs; acceptance is `@client`-only; zero lifecycle hooks anywhere in `posthog-server` |
| 3 | Autocapture | ➖ | browser/mobile UI-event auto-capture; spec explicitly excludes server SDKs (no UI event stream); acceptance is `@client`-only; no autocapture code path reachable from `posthog-server` (exists only in shared core for `posthog-android`) |
| 4 | Before Send Hook | 🟡 | [n2] |
| 5 | Bootstrap | ➖ | client-side cold-start flag/identity hydration from server-rendered values; acceptance is `@client`-only; no bootstrap concept exists in `posthog-server` |
| 6 | Capture | ✅ | [n3] |
| 7 | Capture Exception | 🟡 | [n4] |
| 8 | Consent Gating | ➖ | client-side persistent per-user consent gate (`Applicability: client`); acceptance is `@client`-only; `optIn()`/`optOut()`/`isOptOut()` exist on shared-core `PostHogStateless` but are not exposed through `posthog-server`'s public `PostHogInterface.kt` |
| 9 | Create Person Profile | ➖ | client-side identity/profile-control API (`Applicability: client`); no `createPersonProfile`-equivalent anywhere in `posthog-server`; acceptance is `@client`-only |
| 10 | Debug | 🟡 | [n5] |
| 11 | Device ID Generator | ➖ | client-side persisted anonymous/device-id bootstrap (`Applicability: client`); `posthog-server` hardcodes `deviceId = null`/`anonymousId = null` in flag requests (`internal/PostHogFeatureFlags.kt`); acceptance is `@client`-only |
| 12 | Event Batcher | 🟡 | [n6] |
| 13 | Exception Steps | ➖ | spec explicitly scopes the single-user buffer to client SDKs with explicit server-exclusion language ("Server / multi-tenant... out of scope until a follow-up defines that model"); acceptance is `@client`-only; `PostHogExceptionStepsBuffer` exists only in shared core, zero references in `posthog-server` |
| 14 | Feature Flag Cache | ✅ | [n7] |
| 15 | Feature Flag Called Tracker | 🟡 | [n8] |
| 16 | Flag Definition Loader | ✅ | [n9] |
| 17 | Flush | 🟡 | [n10] |
| 18 | Get Anonymous ID | ➖ | client-side ambient-identity getter (`Applicability: client`); no `getAnonymousId()` anywhere in `posthog-server`; acceptance is `@client`-only with no `@server` scenario |
| 19 | Get Distinct ID | ✅ | [n11] |
| 20 | Get Feature Flag | ✅ | |
| 21 | Get Feature Flag Payload | ✅ | |
| 22 | Get Feature Flag Result | 🟡 | [n12] |
| 23 | Get Feature Flags | 🟡 | [n13] |
| 24 | Get Feature Flags And Payloads | 🟡 | [n13] |
| 25 | Get Session ID | ➖ | client-side ambient session-manager read (`Applicability: client`); no `getSessionId()` anywhere in `posthog-server`; `$session_id` only flows through as an explicit per-call/context property, never an owned rotating session manager; acceptance is `@client`-only |
| 26 | Group | ➖ | client-side ambient-context setter, distinct from `group_identify` (`Applicability: client`, "server SDKs generally expose `group_identify`/`$groupidentify` directly... but not a persistent ambient `group(...)` setter"); `PostHog.kt`'s `group()` is a pure one-shot event emitter with no ambient group-map storage; acceptance is `@client`-only |
| 27 | Group Identify | 🟡 | [n14] |
| 28 | HTTP Client | ✅ | [n15] |
| 29 | Identify | ✅ | [n16] |
| 30 | Is Feature Enabled | ✅ | [n17] |
| 31 | Is Opt Out | ➖ | client-side persisted consent-state getter (`Applicability: client`); `isOptOut()` exists on shared-core `PostHogStateless` but is not exposed through `posthog-server`'s `PostHogInterface.kt`; acceptance is `@client`-only |
| 32 | Is Session Replay Active | ➖ | client-side session-replay status getter (`Applicability: client`); zero session-replay code reachable from `posthog-server`; acceptance is `@client`-only |
| 33 | Local Feature Flag Evaluator | 🟡 | [n18] |
| 34 | Logs | ❌ | [n19] |
| 35 | On Feature Flags | ➖ | client-side callback/event surface tied to ambient flag state (`Applicability: client`); acceptance is `@client`-only; `posthog-server`'s `onFeatureFlags` callback (`PostHogConfig.kt`) is a real but differently-scoped "local-evaluation definitions (re)loaded" signal, not the client's ambient ready-state listener contract |
| 36 | Opt In | ➖ | client-side persistent per-user consent toggle (`Applicability: client`); `optIn()` exists on shared-core `PostHogStateless` but is not exposed through `posthog-server`'s public interface; acceptance is `@client`-only |
| 37 | Persistent Storage | ➖ | client-side persistent state layer (ambient identity/cached SDK state) (`Applicability: client`); `PostHogMemoryQueue` is explicitly documented as "memory-only... without persistence," confirmed by zero file/disk I/O anywhere in `posthog-server`; acceptance is `@client`-only |
| 38 | Register | ➖ | client-side persistent super-properties registry (`Applicability: client`); zero `register`/`unregister` matches anywhere in `posthog-server`; exists only on shared-core client-facing `PostHogInterface` used by `posthog-android`; acceptance is `@client`-only |
| 39 | Reload Feature Flags | ➖ | client-side ambient per-identity flag-cache refresh primitive (`Applicability: client`, "server SDKs usually expose direct flag-evaluation methods rather than a persistent ambient flag cache reload primitive"); acceptance is `@client`-only; `posthog-server`'s same-named `reloadFeatureFlags()` (`PostHog.kt:224-226`) is a structurally different primitive — refreshes the local-evaluation rule-definitions cache, not a per-identity ambient value cache |
| 40 | Remote Config | ➖ | client-side ambient project-config bootstrap (session replay/surveys/error-tracking config) (`Applicability: client`); `posthog-server`'s `remoteConfig` option is a deprecated no-op boolean retained only for source compatibility, and its `remoteConfigProvider` plumbing exists solely to wire up the local flag-evaluation engine, not a broader config bootstrap |
| 41 | Reset | ➖ | client-side ambient-identity/session/super-properties clear (`Applicability: client`); zero `reset(` matches as a public API method anywhere in `posthog-server`; no ambient state exists to reset (statelessness is architectural); acceptance is `@client`-only |
| 42 | Reset Group Properties For Flags | ❌ | [n20] |
| 43 | Reset Person Properties For Flags | ❌ | [n20] |
| 44 | Retry Queue | 🟡 | [n21] |
| 45 | Screen | ➖ | client-side screen-view capture primitive (`Applicability: client`); no `screen(` symbol reachable from `posthog-server`; acceptance is `@client`-only |
| 46 | Session Manager | ➖ | client-side ambient session id/rotation/persistence (`Applicability: client`); `PostHogRequestContext` only forwards a caller/header-supplied `sessionId` value, with no timers, rotation, or persisted store; acceptance is `@client`-only |
| 47 | Session Replay Ingestion Controls | ➖ | browser/mobile session-replay sampling/trigger controls (`Applicability: client`); acceptance is `@client`-only; zero reachable session-replay code in `posthog-server` |
| 48 | Session Replay Privacy | ➖ | browser/mobile DOM/screenshot masking (`Applicability: client`); acceptance is `@client`-only; no masking primitive reachable from `posthog-server` |
| 49 | Set Group Properties For Flags | ❌ | [n20] |
| 50 | Set Person Properties | ✅ | [n22] |
| 51 | Set Person Properties For Flags | ❌ | [n20] |
| 52 | Setup | ✅ | [n23] |
| 53 | Shutdown | 🟡 | [n24] |
| 54 | Start Session Recording | ➖ | client-side session-replay control (`Applicability: client`); acceptance is `@client`-only |
| 55 | Stop Session Recording | ➖ | client-side session-replay control (`Applicability: client`); acceptance is `@client`-only |
| 56 | Surveys | ➖ | browser/mobile survey display lifecycle; spec explicitly carves out servers; acceptance is `@client`-only; `posthog/surveys/` exists in shared core for `posthog-android` only, zero references in `posthog-server` |
| 57 | Traces | ❌ | [n26] |
| 58 | Tracing Headers | ✅ | [n25] |
| 59 | Unregister | ➖ | client-side persistent super-properties registry (`Applicability: client`); zero `unregister` matches anywhere in `posthog-server`; acceptance is `@client`-only |
| 60 | Evaluate Flags | 🟡 | [n27] |
| 61 | Capture AI | ➖ | the spec's applicability is `server` but conditional on AI support: "Other server SDKs (Rust, Go, Ruby, …) adopt this spec if and when they add AI support; until then their AI events ride plain `capture`." `posthog-server` has no `captureAi` surface and no LLM instrumentation (`grep -ril captureAi posthog-server/src/main` → nothing). Its `otel/` package is a span-*context* enrichment processor, not the OpenTelemetry AI bridge the spec's one unconditional requirement binds |
| 62 | Exception Event Metadata | ❌ | [n29] |
| 63 | Session Replay Debug Properties | ➖ | `client` applicability; the spec states server SDKs observe no session timeline and attach none of these keys. `posthog-server` extends `PostHogStateless`, has no replay subsystem reachable from it, and its `PostHogRequestContext` only forwards a caller-supplied `sessionId` |
| 64 | MCP Analytics | ➖ | the spec's applicability table enumerates the in-scope packages by name — posthog-js `@posthog/mcp`, posthog-python `posthog.mcp`, posthog-go `posthogmcp`/`posthogmcpsdk`, posthog-rs `posthog_rs::mcp`, posthog-ruby "not yet". No JVM package is listed and `posthog-server` ships no MCP add-on. Re-scope if a JVM row is added to that table |
| 65 | Emails | ❌ | [n28] |
| 66 | AI Datasets | ➖ | conditional applicability — "Server SDKs **that implement** AI dataset management", reference surface posthog-python only; no dataset surface in `posthog-server` |
| 67 | AI Scorers | ➖ | conditional applicability — "Server SDKs implementing AI scorer management"; no scorer surface in `posthog-server` |
| 68 | Offline Evaluations | ➖ | conditional applicability — "Server SDKs implementing offline evaluation uploads"; no experiment/upload surface in `posthog-server`. This capability also defines the shared app-API client the two rows above depend on, so all three would land together |

## Notes

### n1 — Alias (❌ Fail)
- **Spec requires:** `both` applicability. Server-side flow: validate that both the existing distinct id and the alias target id are present; the `@both`-tagged acceptance scenario "Alias is dropped when required identities are missing" (`acceptance/public/alias.feature`) requires that no event be enqueued and that the SDK record a validation warning.
- **SDK currently (re-confirmed at `8659a7b`):** `PostHog.kt:214-222` (`alias()`) delegates straight to shared-core `PostHogStateless.aliasStateless()` (`posthog/src/main/java/com/posthog/PostHogStateless.kt:356-368`):
  ```kotlin
  public override fun aliasStateless(distinctId: String, alias: String) {
      if (!isEnabled()) { return }
      val props = mutableMapOf<String, Any>()
      props["alias"] = alias
      captureStateless("$create_alias", distinctId, properties = props)
  }
  ```
  There is still no blank/empty check on either `distinctId` or `alias` — directly contrasting with `identify()` at line 379 (`if (distinctId.isBlank()) { log(...); return }`). Unaffected by the 6 intervening commits (none touched this file). A call with a blank/empty alias or distinct id is sent straight to the API as a malformed `$create_alias` event rather than being dropped with a warning.
- **Backwards compatibility:** Backward-compatible — adding a blank-check that logs a warning and returns early, mirroring `identify()`'s existing pattern, is additive; it only changes behavior for a currently-malformed call that today silently ships bad data instead of failing loudly.
- **Remediation:** Add the same `isBlank()` guard `identify()` already has to `aliasStateless()` for both `distinctId` and `alias`, logging a warning and returning without enqueuing when either is blank.

**Re-confirmed 2026-11-02 at `8309f837` — unchanged.** `PostHog.kt:288-296` still delegates straight
to `PostHogStateless.aliasStateless()` (`posthog/src/main/java/com/posthog/PostHogStateless.kt:368-380`),
which builds `props["alias"] = alias` and calls `captureStateless("$create_alias", distinctId, …)`
with **no** validation of either identity and **no** `distinct_id` entry in the payload properties. An
empty or blank id on either side still enqueues an event and records no warning, which is what the
`@both` "Alias is dropped when required identities are missing" scenario forbids. posthog-android's
2026-10-19 audit recorded the same shared-core defect.

### n2 — Before Send Hook (🟡 Partial)
- **Spec requires:** `both` applicability, acceptance `@both` throughout (`acceptance/private/before-send-hook.feature`). A `beforeSend(event) -> event | null` hook run before enqueue; supports multiple registered hooks run in order, each receiving the previous hook's output; stops the chain on a drop; hook exceptions must not crash the caller.
- **SDK currently (re-confirmed at `8659a7b`):** Hooks are registered via `PostHogConfig.addBeforeSend()`/`removeBeforeSend()` (server `PostHogConfig.kt:187-198`, forwarded into the shared core config in `asCoreConfig()`), stored as an ordered list and invoked in `PostHogStateless.buildEvent()` (`posthog/src/main/java/com/posthog/PostHogStateless.kt:308-310`). **Chaining bug still present:** the loop calls `beforeSend.run(postHogEvent)` on every iteration — the original, pre-chain event — instead of the running `eventChecked` variable it just assigned:
  ```kotlin
  var eventChecked: PostHogEvent? = postHogEvent
  for (beforeSend in beforeSendList) {
      try {
          eventChecked = beforeSend.run(postHogEvent)   // should be eventChecked, not postHogEvent
          if (eventChecked == null) { ... return null }
      } catch (e: Throwable) { ... return null }
  }
  return eventChecked
  ```
  With two or more registered hooks, each one independently transforms the original event; hook #2 never sees hook #1's mutation — violating the spec's "each hook receives the previous hook's output" requirement. **Exception-safety deviation also unchanged:** a throwing hook still drops the entire event (`return null`) rather than falling back to the original/last-good event.
- **Backwards compatibility:** Backward-compatible — fixing the chaining bug (`beforeSend.run(eventChecked)`) is a pure bug fix with no signature change. Changing the exception-fallback from drop-to-original is also additive/non-breaking (it means fewer events dropped, not more).
- **Remediation:** Fix `buildEvent()` to pass `eventChecked` (not `postHogEvent`) into each successive hook call. Separately, consider falling back to the pre-hook event on a thrown exception instead of dropping, to align with the spec's documented per-SDK fallback policies.

### n3 — Capture (✅ Pass)
- **Spec requires:** `both` applicability. Enrich events with distinct_id/timestamp/uuid/`$lib`+`$lib_version`/super-properties/`$groups`; honor opt-out with no network call; run `before_send`; never throw to the caller.
- **SDK currently:** `PostHog.kt:57-108` (`capture()`) resolves identity/personless-fallback via `PostHogRequestContext.resolveCaptureContext()`, then delegates to shared-core `captureStateless()` (`PostHogStateless.kt`), which builds properties in order (context → feature flags → `$set`/`$set_once` → `$groups` → `$lib`/`$lib_version`, caller-supplied properties applied last so they win), auto-generates a time-based UUID (`PostHogEvent.kt:21-28`), defaults the timestamp via the configured `dateProvider`, and checks the disabled/opt-out gate before any queueing — the whole body is wrapped in `try/catch(Throwable)` so `capture()` never throws. Well tested at both the server (`PostHogTest.kt`) and shared-core (`PostHogStatelessTest.kt`) layers. No change from prior audit.
- One minor, non-blocking deviation noted for completeness: a throwing `before_send` hook drops the event rather than falling back to the pre-hook message (see n2) — that defect is scored under Before Send Hook, not here, since Capture's own enrichment/opt-out/never-throw contract is otherwise fully satisfied.

### n4 — Capture Exception (🟡 Partial)
- **Spec requires:** Spec's own `## Applicability` line says `client` ("the audited implementations live in client/mobile SDKs with ambient device/user/session context"), but the acceptance feature `capture-exception.feature` is tagged `@both` at the feature level and on every one of its scenarios — treated as in-scope per this audit's acceptance-precedence convention, and doubly justified here since `posthog-server` genuinely implements `captureException()`. Requires correctly-ordered `$exception_list` (outermost/caught-first, root-cause-last), correctly-ordered stack frames (entry-point-first), flat top-level `$exception_type`/`$exception_message` properties, and preserved (not synthesized) stack traces.
- **SDK currently (re-confirmed at `8659a7b`):** `captureException()` (`PostHog.kt:228-248`) resolves request context then delegates to shared-core exception handling built on `ThrowableCoercer` (`posthog/src/main/java/com/posthog/internal/errortracking/ThrowableCoercer.kt`). `$exception_list` ordering is correct (outermost-first, cause-chain walk with a cycle guard); stack frames are correctly reversed to entry-point-first; stack preservation is structurally guaranteed since the JVM always provides a real `Throwable.stackTrace`. **Gap still present:** `$exception_type`/`$exception_message` flat, top-level properties are still never emitted anywhere — re-confirmed by an exhaustive grep across both `posthog-server/src/main` and shared-core `posthog/src/main` returning zero matches for either exact string; `ThrowableCoercer` only ever sets `$exception_list` and `$exception_level`. This directly contradicts the acceptance scenario "Capturing a handled exception emits an exception event," which requires `$exception_type=TypeError`-equivalent/`$exception_message=boom`-equivalent flat properties.
- **Backwards compatibility:** Backward-compatible — adding `$exception_type`/`$exception_message` sourced from `$exception_list[0].type`/`.value` is additive and removes nothing currently emitted.
- **Remediation:** Add `$exception_type`/`$exception_message` as flat top-level properties in the shared-core exception-building path (`ThrowableCoercer` or its caller), sourced from the first (outermost) entry of the constructed `$exception_list`.

### n5 — Debug (🟡 Partial)
- **Spec requires:** Spec's own applicability is `client` ("some SDKs expose only configuration-time logging options instead of a public runtime method"), and the acceptance file is `@client`-only with 3 scenarios: runtime enable/disable toggle; no network/analytics traffic when toggled; defaults to enabled when called with no argument.
- **SDK currently:** `PostHog.kt:53-55` (`debug(enable: Boolean)`) delegates to shared-core `PostHogStateless.debug()` (`posthog/src/main/java/com/posthog/PostHogStateless.kt:603-608`), which live-mutates `config.debug` and gates only local logging (`PostHogPrintLogger`) with no network/analytics side effects. However, both `PostHogInterface.kt:73` and `PostHogStateless.kt:603` still declare `debug(enable: Boolean)` with **no default parameter**, so the "defaults to enabled when omitted" acceptance scenario cannot even be invoked in the SDK's own idiom. No change from prior audit.
- **Backwards compatibility:** Backward-compatible — adding `enable: Boolean = true` as a default parameter value is purely additive.
- **Remediation:** Add a default value of `true` to `debug()`'s `enable` parameter on both `PostHogInterface.kt` and the shared-core base class.

### n6 — Event Batcher (🟡 Partial)
- **Spec requires:** `both` applicability, acceptance `@both`. Accumulate events; flush at count threshold (`flushAt`) or interval timer (`flushInterval`); preserve FIFO order; explicit flush should drain the queue; optionally shrink-and-retry on HTTP 413.
- **SDK currently (re-confirmed at `8659a7b`):** `internal/PostHogMemoryQueue.kt` correctly implements count-threshold flush (`flushIfOverThreshold()`, default `flushAt=100`) and a self-rescheduling interval timer (`startTimer()`, default `flushIntervalSeconds=5`), FIFO ordering via a single `ArrayDeque` with `addLast`/`removeFirst` under one lock (`add()`/`takeEvents()` — `add()`'s parameter was renamed `event`→`record` in the intervening commits, purely cosmetic, logic unchanged), and a `maxBatchSize` cap (default 100). **Gap 1 still present:** explicit `flush()` (`PostHogMemoryQueue.kt:73-85`) still sends only **one** batch capped at `maxBatchSize` — for a queue larger than `maxBatchSize`, a single `flush()` call does not fully drain it. **Gap 2 still present:** HTTP 413 is still not specially handled — it falls into the generic "non-retryable, drop the whole batch" branch in `batchEvents()` (only `isNetworkingError() || statusCode >= 500` triggers a requeue-and-retry).
- **Backwards compatibility:** Backward-compatible — making `flush()` loop until the queue is empty (or a static batch-count guard is hit) is an internal behavior change with no signature impact.
- **Remediation:** Change `flush()` in `PostHogMemoryQueue.kt` to loop `executeBatch()` until the queue is below the 1-event threshold, rather than sending a single capped batch.

### n7 — Feature Flag Cache (✅ Pass, beyond stated scope)
- Spec's own `## Applicability` says `client` ("some server SDKs also cache flag definitions or results" is explicitly acknowledged as an accepted server-side analogue), and the acceptance file is tagged `@both` at the feature level — a thin but real override signal.
- `internal/PostHogFeatureFlagCache.kt` is a genuine evaluated-flag-**value** cache (not merely flag definitions) — a true LRU (`LinkedHashMap` with `accessOrder=true` and `removeEldestEntry`) storing evaluated `Map<String, FeatureFlag>` results keyed by `FeatureFlagCacheKey` (distinctId + groups + properties + flagKeys), with TTL-based lazy eviction on read (`isExpired()`/`expiresAt`). Configurable via `PostHogConfig.kt`'s `featureFlagCacheSize` (default 1000) and `featureFlagCacheMaxAgeMs` (default 5 minutes), both marked `@PostHogExperimental`. Thoroughly tested in `PostHogFeatureFlagCacheTest.kt`. No change from prior audit.

### n8 — Feature Flag Called Tracker (🟡 Partial)
- **Spec requires:** Dedup `$feature_flag_called` by `(flag, value, distinct_id, normalized groups)`; bounded/incremental eviction (capacity pressure SHOULD NOT clear the entire tracker); clear fully only on shutdown/identity-reset boundaries; minimal-event mode gated by `has_experiment===false`, with an allowlist that must include 10 session-attribution properties (`$referring_domain`, `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `utm_term`, `gad_source`, `mc_cid`, `gclid`, `fbclid`) while still excluding `$referrer`.
- **SDK currently (re-confirmed at `8659a7b`) — dedup eviction remains fully compliant:** `posthog/src/main/java/com/posthog/internal/PostHogFeatureFlagCalledCache.kt` uses a hand-rolled LRU that, on overflow, evicts a ~20% batch of the oldest entries (`BATCH_EVICTION_FACTOR`) rather than a full clear; `.clear()` is a separate method called only from lifecycle boundaries. **Gap still present — minimal-event allowlist still missing all 10 session-attribution properties:** `MINIMAL_FEATURE_FLAG_CALLED_PROPERTIES` (`posthog/src/main/java/com/posthog/PostHogStateless.kt:693-711`) still contains exactly the same 16 entries as before (`$feature_flag`, `$feature_flag_response`, `$feature_flag_has_experiment`, `$feature_flag_id`, `$feature_flag_version`, `$feature_flag_reason`, `$feature_flag_request_id`, `$feature_flag_evaluated_at`, `$feature_flag_error`, `locally_evaluated`, `$groups`, `$process_person_profile`, `$session_id`, `$window_id`, `$lib`, `$lib_version`) — zero session-attribution properties. Re-confirmed via exhaustive grep across both `posthog/` and `posthog-server/` for any of the 10 required strings — no matches anywhere.
- **Backwards compatibility:** Backward-compatible — adding 10 keys to a strip-allowlist `Set` is strictly additive; it can only cause minimized events to retain more properties than before, never fewer.
- **Remediation:** Add the 10 session-attribution property names to `MINIMAL_FEATURE_FLAG_CALLED_PROPERTIES` in `posthog/src/main/java/com/posthog/PostHogStateless.kt:693-711`.

### n9 — Flag Definition Loader (✅ Pass)
- Spec Applicability `both`; acceptance file (`acceptance/private/flag-definition-loader.feature`) tagged `@server`.
- `internal/LocalEvaluationPoller.kt` runs a genuine background `ScheduledExecutorService`-based poll loop (configurable `pollIntervalSeconds`, default 30s) that periodically refreshes flag definitions without an application call being the trigger. ETag/If-None-Match support exists on a dedicated local-evaluation endpoint. External/shared cache-provider integration (`PostHogFlagDefinitionCacheProvider.kt`) supports both async and sync contracts, with provider-failure fallback to a direct fetch. Personal-API-key gating for local evaluation is enforced. Well tested. No change from prior audit.

### n10 — Flush (🟡 Partial)
- **Spec requires:** `both` applicability. No-op on empty queue with no network call; bypass batching intervals and drain immediately; on delivery failure the failed batch must remain queued for a later retry, not silently dropped.
- **SDK currently (re-confirmed at `8659a7b`):** `PostHog.kt:49-51` (`flush()`) delegates to shared-core `PostHogStateless.flush()`, which calls `queue?.flush()` → `PostHogMemoryQueue.flush()` (`internal/PostHogMemoryQueue.kt:73-85`). Correctly a no-op when the queue has no events, and correctly bypasses the interval timer. Retryable failures (`isNetworkingError() || statusCode >= 500`) correctly re-add the taken batch back to the front of the queue. **Gap (shared with Event Batcher, n6) still present:** `flush()` sends only a single capped batch (`maxBatchSize`), not a full drain. **Gap 2 still present:** HTTP 429 is still misclassified as non-retryable (falls through to the `else`/drop branch since `429 < 500`) — re-confirmed at `PostHogMemoryQueue.kt:~213`, `batchEvents()`'s retry condition remains `e.isNetworkingError() || e.statusCode >= 500`.
- **Backwards compatibility:** Backward-compatible — looping `flush()` until drained, and reclassifying 429 as retryable, are both internal behavior changes with no signature/contract impact.
- **Remediation:** Same fix as n6 for the drain behavior; separately, add `statusCode == 429` to the retryable branch in `PostHogMemoryQueue.batchEvents()`.

### n11 — Get Distinct ID (✅ Pass)
- Spec's own `## Applicability` line says `client`, but the acceptance feature `get-distinct-id.feature` is tagged `@both` at the feature level and contains an explicit `@server` scenario: "Server SDKs do not expose ambient distinct id state... Then the SDK should report that no ambient distinct id is available."
- `posthog-server` has no `getDistinctId()` method anywhere in `PostHogInterface.kt`/`PostHog.kt` — the only related mechanism is the internal, non-public `PostHogRequestContext.resolveDistinctId()`. The complete absence of any public ambient-distinct-id getter is, per the `@server` scenario's own framing, the correct server-side answer. No change from prior audit.

### n12 — Get Feature Flag Result (🟡 Partial)
- **Spec requires:** `both` applicability. A combined getter returning both the flag's value and its payload together, verified without a second per-key call.
- **SDK currently (re-confirmed at `8659a7b`):** The deprecated legacy path fully satisfies this: `getFeatureFlagResult()` (`PostHogInterface.kt:543-606`, impl `PostHog.kt:181-198`) returns `FeatureFlagResult` (`key`/`enabled`/`variant`/`payload`) — a correct combined shape. **Gap still present:** the newer, now-preferred `evaluateFlags()`/`PostHogFeatureFlagEvaluations` snapshot API still has **no combined result accessor** — its full current public surface is `keys`, `isEnabled(key)`, `getFlag(key)`, `getFlagPayload(key)`, `getFlagPayloadAs<T>(key)`, `onlyAccessed()`, `only(keys)` — confirmed by direct read of the class; no `getFlagResult(key)` and no bulk map accessor exist anywhere.
- **Backwards compatibility:** Backward-compatible — adding a `getFlagResult(key)` accessor to `PostHogFeatureFlagEvaluations` that bundles `getFlag`+`getFlagPayload` into one call/object is purely additive.
- **Remediation:** Add a `PostHogFeatureFlagEvaluations.getFlagResult(key)` method returning a combined value+payload object, so the canonical snapshot API doesn't regress this capability relative to the deprecated one it's meant to replace.

### n13 — Get Feature Flags / Get Feature Flags And Payloads (🟡 Partial, both contracts)
- **Spec requires:** `both` applicability. A bulk getter returning all evaluated flag values (and, for the payloads variant, their payloads) together in one call, without per-key round trips.
- **SDK currently (re-confirmed at `8659a7b`):** No method with either name or shape exists anywhere in `posthog-server` — re-confirmed by grep for `getFeatureFlags(`/`getAllFlags`/`AndPayloads`/`flagsMap`/`payloadsMap` returning zero matches in the public interface. The underlying data is still reachable via `evaluateFlags()`'s `keys: List<String>` plus per-key `getFlag(key)`/`getFlagPayload(key)`, but there is still no single canonical call returning the paired `{flags, payloads}` result shape.
- **Backwards compatibility:** Backward-compatible — adding `PostHogFeatureFlagEvaluations.toMap()` / `toPayloadMap()` (or a `PostHog.getAllFlagsAndPayloads(distinctId)` convenience wrapper) that folds `keys` + per-key accessors into two maps is purely additive.
- **Remediation:** Add bulk accessors (e.g. `PostHogFeatureFlagEvaluations.flagsMap: Map<String, Any?>` and `.payloadsMap: Map<String, String?>`, or a `PostHog.getAllFlagsAndPayloads()` convenience method) that fold the snapshot into the canonical `{flags, payloads}` shape without per-key event-tracking surprises.

### n14 — Group Identify (🟡 Partial)
- **Spec requires:** `both` applicability, acceptance `@both` for the happy path and for the "requires type and key" validation scenario (drop the call + record a validation warning when `groupType`/`groupKey` is missing).
- **SDK currently (re-confirmed at `8659a7b`):** There is still no dedicated `groupIdentify()` method — the emission role is served entirely by `group()`/`groupStateless()` (`PostHog.kt:200-212` → shared-core `PostHogStateless.kt:395-413`), which correctly builds and emits the `$groupidentify` event. **Gap still present:** `type`/`key` are still plain non-null `String` parameters with **no blank-check** anywhere in `groupStateless()` — re-confirmed by direct read of the current method body (only an `isEnabled()` guard exists). A call with a blank `type` or `key` still builds and enqueues a malformed `$groupidentify` event.
- **Backwards compatibility:** Backward-compatible — adding a blank-check that logs and returns early, mirroring `identify()`'s existing pattern, is additive.
- **Remediation:** Add `isBlank()` guards for `type` and `key` to `groupStateless()`, logging a warning and returning without enqueuing when either is blank (same fix pattern and root cause as n1).

### n15 — HTTP Client (✅ Pass)
- Spec applicability `both`. Native OkHttp client is injectable via `PostHogConfig`/`PostHogApi` construction. Ingestion requests carry the project token in the request body; the personal API key for local evaluation is sent as an `Authorization` header, kept separate from ingestion auth. Gzip is applied unconditionally. Non-2xx/3xx failures are surfaced as a typed `PostHogApiError` (with `Retry-After` parsed where present) rather than thrown to `capture()` callers. The `/flags` retry policy matches the spec precisely: exponential backoff starting at 300ms and doubling to 600ms, default budget of one retry, retrying only on transport failures or HTTP 502/504. No change from prior audit. Note: the parsed `Retry-After` value from ingestion responses is still not consumed by `posthog-server`'s own retry queue (see n21) — that gap is scored under Retry Queue, not here.

### n16 — Identify (✅ Pass)
- Spec applicability `both`. `identify()` (`PostHog.kt:37-47` → shared-core `PostHogStateless.kt:370-393`) correctly validates that `distinctId` is non-blank, builds `$set`/`$set_once` from `userProperties`/`userPropertiesSetOnce` correctly, and never attempts to stamp an `$anon_distinct_id`. No change from prior audit.

### n17 — Is Feature Enabled (✅ Pass)
- Spec applicability `both`, hard `SHALL`: the SDK must accept a caller-supplied boolean default and return it whenever the flag has no value. The canonical deprecated `isFeatureEnabled(distinctId, key, defaultValue = false, ...)` correctly returns the caller-supplied default for all "no value" cases, and a resolved value (including explicit `false`) always takes precedence. No change from prior audit. Minor, non-blocking note unchanged: `PostHogFeatureFlagEvaluations.isEnabled(key)` still hardcodes `false` on a miss with no `defaultValue` parameter — an allowed variation for successor APIs.

### n18 — Local Feature Flag Evaluator (🟡 Partial — reassessed this run, now for two compounding reasons)
- **Spec requires:** `both` applicability, acceptance `@both` (`acceptance/private/local-feature-flag-evaluator.feature`). Local rule/rollout-hash/cohort/dependency matching; fall back to remote evaluation ("signal inconclusive") when local evaluation cannot determine an outcome, including when required context (e.g. a group's properties) is missing. **New this cycle (sdk-specs `2036abd`):** the property-filter matcher SHALL support `starts_with`/`not_starts_with`/`ends_with`/`not_ends_with`, stringifying both sides, ASCII-lowercasing, and doing a prefix/suffix compare (negated for the `not_*` variants) — the same approach already used for `icontains`. A missing property for these operators SHALL be inconclusive (defer to remote), same as other operators.
- **SDK currently — deviation 1 (carried forward, unchanged):** for group-scoped flags where the required group context is missing, `computeFlagLocally()` (`posthog-server/src/main/java/com/posthog/server/internal/PostHogFeatureFlags.kt:765-770`) returns `false` directly:
  ```kotlin
  val groupKey = groups?.get(groupTypeName)
  if (groupKey == null) {
      // Group not provided - flag is off, don't failover to API
      config.logger.log("Can't compute group flag '$key' without group '$groupTypeName'")
      return false
  }
  ```
  instead of throwing `InconclusiveMatchException` (which would trigger remote fallback) — contradicting the acceptance scenario "Evaluator signals remote fallback when required context is missing." Re-confirmed verbatim (same code, same comment) at commit `8659a7b`.
- **SDK currently — deviation 2 (newly checked this cycle, confirmed missing):** `FlagEvaluator.matchProperty()` (`posthog-server/src/main/java/com/posthog/server/internal/FlagEvaluator.kt:122-212`) dispatches on `PropertyOperator` via a `when` block covering `EXACT`/`IS_NOT`, `IS_SET`, `ICONTAINS`/`NOT_ICONTAINS`, `REGEX`/`NOT_REGEX`, `GT`/`GTE`/`LT`/`LTE`, `IS_DATE_BEFORE`/`IS_DATE_AFTER`, and the `SEMVER_*` family, ending in `else -> throw InconclusiveMatchException("Unknown operator: $propertyOperator")`. The `PropertyOperator` enum itself (`posthog/src/main/java/com/posthog/internal/PostHogLocalEvaluationModels.kt:120-147`) has **no `STARTS_WITH`/`NOT_STARTS_WITH`/`ENDS_WITH`/`NOT_ENDS_WITH` members at all**, and its `fromString()` factory (lines 150-179) has no `"starts_with"`/`"not_starts_with"`/`"ends_with"`/`"not_ends_with"` string mappings — any such operator value received from a flag definition falls through to `UNKNOWN`. A grep for `starts_with`/`ends_with`/`STARTS_WITH`/`ENDS_WITH` across the entire `posthog-android` monorepo (main and test sources) returns **zero matches** anywhere. Consequence: the "matches locally" acceptance scenario (property present, e.g. `email` starting with `admin@`) is not satisfied — `matchProperty()` unconditionally throws `InconclusiveMatchException` for this operator regardless of whether the value actually matches, so the flag is never resolved `true` locally; it always falls back to remote. The companion "inconclusive when the property is missing" scenario happens to pass, but only as an accidental side effect of the *unrelated* existing containsKey check at `matchProperty()` line 131 (`if (!propertyValues.containsKey(key)) throw InconclusiveMatchException(...)`), which fires before the operator is even dispatched — not because `starts_with`/`ends_with` are recognized and specifically deferred on a missing property. In short: this is a complete absence of the operator family, not a partial implementation — it happens to be spec-compliant on the "missing property" scenario purely incidentally, while failing the "matches" scenario outright, which would be the common/expected case (e.g. bucketing users by verified admin email domains) for any caller relying on this operator today. Per the task's guidance, this is scored as a second, compounding reason for Partial (rather than downgrading to Fail), since local rule matching, rollout hashing, cohort matching, and dependency resolution otherwise all remain correctly implemented and well tested, and unsupported operators correctly defer to remote rather than silently returning a wrong `false`/`true` — i.e. local evaluation degrades safely to a remote round-trip for this operator family instead of corrupting results.
- **Backwards compatibility:** Needs deprecation path for the group-context fix (changing a missing-group-context flag from a hard `false` to inconclusive-then-remote-fallback changes observable behavior — an extra network call and a possibly different resolved value — for any caller currently relying on the fast, local-only `false` answer). Backward-compatible for the starts_with/ends_with fix (adding new enum members, a `fromString()` mapping, and new `matchProperty()` branches is purely additive — today's behavior for these operators is "always defer to remote," and adding local support only ever changes previously-remote-only evaluations to also succeed locally when the prefix/suffix matches, which is expected to agree with the already-remote-computed result since the semantics mirror the server-side flags-service operator).
- **Remediation:** (1) Change the missing-group-context path in `internal/PostHogFeatureFlags.kt` to throw/signal `InconclusiveMatchException` instead of returning a hard `false`, ideally staged given the behavior/latency change. (2) Add `STARTS_WITH`, `NOT_STARTS_WITH`, `ENDS_WITH`, `NOT_ENDS_WITH` to the `PropertyOperator` enum and its `fromString()`/`fromStringOrNull()` mappings in `PostHogLocalEvaluationModels.kt`, and add corresponding branches in `FlagEvaluator.matchProperty()` that stringify both `overrideValue` and `propertyValue`, ASCII-lowercase them (reusing the existing `casefold`-style helper or a simpler `.lowercase()` given these are explicitly ASCII-fold per spec, not full Unicode casefold), and do a `startsWith`/`endsWith` check, negating for the `not_*` variants — mirroring the existing `ICONTAINS`/`NOT_ICONTAINS` pattern (`stringContains()`) exactly.

**Re-assessed 2026-11-02 at `8309f837` — one of the two gaps is closed.** The
`starts_with`/`not_starts_with`/`ends_with`/`not_ends_with` operator family that this note flagged as
absent is now implemented: `FlagEvaluator.kt:186-205` dispatches `PropertyOperator.STARTS_WITH`,
`NOT_STARTS_WITH`, `ENDS_WITH` and `NOT_ENDS_WITH` through `stringStartsWith`/`stringEndsWith`
(`:385-398`). Two gaps remain, one of them new to this note:
- **The pre-existing group-context fallback gap stands.**
- **Experiment holdouts are not implemented.** `grep -rn "holdout" posthog-server/src/main` returns
  nothing, so a flag configured with a holdout is evaluated straight through its release conditions
  and the local answer diverges from the backend. posthog-python is the reference here
  (`feature_flags.py:124-156`, hashing `holdout-<value>` with the service's `-` separator before the
  condition loop).
Backward-compatible either way: both are corrections of answers that already disagree with the
service, not removals of behavior anyone can be relying on. One thing this run could **not** confirm
cheaply is the #89 group-key rendering rule — `hash()` (`FlagEvaluator.kt:72-86`) takes an already-`String`
bucketing value, so whether a non-string group key is canonicalized or host-spelled depends on a
caller this run did not trace. That is a question for the next posthog-java slot, not a separate
Unknown cell.

### n19 — Logs (❌ Fail)
- **Spec requires:** A `captureLog`/logger API producing OTLP-shaped log records shipped via `POST {host}/i/v1/logs`, with severity mapping, batching/rate-capping. (No acceptance `.feature` file exists for this contract, and the spec itself has no explicit client-only carve-out language.)
- **SDK currently (re-confirmed at `8659a7b`):** The capability is still entirely absent from `posthog-server`. `captureLog`/`logger` exist only on the shared core's client-facing `PostHogInterface`/`PostHog` (used by `posthog-android`); `posthog-server`'s own `PostHogInterface.kt`/`PostHog.kt` still declare no such method, re-confirmed by grep for `captureLog`/logger method definitions across all of `posthog-server/` returning zero matches. No change from prior audit.
- **Backwards compatibility:** Backward-compatible — wiring the existing shared-core `PostHogLogsOTLP`/logs transport into a new method on `posthog-server`'s `PostHogInterface`/`PostHog` class is purely additive.
- **Remediation:** Add a `captureLog()` method (or `logger` accessor) to `posthog-server`'s `PostHogInterface.kt`/`PostHog.kt`, wiring the already-implemented shared-core OTLP logs pipeline the same way `posthog-android` already does.

**Re-confirmed 2026-11-02 at `8309f837` — unchanged.** `grep -rn "i/v1/logs\|captureLog"
posthog-server/src/main` still returns zero matches; there is no log-record concept anywhere in the
server module or the shared core it depends on.

### n20 — Set/Reset Person/Group Properties For Flags (❌ Fail, all four contracts)
- **Spec requires:** Each of these four specs' own `## Applicability` line says `client` ("Server SDKs usually take/pass person/group properties directly on each flag-evaluation call instead of maintaining a persistent local override store"). However, all four acceptance feature files are tagged `@both` at the feature level *and on every individual scenario*. Per this audit's precedent, these are treated as in-scope-but-unimplemented rather than N/A.
- **SDK currently (re-confirmed at `8659a7b`):** `grep -rn "PropertiesForFlags"` across `posthog-server/src` (main and test) still returns zero matches for all four. `personProperties`/`groupProperties` exist only as per-call parameters on `getFeatureFlag`/`evaluateFlags`/etc. — architecturally distinct from a *persistent* override store. No change from prior audit.
- **Backwards compatibility:** Backward-compatible — a new opt-in stateful override store (naturally scoped to `PostHogRequestContext`) would be purely additive.
- **Remediation:** Add `setPersonPropertiesForFlags()`/`setGroupPropertiesForFlags()`/`resetPersonPropertiesForFlags()`/`resetGroupPropertiesForFlags()` on `PostHog`/`PostHogInterface`, backed by a `PostHogRequestContext`-scoped (or instance-scoped) override store consulted by `evaluateFlags()`/the deprecated flag getters as a default, overridable by explicit per-call `personProperties`/`groupProperties`.

**Re-confirmed 2026-11-02 at `8309f837` — unchanged.** `grep -rn "PropertiesForFlags|propertiesForFlags"
posthog-server/src/main` still returns zero matches for all four contracts; person and group properties
remain per-call arguments on the flag-evaluation APIs with no persistent local override store.

### n21 — Retry Queue (🟡 Partial)
- **Spec requires:** `both`. In-memory queue with backpressure/drop-when-full; classify retryable (network errors, 5xx, 429) vs. non-retryable (other 4xx) failures; exponential/linear backoff, honoring `Retry-After` where present; retryable failures keep the same events queued for a later, separate flush attempt; success removal by stable identity (not index).
- **SDK currently (re-confirmed at `8659a7b`):** `internal/PostHogMemoryQueue.kt` implements drop-oldest backpressure (`add()`, default `maxQueueSize=10000`), tested. Removal-on-success is identity-safe by construction. Backoff is linear (defaults 5s/60s ceiling). **Gap 1 still present:** HTTP 429 is misclassified as non-retryable — `batchEvents()`'s retry condition is still only `isNetworkingError() || statusCode >= 500`. **Gap 2 still present:** `Retry-After` is parsed by the shared HTTP layer but still never consumed by the server queue's own retry/backoff calculation — `calculateDelay()` still takes no `retryAfterSeconds` parameter; re-confirmed by grep for `retryAfter` across `posthog-server/` returning zero matches. **Gap 3 still present:** no maximum-retry-count cap exists.
- **Backwards compatibility:** Backward-compatible — reclassifying 429 as retryable, honoring `Retry-After` when present, and adding an optional terminal-retry-count cap are all internal behavior refinements with no public signature impact.
- **Remediation:** Add `statusCode == 429` to the retryable branch in `batchEvents()`; thread the parsed `Retry-After` value from `PostHogApiError` into `calculateDelay()`; consider adding an optional max-retry-count ceiling.

**New gap 2026-11-02 — retry backoff is linear and unjittered.** sdk-specs
[#132](https://github.com/PostHog/sdk-specs/pull/132) added "Ingestion retry backoff is jittered"
(SHOULD-tier). `PostHogMemoryQueue.calculateDelay()`
(`posthog-server/src/main/java/com/posthog/server/internal/PostHogMemoryQueue.kt:440-452`) computes
`min(retryDelaySeconds * retryCount, maxRetryDelaySeconds)` — a **linear** progression from 5 s to a
60 s ceiling — and installs it as `pausedUntil` with no randomness: `grep -n "jitter\|Random"` over
that file returns nothing. The spec permits a linear progression (jitter scales whatever the SDK
computed), so the linearity is not itself the finding; the absence of jitter is. No `Retry-After`
handling is visible on this path either, which the spec treats as a floor on the wait. The queue was
otherwise substantially rebuilt this cycle (`flushForShutdown`, `drainUntilDeadline`, a fatal-event
priority path with a bounded 2-second drain) and those additions are improvements, but they land on
Shutdown and Event Batcher rather than on this requirement. Backward-compatible: multiplying the
computed delay by a factor drawn from a window around 1 changes no public surface.

### n22 — Set Person Properties (✅ Pass, via spec's own sanctioned alternative)
- Spec's own `## Applicability` says `client` explicitly, and the acceptance file is `@client`-only. `posthog-server` has no dedicated `setPersonProperties()` method, but correctly expresses the same operation via `identify()`'s `userProperties`/`userPropertiesSetOnce` parameters — exactly the alternative the spec sanctions. No change from prior audit.

### n23 — Setup (✅ Pass, beyond stated scope)
- Spec's own `## Applicability` says `client`, and the acceptance file is `@client`-only — this could reasonably be scored N/A. However, `posthog-server`'s setup path genuinely implements the spec's substantive behaviors: it validates config (rejects a blank API key, never throwing), is `synchronized` against concurrent setup, no-ops with a logged warning on a double-`setup()` call, and tracks duplicate API keys across separate instances via a static `apiKeys` set. Tested. No change from prior audit.

### n24 — Shutdown (🟡 Partial)
- **Spec requires:** `both`. Flush pending events, stop workers permanently, reject/no-op future captures, be idempotent, not crash on delivery failure.
- **SDK currently (re-confirmed at `8659a7b`):** `close()` (`PostHog.kt:33-35` → shared-core `PostHogStateless.close()`, `posthog/src/main/java/com/posthog/PostHogStateless.kt:106-135`) is idempotent by construction, correctly stops the flag poller and clears the feature-flag-called dedup cache, uninstalls integrations defensively, and correctly causes subsequent calls to no-op. **The most significant gap is still present: `close()` still never flushes the queue.** The call chain is still `enabled = false` → `queue?.stop()` → `featureFlags?.shutDown()` → `featureFlagsCalled?.clear()`; `queue?.stop()` (`internal/PostHogMemoryQueue.kt:99-109`) only cancels the interval timer — it does not call `flush()`. Re-confirmed by direct read of the current `close()` method body — no `queue?.flush()` call anywhere in it.
- **Backwards compatibility:** Backward-compatible — adding a `queue?.flush()` call before `queue?.stop()` inside `close()` is additive.
- **Remediation:** Add a `queue?.flush()` call in `PostHogStateless.close()` before `queue?.stop()`, so pending events are drained before the SDK becomes permanently disabled.

### n25 — Tracing Headers (✅ Pass, minor completeness gaps)
- **Spec requires:** `both` applicability. Server-side: request-scoped middleware/context extracting `X-POSTHOG-DISTINCT-ID`/`X-POSTHOG-SESSION-ID` case-insensitively; sanitize (trim/strip control chars/cap length); explicit call-site values win over context; personless-capture fallback only when the caller hasn't explicitly supplied that property; flag-evaluation APIs no-op when no identity is resolvable anywhere; per-request isolation; headers never used for auth.
- **SDK currently:** `PostHogRequestContext.kt` implements this thoroughly and correctly — case-insensitive header extraction, sanitization (trim/strip control chars/cap at 1000 chars), explicit call-site values winning over context, `putIfAbsent`-based personless fallback, no-op flag evaluation on unresolvable identity, genuine `ThreadLocal`-based per-request isolation, and no auth usage of headers. No change from prior audit. Minor, non-blocking gaps unchanged: the deprecated legacy flag getters don't share `evaluateFlags()`'s explicit no-op short-circuit for a blank distinct id; no built-in async/coroutine context-propagation helper (acceptable per spec's "MAY").

### n26 — Traces (❌ Fail, new finding — basis for the previous ➖ withdrawn)
- **Spec requires:** A `startSpan`/`withSpan` API producing OTLP spans shipped to
  `POST {host}/i/v1/traces`, with its own queue, flush triggers and configuration object, and no
  OpenTelemetry runtime dependency.
- **SDK currently:** The 2026-08-10 audit scored this ➖ on the reasoning that the spec "precedes the
  first SDK implementation — no SDK anywhere implements it". **That basis no longer holds:**
  posthog-python has carried a full implementation since 2026-10-12 and posthog-node's was scored ✅
  this run. `posthog-server` has no traces pipeline: no `startSpan`/`withSpan` surface, no span queue,
  and no `/i/v1/traces` transport. Its new `otel/PostHogContextSpanProcessor.kt` is a different thing
  — an `io.opentelemetry.sdk.trace.SpanProcessor` the **application** registers on **its own**
  OpenTelemetry provider, which reads `PostHogRequestContext` and adds `sessionId`/`posthogDistinctId`
  attributes to spans the application is already recording. Its own documentation says it "does not
  export spans or change providers, exporters, or sampling", and it requires the application to supply
  OpenTelemetry SDK 1.32.0+ — the opposite of the spec's "no OpenTelemetry runtime dependency". It
  serves the `tracing-headers` correlation story, not this capability.
- **Backwards compatibility:** Backward-compatible — a traces pipeline is a net-new, additive
  subsystem behind its own opt-in configuration object; nothing existing changes.
- **Remediation:** Implement the capability against `openspec/specs/traces/spec.md`, using
  `packages/core/src/traces/` in the posthog-js monorepo as the worked reference (it is the most
  complete implementation in the matrix and was scored row by row this run). Alternatively, if the JVM
  position is that applications bring their own OpenTelemetry SDK and PostHog only enriches it, that
  is a spec-applicability argument that should be made in `openspec/specs/traces/spec.md` rather than
  left as an unimplemented row — **this is the main item on this page needing a human decision.**

### n27 — Evaluate Flags (🟡 Partial, new row)
- **Spec requires:** A snapshot API evaluating once per request and serving subsequent reads from the
  frozen result: enablement/value/payload accessors, key enumeration, in-memory filtering, lazy and
  deduped `$feature_flag_called`, and **negative-knowledge retention** — remembering that a key was
  absent from both the loaded definitions and a clean remote fallback, in a finite-capacity store
  cleared on each successful refresh, with concurrent probes for the same key coordinated. Since
  [#111](https://github.com/PostHog/sdk-specs/pull/111) the enablement and value accessors SHALL also
  accept an optional per-read `sendFeatureFlagEvents`, while the payload accessor, key enumeration and
  filters SHALL NOT.
- **SDK currently:** The snapshot itself is strong. `PostHogFeatureFlagEvaluations.kt` returns a frozen
  point-in-time result with `isEnabled(key)` (`:74`), `getFlag(key)` (`:90`), a silent `getFlagPayload`
  that explicitly "does not fire any event and does not record the access" (`:105`), typed
  `getFlagPayloadAs<T>()`, `onlyAccessed()` (`:147`), and three `only(...)` overloads including a
  structured `PostHogFeatureFlagFilter` (`:160-184`). `$feature_flag_called` is deduped and carries
  `$feature_flag_error: flag_missing` for unknown keys.

  **And the negative-knowledge requirement — the one six other server SDKs have been recorded as
  failing — is met.** `PostHogFeatureFlags.kt` holds a capacity-bounded `knownMissingFlagKeys`
  (`:49`, sized by `missingFlagKeysMaxSize`), a `missingFlagKeysGeneration` counter (`:52`), and an
  `inFlightMissingFlagProbes` map (`:51`). `invalidateMissingFlagStateLocked()` (`:807-811`) clears the
  store, bumps the generation and releases waiting probes, and it is called from the successful-refresh
  paths (`:524`, `:599`). The evaluation path consults the store before deciding it needs a remote
  probe (`:1115-1122`), and `planMissingFlagProbe`/`completeMissingFlagProbe` (`:1253-1311`) make
  concurrent callers for the same key wait on one in-flight probe with a bounded timeout rather than
  each issuing their own `/flags` request. A response is also matched against the generation it was
  issued under (`:431`), so a refresh landing mid-probe does not install stale negative knowledge.
- **The gap:** none of the accessors take the per-read feature-flag-event option #111 requires.
  `isEnabled(key)` and `getFlag(key)` have single-parameter signatures, so a caller cannot suppress
  `$feature_flag_called` for one snapshot read the way `PostHogFeatureFlagOptions` /
  `PostHogFeatureFlagResultOptions` already allow on the single-flag getters. The payload accessor,
  `keys()` equivalent and `only(...)` filters correctly take no option, which is the other half of the
  requirement. `isEnabled` also takes no caller-supplied default, returning a bare `false` for an
  unknown key.
- **Backwards compatibility:** Backward-compatible — adding an overload that takes an options object
  (the pattern `PostHogFeatureFlagOptions` already establishes on this SDK) is source- and
  binary-additive in Kotlin and Java alike.
- **Remediation:** Add `isEnabled(key, options)` / `getFlag(key, options)` overloads carrying
  `sendFeatureFlagEvents`, resolved against the client-level default and then the SDK default, and
  thread the resolved decision into the existing `recordAccess` so a suppressed read still marks the
  key accessed for `onlyAccessed()` — the requirement is explicit that access and exposure are
  separate. posthog-node's `feature-flag-evaluations.ts:143-167` is the worked reference.

### n28 — Emails (❌ Fail, new row)
- **Spec requires:** "Server SDKs only" — unconditional, unlike the three AI capabilities above it.
  An `emails` surface with `send` and `get`, a secret-key client option, an app-host option with a
  custom-host refusal, the two documented HTTP paths, a reused idempotency key, and the normative
  response → error-name table.
- **SDK currently:** Not implemented. `grep -ril "emails" posthog-server/src/main` returns nothing;
  there is no messaging surface, no secret-key-authenticated app-API client, and no transactional
  template concept anywhere in the server module.
- **Backwards compatibility:** Backward-compatible — a new `emails` property on the client plus a
  secret-key option is purely additive; nothing existing changes meaning. Note the SDK already carries
  a secret-key-shaped credential for local flag evaluation, so the authentication plumbing is partly
  in place.
- **Remediation:** Implement `emails.send`/`emails.get` against `openspec/specs/emails/spec.md`, using
  posthog-node's `packages/node/src/emails/` (459 lines, scored ✅ this run) as the reference for the
  error-name table and the custom-host refusal, which are the two parts most likely to drift.

### n29 — Exception Event Metadata (❌ Fail, new row)
- **Spec requires:** Every `$exception_list` entry carries a `mechanism`; `handled` and `synthetic`
  are serialized **only when known** and MUST NOT be invented; the outermost entry SHALL have
  `mechanism.exception_id` equal to integer `0`; every nested entry SHALL have `mechanism.type` equal
  to `chained` with `mechanism.source` describing the parent edge from the canonical vocabulary
  (`cause`, `context`, `unwrap`, `member`, `suppressed`, `inner`); and the outermost entry SHALL omit
  `source`.
- **SDK currently:** The envelope is built by shared core —
  `posthog/src/main/java/com/posthog/internal/errortracking/ThrowableCoercer.kt` — so this is the same
  defect family [posthog-android.md](posthog-android.md) carries, reached here through
  `api(project(":posthog"))`. Four independent violations:
  1. **`synthetic` is the literal `false` on every entry** (`:212`, `"synthetic" to false` in the
     mechanism map, unconditional). The spec states "A producer MUST NOT default unknown synthetic
     state to `false`" and has a dedicated scenario requiring the key to be *absent* when provenance is
     unknown. For a JVM runtime exception with its own stack the correct value happens to be `false`,
     but the SDK is asserting it rather than knowing it, and it asserts the same `false` for entries
     whose provenance it has not examined.
  2. **`mechanism.source` is never emitted.** The parent edge is smuggled into `type` instead: the
     chain builder sets `mechanismType = "chained"` for causes and `"suppressed"` for suppressed
     exceptions (`:287-316`). The spec requires `type` to be `chained` for *every* nested entry with the
     relationship carried in `source`, so a suppressed exception is currently indistinguishable from a
     cause to any consumer reading `source`, and `type: "suppressed"` is not a value the vocabulary
     defines.
  3. **`exception_id` is omitted entirely on single-entry lists.** `linkChain = items.size > 1`
     (`:320`) passes `exceptionId = null` for a lone exception, and `buildExceptionItem` only writes the
     key when non-null (`:215-217`). The spec is unconditional: "The outermost exception SHALL have
     `mechanism.exception_id` equal to integer `0`", and its own scenario for an entry with no
     relationship metadata expects `exception_id: 0` present with `type`, `handled`, `source`,
     `synthetic` and `parent_id` all omitted. The code's own comment claims parity with "the other
     SDKs" on this point, which the spec text does not support.
  4. **`handled` is resolved once and copied onto every entry** (`:328`, `handled = handled` inside the
     `mapIndexed`), including causes and suppressed entries whose handled state the SDK has not
     determined — the same invent-what-you-don't-know problem as (1).
  One thing posthog-java does **better** than posthog-android here: `$exception_source` is set.
  `PostHogUncaughtExceptionCapture.kt:16,38` writes `$exception_source` from the concrete runtime hook,
  and `PostHogConfig.kt:240` documents the value as `jvm.uncaught_exception_handler`.
- **Backwards compatibility:** **Needs deprecation path** for (1) and (4), **backward-compatible** for
  (2) and (3). Dropping `synthetic` and a copied `handled` from entries where the state is unknown
  removes properties that downstream queries and alerts may filter on today, so the change should ship
  alongside the corrected values and be called out in a release note rather than landed silently.
  Adding `exception_id: 0` to single-entry lists and splitting the relationship out of `type` into
  `source` are additive on the wire — though note the file's own comment that ingestion currently drops
  `exception_id`/`parent_id`, so (3) buys nothing until that server-side change lands and should be
  sequenced after it.
- **Remediation:** In `buildExceptionItem`, write `synthetic` only when the caller supplied a known
  value; write `handled` only on the entry whose capture boundary determined it; always write
  `exception_id`, starting at `0`; and set `type = "chained"` with `source = "cause"` / `"suppressed"`
  for nested entries, leaving `source` off the outermost one. Because this is shared core, the fix
  closes the matching posthog-android row in the same change — coordinate the two rather than patching
  `posthog-server` alone.
