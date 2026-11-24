# posthog-android — SDK Compliance

**Repo:** [PostHog/posthog-android](https://github.com/PostHog/posthog-android)
**Audited commit:** release tag `android-v4.0.3` at commit `1577cfa53665670cd7c09a30abf11dc1d10798ad` ([tag](https://github.com/PostHog/posthog-android/releases/tag/android-v4.0.3)) — audited on 2026-11-24. All 70 rows are scored at this tag — see [4.0.3 re-audit](#403-re-audit-2026-11-24). Earlier runs: 2026-10-19 at `c5e788bd`, and 31 rows on 2026-11-10 at the unreleased 4.0 branch head `aaa23d39` ([PostHog/posthog-android#871](https://github.com/PostHog/posthog-android/pull/871))
**Audited against sdk-specs commit:** `44fe27a`
**Summary:** 45 ✅ · 13 🟡 · 1 ❌ · 11 ➖ · 0 ❓ (70 rows; previous 42/16/1/10/0 on 69 rows at `c5e788bd` + `aaa23d39`; 2026-10-19 at `c5e788bd` scored 37/16/5/6/0; previous full audit 2026-08-10 at `8659a7b4` scored 31/16/9/3/0 on 59 rows)

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

## 4.0.3 re-audit (2026-11-24)

The pointer moves to the release tag `android-v4.0.3`. This run closes the split between the 31 rows
scored at `aaa23d39` and the 38 rows carried forward from `c5e788bd`: every row is now scored at
`1577cfa5`.

**Scope.**
- **The 38 carried rows** were re-read at 4.0.3, using `c5e788bd..android-v4.0.3` to find code that moved.
- **The 31 4.0 rows** were re-checked against the 22 non-bump commits in `aaa23d39..android-v4.0.3`.
  The ones that matter here:
  - PostHog/posthog-android#967: person-properties hash.
  - #970: failed flag records.
  - #971: `disableGeoIp`.
  - #992: replay debug keys while replay is off.
  - #995: queue-depth key.
  - #1000: survey activation before flag reads.
  - The surveys default turning `true`.
  - The registered `$process_person_profile` skip on identity events.
- **Every spec commit in `752f899..44fe27a`** that binds a mobile client was checked.
- **Every ❌ and 🟡 row** was re-read.

Two claims were confirmed with throwaway JVM unit tests against the tag:
- Set-like and `Deque` property values serialize as JSON arrays (passes).
- `getFeatureFlags()` returns `null` on a cold start with flags on disk (gap).

| Contract | Before | 4.0.3 | Why |
|---|---|---|---|
| Bootstrap | 🟡 | ✅ | The only gap was `sessionID`, which `bootstrap/spec.md:145` makes a MAY ([n4](#n4)) |
| Get Remote Config Payload | — | ➖ | **new row** (#220): server SDKs only; "A client SDK SHALL NOT expose it" |
| Identify | 🟡 | ✅ | #967 stores the person-properties hash only from the queued event, as #208 requires ([n28](#n28)) |
| Register | 🟡 | ✅ | The only gap was blank keys, which `register/spec.md:42` makes optional ("may reject"); the #146 identity-event rule is implemented ([n16](#n16)) |

android moves from 42/16/1/10 on 69 rows to **45/13/1/11** on 70 rows (61%→64%).

**Spec changes since `752f899` that pass or don't apply here:**
- **Pass:**
  - #215 set and sequence serialization ([n24](#n24)).
  - #211 failed remote flags, #153 the client-level flag event default and #202 missing-flag response ([n8](#n8), [n9](#n9), [n36](#n36)).
  - #181 and #226 surveys ([n22](#n22)).
  - #232 replay debug ([n17](#n17)).
- **Don't apply:**
  - #224 synthesized stacks: android only takes a `Throwable`, so it never synthesizes a stack.
  - #183 consent event: `optIn()` captures none.
  - #214 token environment variable: the token comes from code only.
  - #219 W3C `traceparent`: a MAY for clients.
- **Bind server SDKs or rows that are ➖ here:** #168, #144, #230, #233, #229, #231, the MCP, LLMA and emails changes, and the exception source registrations.

**New gaps found in rows that were already 🟡:**
- **Surveys:** an unknown question type leaks the survey reservation ([n22](#n22)).
- **Session Replay Debug Properties:** the remote-off bit isn't persisted, and a registered or caller `$sdk_debug_pending_queue_size` wins over the SDK's (#238) ([n17](#n17)).
- **Get Feature Flags:** the cold-start `null` is now confirmed by a probe ([n9](#n9)).

## posthog-android 4.0 re-audit (2026-11-05)

posthog-android 4.0 sends analytics events to capture v1 (`POST /i/v1/analytics/events`) instead of
`/batch`, and adds `captureAi`, which sends AI events to `POST /i/v1/ai/events` on a lane of its own.
The capture v1 specs name android 4.0 directly: [#146](https://github.com/PostHog/sdk-specs/pull/146)
adds the capture v1 requirements to `capture`, `event-batcher`, `http-client` and `retry-queue`, and
[#147](https://github.com/PostHog/sdk-specs/pull/147) adds client SDKs on capture v1 that ship an AI
method, posthog-android 4.0 among them, to `capture-ai`'s Applicability. #147 merged into #146's
branch. 4.0 also changes consent handling, remote config, the flag API, session replay and surveys, and
specs merged since 2026-10-19 change those rows (#81, #102, #109, #111, #115, #121, #123, #124, #135, #138,
#155, #160, #161, #162, #167, #170, #193, #197, #198, #199, #203).

**Scope.** 31 rows are scored at `aaa23d39` against `main` at `752f899` plus #146's text at `d387ab79`,
treated as merged to `main`: the five capture v1 rows, the 25 rows those other changes touch, and Alias, whose code changed in
PostHog/posthog-android#819. The other 33 rows carry forward from 2026-10-19 at `c5e788bd`, scored against `c72e367`.
The five contracts `main` added since then (Experiment Exposure, AI Datasets, AI Scorers, Offline
Evaluations and Emails) are new rows, all ➖: android 4.0 requests `/flags?v=2`, and the other four
are server-only. The spec changes
merged since then that this page doesn't score bind server SDKs, posthog-js, another platform, or
contracts that are ➖ here (#205, #178, #185, #116, #129, #94, #88, #130, #85, #169, #171, and the MCP
analytics, AI evaluation and emails changes). One carried-forward row is stale: **Stop Session
Recording** ([n21](#n21)) still cites the opt-out asymmetry that 4.0's `optOut()` removes by uninstalling
replay, so the next full audit must re-verify it.

| Contract | 2026-10-19 | 4.0 | Why |
|---|---|---|---|
| Alias | ❌ | ✅ | `$create_alias` carries the source id as `properties.distinct_id` too (PostHog/posthog-android#819) ([n1](#n1)) |
| Application Lifecycle | ✅ | ✅ | Installed, Updated, Opened and Backgrounded carry the required properties; un-prefixed `version`/`build` break only a SHOULD NOT ([n31](#n31)) |
| Before Send Hook | ✅ | ✅ | Chain, drop and fail-closed unchanged; `options` and the uuid survive a hook as capture allows ([n3](#n3)) |
| Capture | ✅ | ✅ | Capture v1 wire, headers, per-event results, options, the `$lib`/`$lib_version` pair fill, session id lifting, timestamps and fail-open token all conform; the identity-call migration-guide example (#146 at `15501ca`) lands in 4.0 with PostHog/posthog-android#966 ([n24](#n24)) |
| Capture AI | ➖ | ✅ | Applies now (#147). The AI lane conforms in full, including its own compression setting ([n25](#n25)) |
| Capture Exception | ✅ | ✅ | Handled and uncaught JVM exceptions share one coercer; the native crash serializer keeps frames and drops only unset fields (#124) ([n40](#n40)) |
| Consent Gating | 🟡 | ✅ | Capture is gated, `optOut()` stops replay and integrations, and deferred native crashes follow consent at crash time ([n5](#n5)) |
| Event Batcher | 🟡 | 🟡 | Capture v1 byte-aware 5 MiB batching and client-permitted 413 halving conform; the periodic flush still runs on `java.util.Timer`, not the injectable clock ([n6](#n6)) |
| Exception Event Metadata | 🟡 | 🟡 | Nested `handled`, `suppressed` mechanism type with no `source`, no single-entry `exception_id`, no `$exception_source`, caller override of reserved keys, missing empty `value` ([n7](#n7)) |
| Feature Flag Cache | ✅ | ✅ | A malformed cached payload reads as `null` (#170) ([n33](#n33)) |
| Feature Flag Called Tracker | 🟡 | 🟡 | Dedupe conforms; the minimal-event allowlist drops `$os_name`/`$os_version` and registered attribution keys. Config version 2 (#162, #203) doesn't apply on `/flags?v=2` ([n8](#n8)) |
| Get Feature Flag | ✅ | ✅ | Matches the 4.0 android variant without `defaultValue` ([n39](#n39)) |
| Get Feature Flag Payload | ✅ | ✅ | The getter is gone, as #170 allows; payloads read through `getFeatureFlagResult` ([n38](#n38)) |
| Get Feature Flag Result | ✅ | ✅ | `""` reads as disabled (#193); a malformed payload is `null` without touching the flag ([n36](#n36)) |
| Get Feature Flags | ❌ | 🟡 | `getAllFeatureFlags()` is the spec's android variant now, but returns `null` after a restart until the disk cache is loaded ([n9](#n9)) |
| Get Feature Flags And Payloads | ❌ | 🟡 | The spec records `getAllFeatureFlags()` as android's form; same cold-start gap ([n10](#n10)) |
| HTTP Client | ✅ | ✅ | Capture v1 transport conforms; `compression` turns off analytics compression and leaves `captureAiCompression` alone, as #146 allows; applying the same-origin redirect rule to a caller-supplied `httpClient` is one of the two choices #146 allows ([n26](#n26)) |
| Identify | ✅ | 🟡 | Runs while opted out (#167), but updates the dedup hash for a `$set` it dropped ([n28](#n28)) |
| Is Feature Enabled | ✅ | ✅ | Caller default, known value wins, `""` reads as `false` ([n37](#n37)) |
| Logs | ✅ | ✅ | `compression = NONE` sends raw JSON with no `Content-Encoding` (#81) ([n35](#n35)) |
| On Feature Flags | 🟡 | ✅ | Runtime `onFeatureFlags()` with unsubscribe, late replay and stale-load suppression (#161) ([n13](#n13)) |
| Opt In | 🟡 | 🟡 | Replay restart and crash-time consent (#138, #199) conform; `optOut()` still can't clear local data ([n14](#n14)) |
| Reload Feature Flags | ✅ | ✅ | Callback gets `PostHogFeatureFlagsLoaded`, the android variant ([n34](#n34)) |
| Remote Config | ✅ | ✅ | Request, asset host and cache fallback conform; replies after `close()` or from an earlier setup are dropped ([n32](#n32)) |
| Retry Queue | ✅ | ✅ | Capture v1 status set, 1 s→30 s jittered backoff, `Retry-After` floor, per-event `retry` resends, no OkHttp retries ([n27](#n27)) |
| Session Replay Debug Properties | 🟡 | ✅ → 🟡 | Required keys on every event; the optional bundle only on `$` events, at most once per 30 s. Scored ✅ here, then 🟡 after the 2026-11-18 spec change (#232) added the off-state shape ([n17](#n17)) |
| Session Replay Privacy | 🟡 | ✅ | Wireframe mode is gone (#197), View and Compose unmask agree, and `FLAG_SECURE` windows record black (#160) ([n19](#n19)) |
| Setup | ✅ | ✅ | `projectToken` only; a blank or `phx_` token disables the SDK with a warning ([n29](#n29)) |
| Shutdown | ✅ | ✅ | `close()` flushes, stops queues and integrations, and can be called twice ([n30](#n30)) |
| Start Session Recording | ❌ | ✅ | Replay isn't installed while opted out, so a start stays inactive ([n20](#n20)) |
| Surveys | 🟡 | 🟡 | Web-only exclusion and popup delay conform; submit and dismiss move the last-seen date (#102), and an unknown question type blocks later surveys ([n22](#n22)) |

android moved from 37/16/5/6 on 2026-10-19 to 43/15/1/10 on 69 rows (58%→62%) with this table. The
2026-11-18 Session Replay Debug Properties regression made it **42/16/1/10** (61%), the count the
[4.0.3 re-audit](#403-re-audit-2026-11-24) starts from.

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
| 1 | AI Datasets | ➖ | **new row**: server SDKs only (personal API key); no android surface |
| 2 | AI Scorers | ➖ | **new row**: server SDKs only (personal API key); no android surface |
| 3 | Alias | ✅ | [n1] |
| 4 | Application Lifecycle | ✅ | [n31] |
| 5 | Autocapture | ✅ | [n2] |
| 6 | Before Send Hook | ✅ | [n3] |
| 7 | Bootstrap | ✅ | [n4] |
| 8 | Capture | ✅ | [n24] |
| 9 | Capture AI | ✅ | [n25] |
| 10 | Capture Exception | ✅ | [n40] |
| 11 | Consent Gating | ✅ | [n5] |
| 12 | Create Person Profile | ➖ |  |
| 13 | Debug | ✅ |  |
| 14 | Device ID Generator | ✅ |  |
| 15 | Emails | ➖ | **new row**: server SDKs only; needs a secret key that must never reach a client |
| 16 | Evaluate Flags | ➖ |  |
| 17 | Event Batcher | 🟡 | [n6] |
| 18 | Exception Event Metadata | 🟡 | [n7] |
| 19 | Exception Steps | ✅ |  |
| 20 | Experiment Exposure | ➖ | **new row**: applies to SDKs that read `/flags?v=4` records; android 4.0.3 requests `v=2` (`posthog/src/main/java/com/posthog/internal/PostHogApi.kt:600`), so config-version-2 flags read as legacy values |
| 21 | Feature Flag Cache | ✅ | [n33] |
| 22 | Feature Flag Called Tracker | 🟡 | [n8] |
| 23 | Flag Definition Loader | ➖ |  |
| 24 | Flush | ✅ |  |
| 25 | Get Anonymous ID | ✅ |  |
| 26 | Get Distinct ID | ✅ |  |
| 27 | Get Feature Flag | ✅ | [n39] |
| 28 | Get Feature Flag Payload | ✅ | [n38] |
| 29 | Get Feature Flag Result | ✅ | [n36] |
| 30 | Get Feature Flags | 🟡 | [n9] |
| 31 | Get Feature Flags And Payloads | 🟡 | [n10] |
| 32 | Get Remote Config Payload | ➖ | **new row**: server SDKs only (#220, "A client SDK SHALL NOT expose it"); `PostHogApi.flagRemoteConfigPayload` is `@PostHogInternal` and only posthog-server calls it |
| 33 | Get Session ID | ✅ |  |
| 34 | Group | 🟡 | [n11] |
| 35 | Group Identify | 🟡 | [n12] |
| 36 | HTTP Client | ✅ | [n26] |
| 37 | Identify | ✅ | [n28] |
| 38 | Is Feature Enabled | ✅ | [n37] |
| 39 | Is Opt Out | ✅ |  |
| 40 | Is Session Replay Active | ✅ |  |
| 41 | Local Feature Flag Evaluator | ➖ |  |
| 42 | Logs | ✅ | [n35] |
| 43 | MCP Analytics | ➖ |  |
| 44 | Offline Evaluations | ➖ | **new row**: server SDKs only; no android surface |
| 45 | On Feature Flags | ✅ | [n13] |
| 46 | Opt In | 🟡 | [n14] |
| 47 | Persistent Storage | 🟡 | [n15] |
| 48 | Register | ✅ | [n16] |
| 49 | Reload Feature Flags | ✅ | [n34] |
| 50 | Remote Config | ✅ | [n32] |
| 51 | Reset | ✅ |  |
| 52 | Reset Group Properties For Flags | ✅ |  |
| 53 | Reset Person Properties For Flags | ✅ |  |
| 54 | Retry Queue | ✅ | [n27] |
| 55 | Screen | ✅ |  |
| 56 | Session Manager | ✅ |  |
| 57 | Session Replay Debug Properties | 🟡 | [n17]; #992 cleared the main off-state gap; remote-off persistence, the wrapper bridge and #238 queue-depth precedence remain |
| 58 | Session Replay Ingestion Controls | 🟡 | [n18] |
| 59 | Session Replay Privacy | ✅ | [n19] |
| 60 | Set Group Properties For Flags | ✅ |  |
| 61 | Set Person Properties | ✅ |  |
| 62 | Set Person Properties For Flags | ✅ |  |
| 63 | Setup | ✅ | [n29] |
| 64 | Shutdown | ✅ | [n30] |
| 65 | Start Session Recording | ✅ | [n20] |
| 66 | Stop Session Recording | 🟡 | [n21] |
| 67 | Surveys | 🟡 | [n22] |
| 68 | Traces | ❌ | [n23] |
| 69 | Tracing Headers | ✅ |  |
| 70 | Unregister | ✅ |  |

## Notes

Note numbers were reassigned this run when the matrix was re-sorted alphabetically. Notes carried
forward from the 2026-08-10 audit keep their original analysis, re-checked for existence at
`c5e788bd`; notes [n2](#n2), [n7](#n7), and [n17](#n17) are new or rewritten this run. A reference
to "posthog-android nX" in a document written before 2026-10-19 refers to the old numbering.
Every row is scored at `android-v4.0.3` (`1577cfa5`) as of 2026-11-24. Notes for rows that changed or
gained findings that run carry a **4.0.3** paragraph, and their line references point at the tag.
The other ✅ notes keep the `aaa23d39` or `c5e788bd` lines they were written against: their code was
re-read at 4.0.3 and still conforms, but their line numbers were not re-pointed.

<a id="n1"></a>

### n1 — Alias (✅ Pass, re-audited at 4.0)
- **Spec requires:** `acceptance/public/alias.feature` (`@client` scenario) requires the enqueued
  `$create_alias` event to carry the current distinct id as its `distinct_id` and both `alias` and
  `distinct_id` in its properties. `alias/spec.md` drops the call when `personProfiles` is `never` and
  turns person processing on otherwise.
- **SDK currently (4.0, `aaa23d39`):** conforms. `alias(alias, options)`
  (`posthog/src/main/java/com/posthog/PostHog.kt:2112-2141`) returns when the SDK is disabled or
  `personProfiles` is `NEVER` (`requirePersonProcessing`, `:2479-2491`, which also turns person
  processing on), resolves the current distinct id once, sets `props["alias"]` and
  `props["distinct_id"]` to it, and passes the same id to `capture` as the event's `distinct_id`, so
  the two can't diverge. PostHog/posthog-android#819 (merged 2026-10-22, in `aaa23d39`) added the
  property. At `c5e788bd` it was missing, which is why this row was ❌ on 2026-10-19.
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n2"></a>

### n2 — Autocapture (✅ Pass)
- **Spec requires:** Walk element ancestry on a UI interaction, build a sanitized `$elements` array, emit `$autocapture` with an `$event_type` and screen context; respect no-capture markers; never capture sensitive control values.
- **SDK currently:** **Improved from ❌ Fail — `$autocapture` now genuinely exists.** The previous audit found no generic UI-interaction autocapture at all. `PostHogElementInteractionIntegration` (`posthog-android/src/main/java/com/posthog/android/internal/PostHogElementInteractionIntegration.kt:186`) now captures `$autocapture` for actionable View and Compose taps, carries `$touch_x`/`$touch_y`, and additionally detects and emits `$rageclick` (`:178-182`). A no-capture marker is honoured per subtree via the `com.posthog.android.R.id.posthog_autocapture_no_capture` tag (`internal/InteractionTarget.kt:179`), documented at `PostHogAndroidConfig.kt:77-82`. The payload matches the contract: `$event_type` is `touch` (`internal/InteractionTarget.kt:55`), as `autocapture/spec.md` requires for mobile taps; `$elements` and `$elements_chain` are built from an allowlist of tag name, class, id and `nth-child`/`nth-of-type` only, with the explicit rule "Never add labels, values or arbitrary attributes" (`InteractionTarget.kt:14-60`); and `EditText`, `AbsSeekBar` and `NumberPicker` are not captured as targets (`:146`), so control values never leave the device. The feature is **off by default** — `captureElementInteractions` defaults to `false` (`PostHogAndroidConfig.kt:77`) — but `autocapture/spec.md` says option names and defaults vary by platform and its behaviour applies when autocapture is enabled, so default-off is not a gap. **Re-scored ✅ this run.**
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n3"></a>

### n3 — Before Send Hook (✅ Pass)
- **Spec requires:** hooks run in order, each getting the previous hook's output. `null` drops the event. A
  throwing hook logs a warning, stops the chain and drops the event rather than sending the original or
  last-good value (`before-send-hook/spec.md:89`).
- **SDK currently (4.0, `aaa23d39`):** conforms. `runBeforeSend`
  (`posthog/src/main/java/com/posthog/PostHogStateless.kt:371-408`) passes each hook a copy of the previous
  result (`copyForHooks`, `:411-416`), and returns `null` on a `null` result or a throw, logging only the
  exception type (`:393-396`). Hooks sit in a lock-guarded list (`PostHogConfig.kt:565-600`). 4.0 adds
  `PostHogEvent.options` (`PostHogEvent.kt:54`); a hook that returns a new event with `null` options keeps
  the pre-hook options (`:387-391`), and the SDK re-imposes its uuid (`:400-405`), the two allowances
  capture's step 4 grants ([n24](#n24)).
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n4"></a>

### n4 — Bootstrap (✅ Pass; was 🟡)
- **Spec requires:**
  - Identity seeding that never overwrites persisted identity, plus reconciliation of a differing
    identified bootstrap.
  - Bootstrapped flags and payloads served before the first `/flags`, and replaced by a complete
    response.
  - `$feature_flag_bootstrapped_response`/`_payload` and `$used_bootstrap_value` on
    `$feature_flag_called`.
  - The flags-loaded callback fired at setup (`bootstrap/spec.md:7-215`).
  - Session bootstrap is optional: "A client SDK that owns a session id MAY accept a `sessionID`"
    (`:145`).
- **SDK currently (4.0.3, `1577cfa5`):** conforms. The MUSTs were spot-checked at the tag:
  - **Identity.** `applyBootstrapIfNeeded` (`posthog/src/main/java/com/posthog/PostHog.kt:683-719`)
    seeds identity on a fresh install only. `reconcileBootstrapIdentityIfNeeded` (`:726-759`)
    upgrades a matching anonymous id or identifies a differing one.
  - **Listener.** Bootstrapped flags notify the listeners at setup without a network round trip
    (`:508-510`).
  - **Flag-called enrichment.** `$feature_flag_called` carries the bootstrap fields (`:2849-2854`).
    `flagsLoadedFromRemote` is set by any successful response and cleared on reset
    (`internal/PostHogRemoteConfig.kt:1722-1727`, `:1840`).
  - **Complete response.** It replaces served flags (`:1015-1018`).
  - **Not implemented (MAY).** `PostHogBootstrapConfig` has no `sessionID`
    (`PostHogBootstrapConfig.kt:35-58`).
- **Why the change:** the 2026-10-19 note already called the missing `sessionID` "a spec-permitted
  omission, not a strict violation", so 🟡 contradicted its own evidence.
- **Backwards compatibility:** No change needed.
- **Remediation:** None. Optionally add `sessionID` for parity with SDKs that implement it.

<a id="n5"></a>

### n5 — Consent Gating (✅ Pass; was 🟡)
- **Spec requires:** capture is blocked while opted out (no enqueue, no capture request) and allowed while
  opted in, and a persisted opt-out applies before early capture calls (`consent-gating/spec.md:84-117`).
  Replay "may be stopped, skipped, or restarted" based on consent (`:79`), which is not a MUST. Deferred
  crash reports follow the `opt-in` rule (`:77`).
- **SDK currently (4.0, `aaa23d39`):** conforms.
  - **Capture.** Every event goes through `prepareEvent`, which returns early while opted out
    (`posthog/src/main/java/com/posthog/PostHog.kt:1354-1357`). `isOptedOut()` reads the persisted
    `OPT_OUT` before the first capture (`:1936-1954`).
  - **Replay and integrations.** `optOut()` uninstalls integrations, and `uninstallIntegrations()` calls
    `stopSessionReplay()` and clears the replay handler (`:632-648`, `:2031-2033`). A launch that starts
    opted out installs neither (`:537-543`), and a remote config reply doesn't re-arm them (`:580`).
  - **Deferred native crashes** follow the consent state at crash time ([n14](#n14)).
  - Flag and remote config requests still go out while opted out, which `opt-in` allows (`opt-in/spec.md:90`).
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n6"></a>

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
- **4.0 re-audit (2026-11-05, `be3ed4b4`; unchanged at `aaa23d39`):** still 🟡, on the same gap: `PostHogQueue.start()`
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
- **4.0.3 (`1577cfa5`):** still 🟡, on the same gap: `start()` builds `Timer(true)`
  (`posthog/src/main/java/com/posthog/internal/PostHogQueue.kt:630`). Retried uuids are now kept once
  each (`:488-493`), which doesn't affect this row.
  - **Caveat.** The gap is about the test mechanism only. The "Batcher flushes when interval
    elapses" scenario (`event-batcher/spec.md:112-122`) is satisfied in real time; it fails only when
    a harness advances a fake clock. The next audit should run it through
    `sdk_compliance_adapter` before keeping 🟡.
- **Backwards compatibility:** Backward-compatible — swap to a `dateProvider`-driven scheduled
  executor internally; no public API change, default real-time behavior unchanged.
- **Remediation:** Route the periodic-flush timer through `config.dateProvider` for testability.

<a id="n7"></a>

### n7 — Exception Event Metadata (🟡 Partial)
- **Spec requires:** `both` (`exception-event-metadata/spec.md:11`). Every entry has a non-empty `type` and a
  string `value`, which may be empty (`:24`). Every entry's mechanism carries `exception_id`, `0` on the
  outermost entry (`:26`, `:219`). A nested entry omits `handled` unless known for that entry (`:150`), and
  uses `mechanism.type` `chained` with `mechanism.source` `cause` or `suppressed` (`:91`, `:215-219`).
  `$exception_source` comes from the capture boundary, `android.uncaught_exception_handler` for Android's
  uncaught handler (`:93-124`). Application property bags MUST NOT override `$exception_list`,
  `$exception_level` or `$exception_source` (`:314`, `:330-334`). #123's trace context binds server SDKs
  only (`:433`, `:454`).
- **SDK currently (4.0, `aaa23d39`):** in `posthog/src/main/java/com/posthog/internal/errortracking/ThrowableCoercer.kt`,
  boundary defaults, `chained` cause entries with `parent_id`, the 50-entry cap and the cycle guard
  conform (`:257-259`, `:285-294`, `:372-389`), and `synthetic: false` (`:212`) is correct for a real JVM
  `Throwable` with its own stack (`:186-196`). Gaps:
  1. Nested entries copy the outermost `handled` (`:211`, `:326`).
  2. Suppressed entries use `mechanism.type` `suppressed` (`:309`), and no entry has `mechanism.source`.
  3. A single-entry list has no `exception_id` (`:316-318`), nor does the native crash mechanism
     (`posthog-android/src/main/java/com/posthog/android/internal/errortracking/NativeCrashEventCoercer.kt:69-74`).
  4. No Android path sets `$exception_source`, including the uncaught handler
     (`posthog/src/main/java/com/posthog/errortracking/PostHogErrorTrackingAutoCaptureIntegration.kt:118-121`) and native crashes.
  5. `captureException` merges caller properties over the generated ones (`posthog/src/main/java/com/posthog/PostHog.kt:1726-1728`), and
     `PostHogStateless.kt:851-852` documents that callers can override `$exception_level`.
  6. `value` is left out when the throwable has no message (`ThrowableCoercer.kt:229-233`).
- **4.0.3 (`1577cfa5`):** unchanged. `ThrowableCoercer.kt` hasn't changed since `aaa23d39`, so gaps 1-4
  and 6 sit at the same lines (`:211`, `:309`, `:229-233`). No file in either module sets
  `$exception_source`. The spec changes since `752f899` only register Rails, .NET and Sidekiq capture
  sources (#196, #209, #218), which don't bind android.
- **Backwards compatibility:** Gaps 1-4 and 6 are backward-compatible (each omits or adds a field, and
  `source` keeps the suppressed relationship). Gap 5 needs a deprecation path: ship a typed `level`
  override before the property map stops winning.
- **Remediation:** Omit `handled` on nested entries; emit `type: chained` with `source: cause`/`suppressed`;
  always set `exception_id` (`0` outermost), including native crashes; set `$exception_source` at each
  boundary; always emit `value`; add a typed `level` override, then stop the property map replacing
  reserved keys.

<a id="n8"></a>

### n8 — Feature Flag Called Tracker (🟡 Partial)
- **Spec requires:**
  - **Dedupe.** A repeated read of the same value is suppressed, a changed value is tracked again, and the
    tracker clears on reset and close (`feature-flag-called-tracker/spec.md:61-62`, `:89-196`).
  - **Minimal event mode.** When gated on, the allowlist SHALL cover the static platform identity
    properties the SDK attaches to every event and the session-attribution properties registered as super
    properties (`:205-215`). The `@client` scenario at `:280-298` registers `$referring_domain` and
    `utm_source` and expects both to survive.
  - **Config version 2** attribution and dedupe (#162, `:348-536`) and #203's `$feature_flag_variant_key`
    apply only to config version 2 records the SDK reads.
- **SDK currently (4.0, `aaa23d39`):**
  - **Dedupe conforms.** `sendFeatureFlagCalled` (`posthog/src/main/java/com/posthog/PostHog.kt:2700-2760`)
    keys by flag with a list of seen values (`:211`, `:2715-2722`) and clears on `reset()` (`:2919`) and
    `close()` (`:783`).
  - **Allowlist gap.** `MINIMAL_FEATURE_FLAG_CALLED_PROPERTIES` (`PostHogStateless.kt:929-951`) leaves out
    `$os_name`/`$os_version`, which android adds to every event
    (`posthog-android/src/main/java/com/posthog/android/internal/PostHogAndroidContext.kt:80-81`), and
    `$referring_domain` and the UTM and click-id keys, so the `:280-298` scenario fails.
  - **Config version 2 doesn't apply.** Android requests `/flags/?v=2` (`internal/PostHogApi.kt:598`) and
    `FeatureFlagMetadata` has no config version, rule or variant-key fields, so it sends neither the new
    attribution nor `$experiment_exposure`. `experiment-exposure/spec.md:11` treats such flags as legacy.
  - **Not scored (SHOULD).** The tracker isn't cleared after a flags reload, and the map is unbounded.
- **4.0.3 (`1577cfa5`):** still 🟡 on the allowlist. `MINIMAL_FEATURE_FLAG_CALLED_PROPERTIES`
  (`posthog/src/main/java/com/posthog/PostHogStateless.kt:939-962`) gained `$geoip_disable` but still
  leaves out `$os_name`/`$os_version` and the attribution keys. The spec changes since `752f899` pass:
  - **Client-level event default** (#153). Each read resolves the per-call value, then
    `config.sendFeatureFlagEvent`, and a suppressed read never touches the dedupe map
    (`PostHog.kt:2800-2817`).
  - **Missing flag reports no value** (#202). `$feature_flag_response` is omitted when the read has
    no value (`:2829-2830`).
  - **Failed direct reads report `evaluation_failed`** (#211, PostHog/posthog-android#970).
    `$feature_flag_error` comes from `getFlagError` (`:2831`, `internal/PostHogRemoteConfig.kt:1578-1587`).
    It adds `evaluation_failed` only for a failed key with no served value, and
    `errors_while_computing_flags` as a response-level error. A failed read has no value, so its
    response is omitted.
  - #168's local-evaluation attribution binds server SDKs.
- **Backwards compatibility:** Backward-compatible. Minimized events gain a few static or attribution keys.
- **Remediation:** Add `$os_name`, `$os_version`, `$referring_domain`, `utm_source`, `utm_medium`,
  `utm_campaign`, `utm_content`, `utm_term`, `gad_source`, `mc_cid`, `gclid` and `fbclid` to the allowlist.

<a id="n9"></a>

### n9 — Get Feature Flags (🟡 Partial; was ❌)
- **Spec requires:** the android 4.0 variant is `getAllFeatureFlags()`: a list of flag results, or `null`
  when flags are unavailable; each entry matches `getFeatureFlagResult` for that key, so `""` reads as
  disabled (#193); no `$feature_flag_called` (`get-feature-flags/spec.md:59`, `:165-184`). **Canonical
  get-feature-flags behavior** (`:117-163`) returns the cached flags.
- **SDK currently (4.0, `aaa23d39`):**
  - **Conforms.** `getAllFeatureFlags()` (`posthog/src/main/java/com/posthog/PostHogInterface.kt:283`,
    `PostHog.kt:2776-2785`) builds each entry with `getFeatureFlagResult`, so `""` is listed with
    `enabled = false`, and sends no event.
  - **Gap.** It reads the key set from `PostHogRemoteConfig.getFeatureFlags()`
    (`internal/PostHogRemoteConfig.kt:1391-1402`), which never calls `loadFeatureFlagsFromCacheIfNeeded()`,
    unlike `getFeatureFlagResult` (`:1338`). After a restart, until the first load finishes or a
    single-flag read hydrates the disk cache, it returns `null` while `getFeatureFlagResult(key)` returns the
    cached value.
- **4.0.3 (`1577cfa5`):** still 🟡.
  - **Gap confirmed at runtime.** `getAllFeatureFlags()` (`posthog/src/main/java/com/posthog/PostHog.kt:2876-2885`)
    reads keys from `PostHogRemoteConfig.getFeatureFlags()` (`internal/PostHogRemoteConfig.kt:1420-1431`),
    which still skips `loadFeatureFlagsFromCacheIfNeeded()`; `getFeatureFlagResult` calls it (`:1367`).
    A unit test against the tag, with `featureFlags = {beta: true}` in cache preferences, printed
    `before=null single=true after={beta=true}`: one single-flag read is what loads the disk cache.
  - **Probable side effect (not verified).** `buildProperties` stamps `$feature/*` and
    `$active_feature_flags` from the same getter (`PostHog.kt:919`), so events captured before the
    first `/flags` reply probably carry no flag properties. A full-SDK cold start wasn't tested.
  - **Failed remote flags conform** (#211, PostHog/posthog-android#970; `get-feature-flags/spec.md`
    **Bulk flag values exclude failed remote decisions**):
    - Failed records never reach `featureFlags` (`internal/PostHogRemoteConfig.kt:1329`, `:985`).
    - A complete response replaces served flags (`:1015-1018`), so a failed key isn't kept.
    - An errored response merges and keeps earlier values (`:972-998`).
    - A cache load drops failed keys (`:1262`).
- **Backwards compatibility:** Backward-compatible. A caller that saw `null` gets the cached list.
- **Remediation:** Call `loadFeatureFlagsFromCacheIfNeeded()` in `getFeatureFlags()`, and in
  `getActiveFeatureFlagKeys()`.

<a id="n10"></a>

### n10 — Get Feature Flags And Payloads (🟡 Partial; was ❌)
- **Spec requires:** android 4.0 returns per-flag results that carry the payload from `getAllFeatureFlags()`
  instead of a paired API (`get-feature-flags-and-payloads/spec.md:55`). Values and payloads come from the
  cache (`:113-146`), and each payload decodes on its own, so a malformed one never drops the flag or its
  siblings (`:148-209`).
- **SDK currently (4.0, `aaa23d39`):** each entry of `getAllFeatureFlags()` (`posthog/src/main/java/com/posthog/PostHog.kt:2776-2785`)
  comes from `getFeatureFlagResult`, with its payload from `decodePayload`
  (`internal/PostHogRemoteConfig.kt:1280-1294`); a malformed payload is `null` on that entry only. **Gap:**
  the same cold-start `null` as [n9](#n9).
- **4.0.3 (`1577cfa5`):** still 🟡. The cold-start `null` is confirmed in [n9](#n9). #211's
  **Combined bulk reads exclude failed remote values and payloads** passes: payloads are filtered to
  the successful keys (`internal/PostHogRemoteConfig.kt:993-995`, `:1329-1333`).
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** Same as [n9](#n9).

<a id="n11"></a>

### n11 — Group (🟡 Partial)
- **Spec requires:** `group(type, key, properties)` MUST reject blank/empty `type`/`key` (context
  unchanged, warning logged), per `openspec/specs/group/spec.md:128-136` and
  `acceptance/public/group.feature:29-33` (`@client`).
- **SDK currently:** `group(type, key, groupProperties)` (`PostHog.kt:1543-1601`) has no
  `type.isBlank()`/`key.isBlank()` guard — unconditionally writes `newGroups[type] = key` (line
  1587) and forwards to `groupStateless(...)`. Contrast with `identify()`'s blank-id guard
  (`PostHog.kt:1279-1282`). Confirmed unchanged from prior audit via direct read this cycle.
- **4.0.3 (`1577cfa5`):** unchanged. `group()` (`posthog/src/main/java/com/posthog/PostHog.kt:2621-2685`)
  now returns early while opted out (`:2633-2636`) and checks `requirePersonProcessing` (`:2638`), but
  it still writes `newGroups[type] = key` with no blank check (`:2666`). Kotlin's non-null `String`
  rules out a missing key, not an empty one.
- **Backwards compatibility:** Backward-compatible — add an early-return blank-check guard at the
  top of `group()`/`groupStateless()`; only affects currently-malformed (blank) input.
- **Remediation:** Add shared blank `type`/`key` validation, matching `identify()`'s pattern.

<a id="n12"></a>

### n12 — Group Identify (🟡 Partial)
- **Spec requires:** same blank-`type`/`key` rejection as Group (Android has no standalone public
  `groupIdentify` method — `group()` internally emits `$groupidentify`, matching the spec's
  documented Android variant).
- **SDK currently:** Same root cause as Group — `groupStateless()`
  (`PostHogStateless.kt:395-413`) never validates blank `type`/`key` before enqueuing
  `$groupidentify`, contrasted directly with the `identify()` guard immediately above it
  (`PostHogStateless.kt:379-382`). Confirmed unchanged via direct read this cycle. Event shape
  (`$group_type`, `$group_key`, `$group_set`) otherwise correct.
- **4.0.3 (`1577cfa5`):** unchanged. Android emits `$groupidentify` from `group()` with no blank
  check (`posthog/src/main/java/com/posthog/PostHog.kt:2642-2647`, `:2671`). `PostHogStateless.with`
  is now deprecated for core 7.x, so the stateless path isn't the android entry point.
- **Backwards compatibility:** Backward-compatible — same fix as Group.
- **Remediation:** Add the same blank-check guard used for `group()`.

<a id="n13"></a>

### n13 — On Feature Flags (✅ Pass; was 🟡)
- **Spec requires:** the android 4.0 variant is `onFeatureFlags(callback)` on the instance and the static
  facade, returning a subscription and callable before `setup()` (#161, `on-feature-flags/spec.md:40-43`).
  Late listeners get the current values, unsubscribe works, a failed load still delivers the last known
  flags (`:116-176`), a registration outlives `close()`/`setup()` (`:178-196`), loads discarded by
  `reset()`/`close()` reach no listener (`:198-228`), and an empty variant is left out (#193, `:230-251`).
- **SDK currently (4.0, `aaa23d39`):** conforms. `onFeatureFlags`
  (`posthog/src/main/java/com/posthog/PostHog.kt:2611-2631`, static `:3490-3491`) adds the listener to a
  list that `close()` leaves alone, replays `lastFeatureFlagsLoaded` to a late listener (`:2616-2625`), and
  returns a handle whose unsubscribe is safe to call twice. Each load captures `featureFlagsGeneration`;
  `reset()` and `close()` bump it and clear the replay, so a stale load is neither delivered nor replayed
  (`:255-267`, `:287-289`, `:307`). `PostHogFeatureFlagsLoaded` keeps only `true` and non-empty strings
  (`PostHogFeatureFlagsLoaded.kt:38-41`). `PostHogConfig.onFeatureFlags` is removed (`MIGRATION.md:185`).
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n14"></a>

### n14 — Opt In (🟡 Partial)
- **Spec requires:** `optIn()`/`optOut()` persist the decision and gate capture. The `@client` scenario
  **Opt out can clear local persistence when configured** (`opt-in/spec.md:132-141`). **Opt-in restarts
  session replay in a new session** and **Opt-in restarts the session replay the app wanted at opt-out**
  (`:143-251`). **Deferred crash reports honour consent at crash time** (#199, `:253-299`).
- **SDK currently (4.0, `aaa23d39`):**
  - **Persist and gate.** `optIn()`/`optOut()` (`posthog/src/main/java/com/posthog/PostHog.kt:1956-2008`,
    `:2010-2038`) persist `OPT_OUT`; capture is gated in `prepareEvent` (`:1354-1357`).
  - **Replay.** `optOut()` uninstalls integrations, which stops replay (`:2031-2033`, `:632-648`). `optIn()`
    rotates the session when the app wanted replay, then reinstalls and restarts it (`:1982-1989`). Start
    and stop calls made while opted out don't change what the app wanted (`sessionReplayWanted`,
    `:536`, `:3246-3249`, `:3305-3308`).
  - **Native crashes** (PostHog/posthog-android#952). `PostHogNativeCrashIntegration` records an opt-out
    interval on `optOut()` and on a launch that starts opted out
    (`posthog-android/src/main/java/com/posthog/android/errortracking/PostHogNativeCrashIntegration.kt:170-175`,
    `PostHogAndroid.kt:151-159`), and the scan skips crashes recorded inside one (`:395-401`).
  - **Gap.** `optOut()` takes no parameters and `PostHogConfig` has no clear-on-opt-out option. Opt-out
    clears only the exception-steps buffer (`PostHog.kt:2028`) and push-token state (`:2037`), leaving
    `distinctId`, `anonymousId` and super properties in place, so the `@client` scenario fails.
- **4.0.3 (`1577cfa5`):** unchanged. `optOut()` (`posthog/src/main/java/com/posthog/PostHog.kt:2027-2054`)
  takes no parameters and clears only the exception-steps buffer (`:2045`) and push-token state
  (`:2054`). #183's consent-event requirement doesn't apply: `optIn()` (`:1973-2025`) captures no
  consent event.
- **Backwards compatibility:** Backward-compatible. An optional `optOut(clearLocalData: Boolean = false)`
  keeps today's default.
- **Remediation:** Add the optional clear-on-opt-out parameter.

<a id="n15"></a>

### n15 — Persistent Storage (🟡 Partial)
- **Spec requires:** the `@client` scenario **Storage failures do not crash SDK calls**
  (`persistent-storage/spec.md:136-147`). With "persistent storage writes will fail", `register`
  "should not throw" and "the SDK should record a storage warning". Storage errors are "logged and
  swallowed" (`:55`).
- **SDK currently (4.0.3, `1577cfa5`):**
  - **Where it fails.** The gap is in the SDK facade, not the SharedPreferences adapter.
    `register()` (`posthog/src/main/java/com/posthog/PostHog.kt:3048-3060`) calls
    `getPreferences().setValue(key, value)` (`:3059`) with no try/catch. Neither do `unregister()`
    (`:3066`) nor `group()` (`:2668`). A `PostHogPreferences` whose write throws, which is what the
    scenario injects, reaches application code.
  - **No storage warning.** No code path logs one.
- **Correction:** earlier versions of this note pointed at the primitive branches of
  `PostHogSharedPreferences.setValue`. Those put into the editor's in-memory map and can't
  realistically throw, so they aren't the failure. The scenario fails one layer up.
- **Backwards compatibility:** Backward-compatible — catch write failures where the SDK writes
  preferences and log a warning; no change to the success path.
- **Remediation:** Guard preference writes in `register`/`unregister`/`group` (or in a shared write
  helper), and log a storage warning when one fails.

<a id="n16"></a>

### n16 — Register (✅ Pass; was 🟡)
- **Spec requires:** registered properties ride later events, a later call overrides, registered
  values persist across setup, and a per-event value wins (`register/spec.md:94-160`). Input
  validation is optional: implementations "may reject invalid input (for example empty keys…)"
  (`:42`). #146 adds an interaction (`:85`): a registered `$process_person_profile` is not sent on
  `$identify`, `$create_alias`, `$merge_dangerously`, `$groupidentify`, `$set` or `$set_once`.
- **SDK currently (4.0.3, `1577cfa5`):** conforms.
  - **Register and unregister.** `register()` (`posthog/src/main/java/com/posthog/PostHog.kt:3048-3060`)
    rejects reserved internal keys and persists to preferences; `unregister()` is at `:3062-3067`.
  - **Identity events.** `buildProperties` removes a registered `$process_person_profile` for
    identity events (`:975`, set in `IDENTITY_EVENTS`, `:3440-3441`). `optionsForEvent` does the same
    for a wrapper-registered `process_person_profile` option (`:1141`). A value passed on the call
    still applies. `MIGRATION.md:660-666` documents it.
  - **Not implemented (allowed).** Blank keys aren't rejected; the spec makes that optional.
- **Why the change:** the old 🟡 rested only on the optional blank-key check.
- **Backwards compatibility:** No change needed.
- **Remediation:** None. Optionally reject blank keys.

<a id="n17"></a>

### n17 — Session Replay Debug Properties (🟡 Partial; was ✅)
- **Spec requires:** `client`. Four required keys on every event except `$snapshot` and the minimal
  `$feature_flag_called` envelope (`session-replay-debug-properties/spec.md:30-58`). The optional bundle goes
  only on `$` events other than `$feature_flag_called` and `$snapshot`, decided before `beforeSend`
  (`:117-137`), at most once per 30 s per instance, with the window starting when the event is accepted
  (`:194-231`). `$sdk_debug_pending_queue_size` on every non-`$snapshot` event (`:339-347`). Capture mode is
  always `screenshot` (#197, `:606-617`). A previous-process crash carries a persisted snapshot or none of
  the keys (`:969-980`).
- **SDK currently (4.0, `aaa23d39`):** conforms.
  - **Tiers.** `sdkDebugProperties` (`posthog/src/main/java/com/posthog/PostHog.kt:1028-1056`) copies only
    `REQUIRED_REPLAY_DEBUG_PROPERTY_KEYS` (`:66-72`) unless it holds the bundle claim; the queue depth is
    always added (`:1051`).
  - **Eligibility and window.** `isReplayDebugEvent` (`:88-91`) is checked on the name passed to capture,
    before `beforeSend`. `claimReplayDebugPropertiesWindow` (`:1071-1081`) holds one claim at a time on
    `config.dateProvider`'s clock with a 30 s interval (`:63`); the window starts when the event is queued
    and the claim is released on every other exit (`:1289-1300`), and `close()` clears it (`:787-790`).
  - **Keys.** `debugProperties()` (`posthog-android/src/main/java/com/posthog/android/replay/PostHogReplayIntegration.kt:2993-3044`)
    reports `disabled`/`buffering`/`active`, the three trigger statuses, and capture mode `"screenshot"`
    (`:3039`). `$snapshot` skips shared properties (`PostHog.kt:1420`).
  - **Crash case.** An event timestamped before the current session start gets no keys (`:1031-1033`).
    Android persists no crash-time snapshot, so that is the required outcome.
- **Gap (2026-11-18, sdk-specs change `drop-replay-debug-keys-when-replay-off`): the off-state shape.**
  The new requirement "Attach only the disabled shape while replay is intentionally off" (`openspec/specs/session-replay-debug-properties/spec.md:1236`) says that while replay is intentionally off (`sessionReplay` false and
  not started manually, an explicit stop, opt-out, or a cached remote config with `sessionRecording`
  `false` or `quotaLimited` containing `mobile_recordings`) an event carries `$recording_status: disabled`
  and none of the removal set, and the plugin bridge gets the gated map. At posthog-android
  `origin/main` `1101d79b` the integration is always registered, so `sdkDebugProperties`
  (`posthog/src/main/java/com/posthog/PostHog.kt:863-897`) merges `debugProperties()`
  (`posthog-android/src/main/java/com/posthog/android/replay/PostHogReplayIntegration.kt:3394`) with
  replay off, including `$sdk_debug_replay_capture_mode` (`:3440-3441`), and adds
  `$sdk_debug_session_start` whenever the bundle is claimed (`PostHog.kt:890`). Fix in progress:
  [PostHog/posthog-android#992](https://github.com/PostHog/posthog-android/pull/992) (open; closes this
  gap when merged).
- **4.0.3 (`1577cfa5`): #992 shipped and the main gap is closed. Still 🟡 on the three follow-ups below.**
  - **The gate.** `sdkDebugProperties` (`posthog/src/main/java/com/posthog/PostHog.kt:1032-1068`)
    evaluates `isSessionReplayIntentionallyOff()` (`:3317-3321`) on every event. Replay counts as off
    when there is no handler, or when the handler is idle and the app doesn't want replay (an explicit
    stop clears `sessionReplayWanted`, `:3416`) or the last `/config` turned it off.
  - **The off shape.** While off, the event gets only `$recording_status: disabled`, and no bundle
    claim, so no `$sdk_debug_session_start` (`:1045-1049`). A running recorder is never off, as
    `spec.md:1316-1317` requires.
  - **Queue depth** (#238, `spec.md:386-410`). `$sdk_debug_pending_queue_size` now comes from
    `queue.backedUpSize` (`:1063`), which is set only at or above the current `flushAt`
    (`internal/PostHogQueue.kt:96-97`, PostHog/posthog-android#995). `flushAt` is `@Volatile` because
    `413` halving changes it (`:777-778`).
- **Partial at 4.0.3: a registered or caller queue depth wins (#238).**
  - **Spec:** the queue-depth key is SDK-owned; while the queue is healthy the SDK SHALL remove a
    registered or caller value of the same name, and while it is backed up the SDK depth replaces it
    (`openspec/specs/session-replay-debug-properties/spec.md:412-416`).
  - **Code:** `buildProperties` merges `sdkDebugProperties(...)` (`posthog/src/main/java/com/posthog/PostHog.kt:967`,
    which sets the key at `:1063` only when `backedUpSize` is non-null) before `registeredPrefs` (`:972`) and
    caller `properties` (`:998`), and nothing re-applies or removes the key afterwards (the only other
    reference is the key set at `:79`).
  - **Effect:** a registered or caller value is sent while the queue is healthy, and beats the SDK depth
    while it is backed up. posthog-ios has the same gap ([posthog-ios.md n26](posthog-ios.md#n26)).
- **Allowed divergence: a `/config` with no `sessionRecording` key is remote off.** The spec lets an
  SDK treat a missing key as off remotely (`openspec/specs/session-replay-debug-properties/spec.md:1259-1269`).
  `PostHogRemoteConfigResponse.sessionRecording` defaults to `false`
  (`posthog/src/main/java/com/posthog/internal/PostHogRemoteConfigResponse.kt:10`), so Android cannot
  tell a missing key from `false`. The server always sends the key, so this does not show up in
  practice.
- **Partial at 4.0.3: remote off does not survive a relaunch.**
  - **Spec:** "The SDK SHALL read the cached config value, not derived replay-flag state"
    (`openspec/specs/session-replay-debug-properties/spec.md:1306`).
  - **Code:** the off bit `sessionRecordingRemotelyDisabled` is an in-memory `@Volatile` field
    (`posthog/src/main/java/com/posthog/internal/PostHogRemoteConfig.kt:194-196`), set from each
    `/config` reply (`:363`, `:366`). A boolean `false` deletes the cached replay config
    (`processSessionRecordingConfig`, `:578-580`), and `preloadSessionRecordingConfig` (`:1189-1215`)
    restores no off value.
  - **Effect:** after a relaunch, with `sessionReplay` on locally, `isSessionReplayIntentionallyOff()`
    is false until `/config` replies, so events carry the full replay keys.
- **Partial at 4.0.3: the wrapper bridge reads the ungated map.**
  - **Spec:** "Every consumer of the debug map SHALL receive the gated map. On mobile that includes …
    any API that hands the map to a wrapper SDK" (`openspec/specs/session-replay-debug-properties/spec.md:1362`).
  - **Code:** the gate lives only in `PostHog.sdkDebugProperties` (`posthog/src/main/java/com/posthog/PostHog.kt:1045-1049`).
    `PostHogReplayIntegration.debugProperties()`
    (`posthog-android/src/main/java/com/posthog/android/replay/PostHogReplayIntegration.kt:3055`)
    still builds the full map, including `$sdk_debug_replay_capture_mode` (`:3101`).
  - **Who reads it:** the React Native plugin calls that method directly (posthog-js `origin/main`
    `53e5c0e35` `packages/react-native-plugin/android/src/main/java/com/posthogreactnativeplugin/PosthogReactNativePluginModule.kt:300`).
    React Native events are still correct, because posthog-js#5797 gates the map in JS.
- **Backwards compatibility:** Backward-compatible; the change only removes diagnostic keys from
  events captured while replay is off.
- **Remediation:** Three follow-ups to #992:
  - Persist the remote-off value in the cache preferences and load it in
    `preloadSessionRecordingConfig`, so the gate reads it after a relaunch.
  - After the caller merge in `buildProperties`, set `$sdk_debug_pending_queue_size` from
    `queue?.backedUpSize` again, or remove it when that is `null` (#238).
  - Add a gated internal accessor for the debug map, and move the React Native bridge to it. The missing-key reading needs no change: the spec allows it, and the
  server always sends the key, as `false` or a config object (PostHog/posthog `c1fe8dcf295`
  `posthog/models/remote_config.py:305-326`).

<a id="n18"></a>

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
- **4.0.3 (`1577cfa5`):** unchanged; the line numbers moved.
  - **Spec:** matching "observes the event **after** the before-send hook stage"
    (`session-replay-ingestion-controls/spec.md:203`).
  - **Code:** `enqueueEvent` passes the pre-hook `event` name to `sessionReplayHandler?.onEvent`
    (`posthog/src/main/java/com/posthog/PostHog.kt:1525`) and to `surveysHandler?.onEvent` (`:1519`).
    The snapshot check above them reads `postHogEvent` (`:1489`).
  - **What passes:** an event the hook drops returns before either call (`:1296-1298`), so the
    "dropped by before-send" scenario conforms.
  - **What fails:** only a rename. The old `:834`/`:836` references were stale.
- **Backwards compatibility:** Backward-compatible — one-line swap to `postHogEvent.event` at both
  call sites, no API/wire change.
- **Remediation:** Pass `postHogEvent.event` instead of the pre-hook `event` variable at
  `PostHog.kt:1519` and `:1525`.

<a id="n19"></a>

### n19 — Session Replay Privacy (✅ Pass; was 🟡)
- **Spec requires:** `client`. Mask explicitly masked elements and every match in a subtree, exclude
  no-capture elements and their descendants, redact passwords by default, and redact before queueing
  (`session-replay-privacy/spec.md:111-161`). Explicit unmask beats mask markers and category masks (`:54`,
  `:100`). **Android secure windows are recorded fully masked** (#160, `:243-288`).
- **SDK currently (4.0, `aaa23d39`):** conforms.
  - **One capture mode.** 4.0 removes wireframe recording (#197), so `ph-no-capture` goes through the only
    path left: `maskRule` (`posthog-android/src/main/java/com/posthog/android/replay/PostHogReplayIntegration.kt:1601-1619`)
    sends no-capture Views and ComposeViews to `NO_CAPTURE`, and `findMaskableWidgets` masks the subtree
    (`:1535-1595`).
  - **Unmask and passwords.** View `maskRule` checks `isUnmasked()` first (`:1605`) and Compose checks
    `postHogUnmask` first (`:1863-1867`), so both UI toolkits agree. Passwords are masked on both paths
    when broad text masking is off (`:1464-1467`, `:1877-1880`).
  - **Secure windows.** A window that is secure at capture start gets a black frame without copying pixels
    (`:2615-2643`); the flag is re-read after the copy and the bitmap erased if it turned secure
    (`:2775-2783`). Touches on a secure window are dispatched but not recorded (`:845-859`).
  - **Not scored.** An explicit unmask on a password field leaves it unmasked on both paths; the spec
    doesn't rank unmask against password masking.
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n20"></a>

### n20 — Start Session Recording (✅ Pass; was ❌)
- **Spec requires:** `client`. Start activates replay, a repeat start is a no-op, and a start while opted out
  leaves recording inactive (`start-session-recording/spec.md:101-139`). Start failures don't crash the
  app (`:141-181`).
- **SDK currently (4.0, `aaa23d39`):** conforms.
  - **Opt-out.** The replay handler doesn't exist while opted out: setup installs integrations only when
    opted in (`posthog/src/main/java/com/posthog/PostHog.kt:536-543`), and `optOut()` uninstalls them,
    stopping replay and clearing `sessionReplayHandler` (`:2031-2033`, `:632-648`). `startSessionReplay`
    (`:3238-3252`) ignores a start while opted out without recording the intent, and
    `startSessionReplayInternal` only logs that replay isn't installed (`:3293-3295`). `$snapshot` events are also dropped by `prepareEvent` (`:1354-1357`).
  - **Other gates.** Remote-config gating (`:3262-3267`), the already-active no-op (`:3271-3273`) and
    sampling (`:3276`, `:3287`) are in place. Integration install runs in a try/catch (`:599-621`).
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n21"></a>

### n21 — Stop Session Recording (🟡 Partial)
- **Spec requires:** the scenario **Stop session recording finalizes pending replay data**
  (`stop-session-recording/spec.md:97-106`): "pending replay data should be finalized before the
  recorder stops". The other two scenarios cover deactivating replay and a stop while inactive.
- **SDK currently (4.0.3, `1577cfa5`):**
  - **Conforms.** `stopSessionReplay()` (`posthog/src/main/java/com/posthog/PostHog.kt:3407-3422`)
    stops the handler under `setupLock`. It clears `sessionReplayWanted` unless the stop comes from
    opt-out (`:3415-3417`), and it logs, rather than throws, when replay isn't installed. Since 4.0,
    opt-out uninstalls replay ([n20](#n20)), so the opt-out asymmetry earlier versions of this note
    recorded no longer applies.
  - **Gap.** `PostHogReplayIntegration.stop()` → `stopRecording()`
    (`posthog-android/src/main/java/com/posthog/android/replay/PostHogReplayIntegration.kt:3029-3048`)
    clears the active flag and bumps `snapshotGeneration` (`:3040`), which discards an in-flight frame.
    Nothing flushes the replay queue or releases snapshots held for the minimum duration, so pending
    data waits for the timer instead of being finalized.
- **Backwards compatibility:** Backward-compatible — explicitly flushing the replay queue inside
  `stop()` is additive/clarifying, no signature or common-case behavior change.
- **Remediation:** Flush the replay queue (and decide whether held minimum-duration snapshots are
  sent or dropped) inside `stopSessionReplay()`.

<a id="n22"></a>

### n22 — Surveys (🟡 Partial)
- **Spec requires:** `client`.
  - **Wait period** (#102): the last-seen survey date is written when a survey is shown, and "Submit and
    dismiss SHALL NOT move the date" (`surveys/spec.md:425-429`; scenario `:472-487`).
  - **Undisplayable questions:** a survey with a question type the SDK can't display is skipped, not
    marked seen, and "SHALL NOT prevent another eligible survey from being displayed" (`:262-269`).
  - **Popup delay** (#121, `:323-354`) and **web-only conditions** (`:43`, `:126-135`).
- **SDK currently (4.0, `aaa23d39`):**
  - **Conforms.** The shown callback writes the date
    (`posthog-android/src/main/java/com/posthog/android/surveys/PostHogSurveysIntegration.kt:522-523`).
    The integration reserves the survey before the popup delay, and a repeat trigger hits that reservation
    (`:357-366`, `:867`); the Compose host waits `surveyPopupDelaySeconds` before presenting. Surveys with
    `url` or `selector` conditions are excluded (`hasWebConditions`, `:219-222`, `:269`).
  - **Gap 1.** `setSurveySeen` writes the date again (`:1201-1202`), and it runs on dismiss (`:457`) and on
    submit (`:994`), so the dismiss scenario fails.
  - **Gap 2 (from reading the code).** `GsonSurveyQuestionAdapter` returns `null` for an unknown question
    type (`posthog/src/main/java/com/posthog/internal/surveys/GsonSurveyQuestionAdapter.kt:36-43`), leaving
    a `null` entry in `questions`. `showSurvey` reserves the survey (`:363-364`), then
    `SurveyProgressStore.questionOrder` reads `it.type` on that entry (`SurveyProgressStore.kt:68`) and
    throws. The caller catches it, but the reservation is never released, so no later survey shows until
    reset.
  - **Not scored (SHOULD).** Eligibility isn't re-checked after the popup delay (`:346-348`).
- **4.0.3 (`1577cfa5`):** still 🟡; both gaps re-verified at the tag. Gap 2 has the larger user impact:
  one unknown question type stops every later survey from showing until `reset()`.
  - **Gap 1.** `setSurveySeen` still writes the date
    (`posthog-android/src/main/java/com/posthog/android/surveys/PostHogSurveysIntegration.kt:1188-1203`,
    write at `:1202`) and runs on dismiss (`:457`) and submit (`:994`).
  - **Gap 2.** The adapter still maps an unknown type to `null`
    (`posthog/src/main/java/com/posthog/internal/surveys/GsonSurveyQuestionAdapter.kt:43`), and
    `SurveyProgressStore.questionOrder` still dereferences it
    (`posthog-android/src/main/java/com/posthog/android/surveys/SurveyProgressStore.kt:68`). No filter
    drops `null` questions before the survey is reserved, so the reservation still leaks.
  - **Pass, #181** (**Survey targeting flag reads emit no usage event**, `surveys/spec.md:595`).
    `matchesFeatureFlags` reads `survey-targeting-` keys with `sendFeatureFlagEvent = false` and
    other keys with the configured default (`:325`). The linked-variant read is silent (`:336`).
  - **Pass, #226** (**The local surveys option defaults to enabled**, `:537`).
    `PostHogConfig.surveys` defaults to `true` (`posthog/src/main/java/com/posthog/PostHogConfig.kt:213`).
    With only the default delegate installed, `canRenderSurveys()` (`:207`) skips matching and event
    activation (`:880`, `:1254`). PostHog/posthog-android#1000 also waits for event activation before
    reading an event survey's flags (`:284-288`).
- **Backwards compatibility:** Backward-compatible; no public API changes.
- **Remediation:** Drop `setLastSeenSurveyDate` from `setSurveySeen`. Exclude surveys with an undisplayable
  question before reserving, or release the reservation when `showSurvey` fails.

<a id="n23"></a>

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
- **4.0.3 (`1577cfa5`):** unchanged. Neither `posthog/src/main` nor `posthog-android/src/main` has
  `/i/v1/traces`, `startSpan` or `resourceSpans`.
- **Backwards compatibility:** Backward-compatible — the spec itself states tracing SHALL be off
  until the `traces` config is provided, so the entire public API surface is wholly new; nothing
  existing needs to change or deprecate.
- **Remediation:** Implement the traces capability net-new, likely reusing the logs pipeline's
  OTLP/queue machinery as a template.

<a id="n24"></a>

### n24 — Capture (✅ Pass, re-audited for capture v1)
- **Spec requires:** the capture v1 requirements [#146](https://github.com/PostHog/sdk-specs/pull/146)
  adds to `capture/spec.md` (text at `d387ab79`): the wire contract, request headers, per-event results,
  per-event options with legacy-property hoisting, the layer order's steps 4 and 5 (which apply to client
  SDKs too), **Events name their own library**, session/window id lifting, distinct ids, timestamps,
  per-event serialization, and failing open on a missing or personal token.
  - **`$lib` pair.** `$lib` and `$lib_version` stay in `properties`. **Caller-supplied event properties
    take precedence** names them as its one exception: every SDK, client SDKs included, fills its own
    pair after every other layer and before `before_send`. When `$lib` is not a non-empty string it sets
    both, replacing a lone `$lib_version`. When `$lib` is the SDK's own name and `$lib_version` is not set
    it sets the version. Otherwise it leaves both, and never adds its own version to another library's
    `$lib`.
  - **Post-hook allowances.** Step 4 says "The SDK SHALL NOT add or re-add any value after the hook, with
    two allowances: it MAY re-impose the uuid it generated before the hook … and it MAY treat a returned
    event whose `options` is absent as keeping the pre-hook options, while an empty `options` map still
    clears them". Pipeline step 6 adds that an SDK that keeps the pre-hook options "SHALL also tell
    callers to return an empty `options` map".
  - **Empty variant** (`main`, #193). A cached flag whose value is `""` is left out of
    `$active_feature_flags`, and its `$feature/<key>` still carries `""`.
  - **Null-valued properties** (carried from before capture v1). Null object members are omitted, and
    null array elements stay JSON `null` at their indices; arrays are never compacted.
  - **Identity calls under a layered `false`** (#146 at `15501ca`). A `process_person_profile: true` call
    option beats every layer, and "SDK docs and migration guides SHALL show that call option on an
    identity call as the way to keep identifying under a layered `false`". **Superseded:** #146 as
    merged (`3fb33bf`) replaces this rule, see the 4.0.3 paragraph.
- **4.0.3 (`1577cfa5`), against `44fe27a`:** conforms.
  - **Identity events skip the registered personless setting.** The merged #146 text in
    **Caller-supplied event properties take precedence** (`capture/spec.md:406`) says: "A registered
    `$process_person_profile`, and a `process_person_profile` option a wrapper SDK registers, SHALL
    NOT be sent with the identity events … posthog-android 4.0 … do[es] this."
    - `buildProperties` removes the registered property when `isIdentityEvent` is set
      (`posthog/src/main/java/com/posthog/PostHog.kt:975`; `IDENTITY_EVENTS`, `:3440-3441`).
    - `optionsForEvent` drops the registered option for those events (`:1141`).
    - A value on the call still applies. `MIGRATION.md:660-666` documents the rule.
    - The `@client` scenario **A registered personless setting does not reach identity events**
      (`:476-487`) passes.
  - **Set-like and listed sequence values** (#215, **Capture serializes set-like and listed sequence
    property values as arrays**, `:1362`). Kotlin `Set`s and non-`List` `Deque`/`Queue` values reach
    `GsonSafeMapSerializer`'s fallback (`internal/GsonSafeMapSerializer.kt:81-83`), and Gson writes them
    as arrays. A unit test against the tag serialized
    `setOf("a")`, `linkedSetOf("a","b","c")`, `ArrayDeque(listOf("x","y","z"))` and a set holding
    `{"drop": null, "keep": 1}` as
    `{"one":["a"],"many":["a","b","c"],"deque":["x","y","z"],"nested":{"inner":[{"keep":1}]}}`.
    Order is kept and the null member is dropped.
  - **GeoIP.** The new `disableGeoIp` option (PostHog/posthog-android#971, `PostHogConfig.kt:364-365`)
    sets `$geoip_disable` after the caller merge (`PostHog.kt:1010-1012`). GeoIP control stays a
    server-SDK requirement.
  - **Wire.** A `401` now logs one always-on warning
    (`internal/PostHogApi.kt:254-259`). Everything else in the `aaa23d39` paragraph below still holds.
- **SDK currently (4.0, `aaa23d39`):** conforms.
  - **Identity-call guide (tracking 4.0).** The SDK behaves as required: a call option wins over a
    registered `$process_person_profile: false`. `MIGRATION.md:500` at `aaa23d39` doesn't show the call
    option yet; the example lands in 4.0 with PostHog/posthog-android#966, which targets the release
    branch, so this audit doesn't score it as a gap. Recheck at the release-tag repin.
  - **Wire and headers.** `postCaptureV1` (`posthog/src/main/java/com/posthog/internal/PostHogApi.kt:208-279`)
    POSTs `{"created_at", "batch"}` to `/i/v1/analytics/events` with `Authorization: Bearer`,
    `PostHog-Sdk-Info` (`posthog-android/<version>`, also sent as `User-Agent`), `PostHog-Attempt`,
    `PostHog-Request-Id` (UUID v7) and a fresh `PostHog-Request-Timestamp` on every attempt. There is
    no `api_key`, `sent_at` or `offset`. `nextCaptureV1Identity` (`:281-301`) keeps the request id and
    `created_at` across retries of the same uuid set, in memory, so both reset after an app restart
    (allowed for a durable client queue).
  - **Per-event results.** `captureV1Result` (`:318-381`) resends only `retry` uuids. `drop`,
    `duplicates_dropped`, an unknown verdict and an absent uuid are not resent. A 2xx without a
    readable `results` map is a terminal failure that drops the batch (`:332-338`). In debug mode only,
    as #146 allows a client SDK without an error handler, the SDK logs one aggregate line per batch
    with the endpoint path, the counts and the `details` tags (`:359-373`); a terminal status or an
    unreadable 2xx logs the status, the count and the lane (`events` or `AI events`,
    `PostHogQueue.kt:819`). No line carries event content.
  - **Event shape.** `captureV1Json` (`:882-909`) builds the wire event after `beforeSend` and runs for
    3.x events still on disk too. It keeps `$lib`/`$lib_version` in properties, hoists the four legacy
    option properties into options only when the option is missing or `null`
    (`LEGACY_OPTION_PROPERTIES`, `:865`), and omits an empty `options`. `liftStringProperty`
    (`:917-929`) lifts string `$session_id`/`$window_id` to the root, drops `null` silently, and drops
    any other type with a debug log that names the key and JSON type, never the value. `options` is
    accepted on `capture`, `screen`, `identify`, `setPersonProperties`, `alias`, `group` and
    `captureException`. Options a wrapper SDK registers with the internal `registerOptionsForWrapper`
    (PostHog/posthog-android#954, `PostHog.kt:2972-2981`) sit under each event's own options
    (`optionsForEvent`, `:1122-1145`); they are not an app-facing global options API.
  - **`$lib` pair** (PostHog/posthog-android#956). `buildProperties` calls `fillLibraryIdentity`
    (`posthog/src/main/java/com/posthog/internal/PostHogLibraryIdentity.kt:13-29`) last
    (`PostHog.kt:1013`), after the SDK's values, registered super properties and the caller's
    properties, and before `beforeSend`. It reads each value as set only when it is a non-empty string.
    With no usable `$lib` it sets both, replacing a lone caller `$lib_version`. With `$lib =
    "posthog-android"` (or a wrapper's configured name) and no usable `$lib_version` it sets the
    version. A caller's `$lib = "custom-lib"` with no version is sent without `$lib_version`, as the
    new `@client` scenario requires, and a caller pair is kept as given. Snapshot events go through
    the same fill. At `8b63a135` a caller's `$lib` merged key by key over the SDK's pair and so carried
    the SDK's `$lib_version`, which this rule now forbids.
  - **Empty variant.** `buildProperties` stamps `$feature/<key>` for every cached flag and adds a key
    to `$active_feature_flags` only when its value is neither `false` nor `""` (`PostHog.kt:914-930`).
  - **Null-valued properties.** `GsonSafeMapSerializer` omits null map members and, since
    PostHog/posthog-android#955 (`6b546165`), writes a null or unserializable list element as JSON
    `null` in place (`internal/GsonSafeMapSerializer.kt:101-112`). Before #955 it skipped null list
    elements and compacted the array, a gap the 2026-10-19 and 2026-11-05 audits missed.
  - **Distinct ids, names and tokens.** A blank caller `distinctId` falls back to the current id
    (`PostHog.kt:1360`). There is no local length or placeholder check. An empty event name, including
    one `beforeSend` sets, is dropped locally (`PostHogStateless.kt:472-481`). An empty token or a
    `phx_` key disables the SDK with an always-on warning (`PostHog.kt:326-339`).
  - **Timestamps.** Timestamps are UTC with three fractional digits (`formatISO8601Date`), stamped
    once when the event is created.
  - **Post-hook allowances.** `runBeforeSend` (`posthog/src/main/java/com/posthog/PostHogStateless.kt:371-409`)
    re-imposes the capture's uuid on the event the last hook returned (`:402-405`), and when a hook
    returns a different event whose `options` is `null`, copies in the options the hook was given
    (`:387-391`). `options` isn't a `PostHogEvent` constructor parameter, so `copy()` and the constructor
    always produce `null`. Both are the allowances step 4 grants, and the 4.0 migration guide tells
    callers to set `options` to an empty map to send none (`MIGRATION.md:493`), as step 6 requires.
  - **GeoIP.** The **Client-level GeoIP control** requirement, including #146's clarification that a
    call's own `$geoip_disable` beats a per-call argument, binds server SDKs; client SDKs are not
    required to have the option.
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n25"></a>

### n25 — Capture AI (✅ Pass, new applicability)
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
- **SDK currently (4.0, `aaa23d39`):** conforms.
  - **Method and routing.** `captureAi` (`posthog/src/main/java/com/posthog/PostHog.kt:1202-1226`)
    mirrors `capture`'s parameters and returns the uuid, or `null` when the event isn't queued. It logs
    a debug line for a non-`$ai_` name and sends the event to the AI endpoint anyway. `capture` never
    uses the AI lane.
  - **Separate lane.** `EndpointSpec.ai()` (`internal/EndpointSpec.kt:85-111`) gives the lane its own
    `PostHogQueue`, disk directory, single-thread executor (`PostHogAiQueueThread`), retry state and
    OkHttp client (`aiCaptureClient`, `internal/PostHogApi.kt:122-136`). That client has read/write idle
    timeouts from `captureAiTimeout` and compression from `captureAiCompression`, which defaults to
    gzip. It shares the capture v1 status policy, per-event results and redirect rule with analytics.
    The queue starts at setup (`PostHog.kt:516`), so events left from an earlier launch are sent.
    `flush()` and `close()` signal both lanes (`:2808`, `:779`).
  - **Size.** `queueAiEvent` (`:1234-1251`) measures the serialized event before encryption and drops
    one over `captureAiMaxStoredEventBytes` (`internal/EndpointSpec.kt:260-265`, 8 MiB + 64 KiB, which
    can only be lowered). It logs the name and the limit, never content. A configured value above the
    ceiling is clamped with a log at setup (`PostHog.kt:375-380`). The queue caps at
    `captureAiMaxQueueSize` (default 100) and `AI_MAX_QUEUE_BYTES` (50 MiB) and drops the oldest
    first. Batches use the same 5 MiB byte-aware window as analytics ([n6](#n6)).
  - **Not applicable.** The Full AI capture flag and the built-in-integration requirement bind SDKs
    that ship AI wrapper libraries; posthog-android ships none. The OpenTelemetry context requirement
    binds SDKs with an OTel AI bridge; there is none here.
  - **Null-valued properties.** AI events use the same serializer as `capture`, so null object members
    are omitted and null array elements keep their positions since PostHog/posthog-android#955
    ([n24](#n24)).
  - **Building order.** AI events go through the same `buildProperties`, so the `$lib` pair fill
    (PostHog/posthog-android#956) and registered wrapper options (#954) apply as in [n24](#n24).
  - **Hook.** AI events go through the same `runBeforeSend` as `capture`, so the post-hook allowances
    in [n24](#n24) apply to this lane too.
  - **Compression.** `captureAiCompression` is independent of `compression`, as `capture-ai` requires.
    `http-client`'s whole-client opt-out excludes a delivery lane with its own compression setting, so
    the two rules agree.
- **4.0.3 (`1577cfa5`), against `44fe27a`:** conforms. Two things changed.
  - **#146 as merged (`3fb33bf`) rewords capture-ai.**
    - It no longer names posthog-android. Applicability reads "`server`, and client SDKs on capture v1
      that ship an AI method", which still covers android.
    - The named client defaults (100 events, 60 s, 50 MiB, the 64 KiB headroom, clamping with a log)
      become "Client SDKs MAY use a smaller default queue, an idle read and write timeout … and a
      fixed disk cap" (`capture-ai/spec.md`, **AI lane configuration is scoped to the AI lane**).
    - The quotes above are from the pre-merge text. Android's values fall within what the merged
      text allows, so the score doesn't change.
  - **Code.** An AI event's nested values are now copied before `beforeSend`, even without hooks
    (`runBeforeSend(..., copyNested = aiLane)`, `posthog/src/main/java/com/posthog/PostHog.kt:1295`).
    A caller that reuses a list can no longer grow the event past the size check before it is written.
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n26"></a>

### n26 — HTTP Client (✅ Pass, re-audited for capture v1)
- **Spec requires:** [#146](https://github.com/PostHog/sdk-specs/pull/146)'s **Capture v1 transport**:
  - Build `{host}/i/v1/analytics/events` (and `/i/v1/ai/events`), send the token only as
    `Authorization: Bearer`, and send the capture v1 headers on every attempt.
  - Compress with a single declared `Content-Encoding` and a per-lane compression setting.
    **Request body compression and opt-out** asks for one option that turns compression off for the
    whole client, "except a delivery lane that has its own compression setting (`capture-ai`, **AI lane
    configuration is scoped to the AI lane**)".
  - Follow only a same-origin `307`/`308`, at most five times, resending the same method, headers and
    body; any other redirect is terminal.
  - "A caller-supplied HTTP client either keeps its own redirect policy or, where the SDK can intercept
    its redirects, gets this same rule applied to capture requests; both are compliant." (text at
    `d387ab79`)
- **SDK currently (4.0, `aaa23d39`):** conforms.
  - **Client.** The SDK builds `captureClient` (`posthog/src/main/java/com/posthog/internal/PostHogApi.kt:101-118`)
    with `followRedirects(false)`, `followSslRedirects(false)` and `retryOnConnectionFailure(false)`.
    A network interceptor strips a `503`'s `Retry-After: 0`, so OkHttp never resends on its own.
  - **Redirects.** `postCaptureV1` (`:208-279`) follows a `307`/`308` only when `isConfiguredOrigin`
    (`:397-400`) matches the scheme, host and port of `host`, at most `CAPTURE_V1_MAX_REDIRECTS = 5`
    times, with the same body and headers. Any other 3xx is a terminal `PostHogApiError`.
  - **Headers and compression.** The Bearer header replaces an `Authorization` set in `requestHeaders`
    for capture requests only. `compression` drives the `GzipRequestInterceptor` on the base client
    (`PostHogApi.kt:85`), so `NONE` turns off gzip for analytics and every other request the SDK
    compresses. The AI lane swaps in an interceptor that reads `captureAiCompression`
    (`:121-136`), which the opt-out's lane exception leaves alone. `GzipRequestInterceptor` sets
    exactly `Content-Encoding: gzip` and sends uncompressed when compression fails.
  - The flags retry policy and connection-refused handling recorded on 2026-10-19 are unchanged.
  - **Caller-supplied client.** When the app passes `PostHogConfig.httpClient`, `captureClient` is
    built from `httpClient.newBuilder()` with `followRedirects(false)`, so capture requests get the
    SDK's same-origin rule and other requests keep the caller's policy. #146 allows this. The
    migration guide documents it (`MIGRATION.md:385`).
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n27"></a>

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
- **SDK currently (4.0, `aaa23d39`):** conforms.
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
  - **Retries exclude new events.** #146 (`1004640`, from #180) says a retry resends only the events of
    the failed request. `takeFiles` resends the retry window alone (`PostHogQueue.kt:331-352`).
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n28"></a>

### n28 — Identify (✅ Pass; was 🟡)
- **Spec requires:** **Canonical identify behavior** (`identify/spec.md:178`): client SDKs keep running
  `identify` while opted out (#167), but "MUST NOT capture or send the `$identify` or `$set` event, and
  MUST NOT update the person-properties dedup hash for an event it did not capture." #208 (`81829c5`)
  adds a rule in `identify` and `set-person-properties` (**The person-properties hash only tracks
  updates that surely process the person**). The hash is checked, and recorded once the update is
  queued, only when the update's `process_person_profile` setting "is missing or the Boolean `true`".
  Any other value is sent without the check and clears the stored hash.
- **SDK currently (4.0.3, `1577cfa5`):** conforms. PostHog/posthog-android#967 is in the tag.
  - **Check without storing.** `personPropertiesHashIfChanged`
    (`posthog/src/main/java/com/posthog/PostHog.kt:2507-2526`) checks against the stored hash but
    doesn't store it. An update whose option isn't missing or `true` skips the check
    (`surelyProcessesPersonProfile`, `:1166-1169`).
  - **Store only once queued.** The same-id `$set`, the anonymous-to-identified `$set` and `$identify`
    go through `captureInternal(..., personPropertiesHash = …)`. The hash is recorded only in the
    callback that runs once the event is queued (`:1300-1306`).
    `updatePersonPropertiesHashForQueuedEvent` (`:2536-2562`) records it only when the event as sent
    after `beforeSend` keeps its name, distinct id and `$set`/`$set_once` payload and still surely
    processes the person. Otherwise it clears the hash.
  - **Opt-out.** A `$set` dropped while opted out is never queued, so the hash is left alone and the
    same properties are sent after opt-in. `setPersonProperties` uses the same path (`:2399-2448`).
- **Earlier finding, at 4.0 (`aaa23d39`), before #967:**
  - **Passes.** `identify()` (`posthog/src/main/java/com/posthog/PostHog.kt:2236-2371`) has no opt-out
    guard. It updates the ids, sets person properties for flags and reloads flags (`:2287-2317`); `capture`
    then drops the event. All four `@client` scenarios pass.
  - **Gap.** Two branches update the hash for a `$set` that opt-out drops: the same-id branch through
    `shouldCapturePersonPropertiesEvent` (`:2350-2358`, `:2450-2466`), and the anonymous-to-identified
    transition (`:2339-2342`). After opt-in, the same properties are treated as a duplicate and the `$set`
    is never sent. No scenario covers this path.
- **Backwards compatibility:** No change needed.
- **Remediation:** None. [PostHog/posthog-android#967](https://github.com/PostHog/posthog-android/pull/967) fixed it.

<a id="n29"></a>

### n29 — Setup (✅ Pass)
- **Spec requires:** **Canonical setup behavior**, the `projectToken` option name, the deprecated
  credential alias rules, and the token rename stopping at the public configuration surface
  (`setup/spec.md:122-217`).
- **SDK currently (4.0, `aaa23d39`):** conforms. `setup()` (`posthog/src/main/java/com/posthog/PostHog.kt:316-343`)
  ignores a repeat call, and disables the SDK with a warning when the trimmed token is blank or starts
  with `phx_` (`:326-339`). `projectToken` is trimmed (`PostHogConfig.kt:477`). The `apiKey` alias shipped
  as deprecated in 3.x and 4.0 removes it, which a major release may do. Events queued by 3.x are still
  sent (`MIGRATION.md:503`).
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n30"></a>

### n30 — Shutdown (✅ Pass)
- **Spec requires:** **Canonical shutdown behavior** (`shutdown/spec.md:110-158`): flush, stop workers,
  refuse later captures, safe to call twice, no throw on a delivery failure. The timeout requirement
  applies only where shutdown takes a timeout.
- **SDK currently (4.0, `aaa23d39`):** conforms. `close()` (`posthog/src/main/java/com/posthog/PostHog.kt:758-800`)
  flushes first (`:767`), sets `enabled = false` so later captures return (`:769`, `:1351`), uninstalls
  integrations (`:773`), stops every queue's timer (`:776-779`) and clears the flag-called tracker (`:783`).
  A second call returns early (`:762-764`) and errors are caught (`:798-799`). Android `close()` takes no
  timeout.
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n31"></a>

### n31 — Application Lifecycle (✅ Pass)
- **Spec requires:** **Canonical application-lifecycle behavior**: Installed, Updated (with
  `previous_version`/`previous_build`), Opened (with `from_background`) and Backgrounded, carrying
  `$app_version`/`$app_build` (`application-lifecycle/spec.md:76-130`).
- **SDK currently (4.0, `aaa23d39`):** conforms. `PostHogAppInstallIntegration`
  (`posthog-android/src/main/java/com/posthog/android/internal/PostHogAppInstallIntegration.kt:41-78`) sends Installed or Updated and persists
  the version and build. `PostHogLifecycleObserverIntegration.kt` sends `Application Opened` with
  `from_background` (`:56-79`) and `Application Backgrounded` (`:117-118`). `$app_version`/`$app_build`
  ride every event (`PostHogAndroidContext.kt:68`, `:71`). Not scored (SHOULD NOT): these events still
  also send un-prefixed `version`/`build` (`PostHogAppInstallIntegration.kt:75-76`,
  `PostHogLifecycleObserverIntegration.kt:72-73`).
- **Backwards compatibility:** No change needed.
- **Remediation:** None. Optionally drop un-prefixed `version`/`build`.

<a id="n32"></a>

### n32 — Remote Config (✅ Pass)
- **Spec requires:** `GET {assetBase}/array/{projectKey}/config` with the token and no identity; US/EU Cloud
  map to their `-assets` hosts and a custom host keeps its base path; unknown fields and `quotaLimited`
  values are ignored (#198); a failed fetch keeps the cached config (`remote-config/spec.md:100-220`).
- **SDK currently (4.0, `aaa23d39`):** conforms. `remoteConfig()`
  (`posthog/src/main/java/com/posthog/internal/PostHogApi.kt:679-720`) sends that request.
  `loadRemoteConfig` (`internal/PostHogRemoteConfig.kt:315-443`) skips a load while one is in flight
  (`:336`), loads flags only when `hasFeatureFlags` and `preloadFeatureFlags` are both true (`:364-410`),
  and keeps the cached slices on failure (`:429-438`). 4.0 always loads `/config` at setup (`PostHog.kt:556`;
  the `remoteConfig` option is removed, `MIGRATION.md:76`), and `notifyIntegrationsRemoteConfig`
  (`PostHog.kt:571-591`) drops a reply that arrives after `close()` or belongs to an earlier setup
  (PostHog/posthog-android#953, #961). `quotaLimited` is parsed; only `mobile_recordings` turns replay off
  (`PostHogRemoteConfig.kt:350`), and other values are ignored.
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n33"></a>

### n33 — Feature Flag Cache (✅ Pass)
- **Spec requires:** cache values and payloads, serve reads with no network request, clear on reset. A
  malformed, empty or whitespace-only cached payload is logged and reads as absent, never as the raw string
  (#170, `feature-flag-cache/spec.md:98-162`).
- **SDK currently (4.0, `aaa23d39`):** conforms. `decodePayload`
  (`posthog/src/main/java/com/posthog/internal/PostHogRemoteConfig.kt:1280-1294`) parses strict JSON and
  returns `null` on failure. Payloads loaded from storage are re-decoded from the cached flag details
  (`:1251-1271`), so a raw string left by 3.x is dropped. A failed load leaves the cache alone, a success
  persists it (`:1024-1059`), and `clear()` empties it on reset (`:1772-1806`).
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n34"></a>

### n34 — Reload Feature Flags (✅ Pass)
- **Spec requires:** reload with the current distinct id, groups and properties for flags, and keep the
  cached flags on failure. The android variant is `reloadFeatureFlags(onFeatureFlags: PostHogFeatureFlagsCallback? = null)`,
  whose callback gets `PostHogFeatureFlagsLoaded` (`reload-feature-flags/spec.md:31`); a reported failure
  comes with the last known flags (`:153-155`).
- **SDK currently (4.0, `aaa23d39`):** conforms. `reloadFeatureFlags`
  (`posthog/src/main/java/com/posthog/PostHog.kt:2599-2609`) matches the variant. `executeFeatureFlags`
  (`internal/PostHogRemoteConfig.kt:856-1117`) sends the current context (`:914-921`) and queues a reload
  that arrives while one is in flight (`:880-906`). On failure `errorsLoading` stays `true` and the cache is
  untouched; the callback gets `PostHogFeatureFlagsLoaded(getFeatureFlags(), errorsLoading)` (`:286-300`).
- **Backwards compatibility:** 4.0 changed the callback type (`MIGRATION.md:185-225`).
- **Remediation:** None.

<a id="n35"></a>

### n35 — Logs (✅ Pass)
- **Spec requires:** gzip by default, and raw JSON with no `Content-Encoding` when the app turns compression
  off through the `http-client` option (#81, `logs/spec.md:234-255`).
- **SDK currently (4.0, `aaa23d39`):** conforms. `sendLogs`
  (`posthog/src/main/java/com/posthog/internal/PostHogApi.kt:429-449`) posts on the base client, whose
  `GzipRequestInterceptor` (`:85`, `internal/GzipRequestInterceptor.kt:55-60`) compresses only when
  `config.compression` is `GZIP`. `captureLog` runs `beforeSend` before the rate cap
  (`PostHog.kt:1834-1845`). The logs queue retries 408, 429 and 5xx (`internal/EndpointSpec.kt:270`) and
  uses `Retry-After` as a floor capped at 30 s (`PostHogQueue.kt:604-621`). The other requirements carry
  over from 2026-10-19; the shared queue was reworked in 4.0 and was spot-checked, not re-derived.
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n36"></a>

### n36 — Get Feature Flag Result (✅ Pass)
- **Spec requires:** a key/enabled/variant/payload result and nothing for an unknown flag
  (`get-feature-flag-result/spec.md:151-196`); a payload parse failure keeps the flag (`:198-227`); the
  per-call `sendFeatureFlagEvent` falls back to the client default (`:262-290`); `""` reads as disabled
  (#193, `:292-314`).
- **SDK currently (4.0, `aaa23d39`):** conforms. `PostHogRemoteConfig.getFeatureFlagResult`
  (`posthog/src/main/java/com/posthog/internal/PostHogRemoteConfig.kt:1331-1353`) returns `null` for an
  unknown key and `enabled = value.isNotEmpty()` for a string, so `""` is disabled with `variant = ""`.
  `decodePayload` (`:1280-1294`) turns a malformed payload into `null` without touching the flag.
  `PostHog.getFeatureFlagResult` (`PostHog.kt:2787-2799`) falls back to `PostHogConfig.sendFeatureFlagEvent`.
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n37"></a>

### n37 — Is Feature Enabled (✅ Pass)
- **Spec requires:** the caller's `defaultValue` when the flag has no value, a known value (including
  `false`) wins, a variant reads as `true`, `""` reads as `false` (#193), and per-call suppression works
  (`is-feature-enabled/spec.md:135-201`).
- **SDK currently (4.0, `aaa23d39`):** conforms. `isFeatureEnabled`
  (`posthog/src/main/java/com/posthog/PostHog.kt:2682-2698`) computes `getFeatureFlag(key, sendFeatureFlagEvent) ?: defaultValue`
  and treats a string as enabled only when it isn't empty.
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n38"></a>

### n38 — Get Feature Flag Payload (✅ Pass)
- **Spec requires:** android 4.0 may drop the getter and read payloads through
  `getFeatureFlagResult(key, sendFeatureFlagEvent = false)?.payload` (#170,
  `get-feature-flag-payload/spec.md:55`, `:234-251`). A malformed payload reads as absent, valid JSON keeps
  its type, and nothing is decoded twice (`:161-232`).
- **SDK currently (4.0, `aaa23d39`):** conforms. There is no payload getter (`MIGRATION.md:124-132`). A silent
  result read sends no event (`posthog/src/main/java/com/posthog/PostHog.kt:2708-2713`). `decodePayload`
  (`internal/PostHogRemoteConfig.kt:1280-1294`) decodes `/flags` strings once (`:1273-1277`) and returns
  `null` for a malformed, empty or whitespace-only payload; bootstrap payloads are used as given.
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n39"></a>

### n39 — Get Feature Flag (✅ Pass)
- **Spec requires:** the cached boolean or variant, `$feature_flag_called` by default, and per-call
  suppression; the android variant is `getFeatureFlag(key, sendFeatureFlagEvent = null)`, with 4.0 removing
  `defaultValue` (`get-feature-flag/spec.md:70`, `:139-179`).
- **SDK currently (4.0, `aaa23d39`):** conforms. `getFeatureFlag`
  (`posthog/src/main/java/com/posthog/PostHog.kt:2766-2774`) returns `variant ?: enabled` from the flag
  result (`FeatureFlagResult.kt:28-29`) and sends `$feature_flag_called` unless suppressed (`:2700-2760`).
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

<a id="n40"></a>

### n40 — Capture Exception (✅ Pass)
- **Spec requires:** type and message from `$exception_list[0]`, frames bottom-up, an existing stack kept,
  null custom properties dropped, `ignoredExceptionTypes` on every path. #124: a separate fatal serializer
  emits the same entries and frames, omitting an unset optional field rather than the frame or entry
  (`capture-exception/spec.md:390-434`).
- **SDK currently (4.0, `aaa23d39`):** conforms. `captureException`
  (`posthog/src/main/java/com/posthog/PostHog.kt:1704-1738`) builds `$exception_list` with frames reversed
  to bottom-up (`internal/errortracking/ThrowableCoercer.kt:129`), and uncaught JVM exceptions use the same
  path (`errortracking/PostHogErrorTrackingAutoCaptureIntegration.kt:118-121`). The native crash serializer
  adds each optional frame field only when known and always keeps the frame and stack trace
  (`posthog-android/src/main/java/com/posthog/android/internal/errortracking/NativeCrashEventCoercer.kt:23-82`).
  `ignoredExceptionTypes` also applies to `$exception` events handed to `capture` (`PostHog.kt:1388-1397`).
- **Backwards compatibility:** No change needed.
- **Remediation:** None.
