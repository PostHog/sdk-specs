# posthog-android — SDK Compliance

**Repo:** [PostHog/posthog-android](https://github.com/PostHog/posthog-android)
**Audited commit:** `c5e788bd603d3bdda77ac4d213538b9db637299a` ([commit](https://github.com/PostHog/posthog-android/commit/c5e788bd603d3bdda77ac4d213538b9db637299a)) — audited on 2026-10-19. **Five rows (Capture, Capture AI, Event Batcher, HTTP Client, Retry Queue) re-audited on 2026-11-05 against posthog-android 4.0** at `be3ed4b4008e1c0a29028bf5ce1132034583ee8e` ([commit](https://github.com/PostHog/posthog-android/commit/be3ed4b4008e1c0a29028bf5ce1132034583ee8e), head of the 4.0 integration PR [PostHog/posthog-android#871](https://github.com/PostHog/posthog-android/pull/871)) — see [posthog-android 4.0](#posthog-android-40-re-audit-2026-11-05)
**Audited against sdk-specs commit:** `c72e367` (2026-10-19 rows); `dd11a6b` plus the capture v1 text of [#146](https://github.com/PostHog/sdk-specs/pull/146) (`0081ef78`) and [#147](https://github.com/PostHog/sdk-specs/pull/147) (`9c403c23`) for the five 4.0 rows
**Summary:** 35 ✅ · 19 🟡 · 5 ❌ · 5 ➖ · 0 ❓ (64 rows; 2026-10-19 at `c5e788bd` scored 37/16/5/6/0; previous full audit 2026-08-10 at `8659a7b4` scored 31/16/9/3/0 on 59 rows)

**Why the 2026-10-19 run:** rotation priority 3 — the pointer was ten weeks old, and android carries the
mobile reference for Session Replay Debug Properties. It was also the cheapest third slot available:
this run already had the repository cloned to resolve posthog-flutter's Unknown cells, since Flutter
embeds this SDK on Android.

**Scope of the 2026-10-19 run — a targeted re-audit, not a full 64-row re-derivation.** The five contracts missing
from the previous 59-row file were audited from scratch, every previously ❌ or 🟡 row was re-read
against current code at `c5e788bd`, and the rows that merged spec text touches (PRs #103, #108, #110)
were re-checked. Rows that were ✅ at the last audit, whose code is unchanged, and which no merged
spec text affects were **not** independently re-derived; they carry forward. The matrix is also
re-sorted alphabetically this run to match the other per-SDK files, so **note numbers have been
reassigned** — a reference to "posthog-android nX" in an older document may point at a different row.

**Row-count note:** this file previously appended five contracts out of order at the bottom of the
matrix. It is now a single alphabetical 64-row table.

## posthog-android 4.0 re-audit (2026-11-05)

posthog-android 4.0 sends analytics events to capture v1 (`POST /i/v1/analytics/events`) instead of
`/batch`, and adds `captureAi`, which sends AI events to `POST /i/v1/ai/events` on a lane of its own.
The capture v1 specs name android 4.0 directly: [#146](https://github.com/PostHog/sdk-specs/pull/146)
adds the capture v1 requirements to `capture`, `event-batcher`, `http-client` and `retry-queue`, and
[#147](https://github.com/PostHog/sdk-specs/pull/147) adds client SDKs on capture v1 that ship an AI
method, posthog-android 4.0 among them, to `capture-ai`'s Applicability. Both were open when this was
written, so the rows below are scored against their PR text.

**Scope.** Only the five rows these specs change were re-audited, at `be3ed4b4`. Every other row
carries forward from 2026-10-19 at `c5e788bd`. 4.0 also changes rows outside this scope that the next
full audit must re-verify: Get Feature Flag Payload (`getFeatureFlagPayload()` removed; a malformed
payload is now `null`), Get Feature Flag Result, On Feature Flags ([n13](#n13), runtime
`onFeatureFlags()` registration), Setup (`apiKey` removed; a `phx_` key or blank token disables the
SDK with a warning), Before Send Hook (`PostHogEvent.options`), and Remote Config (the `remoteConfig`
option removed).

| Contract | 2026-10-19 | 4.0 | Why |
|---|---|---|---|
| Capture | ✅ | 🟡 | Capture v1 wire, headers, per-event results, options, `$lib` removal, session id lifting, timestamps and fail-open token all conform; after `beforeSend`, the SDK puts back the capture's uuid and, when the hook returns an event with `options == null`, the options it was given ([n24](#n24)) |
| Capture AI | ➖ | 🟡 | Applies now (#147). The AI lane conforms in full; the row inherits Capture's post-hook uuid and options restore ([n25](#n25)) |
| Event Batcher | 🟡 | 🟡 | Capture v1 byte-aware 5 MiB batching and client-permitted 413 halving conform; the periodic flush still runs on `java.util.Timer`, not the injectable clock ([n6](#n6)) |
| HTTP Client | ✅ | 🟡 | Capture v1 transport conforms; a caller-supplied `httpClient` loses its own redirect policy on capture requests ([n26](#n26)) |
| Retry Queue | ✅ | ✅ | Capture v1 status set, 1 s→30 s jittered backoff, `Retry-After` floor, per-event `retry` resends, no OkHttp retries ([n27](#n27)) |

**Behavior the spec permits for client SDKs, recorded so it isn't mistaken for a gap:** a `404` (or
any retryable status) keeps the events on disk with no attempt limit, so a proxy that doesn't serve
`/i/v1/analytics/events` holds them until it does or `maxQueueSize` evicts the oldest. #146's
`retry-queue` text allows exactly this for a durable client queue ("MAY have no attempt limit, so it
reports no event as exhausted"); the SDK prints one warning even with `debug` off. Likewise allowed for
client SDKs and not scored: halving a multi-event batch on `413`, dropping a non-finite property instead
of sending `null`, writing timestamps with exactly three fractional digits, minting a new
`PostHog-Request-Id` after an app restart, and logging dropped and retried events only in debug mode.

## Movement on 2026-10-19

This is the largest net improvement of any SDK in the matrix so far: ✅ rows **31→37** while the row
count grew by five, and ❌ rows **9→5**.

**Six rows cleared (❌/🟡 → ✅):**

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
- **Autocapture ❌→✅** ([n2](#n2)). `$autocapture` now genuinely exists for View and Compose taps,
  with `$event_type: touch`, an allowlisted `$elements`/`$elements_chain`, text inputs excluded, and a
  no-capture tag. It is off by default, which the spec allows (option names and defaults vary by
  platform).
- **Before Send Hook 🟡→✅** ([n3](#n3)). The chain now passes each hook the previous hook's output,
  and a throwing hook drops the event, which is what the spec requires.

**New rows (5):** Capture AI ➖, Evaluate Flags ➖, MCP Analytics ➖ (all `server`-scoped; android
appeared in none of their applicability tables on 2026-10-19 — Capture AI now applies to android 4.0,
see [n25](#n25)), **Exception Event Metadata 🟡** ([n7](#n7)),
**Session Replay Debug Properties 🟡** ([n17](#n17)) — and android turns out to have by far the most
complete implementation of that contract outside the browser.

## Matrix

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Alias | ❌ | [n1] |
| 2 | Application Lifecycle | ✅ |  |
| 3 | Autocapture | ✅ | [n2] |
| 4 | Before Send Hook | ✅ | [n3] |
| 5 | Bootstrap | 🟡 | [n4] |
| 6 | Capture | 🟡 | [n24] |
| 7 | Capture AI | 🟡 | [n25] |
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
| 31 | HTTP Client | 🟡 | [n26] |
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
| 48 | Retry Queue | ✅ | [n27] |
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

### n2 — Autocapture (✅ Pass)
- **Spec requires:** Walk element ancestry on a UI interaction, build a sanitized `$elements` array, emit `$autocapture` with an `$event_type` and screen context; respect no-capture markers; never capture sensitive control values.
- **SDK currently:** **Improved from ❌ Fail — `$autocapture` now genuinely exists.** The previous audit found no generic UI-interaction autocapture at all. `PostHogElementInteractionIntegration` (`posthog-android/src/main/java/com/posthog/android/internal/PostHogElementInteractionIntegration.kt:186`) now captures `$autocapture` for actionable View and Compose taps, carries `$touch_x`/`$touch_y`, and additionally detects and emits `$rageclick` (`:178-182`). A no-capture marker is honoured per subtree via the `com.posthog.android.R.id.posthog_autocapture_no_capture` tag (`internal/InteractionTarget.kt:179`), documented at `PostHogAndroidConfig.kt:77-82`. The payload matches the contract: `$event_type` is `touch` (`internal/InteractionTarget.kt:55`), as `autocapture/spec.md` requires for mobile taps; `$elements` and `$elements_chain` are built from an allowlist of tag name, class, id and `nth-child`/`nth-of-type` only, with the explicit rule "Never add labels, values or arbitrary attributes" (`InteractionTarget.kt:14-60`); and `EditText`, `AbsSeekBar` and `NumberPicker` are not captured as targets (`:146`), so control values never leave the device. The feature is **off by default** — `captureElementInteractions` defaults to `false` (`PostHogAndroidConfig.kt:77`) — but `autocapture/spec.md` says option names and defaults vary by platform and its behaviour applies when autocapture is enabled, so default-off is not a gap. **Re-scored ✅ this run.**
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

### n3 — Before Send Hook (✅ Pass)
- **Spec requires:** multiple registered hooks run in a chain, each receiving the **previous**
  hook's output; if a hook throws, the SDK records a warning, stops the chain, and drops the event
  rather than sending the original or last-good value (`before-send-hook/spec.md:89`).
- **SDK currently:** Multi-hook support is real (`PostHogBeforeSend.kt:8-16`,
  `PostHogConfig.kt:484-516` stores hooks in a lock-guarded `MutableList`). Neither of the two bugs the
  previous audit recorded holds at `c5e788bd`: `buildEvent` (`posthog/src/main/java/com/posthog/PostHogStateless.kt:322-335`)
  calls `beforeSend.run(eventChecked)` and assigns the result back to `eventChecked`, so each hook
  sees the previous hook's mutation; a `null` result drops the event; and `catch (e: Throwable)` logs
  and returns `null`, which stops the chain and drops the event exactly as the spec requires. The previous
  audit's advice to fall back to the last-good value would have broken that rule, which exists so a
  failed privacy filter cannot leak data. **Re-scored ✅ this run.**
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

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
- **4.0 re-audit (2026-11-05, `be3ed4b4`):** still 🟡, on the same gap: `PostHogQueue.start()`
  (`internal/PostHogQueue.kt:623-645`) still schedules the periodic flush with `Timer(true)` (`:626`).
  The capture v1 batching requirement in [#146](https://github.com/PostHog/sdk-specs/pull/146)
  (**Capture v1 batches are byte-aware and server SDKs never shrink them after a 413**) passes.
  `EndpointSpec.batch()` and `EndpointSpec.ai()` set `maxBatchBytes = CAPTURE_V1_MAX_BATCH_BYTES`
  (5 MiB, `internal/EndpointSpec.kt:204`), and `takeFiles()` (`PostHogQueue.kt:331-352`) checks the
  next file's size before adding it. A file that doesn't fit starts the next request, and a file over
  the limit goes alone, in order. The queue also flushes as soon as 5 MiB is queued, before `flushAt`.
  Size is the stored record file's length (UTF-8 bytes of the serialized event, after any
  `encryption`), not a character count. The analytics lane has no per-event size cap. A `413` halves a
  multi-event batch and is terminal for a single event (`deleteFilesIfAPIError`, `:795-821`), which
  #146 allows for client SDKs.
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
  **One real deviation: no tiering and no throttle.** The spec puts everything beyond the four required keys into an optional bundle restricted to SDK events and rate-limited to once per 30 seconds per instance. Android attaches the *entire* set — `$sdk_debug_replay_capture_mode`, `$sdk_debug_replay_throttle_delay_ms`, `$sdk_debug_replay_pending_trigger_conditions`, `$sdk_debug_replay_flush_hold_reason`, `$sdk_debug_session_start`, `$sdk_debug_current_session_duration` — to **every** event with shared props, including custom (non-`$`) events, with no throttle window anywhere. There is no `REQUIRED_REPLAY_PROPERTIES`-equivalent split. That is a per-event payload cost on every customer event, which is the cost the tiering exists to avoid.
  **The previous-process crash case conforms.** `sdkDebugProperties()` returns an empty map when an explicit timestamp predates the current session start (`PostHog.kt:787-791`). `session-replay-debug-properties/spec.md:965-977` says such an event SHALL carry the state persisted at the time if the platform captured one, and otherwise none of these keys, and that this takes precedence over the every-event rule; its scenario "A previous-process crash carries no live debug state" expects exactly that omission. Android persists no crash-time snapshot today, so omitting the keys is the required outcome. Persisting one (as iOS does through `customData`) would be an improvement, not a compliance fix.
- **Backwards compatibility:** Backward-compatible — the fix removes properties from events, which only shrinks payloads; a consumer reading an optional key off a custom event would lose it, so it warrants a changelog note.
- **Remediation:** Introduce the required/optional split — keep the four required keys plus the queue-depth key on every non-`$snapshot` event, and gate the rest behind an SDK-event check and a 30-second per-instance throttle, mirroring `packages/browser/src/posthog-core.ts`'s `REQUIRED_REPLAY_PROPERTIES`. Because `posthog-flutter` and `posthog-react-native` embed this SDK, fixing the tiering here improves all three.

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

### n24 — Capture (🟡 Partial, downgraded from ✅ on capture v1 spec text)
- **Spec requires:** the capture v1 requirements [#146](https://github.com/PostHog/sdk-specs/pull/146)
  adds to `capture/spec.md`: the wire contract, request headers, per-event results, per-event options
  with legacy-property hoisting, the layer order's steps 4 and 5 (which apply to client SDKs too),
  library identity from the header, session/window id lifting, distinct ids, timestamps, per-event
  serialization, and failing open on a missing or personal token. Step 4 says `before_send` "has the
  final say. The SDK SHALL NOT add or re-add any value after the hook", and pipeline step 6 says a
  hook that returns a new message without `options` "sends none … and the SDK does not restore them".
- **SDK currently (4.0, `be3ed4b4`):** conforms on everything except the two post-hook rules.
  - **Wire and headers.** `postCaptureV1` (`posthog/src/main/java/com/posthog/internal/PostHogApi.kt:208-279`)
    POSTs `{"created_at", "batch"}` to `/i/v1/analytics/events` with `Authorization: Bearer`,
    `PostHog-Sdk-Info` (`posthog-android/<version>`, also sent as `User-Agent`), `PostHog-Attempt`,
    `PostHog-Request-Id` (UUID v7) and a fresh `PostHog-Request-Timestamp` on every attempt. There is
    no `api_key`, `sent_at` or `offset`. `nextCaptureV1Identity` (`:281-301`) keeps the request id and
    `created_at` across retries of the same uuid set, in memory, so both reset after an app restart
    (allowed for a durable client queue).
  - **Per-event results.** `captureV1Result` (`:318-381`) resends only `retry` uuids. `drop`,
    `duplicates_dropped`, an unknown verdict and an absent uuid are not resent. A 2xx without a
    readable `results` map is a terminal failure that drops the batch (`:332-338`). The SDK logs one
    aggregate line per batch with counts and `details` tags and no event content, in debug mode only,
    as #146 allows a client SDK without an error handler.
  - **Event shape.** `captureV1Json` (`:881-910`) builds the wire event after `beforeSend` and runs for
    3.x events still on disk too. It removes `$lib`/`$lib_version`, hoists the four legacy option
    properties into options only when the option is missing or `null` (`LEGACY_OPTION_PROPERTIES`,
    `:865`), and omits an empty `options`. `liftStringProperty` (`:918-930`) lifts string
    `$session_id`/`$window_id` to the root, drops `null` silently, and drops any other type with a
    debug log that names the key and JSON type, never the value. `options` is accepted on `capture`,
    `screen`, `identify`, `setPersonProperties`, `alias`, `group` and `captureException`.
  - **Distinct ids, names and tokens.** A blank caller `distinctId` falls back to the current id
    (`PostHog.kt:1340`). There is no local length or placeholder check. An empty event name, including
    one `beforeSend` sets, is dropped locally (`PostHogStateless.kt:472-481`). An empty token or a
    `phx_` key disables the SDK with an always-on warning (`PostHog.kt:323-336`).
  - **Timestamps.** Timestamps are UTC with three fractional digits (`formatISO8601Date`), stamped
    once when the event is created.
  - **Gap, uuid.** `runBeforeSend` (`posthog/src/main/java/com/posthog/PostHogStateless.kt:371-409`)
    re-imposes the capture's uuid on the event the last hook returned (`:402-405`), so a uuid a hook
    sets is replaced. This is deliberate: a hook that returns an event kept from an earlier call would
    otherwise repeat a uuid in a batch.
  - **Gap, options.** When a hook returns a different event whose `options` is `null`, the SDK copies
    in the options the hook was given (`:387-391`). `options` isn't a `PostHogEvent` constructor
    parameter, so `copy()` and the constructor always produce `null`. Android treats `null` as "not
    set" and an empty map as "none". The personless `process_person_profile: false` therefore survives
    a hook that rebuilds the event, where the spec says it is lost.
  - Both choices are documented in the 4.0 migration guide (`docs/migration-3.x-to-4.0.md`, "Event
    options").
- **Backwards compatibility:** Needs deprecation path — 4.0 ships this behavior and documents it, so
  changing it later changes what existing hooks send.
- **Remediation:** Either carve the Kotlin `copy()` case and uuid uniqueness out of the spec's
  post-hook rule, or stop re-adding values after the hook in a later major. The spec carve-out looks
  the better fit, since both choices protect data.

### n25 — Capture AI (🟡 Partial, new applicability)
- **Spec requires:** [#147](https://github.com/PostHog/sdk-specs/pull/147) extends Applicability to
  client SDKs on capture v1 that ship an AI method, posthog-android 4.0 among them, and adds four
  requirements:
  - AI events travel on their own lane to `/i/v1/ai/events`, with no rerouting by name.
  - AI lane configuration is scoped to the AI lane (`captureAiCompression`, `captureAiMaxQueueSize`,
    `captureAiTimeout` and `captureAiMaxEventBytes`; client defaults are 100 events, a 60 s idle
    timeout, 50 MiB on disk and gzip).
  - AI event size: a whole-event measure against 8 MiB + 64 KiB, and byte-aware 5 MiB batches.
  - Built-in AI integrations always use the AI method.

  The AI method uses "the same event-building order as `capture`".
- **SDK currently (4.0, `be3ed4b4`):** every AI-specific requirement conforms.
  - **Method and routing.** `captureAi` (`posthog/src/main/java/com/posthog/PostHog.kt:1182-1206`)
    mirrors `capture`'s parameters and returns the uuid, or `null` when the event isn't queued. It logs
    a debug line for a non-`$ai_` name and sends the event to the AI endpoint anyway. `capture` never
    uses the AI lane.
  - **Separate lane.** `EndpointSpec.ai()` (`internal/EndpointSpec.kt:85-111`) gives the lane its own
    `PostHogQueue`, disk directory, single-thread executor (`PostHogAiQueueThread`), retry state and
    OkHttp client (`aiCaptureClient`, `internal/PostHogApi.kt:122-136`). That client has read/write idle
    timeouts from `captureAiTimeout` and compression from `captureAiCompression`, which defaults to
    gzip. It shares the capture v1 status policy, per-event results and redirect rule with analytics.
    The queue starts at setup (`PostHog.kt:509`), so events left from an earlier launch are sent.
    `flush()` and `close()` signal both lanes (`:2783`, `:770`).
  - **Size.** `queueAiEvent` (`:1214-1231`) measures the serialized event before encryption and drops
    one over `captureAiMaxStoredEventBytes` (`internal/EndpointSpec.kt:260-265`, 8 MiB + 64 KiB, which
    can only be lowered). It logs the name and the limit, never content. A configured value above the
    ceiling is clamped with a log at setup (`PostHog.kt:372-377`). The queue caps at
    `captureAiMaxQueueSize` (default 100) and `AI_MAX_QUEUE_BYTES` (50 MiB) and drops the oldest
    first. Batches use the same 5 MiB byte-aware window as analytics ([n6](#n6)).
  - **Not applicable.** The Full AI capture flag and the built-in-integration requirement bind SDKs
    that ship AI wrapper libraries; posthog-android ships none. The OpenTelemetry context requirement
    binds SDKs with an OTel AI bridge; there is none here. Null-valued property dropping uses the same
    serializer as `capture`, carried forward from 2026-10-19.
  - **Gap.** AI events go through the same `runBeforeSend` as `capture`, so the post-hook uuid and
    options restore recorded in [n24](#n24) apply to this lane too.
- **Backwards compatibility:** Needs deprecation path — same as [n24](#n24).
- **Remediation:** Same as [n24](#n24); nothing AI-specific is missing.

### n26 — HTTP Client (🟡 Partial, downgraded from ✅ on capture v1 spec text)
- **Spec requires:** [#146](https://github.com/PostHog/sdk-specs/pull/146)'s **Capture v1 transport**:
  - Build `{host}/i/v1/analytics/events` (and `/i/v1/ai/events`), send the token only as
    `Authorization: Bearer`, and send the capture v1 headers on every attempt.
  - Compress with a single declared `Content-Encoding` and a per-lane compression setting.
  - Follow only a same-origin `307`/`308`, at most five times, resending the same method, headers and
    body; any other redirect is terminal.
  - "A caller-supplied HTTP client keeps its own redirect policy."
- **SDK currently (4.0, `be3ed4b4`):** conforms except the last point.
  - **Client.** The SDK builds `captureClient` (`posthog/src/main/java/com/posthog/internal/PostHogApi.kt:101-118`)
    with `followRedirects(false)`, `followSslRedirects(false)` and `retryOnConnectionFailure(false)`.
    A network interceptor strips a `503`'s `Retry-After: 0`, so OkHttp never resends on its own.
  - **Redirects.** `postCaptureV1` (`:208-279`) follows a `307`/`308` only when `isConfiguredOrigin`
    (`:397-400`) matches the scheme, host and port of `host`, at most `CAPTURE_V1_MAX_REDIRECTS = 5`
    times, with the same body and headers. Any other 3xx is a terminal `PostHogApiError`.
  - **Headers and compression.** The Bearer header replaces an `Authorization` set in `requestHeaders`
    for capture requests only. Analytics compression follows `compression`, AI compression follows
    `captureAiCompression`. `GzipRequestInterceptor` sets exactly `Content-Encoding: gzip` and sends
    uncompressed when compression fails.
  - The flags retry policy and connection-refused handling recorded on 2026-10-19 are unchanged.
  - **Gap.** When the app passes `PostHogConfig.httpClient`, `captureClient` is built from
    `httpClient.newBuilder()` with `followRedirects(false)`, so the caller's redirect policy is
    replaced by the SDK's same-origin rule on capture requests. Other requests keep it. The SDK is
    stricter than the caller asked, not looser.
- **Backwards compatibility:** Backward-compatible — keeping a caller client's redirect setting is
  additive.
- **Remediation:** Leave `followRedirects` as the caller set it when `httpClient` is supplied, and
  apply the same-origin rule only to the SDK's own client. Alternatively, have the spec allow an SDK to
  enforce its capture redirect rule on a caller client. The SDK's behavior is arguably safer.

### n27 — Retry Queue (✅ Pass, re-audited for capture v1)
- **Spec requires:** [#146](https://github.com/PostHog/sdk-specs/pull/146)'s **Capture v1 status
  classification and attempt budget**. For a durable client queue:
  - Retry exactly `404`, `408`, `429`, `500`, `502`, `503`, `504`, network errors and the `retry`
    entries of a 2xx. Everything else is terminal, with no legacy fallback on `404`.
  - Wait 1 s doubling to 30 s with jitter. `Retry-After` is a floor applied after jitter, capped at
    30 s. No attempt limit is required.
  - A `413` may halve a multi-event batch.
  - The HTTP library's own retries are off.
  - The existing requirements also apply: durable retention independent of retry scheduling, an
    offline pause, acknowledgement by identity, and jittered backoff (#132).
- **SDK currently (4.0, `be3ed4b4`):** conforms.
  - **Status set.** `isCaptureV1RetriableStatusCode` (`posthog/src/main/java/com/posthog/internal/EndpointSpec.kt:201`)
    is exactly that set, and both capture v1 lanes use it. There is no `/batch` fallback.
  - **Backoff.** `calculateDelay` (`internal/PostHogQueue.kt:604-622`) doubles from 1 s to 30 s with a
    ±25% factor (`retryJitter`, `:70`), caps the result again, and applies `Retry-After` (seconds or an
    HTTP date, `parseRetryAfter`, `internal/PostHogApi.kt:534-544`) as a floor after jitter, capped at
    30 s.
  - **Partial retries.** `sendRecords` (`PostHogQueue.kt:472-533`) keeps only the files whose uuid the
    2xx marked `retry`, honors that response's `Retry-After`, and deletes the rest. A retryable status
    or network error keeps the whole window, which is resent first under the same request identity
    (`takeFiles`, `:331-352`). A terminal status drops only that window (`deleteFilesIfAPIError`,
    `:795-821`). OkHttp retries are off on the capture clients ([n26](#n26)).
  - **No attempt limit.** A retryable failure, `404` included, keeps the events until delivery or until
    `maxQueueSize` evicts the oldest. A `404` prints one always-on warning (`PostHogApi.kt:244-257`).
    #146 explicitly allows this for a durable client queue, so it isn't scored as a gap.
- **Backwards compatibility:** No change needed.
- **Remediation:** None.
