# posthog-ios — SDK Compliance

**Repo:** [PostHog/posthog-ios](https://github.com/PostHog/posthog-ios)
**Audited commit:** `e27cbe4cb0bf5958fe79a061783af2dfb1b17ab4` ([commit](https://github.com/PostHog/posthog-ios/commit/e27cbe4cb0bf5958fe79a061783af2dfb1b17ab4)) on the 4.0 release branch `chore/v4-remove-deprecated` ([PostHog/posthog-ios#873](https://github.com/PostHog/posthog-ios/pull/873)), before 4.0.0 is published — first audited on 2026-11-05 at `3460e534a`, re-checked on 2026-11-10 (see [Re-check](#re-check-2026-11-10))
**Audited against sdk-specs commit:** `752f899` plus [#146](https://github.com/PostHog/sdk-specs/pull/146) at `d387ab79` (capture v1, including #147's AI lane), treated as merged to `main`; first audited against `dd11a6b`
**Summary:** 45 ✅ · 13 🟡 · 1 ❌ · 10 ➖ (69 rows; previous audit 2026-10-08 at `f5cbe87c` + posthog-ios#924–#934 scored 38/16/4/6 on 64 rows)

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
of a build-target split. All file paths below are relative to the posthog-ios repo root, and every
line reference is at `e27cbe4cb`.

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

## Re-check (2026-11-10)

Re-checked at the 4.0 branch head `e27cbe4cb` against sdk-specs `752f899` and #146 at `d387ab79`.
Every line reference on this page is at `e27cbe4cb`.

- **Rows that changed status since the 2026-11-05 audit:** Capture, Capture AI and Capture Exception
  🟡→✅ ([PostHog/posthog-ios#1047](https://github.com/PostHog/posthog-ios/pull/1047) omits `NSNull`
  properties; [n4](#n4), [n5](#n5), [n27](#n27)); On Feature Flags 🟡→✅
  ([PostHog/posthog-ios#1048](https://github.com/PostHog/posthog-ios/pull/1048) drops loads in flight
  across `reset()`; [n28](#n28)). Surveys stays ✅:
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
[#146](https://github.com/PostHog/sdk-specs/pull/146) at `d387ab79`, treated as merged: Capture
([n4](#n4)), Capture AI ([n27](#n27)), Before Send Hook, Event Batcher, HTTP Client ([n22](#n22)) and
Retry Queue.

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
| 5 | Capture | ✅ | was 🟡; [n4]; capture v1 wire conforms (#146); empty event names dropped (also after `beforeSend`); `NSNull` properties omitted (#1047); own `$lib` pair filled after caller properties (#1050); empty variant left out of `$active_feature_flags` |
| 6 | Capture AI | ✅ | was ➖; #146 adds iOS 4.0 to Applicability; the AI lane conforms, including the `NSNull` cleanup (#1047) — [n27] |
| 7 | Capture Exception | ✅ | was 🟡; [n5]; `NSNull` custom properties omitted (#1047) |
| 8 | Create Person Profile | ➖ | unchanged — spec Applicability still says only the posthog-js family exposes it; no `createPersonProfile` in iOS |
| 9 | Debug | ✅ | |
| 10 | Exception Steps | ✅ | |
| 11 | Flush | 🟡 | [n6] |
| 12 | Get Anonymous ID | ✅ | |
| 13 | Get Distinct ID | ✅ | |
| 14 | Get Feature Flag | ✅ | per-call option is `sendFeatureFlagEvent` (#109) |
| 15 | Get Feature Flag Payload | ✅ | was 🟡; getter removed in 4.0, payload read through `getFeatureFlagResult` as the spec now permits — [n7] |
| 16 | Get Feature Flag Result | ✅ | was 🟡; malformed payload → `nil`; an empty variant reads as disabled (#193) — [n8] |
| 17 | Get Feature Flags | 🟡 | was ❌; spec now records `getAllFeatureFlags()`'s result list as the iOS 4.0 surface; empty variant entries read as disabled (#193) — [n9] |
| 18 | Get Feature Flags And Payloads | 🟡 | was ❌; spec now points iOS 4.0 at the payload-carrying `getAllFeatureFlags()` — [n10] |
| 19 | Evaluate Flags | ➖ | unchanged: still "applies to server SDKs"; #111/#85 additions are server snapshot reads |
| 20 | Get Session ID | 🟡 | [n11] |
| 21 | Group | ✅ | [n12] |
| 22 | Group Identify | ✅ | [n13] |
| 23 | Identify | ✅ | new #167 rule met: opt-out gates only the `$identify` event (`PostHog/PostHogSDK.swift:1225-1269`) |
| 24 | Is Feature Enabled | ✅ | was 🟡; `isFeatureEnabled(_:defaultValue:)` added — [n14] |
| 25 | Is Opt Out | ✅ | |
| 26 | Is Session Replay Active | ✅ | |
| 27 | On Feature Flags | ✅ | [n28]; new requirements met: loads in flight across `reset()` are dropped (#1048), empty variants left out of listener flags (#193) |
| 28 | Opt In | 🟡 | [n15]; deferred crash reports follow consent at crash time (#199, met) |
| 29 | Register | ✅ | SDK → registered → caller order (`PostHog/PostHogSDK.swift:838-917`); the SDK's own `$lib` pair fills last, the one exception (`:919-922`) |
| 30 | Reload Feature Flags | ✅ | |
| 31 | Reset | 🟡 | [n16] |
| 32 | Reset Group Properties For Flags | ✅ | |
| 33 | Reset Person Properties For Flags | ✅ | |
| 34 | Screen | ✅ | |
| 35 | Set Group Properties For Flags | ✅ | |
| 36 | Set Person Properties | ✅ | |
| 37 | Set Person Properties For Flags | ✅ | |
| 38 | Setup | ✅ | `projectToken` naming met (`PostHog/PostHogConfig.swift:62`); `apiKey` removed in a major, which the spec allows |
| 39 | Shutdown | ✅ | [n17]; the new timeout requirement (#135) applies only where shutdown takes a timeout |
| 40 | Start Session Recording | ✅ | |
| 41 | Stop Session Recording | ✅ | [n18] |
| 42 | Unregister | ✅ | |
| 43 | Application Lifecycle | ✅ | build-invariant rule met (`$app_build_xcode`/`$app_build_sdk` on install/update only); `version`/`build` dropped in 4.0. `$lib`/`$lib_version` stay on every enqueued event; on the wire see "Capture v1" above |
| 44 | Autocapture | ✅ | |
| 45 | Before Send Hook | ✅ | after the hook only the uuid is re-imposed (#146 allowance); `options` is non-optional, so the absent-options allowance doesn't arise; a throwing hook logs the event and exception name only, in debug mode |
| 46 | Consent Gating | ✅ | identify updates local state while opted out and only skips the event, matching #167; deferred crash reports follow consent at crash time (#199, [n15]) |
| 47 | Device ID Generator | ✅ | |
| 48 | Event Batcher | ✅ | byte-aware check-before-append batching at 5 MiB (`PostHog/PostHogQueue.swift:544-548`); no analytics per-event cap; a multi-event 413 halves the batch (client allowance) |
| 49 | Exception Event Metadata | 🟡 | [n19]; caller properties can still override `$exception_level`/`$exception_source`; trace context (#123) and job-retry handled state (#205) are server-only |
| 50 | Feature Flag Cache | ✅ | was 🟡; malformed → `nil`, bootstrap payloads decoded once — [n20] |
| 51 | Feature Flag Called Tracker | ✅ | [n21]; config-version-2 attribution (now `$feature_flag_variant_key`, #203) needs `/flags?v=4`, which iOS does not request |
| 52 | Flag Definition Loader | ➖ | unchanged: new keyless-provider and polling-opt-out requirements are server-only |
| 53 | HTTP Client | ✅ | [n22]; gzip by default; `compression = .none` turns compression off for every request except the AI lane, which has its own `captureAiCompression`, as #146 now allows |
| 54 | Local Feature Flag Evaluator | ➖ | unchanged: no local rule engine |
| 55 | Persistent Storage | 🟡 | [n23] |
| 56 | Remote Config | ✅ | |
| 57 | Retry Queue | ✅ | capture v1 status set; jitter factor `[0.75, 1.25)`, capped at 30 s, `Retry-After` floor applied after jitter, also on 2xx retries (`PostHog/PostHogQueue.swift:14-43`, `:247-256`); no attempt limit (client allowance); retries exclude new events (#180) |
| 58 | Session Manager | ✅ | |
| 59 | Session Replay Ingestion Controls | ✅ | |
| 60 | Session Replay Privacy | 🟡 | was ❌; 4.0 removes wireframe mode, the only path that leaked; SwiftUI `postHogMask()` wins over an enclosing `postHogNoMask()` (over-masks, not a leak) — [n24] |
| 61 | Surveys | ✅ | popup-delay (#121) and wait-period (#102) SHALLs met since #1049; the SHOULD eligibility re-check when the delay elapses is not met and not scored — [n29] |
| 62 | Bootstrap | 🟡 | [n25] |
| 63 | MCP Analytics | ➖ | Applicability is `server` add-on; no iOS package |
| 64 | Session Replay Debug Properties | 🟡 | [n26]; (c) fixed and new precedence rule (#155) met; (a), (b) still open |
| 65 | Experiment Exposure | ➖ | **new row**: applies to SDKs that read `/flags?v=4` records; iOS requests `v=2` (`PostHog/PostHogApi.swift:595-599`), so config-version-2 flags read as legacy values |
| 66 | AI Datasets | ➖ | **new row**: server SDKs only (personal API key); no iOS surface |
| 67 | AI Scorers | ➖ | **new row**: server SDKs only (personal API key); no iOS surface |
| 68 | Offline Evaluations | ➖ | **new row**: server SDKs only; no iOS surface |
| 69 | Emails | ➖ | **new row**: "Server SDKs only" — needs a secret key that must never reach a client |

## Notes

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

### n2 — Traces (❌ Fail)
- **Spec requires:** `startSpan`/`withSpan`, OTLP traces to `POST {host}/i/v1/traces`, shutdown flush, shared
  backoff, mobile context.
- **SDK currently:** Still not implemented: no `startSpan`, `withSpan`, `resourceSpans` or `i/v1/traces` anywhere
  under `PostHog/`; `PostHog/Tracing/` holds only `PostHogTracingHeadersIntegration.swift`.
- **Backwards compatibility:** Backward-compatible; net-new opt-in API.
- **Remediation:** Implement traces net-new, modeled on the logs pipeline.

### n3 — Alias (🟡 Partial)
- **Spec requires:** unchanged since the last audit. The `@client` scenario "Client alias links the
  current anonymous identity to a known identity" (`acceptance/public/alias.feature`) requires
  `properties.alias` and `properties.distinct_id` on `$create_alias`. The `@both` scenario "Alias is
  dropped when required identities are missing" requires a drop plus a validation warning. Behavior
  step 4 (`openspec/specs/alias/spec.md:73`) still says mobile helpers need not duplicate
  `distinct_id`, which conflicts with the scenario.
- **SDK currently:** `alias(_:options:)` (`PostHog/PostHogSDK.swift:2557-2592`) gained an `options`
  parameter in 4.0 but still builds `let props = ["alias": alias]` (`:2574`) with no `distinct_id`,
  and has no blank-alias guard, so `alias("")` is enqueued. The source id always resolves through
  `getDistinctId()` (`:2576`), so the missing-previous-id case can't happen.
- **Backwards compatibility:** Backward-compatible. Both fixes are additive.
- **Remediation:** Set `props["distinct_id"] = distinctId` (or fix the spec scenario to match
  Behavior step 4), and drop a blank alias with a log, as `identify()` does.

### n4 — Capture (✅ Pass; was 🟡)
- **Spec requires:** "Capture drops null-valued object properties" (`@both` scenarios): explicit
  nulls (`NSNull()`) omitted from custom properties recursively, null array elements kept at their
  index, emptied objects kept as `{}`, applied after `before_send` and on disk serialization.
  Behavior step 2 / Error handling: drop events with an empty or invalid name. "Caller-supplied event
  properties take precedence" (#114/#143, client order SDK → registered → caller, a caller value
  changes that event only), with `$lib`/`$lib_version` as its one exception in #146 at `d387ab79`:
  "Events name their own library" has every capture v1 SDK fill its own pair after every other layer
  and before `before_send` (both when `$lib` is unset, only the version when `$lib` is the SDK's own
  name, never the SDK's version on another library's `$lib`). New on `main` (#193): "Empty variant is
  not an active feature flag". "Event uuid is sent in canonical form" (#119) and "Client-level GeoIP
  control" (#131) are server requirements ("Client SDKs SHALL NOT require the option"); "Client-side
  capture rate limiting never loses tokens to a clock change" (#127) applies only to a client SDK that
  rate-limits captures (posthog-js).
- **SDK currently:**
  - **Empty event names are dropped.** `prepareCaptureEvent` checks after `beforeSend`
    (`PostHog/PostHogSDK.swift:2102-2109`) and `queueEvent` checks again for every path
    (`:2745-2751`), with a one-time warning (`:2664-2672`). Whitespace-only names still pass; the
    spec says "non-empty", so that is not flagged.
  - **Null-valued properties are omitted**
    ([PostHog/posthog-ios#1047](https://github.com/PostHog/posthog-ios/pull/1047)).
    `droppingNullProperties` (`PostHog/Utils/DictUtils.swift:151-201`) removes `NSNull` and boxed-`nil`
    members recursively, including dictionaries inside arrays and dictionaries with non-string keys;
    null array elements keep their index and an emptied dictionary stays `{}`. The analytics and AI
    queues apply it when an event is written to disk, after `beforeSend`
    (`PostHog/QueueEndpoint+Factories.swift:48`, `:79`; `PostHog/Models/PostHogEvent.swift:130-134`),
    and `captureV1JSON` applies it again at send (`PostHog/PostHogApi.swift:411`), which covers events
    queued by an earlier version. `$set`, `$set_once` and `$group_set` keep their nulls
    (`DictUtils.swift:139`), which `identify` and `group-identify` require (their scenarios keep
    `null` values in `$set` and `$group_set`). Replay snapshots are not cleaned; they are not capture
    events.
  - **Library identity.** `buildProperties` no longer merges `sdkInfo` as a context layer; after the
    caller's properties it calls `fillLibraryIdentity` (`PostHog/PostHogSDK.swift:699-710`,
    `:919-922`; [PostHog/posthog-ios#1050](https://github.com/PostHog/posthog-ios/pull/1050)). A missing,
    empty or non-string `$lib` gets both values, replacing a lone `$lib_version`; `$lib == "posthog-ios"`
    (or the wrapper's configured name) with no non-empty `$lib_version` gets the version; any other
    `$lib` is left alone. `beforeSend` runs after, on the filled values. So "Caller property overrides
    an SDK context property" (`$lib: custom-lib`) and the `@client` "Another library's $lib does not get
    the SDK's version" both hold. The memory-exception path with no saved context merges `sdkInfo`
    under its own properties (`PostHog/ErrorTracking/PostHogMemoryExceptionReporter.swift:74`), which
    has the same result because nothing else sets `$lib` there.
  - **Empty variant.** `dynamicContext` stamps `$feature/<key>` for every cached flag but adds a key to
    `$active_feature_flags` only when its value is not `false` and not `""`
    (`PostHog/PostHogSDK.swift:602-626`).
  - **Precedence:** SDK context and SDK-set values first, then `getRegisteredProperties()`
    (`PostHog/PostHogSDK.swift:874-875`), then caller properties (`:896-917`); SDK state is not
    changed by a caller value. iOS has no client-side capture rate limiter, so #127 does not apply.
    #119 and #131 are server-only (`config.disableGeoIp` still stamps `$geoip_disable`, `:848-850`).
    UTC millisecond timestamps, `before_send` before enqueue, and the ObjC-hook-exception drop are
    unchanged.
  - **Capture v1 (#146):** wire, headers, per-event results, options hoisting, `$lib`/`$lib_version`
    kept, session/window id lifting, blank distinct id fallback, timestamps (three fractional digits,
    a client allowance) and fail-open token; see [Capture v1](#capture-v1).
- **Backwards compatibility:** Shipped in the 4.0 changeset and `MIGRATION.md`: null-valued properties
  are no longer sent, and a caller's `$lib` no longer gets the SDK's `$lib_version`. `[String: Any]`
  types are unchanged.

### n5 — Capture Exception (✅ Pass; was 🟡)
- **Spec requires:** Applicability is now `both` (server delivery scenarios are `@server`). "Exception
  capture drops null-valued custom object properties" follows capture's null rule. "Ignored exception
  types" (optional) drops matching `$exception` events on every path and platform. New: "Fatal
  exception payloads keep their exception data" for a separate fatal-path serializer.
- **SDK currently:** Fixed since `f5cbe87c` ([#930](https://github.com/PostHog/posthog-ios/pull/930),
  merged): the matcher is platform-neutral
  (`PostHog/ErrorTracking/PostHogErrorTrackingAutoCaptureIntegration.swift:347-368`) and
  `captureInternal` applies it to every `$exception` (`PostHog/PostHogSDK.swift:1973-1981`); crash
  reports are filtered too (`PostHogErrorTrackingAutoCaptureIntegration.swift:292-296`).
  `captureExceptionEvent` (`PostHog/PostHogSDK.swift:4247-4261`) still merges caller properties as
  given, but every `$exception`, manual or from a crash report, goes through the analytics queue, whose
  encoder now drops null-valued members (#1047, see [n4](#n4)). The fatal-path requirement is met in
  effect: crash reports are processed on the next launch by `PostHogCrashReportProcessor`, which keeps
  every frame, and iOS frames carry no `chunk_id`.
- **Backwards compatibility:** Backward-compatible apart from the 4.0 null-property change in n4.

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

### n11 — Get Session ID (🟡 Partial)
- **Spec requires:** "Session id rotates after inactivity timeout": after the timeout `getSessionId()` returns a
  different id (or, per Lifecycle, no active session).
- **SDK currently:** Unchanged. `getSessionId()` (`PostHog/PostHogSDK.swift:483-489`) reads with `readOnly: true`,
  and `PostHogSessionManager.getSessionId` returns the stored id before any expiry check
  (`PostHog/PostHogSessionManager.swift:119-121`; checks at `:128-140`). An expired id is returned until the next
  event or activity rotates it.
- **Backwards compatibility:** Backward-compatible for either fix.
- **Remediation:** In the read-only path, return `nil` when the activity or max-length threshold has expired, or
  get the scenario relaxed for read-only getters (Behavior step 5 already names iOS's read-only mode).

### n12 — Group (✅ Pass)
- **SDK currently:** `group(type:key:groupProperties:options:)` returns early with a log when `type`
  or `key` is empty (`PostHog/PostHogSDK.swift:2834-2837`) before persisting or sending, as
  [#929](https://github.com/PostHog/posthog-ios/pull/929) (now merged) added. Storage, `$groups`
  attachment (`:883-889`) and flag reload on group change (`:2593-2618`) are unchanged.

### n13 — Group Identify (✅ Pass)
- **Spec requires:** amended since `f238b16`: the `@client` scenario now expects group properties
  under `properties.$group_set` (`$group_set.plan`), and the Requirement says so explicitly. Blank
  type/key rejected.
- **SDK currently:** The private `groupIdentify` (`PostHog/PostHogSDK.swift:2621-2662`), called only
  from `group()`, nests sanitized properties under `$group_set` (`:2634-2641`); the `group()` guard
  covers blank type/key. The new server-delivery scenarios are `@server`.

### n14 — Is Feature Enabled (✅ Pass; was 🟡)
- **Spec requires:** boolean mapping, suppressible tracking, and a caller-supplied `defaultValue`
  returned whenever the flag has no value; a flag value, including `false`, wins. The iOS surface
  variant now lists `isFeatureEnabled(_:defaultValue:)` and `isFeatureEnabled(_:defaultValue:sendFeatureFlagEvent:)`.
- **SDK currently:** Both overloads exist (`PostHog/PostHogSDK.swift:3412-3445`). The shared
  implementation returns `!variant.isEmpty` for a string, the `Bool` when present, else `defaultValue`
  (`PostHog/PostHogSDK.swift:3447-3453`). `$feature_flag_called` reports the flag's own value (`nil` when
  missing), never the default (`PostHog/PostHogSDK.swift:3336-3340`).
- **Backwards compatibility:** Additive (4.0 changeset).

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

### n16 — Reset (🟡 Partial)
- **Spec requires:** reset clears user-scoped state including opt-out persistence.
- **SDK currently:** Unchanged. `reset()` (`PostHog/PostHogSDK.swift:967-1024`) clears identity, super properties,
  flags, the flag-called tracker (`:993-995`) and the session. `storage.reset` deletes the persisted `.optOut` key
  (`PostHog/PostHogStorage.swift:514`), but `reset()` never clears the in-memory `config.optOut` that
  `isOptOutState()` (`PostHog/PostHogSDK.swift:1465-1471`) and `isOptOut()` (`:3732-3738`) read, so an opted-out
  user stays opted out until the next launch.
- **Backwards compatibility:** Signature-compatible; runtime behavior for opted-out users who call `reset()`
  changes, so it needs a release note.
- **Remediation:** In `reset()`, when `persistOptOut` is true, set `config.optOut = false` under `optOutLock`, or
  get the spec to say only persisted state is cleared.

### n17 — Shutdown (✅ Pass)
- **Spec requires:** flush pending events before tearing down workers (`@both` scenario). New (#135): where
  `shutdown` takes or defaults to a timeout, the timeout bounds the whole drain.
- **SDK currently:** `close()` (`PostHog/PostHogSDK.swift:3745-3817`) flushes the event, AI, replay and logs queues
  (`:3755-3758`) before stopping them (`:3760-3763`), stops reachability (`:3789`) and clears the flag-called
  tracker (`:3792-3794`). It is fire-and-forget and takes no timeout (spec surface variant: `close(): void`), so the
  timeout requirement does not apply. Like `flush()` it sends one batch per queue (n6); the doc comment says so.

### n18 — Stop Session Recording (✅ Pass)
- **Spec requires:** `acceptance/public/stop-session-recording.feature` (`@client`): pending replay
  data is finalized before the recorder stops, and no new snapshots are captured. Spec unchanged
  since `f238b16`.
- **SDK currently:** `stopSessionRecording()` (`PostHog/PostHogSDK.swift:3900-3918`) ignores the
  call while disabled or opted out, stops the integration and clears the pending-start intent under
  `setupLock` (`:3906-3912`), then calls `replayQueue?.flush()` (`:3917`). Snapshots held by the
  minimum-duration/remote-config buffer stay held, as the ingestion controls require. Like `flush()`,
  it is one best-effort asynchronous flush.

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
  `$debug_images` protected from caller properties (`PostHog/PostHogSDK.swift:4242-4257`).
- **Spec requires:** "Application property bags MUST NOT override SDK-owned `$exception_list`,
  `$exception_level`, `$exception_source`, `$debug_images`"
  (`openspec/specs/exception-event-metadata/spec.md:300`). New since `f238b16` (#123): active
  OpenTelemetry trace context as `$trace_id`/`$span_id` — server SDKs only; "Client SDKs, which have
  no ambient OpenTelemetry API, do not derive these properties", which iOS satisfies (no
  `$trace_id`/`$span_id` derivation in `PostHog/`).
- **SDK currently:** `reservedExceptionPropertyKeys` holds only `$exception_list` and `$debug_images`
  (`PostHog/PostHogSDK.swift:4242-4245`), so caller properties still override `$exception_level`
  (hard-coded `"error"`, `PostHogExceptionProcessor.swift:108`) and `$exception_source`. This is
  deliberate: there is no typed level parameter, so the property bag is the only way to set a level,
  and posthog-android/posthog-js also let callers win.
- **Backwards compatibility:** Adding the two keys to the reserved set breaks callers who set a level
  through `properties:` today; it needs a typed `level:` parameter (additive) first, or a spec change.
- **Remediation:** Add a typed level (and optionally source) parameter to `captureException`, then
  reserve `$exception_level`/`$exception_source`.

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

### n21 — Feature Flag Called Tracker (✅ Pass)
- **Spec requires:** dedupe per flag/value, clear on reset and shutdown, a server-gated minimal event whose
  allowlist covers session-attribution keys. New (#162): config-version-2 attribution and dedupe key for
  `/flags?v=4` records.
- **SDK currently:** Allowlist includes `$referring_domain`, the `utm_*` keys, `gad_source`, `mc_cid`,
  `gclid`, `fbclid` (`PostHog/PostHogSDK.swift:3493-3536`); dedupe in `reportFeatureFlagCalled`
  (`:3538`ff), cleared on `reset()` (`:993-995`) and `close()` (`:3792-3794`); the minimal gate is
  persisted with the flags (`PostHog/PostHogRemoteConfig.swift:570`). iOS requests `/flags?v=2`
  (`PostHog/PostHogApi.swift:595-599`), so config-version-2 records never reach it and the new
  attribution rules have nothing to act on (the spec: such an SDK "sees config version 2 flags as legacy
  values").

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

### n23 — Persistent Storage (🟡 Partial)
- **Spec requires:** "Storage failures do not crash SDK calls" — no throw **and** a recorded storage warning.
- **SDK currently:** Unchanged. Reads/writes are wrapped in `do`/`catch` (`PostHog/PostHogStorage.swift:366-374`,
  `:377-394`, `:397-425`), but a write failure only calls `hedgeLog` (`:393`), which prints nothing unless debug is
  on (`PostHog/Utils/Hedgelog.swift:17-20`). 4.0 added `hedgeLogWarning` (always prints, `:22-25`) but storage does
  not use it.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** Log storage write failures with `hedgeLogWarning` (or another always-on signal).

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
- **Backwards compatibility:** The leak fix ships in 4.0's breaking replay change (screenshot-only),
  already called out in the changeset. Letting `postHogNoMask()` win would reveal content apps mask today.
- **Remediation:** None in the SDK is proposed; revealing more content is not wanted. Either keep the row
  🟡 or have the spec permit the conservative SwiftUI variant (explicit mask wins).

### n25 — Bootstrap (🟡 Partial)
- **Spec requires:** (MAY) `bootstrap.sessionID` (UUIDv7) adopted as the session id, invalid values
  logged and replaced (`openspec/specs/bootstrap/spec.md:143-158`). Spec unchanged since the last audit.
- **SDK currently:** Every SHALL is met: flag seeding of enabled values only and complete replacement
  (`PostHog/PostHogRemoteConfig.swift:135-157`, `:953-964`), payloads now serialized once at seeding,
  bootstrap cleared on reset (`:1307-1320`). `PostHogBootstrapConfig` still has only `distinctId`,
  `isIdentifiedId`, `featureFlags` and `featureFlagPayloads` (`PostHog/PostHogBootstrapConfig.swift:28-52`),
  and `PostHogSessionManager.swift` never reads bootstrap. 🟡 for the matrix convention on this MAY.
- **Backwards compatibility:** Additive.
- **Remediation:** Optional `sessionID` with UUIDv7 validation, if parity with posthog-js is wanted.

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
  omitted for a non-v7 id (`openspec/specs/session-replay-debug-properties/spec.md:550-561`, scenario
  "Session keys are omitted for a non-UUIDv7 caller session id (mobile)" at `:704` on `752f899`). (b) An event
  timestamped before the current session's start carries the persisted snapshot or none of the keys
  (scenario "A previous-process crash carries no live debug state", `:1016-1022` on `752f899`).
- **SDK currently:** (a) `replayDebugProperties()` always takes the start from
  `sessionManager.sessionStartTimestampSnapshot` (`PostHog/PostHogSDK.swift:764-766`), even when
  `buildProperties` uses a caller-supplied `$session_id` (`:791-794`); no UUIDv7 derivation or
  omission. (b) `buildProperties` (`:770` onward) never compares `timestamp` with the session start,
  so a backdated `capture(..., timestamp:)` gets live `$recording_status`/`$sdk_debug_*` values.
  Crash and OOM reports still bypass `buildProperties` and use the persisted snapshot, so the crash
  arm of (b) is met; manual backdated captures are not.
- **Backwards compatibility:** Backward-compatible; internal property-build changes that only
  correct or remove diagnostic keys.
- **Remediation:** (a) When `propSessionId` is set and differs from the manager's id, derive the
  start from its UUIDv7 timestamp, or omit the key when it isn't v7. (b) Skip the required keys and
  the bundle when `timestamp` is earlier than the current session start.

### n27 — Capture AI (✅ Pass; was ➖)
- **Spec requires:** [#146](https://github.com/PostHog/sdk-specs/pull/146) at `d387ab79` (with #147's
  text) adds "posthog-ios 4.0 and posthog-android 4.0 (`captureAi`)" to Applicability. The AI method
  uses capture's event-building order and "SHALL follow capture's 'Capture drops null-valued object
  properties' requirement"; AI events ride their own lane to `/i/v1/ai/events` with their own queue,
  retry state and lane-scoped options; "client SDKs start their durable queue at launch" (Behavior 3);
  the whole serialized event is capped at 8 MiB + 64 KiB, a configured cap above that is clamped or
  refused, and batches are byte-aware at 5 MiB.
- **SDK currently:**
  - **Met:** `captureAi` takes the same parameters as the fullest `capture` overload and returns the
    uuid; a non-`$ai_` name is sent with a debug log (`PostHog/PostHogSDK.swift:2137-2141`), and
    `capture` never reroutes `$ai_*` events. The lane has its own queue, retry state and request identity
    (keyed by path, `PostHog/PostHogApi.swift:75`). The AI queue starts at setup (`PostHogSDK.swift:314-332`),
    as Behavior 3 asks of client SDKs. `flush()` and `close()` signal both lanes. Options:
    `captureAiCompression` (gzip), `captureAiMaxQueueSize` (100), `captureAiTimeout` (60 s idle) and
    `captureAiMaxEventBytes` (`PostHog/PostHogConfig.swift:483-516`), plus a fixed 50 MiB disk cap. A cap
    above the ceiling is clamped with a log (`PostHog/QueueEndpoint+Factories.swift:64-68`); an event over
    it is dropped with a name-and-size log (`PostHog/PostHogQueue.swift:416-419`). Batches use the 5 MiB
    window. `captureAiCompression` is the lane's own compression setting, which `http-client` now
    leaves out of the whole-client opt-out ([n22](#n22)).
  - **Null properties:** `captureAi` builds properties like `capture` (`PostHogSDK.swift:1703-1730`,
    `:2005`), and the AI queue's encoder and `captureV1JSON` drop null-valued members (#1047,
    `PostHog/QueueEndpoint+Factories.swift:79`; see [n4](#n4)).
  - **Not applicable:** the full-AI-capture flag, built-in AI integrations and the OpenTelemetry bridge;
    iOS ships none of them.
- **Backwards compatibility:** `captureAi` is new in 4.0.

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
