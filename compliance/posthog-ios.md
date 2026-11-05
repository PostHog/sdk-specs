# posthog-ios — SDK Compliance

**Repo:** [PostHog/posthog-ios](https://github.com/PostHog/posthog-ios)
**Audited commit:** `3460e534a9d07bc8e826205d27d68cafaf1294ff` ([commit](https://github.com/PostHog/posthog-ios/commit/3460e534a9d07bc8e826205d27d68cafaf1294ff)) on the 4.0 release branch `chore/v4-remove-deprecated` ([PostHog/posthog-ios#873](https://github.com/PostHog/posthog-ios/pull/873)) — audited on 2026-11-05, before 4.0.0 is published
**Audited against sdk-specs commit:** `dd11a6b`
**Summary:** 40 ✅ · 17 🟡 · 1 ❌ · 11 ➖ (69 rows; previous audit 2026-10-08 at `f5cbe87c` + posthog-ios#924–#934 scored 38/16/4/6 on 64 rows)

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
line reference is at `3460e534a`.

This audit re-verified all 64 existing rows against the 4.0 branch (119 posthog-ios commits since
`f5cbe87c`, including capture v1 [#938](https://github.com/PostHog/posthog-ios/pull/938) and the
fixes from #924–#934, which are now merged) and current specs (48 sdk-specs commits since `f238b16`),
and adds five rows for contracts added to the README table since then: **Experiment Exposure**, **AI
Datasets**, **AI Scorers**, **Offline Evaluations** and **Emails** (all ➖).

Net changes vs. the previous audit:
- **Improved (7):** Get Feature Flag Payload 🟡→✅ (4.0 removes `getFeatureFlagPayload(_:)`; payloads
  are read with `getFeatureFlagResult(_:sendFeatureFlagEvent: false)?.payload`, which the new "Payload
  reads through the flag result getter" requirement permits), Get Feature Flag Result and Feature Flag
  Cache 🟡→✅ (a malformed, empty or whitespace-only payload is `nil`; bootstrapped payloads are decoded
  once), Is Feature Enabled 🟡→✅ (`isFeatureEnabled(_:defaultValue:)`), Session Replay Privacy ❌→✅
  (4.0 records masked screenshots only, so the leaking wireframe path is gone), Get Feature Flags and
  Get Feature Flags And Payloads ❌→🟡 (the specs now record iOS 4.0's `getAllFeatureFlags()` list of
  results, with per-entry payload decoding, as its surface; it is still not the canonical map shape).
- **New spec requirements unmet (3):** On Feature Flags ✅→🟡 (a `/flags` load in flight across
  `reset()` still reaches listeners), Surveys ✅→🟡 (popup delay: a close reported before display
  marks the survey seen and sends `survey dismissed`; `reset()` doesn't cancel a pending delayed display)
  and HTTP Client ✅→🟡 (`compression = .none` leaves `captureAi` requests gzipped, so there is no
  whole-client opt-out).
- **Note-only changes:** Capture stays 🟡, but empty event names are now dropped; only the `NSNull`
  gap remains. Capture AI stays ➖ because its Applicability is still `server`, but iOS 4.0 now ships
  `captureAi` on `/i/v1/ai/events`; [n27] records its conformance. Shutdown, HTTP Client, Group, Group
  Identify, Stop Session Recording and Feature Flag Called Tracker no longer depend on pending PRs.
  New requirements met without a status change: jittered retry backoff (Retry Queue), identify while opted out (Identify, Consent Gating),
  `$group_set` nesting (Group Identify), caller-property precedence (Capture, Register, Session Replay
  Debug Properties), build-invariant lifecycle properties (Application Lifecycle).

## Capture v1 (informational, not scored)

4.0 sends analytics events through capture v1. The capture v1 contract is still in open
[PostHog/sdk-specs#146](https://github.com/PostHog/sdk-specs/pull/146), so no row is scored against it;
this records what the audited branch does so the next audit can score it once #146 merges:

- `POST /i/v1/analytics/events` with `Authorization: Bearer <projectToken>` (set after custom
  `requestHeaders`), `PostHog-Sdk-Info`, `PostHog-Attempt`, `PostHog-Request-Id` and
  `PostHog-Request-Timestamp` headers, and a `{created_at, batch}` body (`PostHog/PostHogApi.swift:198-246`).
- After `beforeSend`, `captureV1JSON` (`PostHog/PostHogApi.swift:386-414`) hoists `$process_person_profile`,
  `$cookieless_mode`, `$ignore_sent_at` and `$product_tour_id` into `options`, lifts string
  `$session_id`/`$window_id` to top-level `session_id`/`window_id`, and removes `$lib`/`$lib_version`
  from `properties` (`:388-389`). Open [PostHog/posthog-ios#1036](https://github.com/PostHog/posthog-ios/pull/1036)
  (4.0 release blocker) stops removing them, so 4.0.0 will send per-event `$lib`/`$lib_version` as 3.x
  did; that differs from #146's "Library identity comes from the request header" as drafted.
- Matches #146: retried statuses (404/408/429/500/502/503/504 and network errors), `Retry-After` as a
  floor clamped to 30 s, byte-aware 5 MiB batches, same-origin 307/308 redirects only, and the client-SDK
  retry policy #146 names iOS 4.0 for: a durable queue with no attempt limit, 1–30 s jittered backoff, and
  halving a multi-event batch on 413 (a single-event 413 is terminal).
- `captureAi` sends AI events on their own lane to `POST /i/v1/ai/events` (see [n27]).

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Logs | 🟡 | [n1]; `close()` flush, empty-key skip and capped `Retry-After` now met; non-finite floats still dropped, one batch per flush |
| 2 | Traces | ❌ | [n2] |
| 3 | Tracing Headers | ✅ | new server span-context bridge requirements (#129) are `@server` only |
| 4 | Alias | 🟡 | [n3] |
| 5 | Capture | 🟡 | [n4]; empty event names now dropped (also after `beforeSend`); `NSNull` still sent as JSON `null` |
| 6 | Capture AI | ➖ | Applicability still `server`; iOS 4.0 ships `captureAi` on `/i/v1/ai/events` and meets Behavior 1, 2, 4 and Error handling, with its AI queue started at setup rather than lazily — [n27] |
| 7 | Capture Exception | 🟡 | [n5]; `NSNull` custom properties still sent as JSON `null` |
| 8 | Create Person Profile | ➖ | unchanged — spec Applicability still says only the posthog-js family exposes it; no `createPersonProfile` in iOS |
| 9 | Debug | ✅ | |
| 10 | Exception Steps | ✅ | |
| 11 | Flush | 🟡 | [n6] |
| 12 | Get Anonymous ID | ✅ | |
| 13 | Get Distinct ID | ✅ | |
| 14 | Get Feature Flag | ✅ | per-call option is `sendFeatureFlagEvent` (#109) |
| 15 | Get Feature Flag Payload | ✅ | was 🟡; getter removed in 4.0, payload read through `getFeatureFlagResult` as the spec now permits — [n7] |
| 16 | Get Feature Flag Result | ✅ | was 🟡; malformed payload → `nil` — [n8] |
| 17 | Get Feature Flags | 🟡 | was ❌; spec now records `getAllFeatureFlags()`'s result list as the iOS 4.0 surface — [n9] |
| 18 | Get Feature Flags And Payloads | 🟡 | was ❌; spec now points iOS 4.0 at the payload-carrying `getAllFeatureFlags()` — [n10] |
| 19 | Evaluate Flags | ➖ | unchanged: still "applies to server SDKs"; #111/#85 additions are server snapshot reads |
| 20 | Get Session ID | 🟡 | [n11] |
| 21 | Group | ✅ | [n12] |
| 22 | Group Identify | ✅ | [n13] |
| 23 | Identify | ✅ | new #167 rule met: opt-out gates only the `$identify` event (`PostHog/PostHogSDK.swift:1155-1199`) |
| 24 | Is Feature Enabled | ✅ | was 🟡; `isFeatureEnabled(_:defaultValue:)` added — [n14] |
| 25 | Is Opt Out | ✅ | |
| 26 | Is Session Replay Active | ✅ | |
| 27 | On Feature Flags | 🟡 | was ✅; new requirement "Loads discarded by reset or close reach no listener" fails for `reset()` — [n28] |
| 28 | Opt In | 🟡 | [n15] |
| 29 | Register | ✅ | SDK → registered → caller order (`PostHog/PostHogSDK.swift:822-901`) |
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
| 45 | Before Send Hook | ✅ | |
| 46 | Consent Gating | ✅ | identify updates local state while opted out and only skips the event, matching #167 |
| 47 | Device ID Generator | ✅ | |
| 48 | Event Batcher | ✅ | capture v1 adds byte-aware check-before-append batching at 5 MiB (`PostHog/PostHogQueue.swift:544-548`) |
| 49 | Exception Event Metadata | 🟡 | [n19]; caller properties can still override `$exception_level`/`$exception_source`; trace context (#123) is server-only |
| 50 | Feature Flag Cache | ✅ | was 🟡; malformed → `nil`, bootstrap payloads decoded once — [n20] |
| 51 | Feature Flag Called Tracker | ✅ | [n21]; config-version-2 attribution needs `/flags?v=4`, which iOS does not request |
| 52 | Flag Definition Loader | ➖ | unchanged: new keyless-provider and polling-opt-out requirements are server-only |
| 53 | HTTP Client | 🟡 | was ✅; [n22]; gzip by default, but `compression = .none` doesn't turn off `captureAi` compression, so the opt-out is not whole-client |
| 54 | Local Feature Flag Evaluator | ➖ | unchanged: no local rule engine |
| 55 | Persistent Storage | 🟡 | [n23] |
| 56 | Remote Config | ✅ | |
| 57 | Retry Queue | ✅ | new jitter requirement met: factor `[0.75, 1.25)`, capped at 30 s, `Retry-After` floor applied after jitter (`PostHog/PostHogQueue.swift:14-43`, `:247-256`) |
| 58 | Session Manager | ✅ | |
| 59 | Session Replay Ingestion Controls | ✅ | |
| 60 | Session Replay Privacy | ✅ | was ❌; 4.0 removes wireframe mode, the only path that leaked — [n24] |
| 61 | Surveys | 🟡 | was ✅; new popup-delay requirement (#121) — [n29] |
| 62 | Bootstrap | 🟡 | [n25] |
| 63 | MCP Analytics | ➖ | Applicability is `server` add-on; no iOS package |
| 64 | Session Replay Debug Properties | 🟡 | [n26]; (c) fixed and new precedence rule (#155) met; (a), (b) still open |
| 65 | Experiment Exposure | ➖ | **new row**: applies to SDKs that read `/flags?v=4` records; iOS requests `v=2` (`PostHog/PostHogApi.swift:596-600`), so config-version-2 flags read as legacy values |
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
- **SDK currently:** Met: `close()` flushes the logs queue (`PostHog/PostHogSDK.swift:3685-3688`); empty keys are
  skipped with a log (`PostHog/Logs/PostHogLogsOTLP.swift:86-95`); `Retry-After` is a floor clamped to
  `min(30 s, 5 min)`, so 30 s (`PostHog/PostHogQueue.swift:247-253`, `PostHog/QueueEndpoint+Factories.swift:14-17`);
  the logs request goes through the shared compression switch (`PostHog/PostHogApi.swift:504`, `:144-157`). Still
  open: (1) NaN/±Inf attributes are dropped before the encoder sees them — `toStorageJSON` runs attributes through
  `sanitizeDictionary` (`PostHog/Logs/PostHogLogRecord.swift:126-128`), whose `isValidObject` rejects non-finite
  numbers (`PostHog/Utils/DictUtils.swift:145-157`) and `sanitizeInvalidValue` has no conversion for them
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
- **SDK currently:** `alias(_:options:)` (`PostHog/PostHogSDK.swift:2487-2522`) gained an `options`
  parameter in 4.0 but still builds `let props = ["alias": alias]` (`:2504`) with no `distinct_id`,
  and has no blank-alias guard, so `alias("")` is enqueued. The source id always resolves through
  `getDistinctId()` (`:2506`), so the missing-previous-id case can't happen.
- **Backwards compatibility:** Backward-compatible. Both fixes are additive.
- **Remediation:** Set `props["distinct_id"] = distinctId` (or fix the spec scenario to match
  Behavior step 4), and drop a blank alias with a log, as `identify()` does.

### n4 — Capture (🟡 Partial)
- **Spec requires:** "Capture drops null-valued object properties" (`@both` scenarios): explicit
  nulls (`NSNull()`) omitted from custom properties recursively, null array elements kept at their
  index, emptied objects kept as `{}`, applied after `before_send` and on disk serialization.
  Behavior step 2 / Error handling: drop events with an empty or invalid name. New since `f238b16`:
  "Caller-supplied event properties take precedence" (#114/#143, client order SDK → registered →
  caller, a caller value changes that event only); "Event uuid is sent in canonical form" (#119) and
  "Client-level GeoIP control" (#131) are server requirements ("Client SDKs SHALL NOT require the
  option"); "Client-side capture rate limiting never loses tokens to a clock change" (#127) applies
  only to a client SDK that rate-limits captures (posthog-js).
- **SDK currently:**
  - **Fixed: empty event names are dropped.** `prepareCaptureEvent` checks after `beforeSend`
    (`PostHog/PostHogSDK.swift:2032-2039`) and `queueEvent` checks again for every path
    (`:2675-2681`), with a one-time warning (`:2594-2602`). Whitespace-only names still pass; the
    spec says "non-empty", so that is not flagged.
  - **Still open: nulls are serialized as JSON `null`.** `sanitizeDictionary`
    (`PostHog/Utils/DictUtils.swift:48-66`) keeps any value `isValidObject` accepts, and
    `isValidObject` (`:145-166`) falls through to `JSONSerialization.isValidJSONObject([object])`,
    which is true for `NSNull`. `captureV1JSON` (`PostHog/PostHogApi.swift:386-414`) copies
    `properties` as-is. The only `NSNull` filtering on events is for a caller `$session_id`
    (`PostHog/PostHogSDK.swift:887-890`); `isNullValue` (`DictUtils.swift:137-142`) is used only for
    options.
  - **Met:** property precedence — SDK context and SDK-set values first, then
    `getRegisteredProperties()` (`PostHog/PostHogSDK.swift:858-859`), then caller properties
    (`:880-901`); SDK state is not changed by a caller value. iOS has no client-side capture rate
    limiter, so #127 does not apply. #119 and #131 are server-only (`config.disableGeoIp` still stamps
    `$geoip_disable`, `:830-832`). UTC millisecond timestamps, `before_send` before enqueue, and the
    ObjC-hook-exception drop are unchanged.
  - **Capture v1 wire (informational, not scored — the capture v1 contract is still in open
    PostHog/sdk-specs#146):** 4.0 sends analytics events to `POST /i/v1/analytics/events`
    (`PostHog/PostHogApi.swift:198-213`) with `Authorization: Bearer <projectToken>` set after custom
    headers (`:242`), `PostHog-Sdk-Info: <name>/<version>`, `PostHog-Attempt`, `PostHog-Request-Id` and
    `PostHog-Request-Timestamp` (`:243-246`), and a `{created_at, batch}` body (`:224-227`).
    `captureV1JSON` (`:386-414`) runs after `beforeSend` and removes `$lib`/`$lib_version` from
    `properties` (`:388-389`), hoists `$cookieless_mode`, `$ignore_sent_at`, `$product_tour_id` and
    `$process_person_profile` into `options` when the option is unset (`:391-397`, list at
    `:370-375`), and lifts string `$session_id`/`$window_id` to top-level `session_id`/`window_id`
    (`:405-410`). Enqueued events still carry `$lib`/`$lib_version` (stamped from `sdkInfo`,
    `PostHog/PostHogSDK.swift:800-803`), so the `@client` "Caller property overrides an SDK context
    property" scenario passes on the enqueued event. Open PostHog/posthog-ios#1036 (4.0 release
    blocker) stops removing `$lib`/`$lib_version` in `captureV1JSON`, keeping them per event as 3.x
    did; that contradicts #146's "Library identity comes from the request header" as currently
    drafted.
- **Backwards compatibility:** Backward-compatible. Omitting null members only changes
  serialization; `[String: Any]` types stay. Person properties set to `null` would need a deliberate
  scope decision.
- **Remediation:** Strip `NSNull`-valued dictionary members recursively at the encode step (after
  `runBeforeSend`, e.g. in `captureV1JSON` and the disk encoder), keeping `NSNull` array elements and
  emptied dictionaries as `{}`.

### n5 — Capture Exception (🟡 Partial)
- **Spec requires:** Applicability is now `both` (server delivery scenarios are `@server`). "Exception
  capture drops null-valued custom object properties" follows capture's null rule. "Ignored exception
  types" (optional) drops matching `$exception` events on every path and platform. New: "Fatal
  exception payloads keep their exception data" for a separate fatal-path serializer.
- **SDK currently:** Fixed since `f5cbe87c` ([#930](https://github.com/PostHog/posthog-ios/pull/930),
  merged): the matcher is platform-neutral
  (`PostHog/ErrorTracking/PostHogErrorTrackingAutoCaptureIntegration.swift:329-350`) and
  `captureInternal` applies it to every `$exception` (`PostHog/PostHogSDK.swift:1903-1911`); crash
  reports are filtered too (`PostHogErrorTrackingAutoCaptureIntegration.swift:279-283`). Still open:
  `captureExceptionEvent` (`PostHog/PostHogSDK.swift:4177-4191`) merges caller properties as-is, so
  `NSNull` values reach the wire as `null` (same root cause as Capture, n4). The fatal-path
  requirement is met in effect: crash reports are processed on the next launch by
  `PostHogCrashReportProcessor`, which keeps every frame, and iOS frames carry no `chunk_id`.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** The shared `NSNull` strip from n4 fixes this row too.

### n6 — Flush (🟡 Partial)
- **Spec requires:** Behavior step 3, "Build and send batches until the queue is drained or a failure stops
  progress", replay queues included.
- **SDK currently:** `flush()` (`PostHog/PostHogSDK.swift:908-918`) now flushes the events, replay, logs and AI
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
  its message (`PostHog/PostHogRemovedAPIs.swift:72-77`). `getFeatureFlagResult(_:sendFeatureFlagEvent:)`
  (`PostHog/PostHogSDK.swift:3250-3253`) reads the cache and only reports `$feature_flag_called` when the
  per-call flag (falling back to `PostHogConfig.sendFeatureFlagEvent`, default `true`,
  `PostHog/PostHogConfig.swift:108`) is `true` (`PostHog/PostHogSDK.swift:3255-3273`). `decodePayload`
  (`PostHog/PostHogRemoteConfig.swift:1075-1083`) returns `nil` and logs on a decode failure, so
  `"{broken"`, `""` and `"   "` read as `nil`. Bootstrapped payloads are serialized once when seeded
  (`PostHog/PostHogRemoteConfig.swift:888-893`), so each cached payload is decoded exactly once and a
  bootstrapped `"123"` stays a `String`.
- **Backwards compatibility:** Breaking in 4.0 by design (method removed; malformed payloads now `nil`);
  both are in the 4.0 changeset and `MIGRATION.md`.

### n8 — Get Feature Flag Result (✅ Pass; was 🟡)
- **Spec requires:** key/enabled/variant/payload, `nil` for unknown flags; a malformed payload is the
  no-payload value without changing key/enabled/variant. New: the per-call option is named
  `sendFeatureFlagEvent` and defaults to sending (#109).
- **SDK currently:** `getFeatureFlagResult` returns `nil` for an unknown key
  (`PostHog/PostHogRemoteConfig.swift:1085-1097`). `makeFeatureFlagResult` computes `enabled`/`variant`
  from the flag value alone and takes the payload from `decodePayload`, which returns `nil` on failure
  (`PostHog/PostHogRemoteConfig.swift:1075-1083`, `:1115-1137`). The public overloads are
  `getFeatureFlagResult(_:)` and `getFeatureFlagResult(_:sendFeatureFlagEvent:)`
  (`PostHog/PostHogSDK.swift:3240-3253`).
- **Backwards compatibility:** Malformed payloads changed from raw string to `nil` in 4.0 (changeset entry).

### n9 — Get Feature Flags (🟡 Partial; was ❌)
- **Spec requires:** a cache-only bulk read of all flag values, no payloads (Behavior step 4), tracking
  suppressible. New since the last audit: the Surface variants record that "iOS (4.0+) ...
  `getAllFeatureFlags()` returns a list of flag result objects (key, enabled, variant, payload), or `null`
  when flags are unavailable, instead of a key-to-value map. It never sends `$feature_flag_called`."
- **SDK currently:** `getAllFeatureFlags() -> [PostHogFeatureFlagResult]?` (`PostHog/PostHogSDK.swift:3399-3404`)
  maps every cached flag through `makeFeatureFlagResult` (`PostHog/PostHogRemoteConfig.swift:1099-1113`),
  makes no request and emits no event, so the cached-values and no-tracking scenarios hold in substance.
  It still deviates from the canonical shape (an array of result objects, not a key→value map) and
  returns payloads, which Behavior step 4 excludes. The internal flat map
  (`PostHogRemoteConfig.getFeatureFlags()`, `PostHog/PostHogRemoteConfig.swift:832-834`) stays internal.
  Code unchanged since 3.x; the move to 🟡 follows the spec recording this shape.
- **Backwards compatibility:** Additive if a flat map getter is added.
- **Remediation:** None required beyond the recorded variant; optionally expose a flat
  `[String: Any]` getter for parity with posthog-js.

### n10 — Get Feature Flags And Payloads (🟡 Partial; was ❌)
- **Spec requires:** one call returning flags and payloads; each payload decoded independently,
  malformed ones omitted or `nil` without dropping the flag value or siblings; a valid JSON `""` kept.
  New: the Description now says posthog-ios 4.0 returns per-flag result objects carrying the payload from
  `getAllFeatureFlags()` (see `get-feature-flags`).
- **SDK currently:** No paired-maps method. `getAllFeatureFlags()` (`PostHog/PostHogSDK.swift:3399-3404`)
  carries each flag's payload, decoded per entry by `decodePayload`
  (`PostHog/PostHogRemoteConfig.swift:1075-1083`, `:1099-1113`): malformed entries become `nil`, the flag
  value and sibling payloads are unaffected, and `"\"\""` decodes to `""`. The decoding requirement is now
  met; the shape is the recorded variant, not the canonical two-map return.
- **Backwards compatibility:** Additive if a paired API is added.
- **Remediation:** None required beyond the recorded variant; optionally add a two-map convenience.

### n11 — Get Session ID (🟡 Partial)
- **Spec requires:** "Session id rotates after inactivity timeout": after the timeout `getSessionId()` returns a
  different id (or, per Lifecycle, no active session).
- **SDK currently:** Unchanged. `getSessionId()` (`PostHog/PostHogSDK.swift:483-489`) reads with `readOnly: true`,
  and `PostHogSessionManager.getSessionId` returns the stored id before any expiry check
  (`PostHog/PostHogSessionManager.swift:115-117`; checks at `:124-136`). An expired id is returned until the next
  event or activity rotates it.
- **Backwards compatibility:** Backward-compatible for either fix.
- **Remediation:** In the read-only path, return `nil` when the activity or max-length threshold has expired, or
  get the scenario relaxed for read-only getters (Behavior step 5 already names iOS's read-only mode).

### n12 — Group (✅ Pass)
- **SDK currently:** `group(type:key:groupProperties:options:)` returns early with a log when `type`
  or `key` is empty (`PostHog/PostHogSDK.swift:2764-2767`) before persisting or sending, as
  [#929](https://github.com/PostHog/posthog-ios/pull/929) (now merged) added. Storage, `$groups`
  attachment (`:867-873`) and flag reload on group change (`:2523-2548`) are unchanged.

### n13 — Group Identify (✅ Pass)
- **Spec requires:** amended since `f238b16`: the `@client` scenario now expects group properties
  under `properties.$group_set` (`$group_set.plan`), and the Requirement says so explicitly. Blank
  type/key rejected.
- **SDK currently:** The private `groupIdentify` (`PostHog/PostHogSDK.swift:2551-2592`), called only
  from `group()`, nests sanitized properties under `$group_set` (`:2564-2571`); the `group()` guard
  covers blank type/key. The new server-delivery scenarios are `@server`.

### n14 — Is Feature Enabled (✅ Pass; was 🟡)
- **Spec requires:** boolean mapping, suppressible tracking, and a caller-supplied `defaultValue`
  returned whenever the flag has no value; a flag value, including `false`, wins. The iOS surface
  variant now lists `isFeatureEnabled(_:defaultValue:)` and `isFeatureEnabled(_:defaultValue:sendFeatureFlagEvent:)`.
- **SDK currently:** Both overloads exist (`PostHog/PostHogSDK.swift:3342-3375`). The shared
  implementation returns `!variant.isEmpty` for a string, the `Bool` when present, else `defaultValue`
  (`PostHog/PostHogSDK.swift:3377-3383`). `$feature_flag_called` reports the flag's own value (`nil` when
  missing), never the default (`PostHog/PostHogSDK.swift:3266-3270`).
- **Backwards compatibility:** Additive (4.0 changeset).

### n15 — Opt In (🟡 Partial)
- **Spec requires:** scenario "Opt out can clear local persistence when configured".
- **SDK currently:** Unchanged gap. `optIn()`/`optOut()` (`PostHog/PostHogSDK.swift:3559-3655`) persist consent
  under `optOutLock` (unless `persistOptOut` is false) and install/uninstall integrations; `optOut()` takes no
  parameter and no config clears persisted identity or super properties on opt-out.
- **Backwards compatibility:** Backward-compatible with an optional parameter or config flag defaulting to today's
  behavior.
- **Remediation:** Add an optional clear-local-data parameter to `optOut()`.

### n16 — Reset (🟡 Partial)
- **Spec requires:** reset clears user-scoped state including opt-out persistence.
- **SDK currently:** Unchanged. `reset()` (`PostHog/PostHogSDK.swift:946-998`) clears identity, super properties,
  flags, the flag-called tracker (`:967-969`) and the session. `storage.reset` deletes the persisted `.optOut` key
  (`PostHog/PostHogStorage.swift:512`), but `reset()` never clears the in-memory `config.optOut` that
  `isOptOutState()` (`PostHog/PostHogSDK.swift:1395-1401`) and `isOptOut()` (`:3662-3668`) read, so an opted-out
  user stays opted out until the next launch.
- **Backwards compatibility:** Signature-compatible; runtime behavior for opted-out users who call `reset()`
  changes, so it needs a release note.
- **Remediation:** In `reset()`, when `persistOptOut` is true, set `config.optOut = false` under `optOutLock`, or
  get the spec to say only persisted state is cleared.

### n17 — Shutdown (✅ Pass)
- **Spec requires:** flush pending events before tearing down workers (`@both` scenario). New (#135): where
  `shutdown` takes or defaults to a timeout, the timeout bounds the whole drain.
- **SDK currently:** `close()` (`PostHog/PostHogSDK.swift:3675-3747`) flushes the event, AI, replay and logs queues
  (`:3685-3688`) before stopping them (`:3690-3693`), stops reachability (`:3719`) and clears the flag-called
  tracker (`:3722-3724`). It is fire-and-forget and takes no timeout (spec surface variant: `close(): void`), so the
  timeout requirement does not apply. Like `flush()` it sends one batch per queue (n6); the doc comment says so.

### n18 — Stop Session Recording (✅ Pass)
- **Spec requires:** `acceptance/public/stop-session-recording.feature` (`@client`): pending replay
  data is finalized before the recorder stops, and no new snapshots are captured. Spec unchanged
  since `f238b16`.
- **SDK currently:** `stopSessionRecording()` (`PostHog/PostHogSDK.swift:3830-3848`) ignores the
  call while disabled or opted out, stops the integration and clears the pending-start intent under
  `setupLock` (`:3836-3842`), then calls `replayQueue?.flush()` (`:3847`). Snapshots held by the
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
  `$debug_images` protected from caller properties (`PostHog/PostHogSDK.swift:4172-4187`).
- **Spec requires:** "Application property bags MUST NOT override SDK-owned `$exception_list`,
  `$exception_level`, `$exception_source`, `$debug_images`"
  (`openspec/specs/exception-event-metadata/spec.md:300`). New since `f238b16` (#123): active
  OpenTelemetry trace context as `$trace_id`/`$span_id` — server SDKs only; "Client SDKs, which have
  no ambient OpenTelemetry API, do not derive these properties", which iOS satisfies (no
  `$trace_id`/`$span_id` derivation in `PostHog/`).
- **SDK currently:** `reservedExceptionPropertyKeys` holds only `$exception_list` and `$debug_images`
  (`PostHog/PostHogSDK.swift:4172-4175`), so caller properties still override `$exception_level`
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
  (`PostHog/PostHogRemoteConfig.swift:931-938`). Reads decode once and return `nil` on failure
  (`:1075-1083`). Bootstrap payloads are serialized before seeding, so they round-trip unchanged
  (`:884-895`). Reads make no network request; `clear()` empties the caches and bootstrap layer on reset
  (`:1238-1249`).
- **Backwards compatibility:** Behavior change for malformed and bootstrapped numeric/boolean-looking
  strings, shipped as 4.0 breaking entries.

### n21 — Feature Flag Called Tracker (✅ Pass)
- **Spec requires:** dedupe per flag/value, clear on reset and shutdown, a server-gated minimal event whose
  allowlist covers session-attribution keys. New (#162): config-version-2 attribution and dedupe key for
  `/flags?v=4` records.
- **SDK currently:** Allowlist includes `$referring_domain`, the `utm_*` keys, `gad_source`, `mc_cid`,
  `gclid`, `fbclid` (`PostHog/PostHogSDK.swift:3423-3466`); dedupe in `reportFeatureFlagCalled`
  (`:3468`ff), cleared on `reset()` (`:967-969`) and `close()` (`:3722-3724`); the minimal gate is
  persisted with the flags (`PostHog/PostHogRemoteConfig.swift:545`). iOS requests `/flags?v=2`
  (`PostHog/PostHogApi.swift:596-600`), so config-version-2 records never reach it and the new
  attribution rules have nothing to act on (the spec: such an SDK "sees config version 2 flags as legacy
  values").

### n22 — HTTP Client (🟡 Partial; was ✅)
- **Spec requires:** flags retry policy (transient transport errors incl. DNS/TLS; refused connections not
  retried; 502/504 only; one retry, 300 ms doubling) and (new, #81) gzip by default with a client-wide opt-out,
  raw JSON without `Content-Encoding` when off, and no silent downgrade after a server rejection.
- **SDK currently:** Flags retries: `isRetryableFlagsError` covers timeout, connection lost, not connected, DNS
  and TLS failures and leaves `CannotConnectToHost` out (`PostHog/PostHogApi.swift:733-750`); status retries are
  502/504 only (`:752-754`); `featureFlagRequestMaxRetries = 1` (`PostHog/PostHogConfig.swift:36`). Compression:
  `PostHogCompression` enum (`.gzip`/`.none`, `PostHog/PostHogCompression.swift`), `compression` defaults to
  `.gzip` (`PostHog/PostHogConfig.swift:491`); `requestAndPayload` sends the raw body with no `Content-Encoding`
  when off and falls back to raw only on a local gzip error (`PostHog/PostHogApi.swift:144-157`), used by capture
  v1, snapshot, logs and push (`:236`, `:475`, `:504`, `:580`). A server rejection is handed to the retry layer, not
  resent uncompressed. Gap: `captureAi` requests use their own `captureAiCompression`, also defaulting to `.gzip`
  (`PostHog/PostHogConfig.swift:484-496`), and `uploadCaptureV1` passes it for the AI path (`PostHog/PostHogApi.swift:235-240`),
  which `requestAndPayload` prefers over `compression` (`:148`). So `compression = .none` alone still gzips AI
  requests; the spec requires an option that turns compression off "for the whole client", covering every
  endpoint the SDK would otherwise compress. Setting both properties to `.none` works around it.
- **Backwards compatibility:** Backward-compatible if `compression = .none` also turns off AI compression unless
  `captureAiCompression` is set explicitly (for example, make `captureAiCompression` optional and fall back to
  `compression`).
- **Remediation:** Make `compression` the whole-client switch, with `captureAiCompression` an optional per-lane
  override.

### n23 — Persistent Storage (🟡 Partial)
- **Spec requires:** "Storage failures do not crash SDK calls" — no throw **and** a recorded storage warning.
- **SDK currently:** Unchanged. Reads/writes are wrapped in `do`/`catch` (`PostHog/PostHogStorage.swift:365-373`,
  `:376-393`, `:396-424`), but a write failure only calls `hedgeLog` (`:392`), which prints nothing unless debug is
  on (`PostHog/Utils/Hedgelog.swift:17-20`). 4.0 added `hedgeLogWarning` (always prints, `:22-25`) but storage does
  not use it.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** Log storage write failures with `hedgeLogWarning` (or another always-on signal).

### n24 — Session Replay Privacy (✅ Pass; was ❌)
- **Spec requires:** no-capture elements (`ph-no-capture`, `postHogMask()`) and all their descendants
  are masked even with broad masking off; screenshot replay paints masks before encoding and drops a
  frame whose masks are unreliable (Behavior 2, 4, 6; scenario "Replay privacy excludes no-capture
  elements"). Explicit unmask markers win over explicit mask markers (Interactions). New since
  `f238b16`: "Android secure windows are recorded fully masked" (sdk-specs #160), which states it
  "is not applicable on iOS".
- **SDK currently:** 4.0 always records masked screenshots; `screenshotMode` and
  `screenshotModeBackgroundCapture` survive only as unavailable stubs
  (`PostHog/PostHogRemovedAPIs.swift:105,119`), so the wireframe `toWireframe` path that leaked is
  gone. In the screenshot walk, a `ph-no-capture` view is masked whole and passes `maskChildren` to
  every descendant (`PostHog/Replay/PostHogReplayIntegration.swift:1069-1074`; `isNoCapture()` at
  `PostHog/Replay/UIView+Util.swift:76-78`). `collectMaskedRegions`
  (`PostHog/Replay/PostHogReplayIntegration.swift:1166-1192`) adds the SwiftUI `postHogMask()`
  registry regions (`PostHog/SwiftUI/PostHogMaskViewModifier.swift:62-117`) and returns nil — skipping
  the frame — while a reporter hasn't laid out, or when a camera layer is present. A frame whose
  masked render fails is dropped rather than sent raw (`PostHogReplayIntegration.swift:794-799`).
  `isNoMask()` is checked first (`:896-903`), so a `ph-no-capture` view inside a `ph-no-mask` subtree
  is not masked; the spec's "explicit unmask markers take precedence over explicit mask markers"
  allows that, and secure-entry fields stay masked there (`:900`, `findSecureTextEntries`).
- **Backwards compatibility:** The fix ships in 4.0's breaking replay change (screenshot-only),
  already called out in the changeset.

### n25 — Bootstrap (🟡 Partial)
- **Spec requires:** (MAY) `bootstrap.sessionID` (UUIDv7) adopted as the session id, invalid values
  logged and replaced (`openspec/specs/bootstrap/spec.md:143-158`). Spec unchanged since the last audit.
- **SDK currently:** Every SHALL is met: flag seeding of enabled values only and complete replacement
  (`PostHog/PostHogRemoteConfig.swift:131-153`, `:884-895`), payloads now serialized once at seeding,
  bootstrap cleared on reset (`:1238-1249`). `PostHogBootstrapConfig` still has only `distinctId`,
  `isIdentifiedId`, `featureFlags` and `featureFlagPayloads` (`PostHog/PostHogBootstrapConfig.swift:28-52`),
  and `PostHogSessionManager.swift` never reads bootstrap. 🟡 for the matrix convention on this MAY.
- **Backwards compatibility:** Additive.
- **Remediation:** Optional `sessionID` with UUIDv7 validation, if parity with posthog-js is wanted.

### n26 — Session Replay Debug Properties (🟡 Partial)
- **Fixed in 4.0:** (c) — PostHog/posthog-ios#932: `debugProperties()` reports `disabled` when the
  read-only session id is nil or empty, mirroring `isSessionReplayActive()`
  (`PostHog/Replay/PostHogReplayIntegration.swift:1695-1698`; getter at
  `PostHog/PostHogSDK.swift:3907-3919`). New spec text met: sdk-specs #155 made the debug keys follow
  capture's precedence (super property overrides the SDK value, caller property overrides both,
  per event only). 4.0 sets the debug keys among the SDK-owned values, then merges registered super
  properties, then caller properties (`PostHog/PostHogSDK.swift:826-880`).
- **Spec requires:** (a) `$sdk_debug_session_start` "MUST never describe" a different session than
  the event's own `$session_id`; for a caller-supplied id it comes from the UUIDv7 timestamp and is
  omitted for a non-v7 id (`openspec/specs/session-replay-debug-properties/spec.md:550-561`, scenario
  "Session keys are omitted for a non-UUIDv7 caller session id (mobile)" at `:701`). (b) An event
  timestamped before the current session's start carries the persisted snapshot or none of the keys
  (scenario "A previous-process crash carries no live debug state", `:1026-1032`).
- **SDK currently:** (a) `replayDebugProperties()` always takes the start from
  `sessionManager.sessionStartTimestampSnapshot` (`PostHog/PostHogSDK.swift:743-745`), even when
  `buildProperties` uses a caller-supplied `$session_id` (`:770-773`); no UUIDv7 derivation or
  omission. (b) `buildProperties` (`:749` onward) never compares `timestamp` with the session start,
  so a backdated `capture(..., timestamp:)` gets live `$recording_status`/`$sdk_debug_*` values.
  Crash and OOM reports still bypass `buildProperties` and use the persisted snapshot, so the crash
  arm of (b) is met; manual backdated captures are not.
- **Backwards compatibility:** Backward-compatible; internal property-build changes that only
  correct or remove diagnostic keys.
- **Remediation:** (a) When `propSessionId` is set and differs from the manager's id, derive the
  start from its UUIDv7 timestamp, or omit the key when it isn't v7. (b) Skip the required keys and
  the bundle when `timestamp` is earlier than the current session start.

### n27 — Capture AI (➖ N/A)
- **Spec requires:** Applicability is `server` ("currently implemented by posthog-python and
  posthog-node"), with `@server` scenarios. Behavior: 1 same admission pipeline as `capture`; 2 a
  client-generated UUID returned to the caller; 3 an isolated queue with its own caps and retry that
  starts lazily; 4 a stable envelope across retries. Error handling: never throw; drop oversized
  events logging only name and size.
- **SDK currently:** iOS 4.0 adds `captureAi(_:distinctId:properties:userProperties:userPropertiesSetOnce:groups:timestamp:options:) -> String?`
  (`PostHog/PostHogSDK.swift:1631-1655`), mirroring `capture`'s parameters and routed through
  `captureInternal(..., aiLane: true)`, so `beforeSend`, enrichment and opt-out apply (Behavior 1)
  and the event UUID is returned (2). AI events go to `/i/v1/ai/events`
  (`PostHog/PostHogApi.swift:206-213`) from their own disk queue with separate count, byte, timeout
  and compression settings (`PostHog/QueueEndpoint+Factories.swift:60-90`;
  `PostHog/PostHogConfig.swift:493-518`). The queue is stored per event and resent unchanged (4). An
  event over `captureAiMaxEventBytes` is dropped with a log of its name and size only
  (`PostHog/PostHogQueue.swift:417-418`). One deviation: the AI queue is created and started at
  setup (`PostHog/PostHogSDK.swift:314-331`), not lazily (Behavior 3). There is no
  `enableFullAiCapture` flag, which only matters for PostHog AI wrapper libraries, and iOS has none.
- **Why ➖:** the legend's N/A means the contract does not apply to the platform, and the spec's
  Applicability still names only server SDKs. Scoring it would need an Applicability change in
  sdk-specs (for example, to cover client SDKs that ship `capture_ai`). Recorded here so that change
  can cite iOS's conformance.
- **Backwards compatibility:** N/A.
- **Remediation:** None required. If the spec extends Applicability to clients, start the AI queue on
  first `captureAi` call.

### n28 — On Feature Flags (🟡 Partial; was ✅)
- **Spec requires:** new since the last audit (#94, #161): a failed non-quota load invokes listeners with
  the last known flags and `errorsLoading`; a runtime registration stays active across `close()`/`setup()`
  until unsubscribed ("Lifetime of a runtime listener registration"); and "Loads discarded by reset or
  close reach no listener": a load in flight when `reset()` or `close()` ran SHALL NOT be delivered nor
  replayed to a later listener.
- **SDK currently:** Failed loads deliver `featureFlags ?? current` with `errorsLoading: true`
  (`PostHog/PostHogSDK.swift:259-275`). Registrations live on the SDK's own multicast, survive
  `close()`/`setup()`, replay the latest value on register, and unsubscribe idempotently
  (`PostHog/PostHogSDK.swift:3126-3157`). `close()` nils `remoteConfig`, the relay token and the cached
  value (`PostHog/PostHogSDK.swift:3714-3716`), so the close half passes. The reset half fails: `reset()`
  clears the cache and `lastFeatureFlagsLoaded` and starts a reload (`PostHog/PostHogSDK.swift:975-980`),
  but the response handler for a `/flags` request already in flight has no generation check. It writes the
  previous identity's flags into the cache (`PostHog/PostHogRemoteConfig.swift:560-580`) and notifies;
  the relay compares against that freshly written cache and delivers it. The new reload is queued as the
  pending request (`PostHog/PostHogRemoteConfig.swift:440-458`) and only corrects the cache afterwards.
  The spec's change design (`openspec/changes/archive/2026-10-30-record-android-flag-listener-subscription/design.md`, #161) records the same result:
  "Fails for `reset()`; passes for `close()`".
- **Backwards compatibility:** Backward-compatible; dropping a superseded load only removes a callback
  that carried the wrong identity's flags.
- **Remediation:** Bump a load generation in `reset()` (as posthog-android and posthog-js do), capture it
  when a `/flags` request starts, and drop the response (no cache write, no notify) when it changed.

### n29 — Surveys (🟡 Partial; was ✅)
- **Spec requires:** new requirement "Survey popup delay" (`openspec/specs/surveys/spec.md:321-417`,
  sdk-specs #121). Wait `appearance.surveyPopupDelaySeconds` (negative clamps to 0) before display;
  reserve the survey before the wait so repeats don't restart it or show a second survey. A survey
  not yet on screen hasn't been shown: if it is dropped before display (hidden/cancelled by the app,
  superseded, undisplayable) the SDK emits neither `survey shown` nor `survey dismissed`, doesn't
  mark it seen or write the last-seen date, and releases the reservation; also release on reset or
  surveys teardown. Host UI layers must report every survey as shown or closed, and "closing a survey
  before it was shown does not mark it seen and emits no interaction event". SHOULD re-check
  eligibility when the delay elapses.
- **SDK currently:** Met: `showNextSurvey()` reserves the survey with `setActiveSurvey` before calling
  `renderSurvey` (`PostHog/Surveys/PostHogSurveyIntegration.swift:295-331`), and `canShowNextSurvey()`
  blocks a second survey while it is held (`:1065-1067`). The default delegate clamps the delay
  (`PostHog/Surveys/PostHogSurveysDefaultDelegate.swift:98`), shows immediately at 0, and otherwise
  schedules one `asyncAfter` (`:106-126`). `survey shown` and the last-seen date are written only in
  `handleSurveyShown` (`PostHogSurveyIntegration.swift:526-546`). `stop()` clears the active survey
  before `cleanupSurveys()` closes the pending one (`:114-123`), so teardown emits nothing.
  Gaps: (1) `handleSurveyClosed` (`:640-677`) does not check whether the survey was ever shown: a
  close reported before display marks it seen (`:661`) and sends `survey dismissed` (`:664-670`).
  Any custom `PostHogSurveysDelegate` (and wrapper hosts) that reports a dropped pending survey as
  closed — as the spec tells hosts to do — trips this. (2) `reset()` bumps the survey generation but
  doesn't cancel a pending delayed display: the default delegate's work item still shows the old
  user's survey after the delay (its callbacks are then ignored by the generation check,
  `:507-522`), and the reservation is held until that survey is closed. (3) No eligibility re-check
  when the delay elapses (SHOULD).
- **Backwards compatibility:** Backward-compatible. Only pre-display closes change: they stop sending
  `survey dismissed` and stop marking the survey seen.
- **Remediation:** Track a per-attempt "shown" flag set in `handleSurveyShown`; in
  `handleSurveyClosed`, when it is unset, release the reservation without `setSurveySeen` or
  `survey dismissed`. Have `reset()` close the pending survey through the surveys delegate (or
  re-check generation in the work item before showing). Optionally re-run the eligibility filter
  before displaying.
