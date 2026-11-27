# posthog-ios — SDK Compliance

**Repo:** [PostHog/posthog-ios](https://github.com/PostHog/posthog-ios)
**Audited commit:** tag `4.0.5` at `c8fcc2c069c7119253aa5219c45c369f16d669dc` ([tag](https://github.com/PostHog/posthog-ios/tree/4.0.5)), re-audited on 2026-11-24 as a delta from `e27cbe4cb` (see [4.0.5 re-audit](#405-re-audit-2026-11-24)); before that audited on 2026-11-05 at `3460e534a` and re-checked on 2026-11-10 at `e27cbe4cb` on the 4.0 release branch ([PostHog/posthog-ios#873](https://github.com/PostHog/posthog-ios/pull/873)) (see [Re-check](#re-check-2026-11-10))
**Audited against sdk-specs commit:** `44fe27a` (includes merged capture v1, [#146](https://github.com/PostHog/sdk-specs/pull/146)); previously `752f899` plus #146 at `d387ab79`, first audited against `dd11a6b`
**Summary:** 43 ✅ · 15 🟡 · 1 ❌ · 11 ➖ (70 rows; previous audit at `e27cbe4cb` scored 44/14/1/10 on 69 rows)

Note on repo layout: `posthog-ios` is a single-package repo, distributed through Swift Package Manager
only from 4.0. Core SDK logic lives at `PostHog/` (flat files: `PostHogSDK.swift` — the main public
API surface (capture, captureAi, identify, alias, group, feature flags, session recording controls,
shutdown); `PostHogConfig.swift`; `PostHogRemoteConfig.swift` — `/flags` fetch, feature-flag/payload
cache, remote replay/error-tracking config; `PostHogStorage.swift`/`PostHogStorageManager.swift` —
persistence; `PostHogQueue.swift`/`QueueEndpoint+Factories.swift` — batching/retry per lane (events,
AI, replay, logs); `PostHogApi.swift` — HTTP transport, including the capture v1 wire builder;
`PostHogSessionManager.swift`; `PostHogBootstrapConfig.swift`; `PostHogRemovedAPIs.swift` — `unavailable`
stubs for APIs removed in 4.0). Platform-specific integrations live in subfolders: `AppLifeCycle/`,
`Autocapture/`, `ErrorTracking/`, `Logs/`, `Replay/` (session replay — masked screenshots only from
4.0), `ScreenViews/`, `Surveys/`, `SwiftUI/` (SwiftUI-specific modifiers), `Tracing/` (tracing-headers
only — no OTLP traces implementation exists), `PushNotifications/`. There is exactly one SDK target, so
any capability judged N/A (e.g. local flag evaluation, flag-definition polling, evaluate-flags, the AI
dataset/scorer/evaluation APIs, emails) is N/A because the capability requires a personal or secret
key a mobile app cannot safely hold, or is server-only per its spec's Applicability line, not because
of a build-target split. All file paths below are relative to the posthog-ios repo root. Line
references re-verified in the 4.0.5 re-audit (the 4.0.5 section and notes n3, n4, n5, n11, n16, n19,
n21, n23, n24, n26 and n27) are at `4.0.5`; the rest are at `e27cbe4cb`, in files the 4.0.5
re-audit found unchanged or did not re-read.

This audit re-verified all 64 existing rows against the 4.0 branch (posthog-ios commits since
`f5cbe87c`, including capture v1 [#938](https://github.com/PostHog/posthog-ios/pull/938) and the
fixes from #924–#934, which are now merged) and current specs, and adds five rows for contracts added
to the README table since then: **Experiment Exposure**, **AI Datasets**, **AI Scorers**, **Offline
Evaluations** and **Emails** (all ➖).

Net changes vs. the previous audit:
- **Improved (9):** Get Feature Flag Payload 🟡→✅ (4.0 removes `getFeatureFlagPayload(_:)`; payloads
  are read with `getFeatureFlagResult(_:sendFeatureFlagEvent: false)?.payload`, which the new "Payload
  reads through the flag result getter" requirement permits), Get Feature Flag Result and Feature Flag
  Cache 🟡→✅ (a malformed, empty or whitespace-only payload is `nil`; bootstrapped payloads are decoded
  once), Is Feature Enabled 🟡→✅ (`isFeatureEnabled(_:defaultValue:)`), Capture and Capture Exception
  🟡→✅ (empty event names are dropped and `NSNull` properties are omitted on the queue and the wire,
  [PostHog/posthog-ios#1047](https://github.com/PostHog/posthog-ios/pull/1047)), Session Replay Privacy
  ❌→🟡 (4.0 records masked screenshots only, so the leaking wireframe path is gone; SwiftUI's explicit
  mask still wins over an enclosing `postHogNoMask()`, the reverse of the spec's precedence), Get Feature
  Flags and Get Feature Flags And Payloads ❌→🟡 (the specs now record iOS 4.0's `getAllFeatureFlags()`
  list of results, with per-entry payload decoding, as its surface; it is still not the canonical map
  shape).
- **Downgraded (1):** Exception Steps ✅→🟡. #1047's queue and wire `NSNull` cleanup runs after the
  step buffer has measured and stored the step, so the buffered and sent forms differ ([n30](#n30)).
- **Newly applicable (1):** Capture AI ➖→✅. #146 adds iOS 4.0 to its Applicability, and the AI lane
  conforms ([n27](#n27)).
- **Note-only changes:** Shutdown, HTTP Client, Group, Group Identify, Stop Session Recording and
  Feature Flag Called Tracker no longer depend on pending PRs. New requirements met without a status
  change: capture v1 (Capture, Before Send Hook, Event Batcher, HTTP Client, Retry Queue; see
  [Capture v1](#capture-v1)), jittered retry backoff (Retry Queue), identify while opted out (Identify,
  Consent Gating), `$group_set` nesting (Group Identify), caller-property precedence (Capture, Register,
  Session Replay Debug Properties), build-invariant lifecycle properties (Application Lifecycle), load
  generations across `reset()` and empty variants left out of listener flags (On Feature Flags), empty
  variants read as disabled (Capture, Get Feature Flag Result, Get Feature Flags, Is Feature Enabled),
  and deferred crash reports following consent at crash time (Opt In).

## 4.0.5 re-audit (2026-11-24)

Delta audit of the released tag `4.0.5` (`c8fcc2c06`) against sdk-specs `44fe27a`, starting from the
`e27cbe4cb` audit below. The tag was compared with `e27cbe4cb` as trees, because #873 was squash-merged
as `0dbc2245a`. Every open row was re-checked; none was fixed in 4.0.1–4.0.5.

- **Rows that changed status:** Capture ✅→🟡: the sdk-specs #215 requirement "Capture serializes
  set-like and listed sequence property values as arrays" lists `Set`/`NSSet` for Swift, and iOS
  drops such a property ([n4](#n4)). Capture AI ✅→🟡 for the same drop: `captureAi` goes through
  `captureInternal` → `sanitizeDictionary` like `capture` ([n27](#n27)). Bootstrap 🟡→✅: its only gap,
  `bootstrap.sessionID`, is a MAY, scored as on posthog-android ([n25](#n25)). New row: **Get Remote Config Payload** ➖ ("Server SDKs only. The
  request needs a secret key, which must never reach a client.").
- **Spec changes met without a status change:**
  - Failed remote flags (#211), met by
    [PostHog/posthog-ios#1059](https://github.com/PostHog/posthog-ios/pull/1059): a `failed: true`
    record is not a value (`PostHog/PostHogRemoteConfig.swift:1325`). On an errored merge it doesn't
    replace a served value (`:589-595`), and failed placeholders persisted by an older version are cleaned
    at launch (`:155`, `:1034-1053`). Get Feature Flag Result, Get Feature Flags, Get Feature Flags And
    Payloads and Is Feature Enabled (the caller's default wins) hold.
  - Feature Flag Called Tracker: `$feature_flag_called` reports `evaluation_failed` and
    `errors_while_computing_flags` in `$feature_flag_error` (`:931-943`; `PostHog/PostHogSDK.swift:3614-3616`). The
    client-level `sendFeatureFlagEvent` default (#153) is met: every getter resolves
    `sendFeatureFlagEvent ?? config.sendFeatureFlagEvent` (`:3373`), so a suppressed read never reaches
    the dedupe tracker. A missing flag reports no value (#202): `$feature_flag_response` is `NSNull`
    (`:3606`), which is omitted on the wire. See [n21](#n21).
  - Synthesized stacks stop at the call site (#224), met by
    [PostHog/posthog-ios#1079](https://github.com/PostHog/posthog-ios/pull/1079) ([n5](#n5)).
  - Surveys: `survey-targeting-` flag reads send no event (#181), with `PostHog/Surveys/PostHogSurveyIntegration.swift:280-288`
    covering every key field (`:154-171`) and the variant read passing `false` (`:297`). The local
    option defaults to enabled (#226; `PostHog/PostHogConfig.swift:642`).
  - A registered `$process_person_profile` is not sent on identity events (merged #146, d59f33a;
    `PostHog/PostHogSDK.swift:659`, `:690-692`, `:896-899`; [n4](#n4)).
  - Replay debug keys are dropped while replay is off (#232), met by
    [PostHog/posthog-ios#1090](https://github.com/PostHog/posthog-ios/pull/1090), shipped in 4.0.3. The
    queue-depth key is attached only at or above `flushAt` (#238, met in part by
    [PostHog/posthog-ios#1102](https://github.com/PostHog/posthog-ios/pull/1102)); see [n26](#n26).
- **Not applicable or met trivially:** the consent event once per opt-in (#183; iOS captures no
  consent event), `POSTHOG_PROJECT_TOKEN` (#214; the token is read only from code), W3C `traceparent` (#219,
  MAY), and the server-only flag, MCP and LLMA changes (#144, #168, #220, #229–#231, #233).
- **Merged #146 vs. the `d387ab79` text audited earlier:** iOS is no longer named in the capture v1
  lists (5d75baf), but the rules still apply to "client SDKs on capture v1". Null-property omission
  is now a MAY (4bd0b50), and iOS omits. The `15501ca` docs requirement (n4) is gone, replaced by
  d59f33a.
- **Not audited:** the opt-in GPU capture path (`captureMethod = .gpu`, about 3,500 new lines under
  `PostHog/Replay/`; the default stays `.standard`, `PostHog/Replay/PostHogSessionReplayConfig.swift:95`)
  against Session Replay Privacy. The new `set-person-properties` scenario for a non-Boolean option
  (#208) was not re-checked.

## Re-check (2026-11-10)

Re-checked at the 4.0 branch head `e27cbe4cb` against sdk-specs `752f899` and #146 at `d387ab79`.
Line references in this section are at `e27cbe4cb`.

- **Rows that changed status since the 2026-11-05 audit:** Capture, Capture AI and Capture Exception
  🟡→✅ ([PostHog/posthog-ios#1047](https://github.com/PostHog/posthog-ios/pull/1047) omits `NSNull`
  properties; [n4](#n4), [n5](#n5), [n27](#n27)); On Feature Flags 🟡→✅
  ([PostHog/posthog-ios#1048](https://github.com/PostHog/posthog-ios/pull/1048) drops loads in flight
  across `reset()`; [n28](#n28)); Exception Steps ✅→🟡 (the same `NSNull` cleanup runs only after the
  step buffer, so the byte-counted and sent steps differ; [n30](#n30)). Surveys stays ✅:
  [PostHog/posthog-ios#1049](https://github.com/PostHog/posthog-ios/pull/1049) meets every SHALL of the
  popup-delay requirement (#121) and #102's wait period; the one unmet SHOULD (re-check eligibility
  when the delay elapses) is recorded but not scored ([n29](#n29)).
- **#146 since `5c26b9bc`:** `http-client` now leaves "a delivery lane that has its own compression
  setting (`capture-ai`)" out of the whole-client opt-out, so `captureAiCompression` conforms and HTTP
  Client is scored ✅ on its merits ([n22](#n22)). "Events name their own library" now applies to
  client SDKs: the SDK fills its own `$lib`/`$lib_version` pair after the caller's properties and
  before `beforeSend`. iOS does so since
  [PostHog/posthog-ios#1050](https://github.com/PostHog/posthog-ios/pull/1050) ([n4](#n4)).
- **`main` since `8306698`:**
  - Empty variant read as disabled (#193): met in Capture (`$active_feature_flags`), Get Feature Flag
    Result, Get Feature Flags, Is Feature Enabled and On Feature Flags ([n4](#n4), [n8](#n8),
    [n9](#n9), [n28](#n28)).
  - Deferred crash reports honour consent at crash time (#199): met ([n15](#n15)); Opt In stays 🟡 on
    its old gap and Consent Gating stays ✅.
  - `$feature_flag_variant` → `$feature_flag_variant_key` (#203): iOS requests `/flags?v=2`, so
    Experiment Exposure stays ➖ and Feature Flag Called Tracker has no config-version-2 attribution to
    rename.
  - Job-retry handled state (#205), server exception acceptance (#188), local feature enrollment
    (#178), the tracing-headers cookie fallback (#116) and `$mcp_session_source` (#185) are server-only;
    no row changes.
- **Earlier spec changes, re-checked 2026-11-09:** Opt In meets #138's two replay restart requirements
  ([n15](#n15)); Surveys meets #102's wait period since #1049 ([n29](#n29)); Session Replay Privacy and
  Debug Properties meet #197 (wireframe removed, capture mode `screenshot`) and stay 🟡 on their
  existing gaps; Remote Config reads `quotaLimited` (#198) with `as? [String]` and `.contains(...)`, so
  unknown values are ignored; Evaluate Flags (#169) and MCP Analytics (#189, #190, #194) are
  server-only.
- **Other SDK changes, no status change:** #1036 (`$lib`/`$lib_version` stay in properties), #1037 (an
  empty string variant reads as disabled), #1040 (crash and memory reports recorded while opted out are
  dropped), #896 (replay scheduled from a run-loop observer), #1045 (wrapper SDKs register capture
  options for every event, behind `@_spi(PostHogInternal)`) and #1050's person-properties hash fix for
  updates that may be personless (Identify, Set Person Properties).

## Capture v1

4.0 sends analytics events through capture v1. These rows are scored against
[#146](https://github.com/PostHog/sdk-specs/pull/146), first at `d387ab79` and re-checked against the
merged text in the 4.0.5 re-audit: Capture ([n4](#n4)), Capture AI ([n27](#n27)), Before Send Hook,
Event Batcher, HTTP Client ([n22](#n22)) and Retry Queue. The merged text names only the server SDKs
(5d75baf). Client SDKs on capture v1 follow the same rules through "client SDKs" wording, so these
scores hold. `PostHog/PostHogApi.swift` is unchanged at 4.0.5, so its line references below still
apply.

- **Wire.** `POST /i/v1/analytics/events` with a `{created_at, batch}` body and no `api_key`, `sent_at`
  or `offset` (`PostHog/PostHogApi.swift:212`, `:224-227`). Headers on every attempt: `Authorization:
  Bearer` set after custom headers, `PostHog-Sdk-Info: posthog-ios/<version>` (also the `User-Agent`),
  `PostHog-Attempt`, `PostHog-Request-Id` and a fresh `PostHog-Request-Timestamp` (`:241-246`); custom
  headers can't override them (`:139-142`). `created_at` and the request id are kept across retries of
  the same uuid set (`:286-297`).
- **Event shape.** After `beforeSend`, `captureV1JSON` (`:386-413`) hoists `$process_person_profile`,
  `$cookieless_mode`, `$ignore_sent_at` and `$product_tour_id` into `options` when the option is absent
  or null, lifts string `$session_id`/`$window_id` to the root (other types dropped with a log naming
  the type, `:426-450`), drops null-valued properties again (`:411`, for events queued before the
  cleanup existed), and keeps `$lib`/`$lib_version` in `properties`
  ([PostHog/posthog-ios#1036](https://github.com/PostHog/posthog-ios/pull/1036)), as **Events name their
  own library** requires.
- **Per-event results.** Only `retry` uuids are resent; `drop`, `duplicates_dropped`, unknown results
  and absent uuids are not; a 2xx without a readable `results` map is terminal (`:314-366`). The
  aggregate drop line is debug-only, which #146 allows a client SDK.
- **Delivery.** Retried statuses are exactly 404/408/429/500/502/503/504, network errors and 2xx
  `retry` entries; 1–30 s backoff with jitter in [0.75, 1.25); `Retry-After` as a floor after jitter,
  capped at 30 s, also on a 2xx retry; no attempt limit on the durable queue; retries resend only the
  failed request's events (#180, `PostHog/PostHogQueue.swift:498-507`); byte-aware 5 MiB batches, with a
  multi-event 413 halving the batch and a single-event 413 terminal; same-origin 307/308 redirects only,
  at most 5 (`PostHogApi.swift:881-910`). Callers supply a `URLSessionConfiguration`, not a session, so
  the SDK's redirect rule covers every capture request.
- **Hook.** After `beforeSend` the SDK only re-imposes the uuid (`PostHog/PostHogSDK.swift:2725`), the
  first allowance in #146's layer order. `PostHogEvent.options` is non-optional, so the absent-options
  allowance never arises.
- `captureAi` sends AI events on their own lane to `POST /i/v1/ai/events` (see [n27]).

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Logs | 🟡 | [n1]; `close()` flush, empty-key skip and capped `Retry-After` now met; non-finite floats still dropped, one batch per flush |
| 2 | Traces | ❌ | [n2] |
| 3 | Tracing Headers | ✅ | new server span-context bridge requirements (#129) are `@server` only |
| 4 | Alias | 🟡 | [n3] |
| 5 | Capture | 🟡 | was ✅; [n4]; #215: a `Set`/`NSSet` property is dropped instead of sent as a JSON array. Capture v1 wire conforms (merged #146); registered `$process_person_profile` left off identity events; empty event names dropped; `NSNull` properties omitted (#1047, now a MAY); own `$lib` pair filled after caller properties (#1050); empty variant left out of `$active_feature_flags` |
| 6 | Capture AI | 🟡 | was ✅; inherits Capture's #215 `Set`/`NSSet` drop ([n4]). Merged #146 applies it to "client SDKs on capture v1 that ship an AI method"; the AI lane conforms, including the `NSNull` cleanup (#1047) — [n27] |
| 7 | Capture Exception | ✅ | [n5]; `NSNull` custom properties omitted (#1047); synthesized stacks start at the caller (#224, posthog-ios#1079) |
| 8 | Create Person Profile | ➖ | unchanged — spec Applicability still says only the posthog-js family exposes it; no `createPersonProfile` in iOS |
| 9 | Debug | ✅ | |
| 10 | Exception Steps | 🟡 | was ✅; `NSNull` step members are byte-counted and buffered, then stripped on the queue and the wire — [n30](#n30) |
| 11 | Flush | 🟡 | [n6] |
| 12 | Get Anonymous ID | ✅ | |
| 13 | Get Distinct ID | ✅ | |
| 14 | Get Feature Flag | ✅ | per-call option is `sendFeatureFlagEvent` (#109) |
| 15 | Get Feature Flag Payload | ✅ | was 🟡; getter removed in 4.0, payload read through `getFeatureFlagResult` as the spec now permits — [n7] |
| 16 | Get Feature Flag Result | ✅ | malformed payload → `nil`; empty variant reads as disabled (#193); a failed record returns no result (#211, posthog-ios#1059) — [n8] |
| 17 | Get Feature Flags | 🟡 | was ❌; spec now records `getAllFeatureFlags()`'s result list as the iOS 4.0 surface; empty variant entries read as disabled (#193) — [n9] |
| 18 | Get Feature Flags And Payloads | 🟡 | was ❌; spec now points iOS 4.0 at the payload-carrying `getAllFeatureFlags()` — [n10] |
| 19 | Evaluate Flags | ➖ | unchanged: still "applies to server SDKs"; #111/#85 additions are server snapshot reads |
| 20 | Get Remote Config Payload | ➖ | **new row**: "Server SDKs only. The request needs a secret key, which must never reach a client." |
| 21 | Get Session ID | 🟡 | [n11] |
| 22 | Group | ✅ | [n12] |
| 23 | Group Identify | ✅ | [n13] |
| 24 | Identify | ✅ | new #167 rule met: opt-out gates only the `$identify` event (`PostHog/PostHogSDK.swift:1225-1269`) |
| 25 | Is Feature Enabled | ✅ | was 🟡; `isFeatureEnabled(_:defaultValue:)` added — [n14] |
| 26 | Is Opt Out | ✅ | |
| 27 | Is Session Replay Active | ✅ | |
| 28 | On Feature Flags | ✅ | [n28]; new requirements met: loads in flight across `reset()` are dropped (#1048), empty variants left out of listener flags (#193) |
| 29 | Opt In | 🟡 | [n15]; deferred crash reports follow consent at crash time (#199, met) |
| 30 | Register | ✅ | SDK → registered → caller order (`PostHog/PostHogSDK.swift:838-917`); the SDK's own `$lib` pair fills last, the one exception (`:919-922`) |
| 31 | Reload Feature Flags | ✅ | |
| 32 | Reset | 🟡 | [n16] |
| 33 | Reset Group Properties For Flags | ✅ | |
| 34 | Reset Person Properties For Flags | ✅ | |
| 35 | Screen | ✅ | |
| 36 | Set Group Properties For Flags | ✅ | |
| 37 | Set Person Properties | ✅ | |
| 38 | Set Person Properties For Flags | ✅ | |
| 39 | Setup | ✅ | `projectToken` naming met (`PostHog/PostHogConfig.swift:62`); `apiKey` removed in a major, which the spec allows |
| 40 | Shutdown | ✅ | [n17]; the new timeout requirement (#135) applies only where shutdown takes a timeout |
| 41 | Start Session Recording | ✅ | |
| 42 | Stop Session Recording | ✅ | [n18] |
| 43 | Unregister | ✅ | |
| 44 | Application Lifecycle | ✅ | build-invariant rule met (`$app_build_xcode`/`$app_build_sdk` on install/update only); `version`/`build` dropped in 4.0. `$lib`/`$lib_version` stay on every enqueued event; on the wire see "Capture v1" above |
| 45 | Autocapture | ✅ | |
| 46 | Before Send Hook | ✅ | after the hook only the uuid is re-imposed (#146 allowance); `options` is non-optional, so the absent-options allowance doesn't arise; a throwing hook logs the event and exception name only, in debug mode |
| 47 | Consent Gating | ✅ | identify updates local state while opted out and only skips the event, matching #167; deferred crash reports follow consent at crash time (#199, [n15]) |
| 48 | Device ID Generator | ✅ | |
| 49 | Event Batcher | ✅ | byte-aware check-before-append batching at 5 MiB (`PostHog/PostHogQueue.swift:544-548`); no analytics per-event cap; a multi-event 413 halves the batch (client allowance) |
| 50 | Exception Event Metadata | 🟡 | [n19]; caller properties can still override `$exception_level`/`$exception_source`; trace context (#123) and job-retry handled state (#205) are server-only |
| 51 | Feature Flag Cache | ✅ | was 🟡; malformed → `nil`, bootstrap payloads decoded once — [n20] |
| 52 | Feature Flag Called Tracker | ✅ | [n21]; client-level event default (#153), missing flag reports no value (#202) and `evaluation_failed` (#211, posthog-ios#1059) met; config-version-2 attribution needs `/flags?v=4`, which iOS does not request |
| 53 | Flag Definition Loader | ➖ | unchanged: new keyless-provider and polling-opt-out requirements are server-only |
| 54 | HTTP Client | ✅ | [n22]; gzip by default; `compression = .none` turns compression off for every request except the AI lane, which has its own `captureAiCompression`, as #146 now allows |
| 55 | Local Feature Flag Evaluator | ➖ | unchanged: no local rule engine |
| 56 | Persistent Storage | 🟡 | [n23] |
| 57 | Remote Config | ✅ | |
| 58 | Retry Queue | ✅ | capture v1 status set; jitter factor `[0.75, 1.25)`, capped at 30 s, `Retry-After` floor applied after jitter, also on 2xx retries (`PostHog/PostHogQueue.swift:14-43`, `:247-256`); no attempt limit (client allowance); retries exclude new events (#180) |
| 59 | Session Manager | ✅ | |
| 60 | Session Replay Ingestion Controls | ✅ | |
| 61 | Session Replay Privacy | 🟡 | was ❌; 4.0 removes wireframe mode, the only path that leaked; SwiftUI `postHogMask()` wins over an enclosing `postHogNoMask()` (over-masks, not a leak) — [n24] |
| 62 | Surveys | ✅ | popup-delay (#121) and wait-period (#102) SHALLs met since #1049; `survey-targeting-` reads send no event (#181) and surveys default on (#226); the SHOULD eligibility re-check when the delay elapses is not met and not scored — [n29] |
| 63 | Bootstrap | ✅ | [n25] |
| 64 | MCP Analytics | ➖ | Applicability is `server` add-on; no iOS package |
| 65 | Session Replay Debug Properties | 🟡 | [n26]; (c) and (d) fixed ((d) by posthog-ios#1090, 4.0.3); (a), (b) still open; caller or registered `$sdk_debug_pending_queue_size` not removed or replaced (#238) |
| 66 | Experiment Exposure | ➖ | **new row**: applies to SDKs that read `/flags?v=4` records; iOS requests `v=2` (`PostHog/PostHogApi.swift:595-599`), so config-version-2 flags read as legacy values |
| 67 | AI Datasets | ➖ | **new row**: server SDKs only (personal API key); no iOS surface |
| 68 | AI Scorers | ➖ | **new row**: server SDKs only (personal API key); no iOS surface |
| 69 | Offline Evaluations | ➖ | **new row**: server SDKs only; no iOS surface |
| 70 | Emails | ➖ | **new row**: "Server SDKs only" — needs a secret key that must never reach a client |

## Notes

<a id="n1"></a>

### n1 — Logs (🟡 Partial)
- **Spec requires:** non-finite floats encoded as `stringValue`, empty attribute keys dropped, a final flush on
  shutdown, a persistent-queue drain that repeats "until the queue is drained or a send fails", `Retry-After` as a
  floor clamped to a documented maximum, and (new, #81) raw JSON with no `Content-Encoding` when the app turns
  compression off.
- **SDK currently:** Met: `close()` flushes the logs queue (`PostHog/PostHogSDK.swift:3755-3758`); empty keys are
  skipped with a log (`PostHog/Logs/PostHogLogsOTLP.swift:86-95`); `Retry-After` is a floor clamped to
  `min(30 s, 5 min)`, so 30 s (`PostHog/PostHogQueue.swift:247-253`, `PostHog/QueueEndpoint+Factories.swift:14-17`);
  the logs request goes through the shared compression switch (`PostHog/PostHogApi.swift:503`, `:144-157`). Still
  open: (1) NaN/±Inf attributes are dropped before the encoder sees them — `toStorageJSON` runs attributes through
  `sanitizeDictionary` (`PostHog/Logs/PostHogLogRecord.swift:126-128`), whose `isValidObject` rejects non-finite
  numbers (`PostHog/Utils/DictUtils.swift:211-223`) and `sanitizeInvalidValue` has no conversion for them
  (`:70-89`), so the encoder's `"NaN"`/`"Infinity"` branch (`PostHog/Logs/PostHogLogsOTLP.swift:72-78`) is
  unreachable. (2) A flush sends one window (see n6).
- **Backwards compatibility:** Backward-compatible; internal changes only.
- **Remediation:** Give the logs storage path a sanitizer that stringifies non-finite floats instead of dropping
  them; loop the queue drain (n6).

<a id="n2"></a>

### n2 — Traces (❌ Fail)
- **Spec requires:** `startSpan`/`withSpan`, OTLP traces to `POST {host}/i/v1/traces`, shutdown flush, shared
  backoff, mobile context.
- **SDK currently:** Still not implemented: no `startSpan`, `withSpan`, `resourceSpans` or `i/v1/traces` anywhere
  under `PostHog/`; `PostHog/Tracing/` holds only `PostHogTracingHeadersIntegration.swift`.
- **Backwards compatibility:** Backward-compatible; net-new opt-in API.
- **Remediation:** Implement traces net-new, modeled on the logs pipeline.

<a id="n3"></a>

### n3 — Alias (🟡 Partial)
- **Spec requires:** unchanged since the last audit. The `@client` scenario "Client alias links the
  current anonymous identity to a known identity" (`acceptance/public/alias.feature`) requires
  `properties.alias` and `properties.distinct_id` on `$create_alias`. The `@both` scenario "Alias is
  dropped when required identities are missing" requires a drop plus a validation warning. Behavior
  step 4 (`openspec/specs/alias/spec.md:73`) still says mobile helpers need not duplicate
  `distinct_id`, which conflicts with the scenario.
- **SDK currently:** Unchanged at 4.0.5. `alias(_:options:)` (`PostHog/PostHogSDK.swift:2588-2622`) gained an `options`
  parameter in 4.0 but still builds `let props = ["alias": alias]` (`:2605`) with no `distinct_id`,
  and has no blank-alias guard, so `alias("")` is enqueued. The source id always resolves through
  `getDistinctId()` (`:2607`), so the missing-previous-id case can't happen.
- **Backwards compatibility:** Backward-compatible. Both fixes are additive.
- **Remediation:** Set `props["distinct_id"] = distinctId` (or fix the spec scenario to match
  Behavior step 4), and drop a blank alias with a log, as `identify()` does.

<a id="n4"></a>

### n4 — Capture (🟡 Partial; was ✅)
- **Spec requires:**
  - **New (#215):** "Capture serializes set-like and listed sequence property values as arrays"
    (`openspec/specs/capture/spec.md:1362`): such a value "SHALL serialize as a JSON array of its
    elements. The SDK MUST NOT serialize such a value as an empty object, as JSON `null`, or as a string
    representation of the container, and MUST NOT drop the property or the event because of it". The
    runtime table lists `Set` and `NSSet` for Swift / Objective-C (`:1374`).
  - **Merged #146 (d59f33a):** "A registered `$process_person_profile` … SHALL NOT be sent with the
    identity events `$identify`, `$create_alias`, `$merge_dangerously`, `$groupidentify`, `$set` and
    `$set_once`" (`:406`). This replaces the `15501ca` rule that docs show a per-call option on identity
    calls.
  - **Merged #146 (4bd0b50):** "Capture drops null-valued object properties" is now a MAY ("An SDK MAY
    omit…"). An SDK that omits must still clean recursively, keep null array elements at their index,
    keep emptied objects as `{}`, and apply the cleanup after `before_send` and on disk serialization.
  - **Unchanged:** drop empty or invalid event names (Behavior step 2 / Error handling); client
    precedence SDK → registered → caller, with `$lib`/`$lib_version` as the one exception ("Events name
    their own library", now scoped to capture v1); "Empty variant is not an active feature flag" (#193).
    #119 and #131 are server requirements; #127 applies only to an SDK that rate-limits captures.
- **SDK currently:**
  - **Gap: sets are dropped (#215).** Every capture path runs caller properties through
    `sanitizeDictionary` (`PostHog/Utils/DictUtils.swift:48-63`; for example
    `PostHog/PostHogSDK.swift:2035`). `isValidObject` (`DictUtils.swift:211`) rejects a set, and
    `sanitizeInvalidValue` (`:70-85`) converts only `URL`, `Date`, dictionaries and `[Any]`. So a `Set` or
    `NSSet` property is removed, with a debug-only `"isn't serializable, dropping the item"` log (`:62`).
    Falsification: run locally, `Set(["a"]) as Any as? [Any]` and the `NSSet` equivalent are both
    `nil`, and `JSONSerialization.isValidJSONObject` rejects both. No other set handling exists on the
    serialization path. The public API takes `[String: Any]`, so callers can pass one.
  - **Identity events (met).** `optionsForEvent` removes a registered `process_person_profile` for
    the six identity events (`PostHog/PostHogSDK.swift:659`, `:690-692`). `buildProperties` removes a
    registered `$process_person_profile` after merging super properties (`:896-899`). A value on the
    call still applies (`:941`). `MIGRATION.md:577` documents it.
  - **Empty event names are dropped** after `beforeSend` (`PostHog/PostHogSDK.swift:2131`) and again
    in `queueEvent` for every path (`:2783`). Whitespace-only names pass; the spec says "non-empty", so
    that is not flagged.
  - **Null-valued properties are omitted**
    ([PostHog/posthog-ios#1047](https://github.com/PostHog/posthog-ios/pull/1047)), as the MAY permits.
    `droppingNullProperties` (`PostHog/Utils/DictUtils.swift:151-201`) cleans recursively, keeps null
    array elements and `{}`, and runs when the analytics and AI queues write an event to disk
    (`PostHog/QueueEndpoint+Factories.swift:48`, `:79`) and again in `captureV1JSON`
    (`PostHog/PostHogApi.swift:411`). `$set`, `$set_once` and `$group_set` keep their nulls
    (`DictUtils.swift:139`).
  - **Library identity.** After the caller's properties, `fillLibraryIdentity`
    (`PostHog/PostHogSDK.swift:722`, called at `:945`) fills both values when `$lib` is missing, and only
    the version when `$lib` is the SDK's own name; any other `$lib` is left alone. `beforeSend` runs
    after. ([PostHog/posthog-ios#1050](https://github.com/PostHog/posthog-ios/pull/1050))
  - **Empty variant.** `$feature/<key>` is stamped for every cached flag; `isActiveFlagValue` leaves
    `false` and `""` out of `$active_feature_flags` (`PostHog/PostHogSDK.swift:610-626`).
  - **Precedence:** SDK values, then registered properties (`:896`), then caller properties (`:941`).
  - **Capture v1 (merged #146):** see [Capture v1](#capture-v1).
- **Backwards compatibility:** Converting sets is additive: a property that is dropped today would be
  sent. Shipped in 4.0: nulls omitted, and a caller's `$lib` keeps its own version.
- **Remediation:** In `sanitizeInvalidValue`, add `if let set = value as? NSSet` before the `[Any]` branch
  and return `sanitizeArray(set.allObjects)`. A Swift `Set` bridges to `NSSet`; this was checked locally.
  Keep an empty set as `[]`: don't let it fall into the "empty array is omitted" rule. Add a test for
  `Set<String>`, `NSSet` and a nested set.

<a id="n5"></a>

### n5 — Capture Exception (✅ Pass; was 🟡)
- **Spec requires:** Applicability is now `both` (server delivery scenarios are `@server`). "Exception
  capture drops null-valued custom object properties" follows capture's null rule (a MAY since merged
  #146). "Ignored exception
  types" (optional) drops matching `$exception` events on every path and platform. New: "Fatal
  exception payloads keep their exception data" for a separate fatal-path serializer. New (#224):
  "Synthesized stacks stop at the application call site" (`openspec/specs/capture-exception/spec.md:275`):
  "that stack SHALL end at the application frame that called the public exception-capture API … in
  every build configuration", with no frame added by one overload delegating to another.
- **SDK currently:** #224 is met since [PostHog/posthog-ios#1079](https://github.com/PostHog/posthog-ios/pull/1079)
  (in 4.0.0). Every public `captureException`/`captureExceptionObjC` overload reads
  `Thread.callStackReturnAddresses.dropFirst()` in its own body (`PostHog/PostHogSDK.swift:4091`,
  `:4108`, `:4124`, and the `NSException` overloads after them), no overload calls another, and the
  addresses are symbolicated with `stripTopPostHogFrames: true`
  (`PostHog/ErrorTracking/PostHogExceptionProcessor.swift:436`). Not verified: a release SPM build with
  cross-module optimization inlining an entry point; read from code, not run. Fixed since `f5cbe87c` ([#930](https://github.com/PostHog/posthog-ios/pull/930),
  merged): the matcher is platform-neutral
  (`PostHog/ErrorTracking/PostHogErrorTrackingAutoCaptureIntegration.swift:347-368`) and
  `captureInternal` applies it to every `$exception` (`PostHog/PostHogSDK.swift:2002-2007` at 4.0.5); crash
  reports are filtered too (`PostHogErrorTrackingAutoCaptureIntegration.swift:292-296`).
  `captureExceptionEvent` (`PostHog/PostHogSDK.swift:4335-4349` at 4.0.5) still merges caller properties as
  given, but every `$exception`, manual or from a crash report, goes through the analytics queue, whose
  encoder now drops null-valued members (#1047, see [n4](#n4)). The fatal-path requirement is met in
  effect: crash reports are processed on the next launch by `PostHogCrashReportProcessor`, which keeps
  every frame, and iOS frames carry no `chunk_id`.
- **Backwards compatibility:** Backward-compatible apart from the 4.0 null-property change in n4.

<a id="n6"></a>

### n6 — Flush (🟡 Partial)
- **Spec requires:** Behavior step 3, "Build and send batches until the queue is drained or a failure stops
  progress", replay queues included.
- **SDK currently:** `flush()` (`PostHog/PostHogSDK.swift:929-939`) now flushes the events, replay, logs and AI
  queues. Each `PostHogQueue.flush()` (`PostHog/PostHogQueue.swift:369-382`) still takes one window:
  `peekEntries(count, maxBytes:)` reads at most `cap` entries, and on capture v1 at most about one 5 MiB batch
  (`:512`); `consume` only continues inside that window (`:573-576`). Nothing re-takes from the queue head after a
  successful send, so with more than `maxBatchSize` (default 50) events queued one flush delivers one batch.
  Unchanged since the previous audit apart from the byte cap.
- **Backwards compatibility:** Backward-compatible; only the number of requests per flush changes.
- **Remediation:** After a successful window, peek the next one, bounded by the depth captured at flush start;
  stop on the first failure.

<a id="n7"></a>

### n7 — Get Feature Flag Payload (✅ Pass; was 🟡)
- **Spec requires:** a cache-only payload read with no `$feature_flag_called` by default; malformed, `""`
  or whitespace-only serialized payloads return the no-payload value, never the raw string; already-decoded
  payloads are not decoded again. New (#170): a client SDK MAY omit the dedicated getter when its flag
  result getter returns the payload and accepts a per-call `sendFeatureFlagEvent`; the scenarios then hold
  for `getFeatureFlagResult(key, sendFeatureFlagEvent: false)?.payload`, and that read sends no
  `$feature_flag_called` (`openspec/specs/get-feature-flag-payload/spec.md`, "Payload reads through the
  flag result getter"; the iOS surface variant names exactly this call).
- **SDK currently:** `getFeatureFlagPayload(_:)` is `@available(*, unavailable)` with the replacement in
  its message (`PostHog/PostHogRemovedAPIs.swift:79-84`). `getFeatureFlagResult(_:sendFeatureFlagEvent:)`
  (`PostHog/PostHogSDK.swift:3320-3323`) reads the cache and only reports `$feature_flag_called` when the
  per-call flag (falling back to `PostHogConfig.sendFeatureFlagEvent`, default `true`,
  `PostHog/PostHogConfig.swift:108`) is `true` (`PostHog/PostHogSDK.swift:3325-3343`). `decodePayload`
  (`PostHog/PostHogRemoteConfig.swift:1144-1152`) returns `nil` and logs on a decode failure, so
  `"{broken"`, `""` and `"   "` read as `nil`. Bootstrapped payloads are serialized once when seeded
  (`PostHog/PostHogRemoteConfig.swift:957-962`), so each cached payload is decoded exactly once and a
  bootstrapped `"123"` stays a `String`.
- **Backwards compatibility:** Breaking in 4.0 by design (method removed; malformed payloads now `nil`);
  both are in the 4.0 changeset and `MIGRATION.md`.

<a id="n8"></a>

### n8 — Get Feature Flag Result (✅ Pass; was 🟡)
- **Spec requires:** key/enabled/variant/payload, `nil` for unknown flags; a malformed payload is the
  no-payload value without changing key/enabled/variant. New: the per-call option is named
  `sendFeatureFlagEvent` and defaults to sending (#109). New on `main` (#193): "Empty variant reads as
  disabled": `""` returns `enabled: false`, `variant: ""`, and `isFeatureEnabled` returns `false`
  for it with or without a default.
- **SDK currently:** `getFeatureFlagResult` returns `nil` for an unknown key
  (`PostHog/PostHogRemoteConfig.swift:1154-1166`). `makeFeatureFlagResult` computes `enabled`/`variant`
  from the flag value alone and takes the payload from `decodePayload`, which returns `nil` on failure
  (`PostHog/PostHogRemoteConfig.swift:1144-1152`, `:1184-1206`). The public overloads are
  `getFeatureFlagResult(_:)` and `getFeatureFlagResult(_:sendFeatureFlagEvent:)`
  (`PostHog/PostHogSDK.swift:3310-3323`). A string value sets `enabled = !value.isEmpty` and keeps
  the string as `variant` (`PostHog/PostHogRemoteConfig.swift:1190-1192`), so `""` reads as disabled
  with variant `""`; `isFeatureEnabled` returns `!variant.isEmpty` for a string before it looks at the
  default (`PostHog/PostHogSDK.swift:3447-3453`) (posthog-ios#1037).
- **Backwards compatibility:** Malformed payloads changed from raw string to `nil` in 4.0 (changeset entry).

<a id="n9"></a>

### n9 — Get Feature Flags (🟡 Partial; was ❌)
- **Spec requires:** a cache-only bulk read of all flag values, no payloads (Behavior step 4), tracking
  suppressible. New since the last audit: the Surface variants record that "iOS (4.0+) ...
  `getAllFeatureFlags()` returns a list of flag result objects (key, enabled, variant, payload), or `null`
  when flags are unavailable, instead of a key-to-value map. It never sends `$feature_flag_called`."
  New on `main` (#193): each entry matches `getFeatureFlagResult` for that key, so a `""` flag stays in
  the list with `enabled: false` and `variant: ""`.
- **SDK currently:** `getAllFeatureFlags() -> [PostHogFeatureFlagResult]?` (`PostHog/PostHogSDK.swift:3469-3474`)
  maps every cached flag through `makeFeatureFlagResult` (`PostHog/PostHogRemoteConfig.swift:1168-1182`),
  makes no request and emits no event, so the cached-values and no-tracking scenarios hold in substance.
  It still deviates from the canonical shape (an array of result objects, not a key→value map) and
  returns payloads, which Behavior step 4 excludes. The internal flat map
  (`PostHogRemoteConfig.getFeatureFlags()`, `PostHog/PostHogRemoteConfig.swift:901-903`) stays internal.
  Each entry is built by the same `makeFeatureFlagResult` as `getFeatureFlagResult`, so the #193 scenario
  holds. The move to 🟡 follows the spec recording this shape.
- **Backwards compatibility:** Additive if a flat map getter is added.
- **Remediation:** None required beyond the recorded variant; optionally expose a flat
  `[String: Any]` getter for parity with posthog-js.

<a id="n10"></a>

### n10 — Get Feature Flags And Payloads (🟡 Partial; was ❌)
- **Spec requires:** one call returning flags and payloads; each payload decoded independently,
  malformed ones omitted or `nil` without dropping the flag value or siblings; a valid JSON `""` kept.
  New: the Description now says posthog-ios 4.0 returns per-flag result objects carrying the payload from
  `getAllFeatureFlags()` (see `get-feature-flags`).
- **SDK currently:** No paired-maps method. `getAllFeatureFlags()` (`PostHog/PostHogSDK.swift:3469-3474`)
  carries each flag's payload, decoded per entry by `decodePayload`
  (`PostHog/PostHogRemoteConfig.swift:1144-1152`, `:1168-1182`): malformed entries become `nil`, the flag
  value and sibling payloads are unaffected, and `"\"\""` decodes to `""`. The decoding requirement is now
  met; the shape is the recorded variant, not the canonical two-map return.
- **Backwards compatibility:** Additive if a paired API is added.
- **Remediation:** None required beyond the recorded variant; optionally add a two-map convenience.

<a id="n11"></a>

### n11 — Get Session ID (🟡 Partial)
- **Spec requires:** "Session id rotates after inactivity timeout": after the timeout `getSessionId()` returns a
  different id (or, per Lifecycle, no active session).
- **SDK currently:** Unchanged at 4.0.5. `getSessionId()` (`PostHog/PostHogSDK.swift:485-491`) reads with `readOnly: true`,
  and `PostHogSessionManager.getSessionId` returns the stored id before any expiry check
  (`PostHog/PostHogSessionManager.swift:115-118`; checks at `:120-137`). An expired id is returned until the next
  event or activity rotates it.
- **Backwards compatibility:** Backward-compatible for either fix.
- **Remediation:** In the read-only path, return `nil` when the activity or max-length threshold has expired, or
  get the scenario relaxed for read-only getters (Behavior step 5 already names iOS's read-only mode).

<a id="n12"></a>

### n12 — Group (✅ Pass)
- **SDK currently:** `group(type:key:groupProperties:options:)` returns early with a log when `type`
  or `key` is empty (`PostHog/PostHogSDK.swift:2834-2837`) before persisting or sending, as
  [#929](https://github.com/PostHog/posthog-ios/pull/929) (now merged) added. Storage, `$groups`
  attachment (`:883-889`) and flag reload on group change (`:2593-2618`) are unchanged.

<a id="n13"></a>

### n13 — Group Identify (✅ Pass)
- **Spec requires:** amended since `f238b16`: the `@client` scenario now expects group properties
  under `properties.$group_set` (`$group_set.plan`), and the Requirement says so explicitly. Blank
  type/key rejected.
- **SDK currently:** The private `groupIdentify` (`PostHog/PostHogSDK.swift:2621-2662`), called only
  from `group()`, nests sanitized properties under `$group_set` (`:2634-2641`); the `group()` guard
  covers blank type/key. The new server-delivery scenarios are `@server`.

<a id="n14"></a>

### n14 — Is Feature Enabled (✅ Pass; was 🟡)
- **Spec requires:** boolean mapping, suppressible tracking, and a caller-supplied `defaultValue`
  returned whenever the flag has no value; a flag value, including `false`, wins. The iOS surface
  variant now lists `isFeatureEnabled(_:defaultValue:)` and `isFeatureEnabled(_:defaultValue:sendFeatureFlagEvent:)`.
- **SDK currently:** Both overloads exist (`PostHog/PostHogSDK.swift:3412-3445`). The shared
  implementation returns `!variant.isEmpty` for a string, the `Bool` when present, else `defaultValue`
  (`PostHog/PostHogSDK.swift:3447-3453`). `$feature_flag_called` reports the flag's own value (`nil` when
  missing), never the default (`PostHog/PostHogSDK.swift:3336-3340`).
- **Backwards compatibility:** Additive (4.0 changeset).

<a id="n15"></a>

### n15 — Opt In (🟡 Partial)
- **Spec requires:** scenario "Opt out can clear local persistence when configured". New on `main`
  (#199): "Deferred crash reports honour consent at crash time": a crash reconstructed on a later
  launch is sent only if the SDK was opted in when it happened; a consented report found by an
  opted-out launch waits for opt-in; opting out stops the crash context from carrying identity.
- **SDK currently:** Unchanged gap. `optIn()`/`optOut()` (`PostHog/PostHogSDK.swift:3629-3725`) persist consent
  under `optOutLock` (unless `persistOptOut` is false) and install/uninstall integrations; `optOut()` takes no
  parameter and no config clears persisted identity or super properties on opt-out.
  Met (new on `main`, #138): "Opt-in restarts session replay in a new session" and "Opt-in restarts the
  session replay the app wanted at opt-out". `startSessionRecordingOnOptIn` starts from
  `config.sessionReplay` at setup (`:356`), so an app that launches opted out records on its first
  opt-in. `startSessionRecording` sets it (`:3856`), and `stopSessionRecording` clears it only when not
  opted out (`:3908`), so a stop while opted out doesn't block the restart. `optIn()` calls
  `sessionManager.startSession()` (`PostHog/PostHogSDK.swift:3653-3655`;
  `PostHog/PostHogSessionManager.swift:166`) before reinstalling, even when a linked flag then holds
  replay off, and afterwards stops replay the app had stopped or installs a manually started one
  (`PostHog/PostHogSDK.swift:3659-3666`).
  Met (#199): PLCrashReporter and the MetricKit memory reporter are enabled only by installing the
  error-tracking integration, which `setup()` skips while opted out (`PostHog/PostHogSDK.swift:359-368`)
  and `optIn()` runs (`:3657`). So a launch that starts opted out records no crash, and a report left
  by an opted-in process stays on disk until the integration installs on opt-in, then is sent
  (`PostHog/ErrorTracking/PostHogErrorTrackingAutoCaptureIntegration.swift:70-75`). The handler can't
  be torn down after a runtime opt-out, so `uninstall` replaces the crash context with only a
  `$opted_out` marker (`:119-124`; `PostHog/ErrorTracking/PostHogExceptionStepsBuffer.swift:156-163`),
  which also drops identity and event properties; the next install drops a report carrying it
  (`PostHogErrorTrackingAutoCaptureIntegration.swift:267-270`), and the memory reporter drops a
  marked diagnostic (`PostHog/ErrorTracking/PostHogMemoryExceptionReporter.swift:50-52`)
  ([PostHog/posthog-ios#1040](https://github.com/PostHog/posthog-ios/pull/1040)). Not verified: whether
  MetricKit still hands a consented memory diagnostic to a later opted-in launch after an opted-out
  launch has passed; the spec only asks for that "where the platform still holds it". Read from code;
  the acceptance scenarios were not run.
- **Backwards compatibility:** Backward-compatible with an optional parameter or config flag defaulting to today's
  behavior.
- **Remediation:** Add an optional clear-local-data parameter to `optOut()`.

<a id="n16"></a>

### n16 — Reset (🟡 Partial)
- **Spec requires:** reset clears user-scoped state including opt-out persistence.
- **SDK currently:** Unchanged at 4.0.5. `reset()` (`PostHog/PostHogSDK.swift:991` onward) clears identity, super properties,
  flags, the flag-called tracker (`:1017-1019`) and the session. `storage.reset` deletes the persisted `.optOut` key
  (`PostHog/PostHogStorage.swift:515`), but `reset()` never clears the in-memory `config.optOut` that
  `isOptOutState()` (`PostHog/PostHogSDK.swift:1494`) and `isOptOut()` (`:3773`) read, so an opted-out
  user stays opted out until the next launch.
- **Backwards compatibility:** Signature-compatible; runtime behavior for opted-out users who call `reset()`
  changes, so it needs a release note.
- **Remediation:** In `reset()`, when `persistOptOut` is true, set `config.optOut = false` under `optOutLock`, or
  get the spec to say only persisted state is cleared.

<a id="n17"></a>

### n17 — Shutdown (✅ Pass)
- **Spec requires:** flush pending events before tearing down workers (`@both` scenario). New (#135): where
  `shutdown` takes or defaults to a timeout, the timeout bounds the whole drain.
- **SDK currently:** `close()` (`PostHog/PostHogSDK.swift:3745-3817`) flushes the event, AI, replay and logs queues
  (`:3755-3758`) before stopping them (`:3760-3763`), stops reachability (`:3789`) and clears the flag-called
  tracker (`:3792-3794`). It is fire-and-forget and takes no timeout (spec surface variant: `close(): void`), so the
  timeout requirement does not apply. Like `flush()` it sends one batch per queue (n6); the doc comment says so.

<a id="n18"></a>

### n18 — Stop Session Recording (✅ Pass)
- **Spec requires:** `acceptance/public/stop-session-recording.feature` (`@client`): pending replay
  data is finalized before the recorder stops, and no new snapshots are captured. Spec unchanged
  since `f238b16`.
- **SDK currently:** `stopSessionRecording()` (`PostHog/PostHogSDK.swift:3900-3918`) ignores the
  call while disabled or opted out, stops the integration and clears the pending-start intent under
  `setupLock` (`:3906-3912`), then calls `replayQueue?.flush()` (`:3917`). Snapshots held by the
  minimum-duration/remote-config buffer stay held, as the ingestion controls require. Like `flush()`,
  it is one best-effort asynchronous flush.

<a id="n19"></a>

### n19 — Exception Event Metadata (🟡 Partial)
- **Landed at HEAD ([#931](https://github.com/PostHog/posthog-ios/pull/931), merged):** linkage ids
  and `type: "chained"`/`source: "cause"` on nested entries with no copied `handled`
  (`PostHog/ErrorTracking/PostHogExceptionProcessor.swift:310-332`); the 50-entry cap
  (`:18`, `:140`, `:193`); `$exception_source` `ios.crash_reporter`
  (`PostHog/ErrorTracking/PostHogCrashReportProcessor.swift:25`) and
  `ios.metrickit_memory_exception` (`PostHog/ErrorTracking/PostHogMemoryExceptionProcessor.swift:23,83`);
  `value: ""` for a reason-less `NSException` (`PostHogExceptionProcessor.swift:273-274`); UUID-less
  images skipped on the crash path (`PostHogCrashReportProcessor.swift:239-242`) and live path
  (`PostHog/ErrorTracking/Utils/PostHogDebugImageProvider.swift:99`); `$exception_list` and
  `$debug_images` protected from caller properties (`PostHog/PostHogSDK.swift:4330-4349` at 4.0.5).
- **Spec requires:** "Application property bags MUST NOT override SDK-owned `$exception_list`,
  `$exception_level`, `$exception_source`, `$debug_images`"
  (`openspec/specs/exception-event-metadata/spec.md:300`). New since `f238b16` (#123): active
  OpenTelemetry trace context as `$trace_id`/`$span_id` — server SDKs only; "Client SDKs, which have
  no ambient OpenTelemetry API, do not derive these properties", which iOS satisfies (no
  `$trace_id`/`$span_id` derivation in `PostHog/`).
- **SDK currently:** Unchanged at 4.0.5. `reservedExceptionPropertyKeys` holds only `$exception_list` and `$debug_images`
  (`PostHog/PostHogSDK.swift:4330-4333`), so caller properties still override `$exception_level`
  (hard-coded `"error"`, `PostHogExceptionProcessor.swift:108`) and `$exception_source`. This is
  deliberate: there is no typed level parameter, so the property bag is the only way to set a level,
  and posthog-android/posthog-js also let callers win.
- **Backwards compatibility:** Adding the two keys to the reserved set breaks callers who set a level
  through `properties:` today; it needs a typed `level:` parameter (additive) first, or a spec change.
- **Remediation:** Add a typed level (and optionally source) parameter to `captureException`, then
  reserve `$exception_level`/`$exception_source`.

<a id="n20"></a>

### n20 — Feature Flag Cache (✅ Pass; was 🟡)
- **Spec requires:** cached reads/writes, persistence, reset clearing; payload reads never expose invalid
  JSON as a raw string; already-decoded strings not decoded again; internal caches MAY stay serialized.
- **SDK currently:** Payloads stay serialized under `.enabledFeatureFlagPayloads`
  (`PostHog/PostHogRemoteConfig.swift:1000-1007`). Reads decode once and return `nil` on failure
  (`:1144-1152`). Bootstrap payloads are serialized before seeding, so they round-trip unchanged
  (`:953-964`). Reads make no network request; `clear()` empties the caches and bootstrap layer on reset
  (`:1307-1320`).
- **Backwards compatibility:** Behavior change for malformed and bootstrapped numeric/boolean-looking
  strings, shipped as 4.0 breaking entries.

<a id="n21"></a>

### n21 — Feature Flag Called Tracker (✅ Pass)
- **Spec requires:** dedupe per flag/value, clear on reset and shutdown, a server-gated minimal event whose
  allowlist covers session-attribution keys. New (#162): config-version-2 attribution and dedupe key for
  `/flags?v=4` records. New on `main`: "Client-level feature flag event default" (#153,
  `openspec/specs/feature-flag-called-tracker/spec.md:648`): every read resolves per-call option →
  client-level config → `true`, and a `false` decision "SHALL NOT consult or update the dedupe tracker".
  "A missing flag reports no value" (#202, `:198`): `$feature_flag_response` absent or `null`, never `""`.
  "Failed direct getter evaluations report evaluation_failed" (#211, `:595`).
- **SDK currently:** Line references at 4.0.5. Allowlist includes `$referring_domain`, the `utm_*` keys, `gad_source`, `mc_cid`,
  `gclid`, `fbclid` and `$feature_flag_error` (`PostHog/PostHogSDK.swift:3530-3573`); dedupe in `reportFeatureFlagCalled`
  (`:3575`ff), cleared on `reset()` (`:1017-1019`) and `close()` (`:3833-3835`); the minimal gate is
  persisted with the flags (`PostHog/PostHogRemoteConfig.swift:575`). #153: every getter routes through
  `getFeatureFlagResult`, which resolves `sendFeatureFlagEvent ?? config.sendFeatureFlagEvent`
  (`PostHog/PostHogSDK.swift:3373`) and only then calls the tracker, so a suppressed read leaves it
  untouched. #202: a missing flag sends `$feature_flag_response: NSNull()` (`:3606`), which the queue
  encoder omits, and an empty variant sends `""`. #211
  ([PostHog/posthog-ios#1059](https://github.com/PostHog/posthog-ios/pull/1059)): `getFeatureFlagErrors`
  reports `evaluation_failed` for a present `failed: true` record with no served value and
  `errors_while_computing_flags` from the persisted response bit (`PostHog/PostHogRemoteConfig.swift:931-943`),
  sent as `$feature_flag_error` (`PostHog/PostHogSDK.swift:3614-3616`); a failed record never becomes a
  value (`PostHog/PostHogRemoteConfig.swift:1325`), so the response is the missing sentinel. iOS requests `/flags?v=2`
  (`PostHog/PostHogApi.swift:595-599`), so config-version-2 records never reach it and the new
  attribution rules have nothing to act on (the spec: such an SDK "sees config version 2 flags as legacy
  values").

<a id="n22"></a>

### n22 — HTTP Client (✅ Pass)
- **Spec requires:** flags retry policy (transient transport errors incl. DNS/TLS; refused connections not
  retried; 502/504 only; one retry, 300 ms doubling) and (#81) gzip by default with an option that turns
  compression off for the whole client, raw JSON without `Content-Encoding` when off, and no silent
  downgrade after a server rejection. #146 at `d387ab79` excludes "a delivery lane that has its own
  compression setting (`capture-ai`, **AI lane configuration is scoped to the AI lane**)" from that
  opt-out, and its "Opting out covers every endpoint the SDK compresses" scenario skips such a lane.
- **SDK currently:** Flags retries: `isRetryableFlagsError` covers timeout, connection lost, not connected, DNS
  and TLS failures and leaves `CannotConnectToHost` out (`PostHog/PostHogApi.swift:732-749`); status retries are
  502/504 only (`:751-753`); `featureFlagRequestMaxRetries = 1` (`PostHog/PostHogConfig.swift:36`). Compression:
  `PostHogCompression` enum (`.gzip`/`.none`, `PostHog/PostHogCompression.swift`), `compression` defaults to
  `.gzip` (`PostHog/PostHogConfig.swift:491`); `requestAndPayload` sends the raw body with no `Content-Encoding`
  when off and falls back to raw only on a local gzip error (`PostHog/PostHogApi.swift:144-157`), used by capture
  v1, snapshot, logs and push (`:236`, `:474`, `:503`, `:579`). A server rejection is handed to the retry layer, not
  resent uncompressed. `captureAi` requests use their own `captureAiCompression`, also defaulting to `.gzip`
  (`PostHog/PostHogConfig.swift:484-496`, whose doc comment says so), which `uploadCaptureV1` passes for the AI
  path (`PostHog/PostHogApi.swift:234-240`). That is the per-lane setting #146 now allows, so
  `compression = .none` turning off every other request is the whole-client opt-out the spec asks for.
- **Met (#146, capture v1 transport):** capture v1 URLs, Bearer-only token and the full header set on
  every attempt; exactly `Content-Encoding: gzip`, with a raw fallback only on a local gzip error; no
  legacy encodings; same-origin 307/308 redirects only, at most 5; see [Capture v1](#capture-v1).

<a id="n23"></a>

### n23 — Persistent Storage (🟡 Partial)
- **Spec requires:** "Storage failures do not crash SDK calls" — no throw **and** a recorded storage warning.
- **SDK currently:** Unchanged at 4.0.5. Reads/writes are wrapped in `do`/`catch` (`PostHog/PostHogStorage.swift:366-374`,
  `:377-394`, `:397-425`), but a write failure only calls `hedgeLog` (`:394` at 4.0.5), which prints nothing unless debug is
  on (`PostHog/Utils/Hedgelog.swift:17-20`). 4.0 added `hedgeLogWarning` (always prints, `:22-25`) but storage does
  not use it.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** Log storage write failures with `hedgeLogWarning` (or another always-on signal).

<a id="n24"></a>

### n24 — Session Replay Privacy (🟡 Partial; was ❌)
- **Spec requires:** no-capture elements (`ph-no-capture`, `postHogMask()`) and all their descendants
  are masked even with broad masking off; screenshot replay paints masks before encoding and drops a
  frame whose masks are unreliable (Behavior 2, 4, 6; scenario "Replay privacy excludes no-capture
  elements"). Explicit unmask markers win over explicit mask markers (Interactions). New since
  `f238b16`: "Android secure windows are recorded fully masked" (sdk-specs #160), which states it
  "is not applicable on iOS".
- **SDK currently:** 4.0 always records masked screenshots; `screenshotMode` and
  `screenshotModeBackgroundCapture` survive only as unavailable stubs
  (`PostHog/PostHogRemovedAPIs.swift:112,126`), so the wireframe `toWireframe` path that leaked is
  gone. In the screenshot walk, a `ph-no-capture` view is masked whole and passes `maskChildren` to
  every descendant (`PostHog/Replay/PostHogReplayIntegration.swift:1077-1082`; `isNoCapture()` at
  `PostHog/Replay/UIView+Util.swift:76-78`). `collectMaskedRegions`
  (`PostHog/Replay/PostHogReplayIntegration.swift:1174-1200`) adds the SwiftUI `postHogMask()`
  registry regions (`PostHog/SwiftUI/PostHogMaskViewModifier.swift:62-117`) and returns nil — skipping
  the frame — while a reporter hasn't laid out, or when a camera layer is present. A frame whose
  masked render fails is dropped rather than sent raw (`PostHogReplayIntegration.swift:798-803`).
  `isNoMask()` is checked first (`:904-911`), so a `ph-no-capture` view inside a `ph-no-mask` subtree
  is not masked; the spec's "explicit unmask markers take precedence over explicit mask markers"
  allows that, and secure-entry fields stay masked there (`:908`, `findSecureTextEntries`).
  Gap: SwiftUI reverses that precedence. `postHogMask()` documents that "an explicit `postHogMask()`
  always masks its region, even inside an area marked with `postHogNoMask()` — the explicit mask wins"
  (`PostHog/SwiftUI/PostHogMaskViewModifier.swift:25-26`), `collectMaskedRegions` appends the registry's
  regions regardless of an enclosing no-mask (`PostHog/Replay/PostHogReplayIntegration.swift:1187-1200`),
  and `PostHogTests/PostHogMaskScenarioTest.swift:111-129` asserts a masked child inside a
  `postHogNoMask()` container stays masked. This over-masks; it does not leak.
  4.0.5: the documented SwiftUI precedence is unchanged (`PostHog/SwiftUI/PostHogMaskViewModifier.swift:25-26`
  at 4.0.5); the other line references in this note are at `e27cbe4cb`. Not audited (❓): the GPU
  capture path added since `e27cbe4cb` ([PostHog/posthog-ios#911](https://github.com/PostHog/posthog-ios/pull/911),
  [#966](https://github.com/PostHog/posthog-ios/pull/966) and masking fixes #1097, #1103, #1109,
  #1110, #1115), which is opt-in (`captureMethod = .gpu`; the default is `.standard`,
  `PostHog/Replay/PostHogSessionReplayConfig.swift:95`).
- **Gap (2026-11-24, sdk-specs change `add-mobile-remote-masking`): remote mobile masking.** The new
  requirements from "Mobile SDKs read dedicated mobile masking keys" (`openspec/specs/session-replay-privacy/spec.md:290`)
  onward say the SDK combines `maskAllTextInputs` and `maskAllImages` with
  `sessionRecording.masking.mobile` so the stricter side wins, applies the cached and live config per
  frame, drops frames not yet handed to the upload queue when a flag gets stricter, and exposes the resolved flags to wrappers. At
  `origin/main` `2702ea6364` nothing under `PostHog/` reads a `masking` key, so masking comes from
  local config only. Fix in progress:
  [#1124](https://github.com/PostHog/posthog-ios/pull/1124) (unmerged), which also stamps `RRScreenshotFrame.maskingGeneration` and drops a stale frame in
  `PostHogReplayQueue`.
- **Backwards compatibility:** The leak fix ships in 4.0's breaking replay change (screenshot-only),
  already called out in the changeset. Letting `postHogNoMask()` win would reveal content apps mask today.
- **Remediation:** None in the SDK is proposed for the SwiftUI precedence; revealing more content is not
  wanted. Either keep the row 🟡 or have the spec permit the conservative SwiftUI variant (explicit mask
  wins). For remote mobile masking, land [#1124](https://github.com/PostHog/posthog-ios/pull/1124).

<a id="n25"></a>

### n25 — Bootstrap (✅ Pass; was 🟡)
- **Spec requires:** (MAY) `bootstrap.sessionID` (UUIDv7) adopted as the session id, invalid values
  logged and replaced (`openspec/specs/bootstrap/spec.md:143-158`). Spec unchanged since the last audit.
- **SDK currently:** Every SHALL is met: flag seeding of enabled values only and complete replacement
  (`PostHog/PostHogRemoteConfig.swift:135-157`, `:953-964`), payloads now serialized once at seeding,
  bootstrap cleared on reset (`:1307-1320`). `PostHogBootstrapConfig` still has only `distinctId`,
  `isIdentifiedId`, `featureFlags` and `featureFlagPayloads` (`PostHog/PostHogBootstrapConfig.swift:28-52`),
  and `PostHogSessionManager.swift` never reads bootstrap. That omission is MAY-only, so it is not a gap
  (as on posthog-android n4).
- **Backwards compatibility:** Additive.
- **Remediation:** Optional `sessionID` with UUIDv7 validation, if parity with posthog-js is wanted.

<a id="n26"></a>

### n26 — Session Replay Debug Properties (🟡 Partial)
- **Fixed in 4.0:** (c) — PostHog/posthog-ios#932: `debugProperties()` reports `disabled` when the
  read-only session id is nil or empty, mirroring `isSessionReplayActive()`
  (`PostHog/Replay/PostHogReplayIntegration.swift:1710-1713`; getter at
  `PostHog/PostHogSDK.swift:3977-3989`). New spec text met: sdk-specs #155 made the debug keys follow
  capture's precedence (super property overrides the SDK value, caller property overrides both,
  per event only). 4.0 sets the debug keys among the SDK-owned values, then merges registered super
  properties, then caller properties (`PostHog/PostHogSDK.swift:842-896`).
- **Spec requires:** (a) `$sdk_debug_session_start` "MUST never describe" a different session than
  the event's own `$session_id`; for a caller-supplied id it comes from the UUIDv7 timestamp and is
  omitted for a non-v7 id (`openspec/specs/session-replay-debug-properties/spec.md:555-566`, scenario
  "Session keys are omitted for a non-UUIDv7 caller session id (mobile)" at `:704` on `752f899`). (b) An event
  timestamped before the current session's start carries the persisted snapshot or none of the keys
  (scenario "A previous-process crash carries no live debug state", `:1016-1022` on `752f899`).
- **New (#238, `openspec/specs/session-replay-debug-properties/spec.md:386`):** "The queue-depth key is
  attached only while the send queue is backed up". A mobile SDK SHOULD attach
  `$sdk_debug_pending_queue_size` at or above its flush threshold and MAY omit it below. "While the queue
  is not backed up, the SDK SHALL remove a registered or caller-supplied value of the same name …
  While the queue is backed up, the SDK-computed depth replaces such a value" (`:411-416`).
- **SDK currently (line references at 4.0.5):**
  - **(a) open.** `replayDebugSnapshot()` takes the start from
    `sessionManager.sessionStartTimestampSnapshot` (`PostHog/PostHogSDK.swift:777-788`, start at `:785`),
    even when `buildProperties` uses a caller-supplied `$session_id` (`:812-815`). There is no UUIDv7
    derivation or omission.
  - **(b) open.** `buildProperties` (`:790` onward) never compares `timestamp` with the session start,
    so a backdated `capture(..., timestamp:)` gets live `$recording_status`/`$sdk_debug_*` values.
    Crash and OOM reports still bypass `buildProperties` and use the persisted snapshot, so the crash
    arm of (b) is met; manual backdated captures are not.
  - **(d) met since [PostHog/posthog-ios#1090](https://github.com/PostHog/posthog-ios/pull/1090)**
    (shipped in 4.0.3). This is the requirement "Attach only the disabled shape while replay is
    intentionally off" (#232, 2026-11-18). The integration's `isReplayOff`
    (`PostHog/Replay/PostHogReplayIntegration.swift:465-476`) covers an explicit stop,
    `sessionReplay` off and not started manually, and a cached remote config with
    `sessionRecording == false` or the mobile recordings quota limit
    (`PostHog/PostHogRemoteConfig.swift:1435-1441`). While replay is off, `debugSnapshot()` returns only
    `$recording_status: disabled` (`PostHogReplayIntegration.swift:1859-1860`).
  - **(d), SDK side.** The no-integration fallback is now just `$recording_status: disabled`, and
    `$sdk_debug_session_start` is added only while replay is on (`PostHog/PostHogSDK.swift:777-788`).
    The same snapshot feeds the crash-context build (`readOnlySession`, `:874-880`) and the
    wrapper-deferred map (`:2251-2257`), and an event built while replay is off doesn't claim the
    bundle window (`:876`). Opt-out uninstalls the integration, so the fallback applies.
  - **Queue depth, partly met (#238).** Since
    [PostHog/posthog-ios#1102](https://github.com/PostHog/posthog-ios/pull/1102), the SDK sets
    `$sdk_debug_pending_queue_size` from `backedUpDepth` (`PostHog/PostHogSDK.swift:891`), which is nil
    when the depth is 0 or below `flushAt` (`PostHog/PostHogQueue.swift:145-150`). That meets the
    SHOULD/MAY. **Gap:** registered super properties (`PostHog/PostHogSDK.swift:896`) and caller
    properties (`:941`) are merged after it. So a registered or caller `$sdk_debug_pending_queue_size`
    is sent while the queue is healthy, and it beats the computed depth while the queue is backed up.
    No later step strips the key; the only other reference is the crash-context strip list (`:4473`).
    Read from code; not run.
- **Backwards compatibility:** Backward-compatible; internal property-build changes that only
  correct or remove diagnostic keys.
- **Remediation:** (a) When `propSessionId` is set and differs from the manager's id, derive the
  start from its UUIDv7 timestamp, or omit the key when it isn't v7. (b) Skip the required keys and
  the bundle when `timestamp` is earlier than the current session start. #238: after the caller merge
  in `buildProperties`, set `props["$sdk_debug_pending_queue_size"] = queue?.backedUpDepth` again (nil
  removes the key), so the SDK value wins either way.

<a id="n27"></a>

### n27 — Capture AI (🟡 Partial; was ✅, before that ➖)
- **Spec requires:** Applicability in merged [#146](https://github.com/PostHog/sdk-specs/pull/146)
  (`openspec/specs/capture-ai/spec.md:23`) covers "client SDKs on capture v1 that ship an AI method".
  The `d387ab79` text this row was first scored on named posthog-ios 4.0 explicitly; the merged
  revision (5d75baf) names only the server SDKs and keeps client rules in "Client SDKs:" notes. The AI
  method uses capture's event-building order and follows capture's null-property rule, which merged
  #146 made a MAY (4bd0b50; its omission scenarios are now `@null_property_omission_capable`). Client
  SDKs "MAY use a smaller queue, a disk cap and a longer timeout"; AI events ride their own lane to `/i/v1/ai/events` with their own queue,
  retry state and lane-scoped options; "client SDKs start their durable queue at launch" (Behavior 3);
  the whole serialized event is capped at 8 MiB + 64 KiB, a configured cap above that is clamped or
  refused, and batches are byte-aware at 5 MiB.
- **SDK currently (`PostHogSDK.swift` and `PostHogConfig.swift` line references at 4.0.5; the queue, API
  and endpoint files are unchanged since `e27cbe4cb`):**
  - **Met:** `captureAi` (`PostHog/PostHogSDK.swift:1733`) takes the same parameters as the fullest `capture` overload and returns the
    uuid; a non-`$ai_` name is sent with a debug log (`:2165`), and
    `capture` never reroutes `$ai_*` events. The lane has its own queue, retry state and request identity
    (keyed by path, `PostHog/PostHogApi.swift:75`). The AI queue starts at setup (`PostHogSDK.swift:314-319`),
    as Behavior 3 asks of client SDKs. `flush()` and `close()` signal both lanes. Options:
    `captureAiCompression` (gzip), `captureAiMaxQueueSize` (100), `captureAiTimeout` (60 s idle) and
    `captureAiMaxEventBytes` (`PostHog/PostHogConfig.swift:497-527`), plus a fixed 50 MiB disk cap. A cap
    above the ceiling is clamped with a log (`PostHog/QueueEndpoint+Factories.swift:64-68`); an event over
    it is dropped with a name-and-size log (`PostHog/PostHogQueue.swift:416-419`). Batches use the 5 MiB
    window. `captureAiCompression` is the lane's own compression setting, which `http-client` now
    leaves out of the whole-client opt-out ([n22](#n22)).
  - **Null properties:** `captureAi` builds properties like `capture`, and the AI queue's encoder and `captureV1JSON` drop null-valued members, as the MAY permits (#1047,
    `PostHog/QueueEndpoint+Factories.swift:79`; see [n4](#n4)).
  - **Not applicable:** the full-AI-capture flag, built-in AI integrations and the OpenTelemetry bridge;
    iOS ships none of them.
  - **Gap (#215):** `captureAi` (`PostHog/PostHogSDK.swift:1733-1755`) calls `captureInternal` (`:1932`), which runs `sanitizeDictionary` on the properties (`:2035`), so a `Set`/`NSSet` property is dropped exactly as in [n4](#n4). Shared `capture` gaps are scored on Capture AI too, as `posthog-flutter.md` n39 does.
- **Backwards compatibility:** `captureAi` is new in 4.0.
- **Remediation:** Fixed by [n4](#n4)'s `Set` conversion in `sanitizeInvalidValue`.

<a id="n28"></a>

### n28 — On Feature Flags (✅ Pass)
- **Spec requires:** new since the last audit (#94, #161): a failed non-quota load invokes listeners with
  the last known flags and `errorsLoading`; a runtime registration stays active across `close()`/`setup()`
  until unsubscribed ("Lifetime of a runtime listener registration"); and "Loads discarded by reset or
  close reach no listener": a load in flight when `reset()` or `close()` ran SHALL NOT be delivered nor
  replayed to a later listener. New on `main` (#193): "Empty variant is left out of the flags a listener
  receives", like a `false` flag.
- **SDK currently:** Failed loads deliver `featureFlags ?? current` with `errorsLoading: true`
  (`PostHog/PostHogSDK.swift:259-275`). Registrations live on the SDK's own multicast, survive
  `close()`/`setup()`, replay the latest value on register, and unsubscribe idempotently
  (`PostHog/PostHogSDK.swift:3196-3227`). `close()` nils `remoteConfig`, the relay token and the cached
  value (`PostHog/PostHogSDK.swift:3784-3786`). `reset()` clears the cache and `lastFeatureFlagsLoaded`
  and starts a reload (`PostHog/PostHogSDK.swift:1000-1006`); since
  [PostHog/posthog-ios#1048](https://github.com/PostHog/posthog-ios/pull/1048), `clear()` also bumps a
  reset generation (`PostHog/PostHogRemoteConfig.swift:1318-1319`) that each `/flags` load captures
  when it reads its identity (`:312-314`). A response from an older generation is dropped before and
  again under the cache lock (`:492-497`, `:556-558`), so it writes no cache and notifies no one; a
  queued notification from an older generation is dropped on the main queue (`:820-825`); and a
  request queued before the reset can't replace the post-reset one (`:460-464`). Nothing reaches
  `lastFeatureFlagsLoaded`, so nothing is replayed to a later listener. `PostHogFeatureFlagsLoaded`
  keeps only `true` booleans and non-empty strings in `flags` and `variants`
  (`PostHog/Models/PostHogFeatureFlagsLoaded.swift:42-56`), so a `""` flag is left out.

<a id="n29"></a>

### n29 — Surveys (✅ Pass)
- **Spec requires:** new requirement "Survey popup delay" (`openspec/specs/surveys/spec.md:321-417`,
  sdk-specs #121). Wait `appearance.surveyPopupDelaySeconds` (negative clamps to 0) before display;
  reserve the survey before the wait so repeats don't restart it or show a second survey. A survey
  not yet on screen hasn't been shown: if it is dropped before display (hidden/cancelled by the app,
  superseded, undisplayable) the SDK emits neither `survey shown` nor `survey dismissed`, doesn't
  mark it seen or write the last-seen date, and releases the reservation; also release on reset or
  surveys teardown. Host UI layers must report every survey as shown or closed, and "closing a survey
  before it was shown does not mark it seen and emits no interaction event". SHOULD re-check
  eligibility when the delay elapses. New on `main` (#102): "The survey wait period starts when a survey
  is shown": the device-wide last-seen survey date is written on show, and "Submit and dismiss SHALL NOT
  move the date"; `reset` clears it; a resumed in-progress survey is still gated by the wait period.
- **SDK currently:** All SHALLs are met since
  [PostHog/posthog-ios#1049](https://github.com/PostHog/posthog-ios/pull/1049).
  `showNextSurvey()` reserves the survey with `setActiveSurvey` before calling `renderSurvey`
  (`PostHog/Surveys/PostHogSurveyIntegration.swift:298-334`), and `canShowNextSurvey()` blocks a second
  survey while it is held (`:1018-1020`). The default delegate clamps the delay
  (`PostHog/Surveys/PostHogSurveysDefaultDelegate.swift:103`), shows immediately at 0, and otherwise
  schedules one `asyncAfter` (`:111-133`). `handleSurveyShown` marks the attempt shown, writes the
  last-seen date and sends `survey shown` (`PostHogSurveyIntegration.swift:529-550`, date at `:537`);
  a first answer from a delegate that never reported the show does the same (`:606-609`).
  `handleSurveyClosed` releases the reservation and returns, with no `setSurveySeen` and no
  `survey dismissed`, when the attempt was never shown (`:664-669`). `setSurveySeen` no longer writes
  the date (`:395-403`), so submit and dismiss don't move the wait period. `reset()` deletes the date
  (`PostHog/PostHogStorage.swift`) and calls `cancelPendingSurvey()` (`PostHog/PostHogSDK.swift:988-992`),
  which releases a reservation that was never shown and cancels the default delegate's pending display,
  or calls `cleanupSurveys()` on a custom delegate (`PostHogSurveyIntegration.swift:897-916`). `stop()`
  clears the active survey before `cleanupSurveys()` closes the pending one (`:117-126`), so teardown
  emits nothing. Resumed in-progress surveys still go through `hasWaitPeriodPassed` (`:151`, `:454`).
  Not scored (SHOULD): when the delay elapses, the default delegate's work item shows the reserved survey
  without re-checking eligibility (`PostHogSurveysDefaultDelegate.swift:115-130`), so, for example, an
  `identify` during the wait that turns the targeting flag off doesn't stop it.
- **Backwards compatibility:** Backward-compatible; a re-check would only skip surveys that are no
  longer eligible.
- **Remediation (optional, SHOULD):** Before the work item shows the survey, ask the integration to re-run its eligibility
  filter for that survey; when it fails, release the reservation (report the survey closed, which is
  now a no-op for an unshown survey) instead of displaying it.

<a id="n30"></a>

### n30 — Exception Steps (🟡 Partial; was ✅)
- **Spec requires:** "Normalize to the wire form once, before processing"
  (`openspec/specs/exception-steps/spec.md:154-164`): the step is normalized once, before it is
  byte-counted, buffered, persisted or attached, and these representations "SHALL be identical", with
  no second, divergent normalization at capture.
- **SDK currently:** `PostHogExceptionStepsBuffer.add` normalizes with `sanitizeDictionary`, measures
  that with `JSONSerialization`, stores and publishes it
  (`PostHog/ErrorTracking/PostHogExceptionStepsBuffer.swift:47-80`). `sanitizeDictionary` keeps
  `NSNull` (`PostHog/Utils/DictUtils.swift:48-64`, `:211-234`), and the crash custom-data writer
  serializes the steps as stored (`PostHogExceptionStepsBuffer.swift:168-176`). Capture attaches that
  snapshot as `$exception_steps` (`PostHog/PostHogSDK.swift:2027-2035`), then the analytics queue
  removes null object members recursively (`PostHog/QueueEndpoint+Factories.swift:48` →
  `PostHog/Models/PostHogEvent.swift:130-134` → `PostHog/Utils/DictUtils.swift:151-201`), and the
  capture v1 builder does it again (`PostHog/PostHogApi.swift:411`). A step with
  `properties: ["optional": NSNull()]` is byte-counted and persisted with `"optional": null` but sent
  without it. Null array elements are kept in both. Read from code; not run.
- **Backwards compatibility:** Backward-compatible; null members would stop using buffer budget.
- **Remediation:** Apply `droppingNullProperties`'s member cleanup to the step in
  `PostHogExceptionStepsBuffer.add`, after `sanitizeDictionary` and before measuring, and test that
  the buffered step equals the decoded queue and wire step.
