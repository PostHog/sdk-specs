# posthog-ios — SDK Compliance

**Repo:** [PostHog/posthog-ios](https://github.com/PostHog/posthog-ios)
**Audited commit:** `f5cbe87c78c1af332bcb908e64cf516e84199fb1` ([commit](https://github.com/PostHog/posthog-ios/commit/f5cbe87c78c1af332bcb908e64cf516e84199fb1)) — audited on 2026-10-08
**Audited against sdk-specs commit:** `f238b16`
**Summary (assuming the pending PRs below merge):** 38 ✅ · 16 🟡 · 4 ❌ · 6 ➖ · 0 ❓
**Summary at the audited commit:** 32 ✅ · 21 🟡 · 5 ❌ · 6 ➖ · 0 ❓

Note on repo layout: `posthog-ios` is a single-package repo. Core SDK logic lives at
`PostHog/` (flat files: `PostHogSDK.swift` — the main public API surface (capture, identify,
alias, group, feature flags, session recording controls, shutdown); `PostHogConfig.swift`;
`PostHogRemoteConfig.swift` — `/flags` fetch, feature-flag/payload cache, remote replay/error-
tracking config; `PostHogStorage.swift`/`PostHogStorageManager.swift` — persistence;
`PostHogQueue.swift`/`PostHogFileBackedQueue.swift`/`PostHogLegacyQueue.swift` — batching/retry;
`PostHogApi.swift` — HTTP transport; `PostHogSessionManager.swift`; `PostHogBootstrapConfig.swift`).
Platform-specific integrations live in subfolders: `AppLifeCycle/`, `Autocapture/`, `ErrorTracking/`,
`Logs/`, `Replay/` (session replay — masking, wireframes, screenshot capture), `ScreenViews/`,
`Surveys/`, `SwiftUI/` (SwiftUI-specific modifiers), `Tracing/` (tracing-headers only — no OTLP
traces implementation exists), `PushNotifications/`. Unlike posthog-android, posthog-ios is not a
monorepo with a separate server module — there is exactly one SDK target, so any capability judged
N/A for platform reasons (e.g. local flag evaluation, flag-definition polling, capture-ai,
evaluate-flags) is N/A because the capability requires a personal/admin API key a mobile app cannot
safely hold, or is an explicitly server-only capability per its spec's Applicability line, not
because of a build-target split. All file paths below are relative to the posthog-ios repo root.

This audit re-verified all 64 rows against current code (161 posthog-ios commits since the
previous audit at `c0218386`, 2026-08-17) and current specs (50 sdk-specs commits since `0ea0aba`),
rather than carrying forward the previous verdicts. Two new contracts were evaluated from scratch:
**MCP Analytics** (➖, server-only add-on) and **Session Replay Debug Properties** (🟡).

Net changes vs. the previous audit:
- **Improved (7):** On Feature Flags ❌→✅ ([#897](https://github.com/PostHog/posthog-ios/pull/897)), Surveys ❌→✅ (intro screen [#754](https://github.com/PostHog/posthog-ios/pull/754), undisplayable
  question types skipped [#887](https://github.com/PostHog/posthog-ios/pull/887)), Screen 🟡→✅ ([#904](https://github.com/PostHog/posthog-ios/pull/904)), Set Person Properties 🟡→✅ ([#817](https://github.com/PostHog/posthog-ios/pull/817)), Before Send
  Hook 🟡→✅ (spec is now fail-closed; [#774](https://github.com/PostHog/posthog-ios/pull/774) drops the event on an ObjC hook exception), Event Batcher
  🟡→✅ (replay request boundary [#895](https://github.com/PostHog/posthog-ios/pull/895); the old injectable-clock finding was not a spec requirement),
  Consent Gating 🟡→✅ (the spec gates event-producing APIs; the old "block every network request"
  reading went beyond it — `reloadFeatureFlags` while opted out is noted, not failed).
- **New spec requirements unmet (3):** Capture ✅→🟡 (null-valued properties must be dropped; iOS
  sends `NSNull` as JSON `null`), Get Feature Flag Result and Feature Flag Cache ✅→🟡 (malformed
  payload JSON must decode to nil; iOS returns the raw string).
- **Previously missed, code unchanged (4):** Flush ✅→🟡 (explicit flush sends one batch, not the
  whole queue), HTTP Client ✅→🟡 (flags requests don't retry DNS/TLS failures), Get Session ID ✅→🟡
  (read-only getter returns an expired id after the inactivity timeout — note the spec's behavior
  section explicitly permits iOS's read-only mode, so this conflict may be better resolved
  spec-side), Is Feature Enabled ✅→🟡 (no caller-supplied `defaultValue`).
- Logs, Capture Exception and Exception Event Metadata stay 🟡 with refreshed findings; old gaps
  that the spec dropped or the SDK fixed are removed from their notes.

## Pending posthog-ios PRs

Verdicts in the table and summary assume these open PRs merge. Until then, the audited-commit
summary above is what `main` actually ships.

| PR | Fixes | Row(s) |
|---|---|---|
| [PostHog/posthog-ios#924](https://github.com/PostHog/posthog-ios/pull/924) | `close()` flushes queued events, replay and logs | Shutdown ❌→✅, Logs (part) |
| [PostHog/posthog-ios#925](https://github.com/PostHog/posthog-ios/pull/925) | Cap `Retry-After` for logs at 5 minutes | Logs (part) |
| [PostHog/posthog-ios#926](https://github.com/PostHog/posthog-ios/pull/926) | Retry flags requests on DNS/TLS/no-internet failures | HTTP Client 🟡→✅ |
| [PostHog/posthog-ios#927](https://github.com/PostHog/posthog-ios/pull/927) | Skip empty logs attribute keys | Logs (part) |
| [PostHog/posthog-ios#928](https://github.com/PostHog/posthog-ios/pull/928) | Keep attribution keys on minimal `$feature_flag_called` | Feature Flag Called Tracker 🟡→✅ |
| [PostHog/posthog-ios#929](https://github.com/PostHog/posthog-ios/pull/929) | Ignore `group()` with an empty type or key | Group, Group Identify 🟡→✅ |
| [PostHog/posthog-ios#930](https://github.com/PostHog/posthog-ios/pull/930) | `ignoredExceptionTypes` on watchOS/visionOS | Capture Exception (part) |
| [PostHog/posthog-ios#931](https://github.com/PostHog/posthog-ios/pull/931) | Exception Event Metadata envelope | Exception Event Metadata (part) |
| [PostHog/posthog-ios#932](https://github.com/PostHog/posthog-ios/pull/932) | `$recording_status: disabled` with no session | Session Replay Debug Properties (part) |
| [PostHog/posthog-ios#933](https://github.com/PostHog/posthog-ios/pull/933) | `stopSessionRecording()` flushes pending replay | Stop Session Recording 🟡→✅ |

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Logs | 🟡 | [n1]; partly fixed by [#924](https://github.com/PostHog/posthog-ios/pull/924), [#925](https://github.com/PostHog/posthog-ios/pull/925), [#927](https://github.com/PostHog/posthog-ios/pull/927) (pending) |
| 2 | Traces | ❌ | [n2] |
| 3 | Tracing Headers | ✅ | |
| 4 | Alias | 🟡 | [n3] |
| 5 | Capture | 🟡 | [n4] |
| 6 | Capture AI | ➖ | unchanged — Applicability still `server`; the new null-drop requirement/scenario is `@server`; no AI capture in iOS (repo grep for `captureAi`/`capture_ai`/`$ai_generation` → no hits) |
| 7 | Capture Exception | 🟡 | [n5]; partly fixed by [#930](https://github.com/PostHog/posthog-ios/pull/930) (pending) |
| 8 | Create Person Profile | ➖ | unchanged — spec Applicability still says only the posthog-js family exposes it; no `createPersonProfile` in iOS (repo grep → no hits) |
| 9 | Debug | ✅ | |
| 10 | Exception Steps | ✅ | |
| 11 | Flush | 🟡 | [n6] |
| 12 | Get Anonymous ID | ✅ | |
| 13 | Get Distinct ID | ✅ | |
| 14 | Get Feature Flag | ✅ | |
| 15 | Get Feature Flag Payload | 🟡 | [n7] |
| 16 | Get Feature Flag Result | 🟡 | [n8] |
| 17 | Get Feature Flags | ❌ | [n9] |
| 18 | Get Feature Flags And Payloads | ❌ | [n10] |
| 19 | Evaluate Flags | ➖ | unchanged: spec grew (missing-key negative knowledge, runtime filter) but still "applies to server SDKs"; feature file still `@server` |
| 20 | Get Session ID | 🟡 | [n11] |
| 21 | Group | ✅ | was 🟡; fixed by [#929](https://github.com/PostHog/posthog-ios/pull/929) (pending) — [n12] |
| 22 | Group Identify | ✅ | was 🟡; fixed by [#929](https://github.com/PostHog/posthog-ios/pull/929) (pending) — [n13] |
| 23 | Identify | ✅ | |
| 24 | Is Feature Enabled | 🟡 | [n14] |
| 25 | Is Opt Out | ✅ | |
| 26 | Is Session Replay Active | ✅ | |
| 27 | On Feature Flags | ✅ | |
| 28 | Opt In | 🟡 | [n15] |
| 29 | Register | ✅ | |
| 30 | Reload Feature Flags | ✅ | |
| 31 | Reset | 🟡 | [n16] |
| 32 | Reset Group Properties For Flags | ✅ | |
| 33 | Reset Person Properties For Flags | ✅ | |
| 34 | Screen | ✅ | |
| 35 | Set Group Properties For Flags | ✅ | |
| 36 | Set Person Properties | ✅ | |
| 37 | Set Person Properties For Flags | ✅ | |
| 38 | Setup | ✅ | |
| 39 | Shutdown | ✅ | was ❌; fixed by [#924](https://github.com/PostHog/posthog-ios/pull/924) (pending) — [n17] |
| 40 | Start Session Recording | ✅ | |
| 41 | Stop Session Recording | ✅ | was 🟡; fixed by [#933](https://github.com/PostHog/posthog-ios/pull/933) (pending) — [n18] |
| 42 | Unregister | ✅ | |
| 43 | Application Lifecycle | ✅ | |
| 44 | Autocapture | ✅ | |
| 45 | Before Send Hook | ✅ | |
| 46 | Consent Gating | ✅ | |
| 47 | Device ID Generator | ✅ | |
| 48 | Event Batcher | ✅ | |
| 49 | Exception Event Metadata | 🟡 | [n19]; partly fixed by [#931](https://github.com/PostHog/posthog-ios/pull/931) (pending) |
| 50 | Feature Flag Cache | 🟡 | [n20] |
| 51 | Feature Flag Called Tracker | ✅ | was 🟡; fixed by [#928](https://github.com/PostHog/posthog-ios/pull/928) (pending) — [n21] |
| 52 | Flag Definition Loader | ➖ | unchanged: no definition loader/personal-key polling (`grep -rniE "etag\|personalApiKey\|flagDefinition" PostHog/` → none); only `preloadFeatureFlags`, the client-wrapper case named in Applicability; feature file is `@server` |
| 53 | HTTP Client | ✅ | was 🟡; fixed by [#926](https://github.com/PostHog/posthog-ios/pull/926) (pending) — [n22] |
| 54 | Local Feature Flag Evaluator | ➖ | unchanged: no local rule engine; spec now states reading remote values from "mobile/browser value caches ... SHALL NOT itself count as local-rule evaluation" |
| 55 | Persistent Storage | 🟡 | [n23] |
| 56 | Remote Config | ✅ | |
| 57 | Retry Queue | ✅ | |
| 58 | Session Manager | ✅ | |
| 59 | Session Replay Ingestion Controls | ✅ | |
| 60 | Session Replay Privacy | ❌ | [n24] |
| 61 | Surveys | ✅ | |
| 62 | Bootstrap | 🟡 | [n25] |
| 63 | MCP Analytics | ➖ | Applicability is `server` add-on (js/python/go/ruby packages); no iOS package |
| 64 | Session Replay Debug Properties | 🟡 | [n26]; partly fixed by [#932](https://github.com/PostHog/posthog-ios/pull/932) (pending) |

## Notes

### n1 — Logs (🟡 Partial)
- **Pending fix ([PostHog/posthog-ios#924](https://github.com/PostHog/posthog-ios/pull/924), [PostHog/posthog-ios#925](https://github.com/PostHog/posthog-ios/pull/925), [PostHog/posthog-ios#927](https://github.com/PostHog/posthog-ios/pull/927)):** [#924](https://github.com/PostHog/posthog-ios/pull/924) flushes logs on `close()`; [#925](https://github.com/PostHog/posthog-ios/pull/925) caps `Retry-After` for logs at 5 minutes; [#927](https://github.com/PostHog/posthog-ios/pull/927) skips empty attribute keys. Still open: non-finite floats dropped instead of stringified, and one batch per flush.
- **Spec requires:** non-finite floats encoded as `stringValue` and empty attribute keys dropped
  with a debug warning; a timeout-bounded final flush on shutdown; a persistent-queue drain that
  repeats take-POST-remove "until the queue is drained or a send fails"; `Retry-After` used as a
  floor, clamped to a documented per-SDK maximum first:
  `max(ownBackoff, min(parsedRetryAfter, documentedMaximum))`. A throwing `beforeSend` must drop the
  record and emit a diagnostic naming `beforeSend`.
- **SDK currently:** Fixed since the last audit: ObjC `beforeSend` raises are now caught and the
  record dropped with a diagnostic (`Utils/BoxedBeforeSend.swift:54-59`, `PHObjCExceptionCatcher.m`,
  [#774](https://github.com/PostHog/posthog-ios/pull/774)). The Swift hook type is non-throwing (`Logs/PostHogLogsConfig.swift:16`), which the spec
  accepts. The intra-millisecond bump is now a SHOULD, so `nanosNow()` (`Utils/DateUtils.swift:71-79`,
  wall clock, no bump) no longer counts as a gap. Still open: (1) `close()`
  (`PostHogSDK.swift:2820-2871`) calls `logsQueue?.stop()` and nils the queue with no flush, and
  `PostHogQueue.stop()` (`PostHogQueue.swift:283-312`) never sends. (2) NaN/±Inf attribute values
  are still dropped before encoding: `toStorageJSON` passes attributes through `sanitizeDictionary`
  (`Logs/PostHogLogRecord.swift:126-128`), and `isValidObject` rejects non-finite numbers
  (`Utils/DictUtils.swift:111-119`, removed at `:55-63`). The encoder's stringifier
  (`Logs/PostHogLogsOTLP.swift:72-78`) is never reached. New against this spec: (3) an empty `""`
  key is sent. `toKeyValueList` (`Logs/PostHogLogsOTLP.swift:82-96`) skips only nil, `NSNull`, and
  unencodable values. (4) Each flush sends one batch. `flush()` peeks one `cap`-sized window
  (`PostHogQueue.swift:314-328`, `:438`), and `consume` only continues within that window
  (`:481-487`), so a backlog larger than `logs.maxBatchSize` waits for later triggers. (5) The
  `Retry-After` floor is not clamped: `delay = max(backoffDelay, result.retryAfter ?? 0)`
  (`PostHogQueue.swift:157-160`), and `parseRetryAfter` (`Utils/DateUtils.swift:51-61`) has no
  maximum, so a large header pauses the logs queue for that long. Both wire forms are parsed, and
  past dates or unparseable values fall back to the backoff, as the spec requires.
- **Backwards compatibility:** Backward-compatible. All five are internal changes with no public
  signature change. For (2), `sanitizeDictionary` is public and shared with events and replay, so
  the fix belongs on the logs storage path only. For (5), the queue code is shared with
  `/batch` and `/snapshot`, so clamping changes their pause length too, but only for oversized
  headers.
- **Remediation:** Flush `logsQueue` (bounded by a timeout) before `stop()` in `close()`. Give
  logs attributes a sanitizer that stringifies non-finite floats instead of dropping them. Skip
  empty keys in `toKeyValueList` with a `hedgeLog`. After a successful send, re-take from the
  queue head up to the depth captured at flush start. Add a documented `Retry-After` maximum
  (30s–5min) and apply `max(backoff, min(header, max))`.

### n2 — Traces (❌ Fail)
- **Spec requires:** a `startSpan` handle API plus a scoped `withSpan` helper, no-op handles when
  unconfigured, W3C traceparent/tracestate interop, span limits, an in-memory span queue with live
  span bounds, OTLP Traces JSON to `POST {host}/i/v1/traces`, a shutdown flush, and the shared
  `Retry-After`/backoff policy. Mobile ports are addressed throughout (`screen.name`/`app.state`
  context, background flush, larger live-span bounds).
- **SDK currently:** Still not implemented. A search of `PostHog/` for `startSpan`, `withSpan`,
  `resourceSpans`, `traceparent`, and `i/v1/traces` returns nothing. `PostHog/Tracing/` holds only
  `PostHogTracingHeadersIntegration.swift`, which is the separate `tracing-headers` capability.
  Unchanged from the previous audit. The spec itself grew substantially (+564/−160 lines).
- **Backwards compatibility:** Backward-compatible. This is a net-new, opt-in pipeline and API.
- **Remediation:** Implement `traces` net-new, modeled on the logs pipeline: a span handle type, a
  no-op fallback, `startSpan`/`withSpan`, an OTLP traces queue and transport, and mobile context
  enrichment.

### n3 — Alias (🟡 Partial)
- **Spec requires:** the `@client` scenario "Client alias links the current anonymous identity to a
  known identity" (`acceptance/public/alias.feature`) requires the enqueued `$create_alias`
  event's properties to include both `alias` and `distinct_id`. The `@both` scenario "Alias is
  dropped when required identities are missing" requires a drop plus a validation warning. Note:
  spec Behavior step 4 (`openspec/specs/alias/spec.md:73`) says audited mobile helpers do not
  require the `properties.distinct_id` duplication, which conflicts with the `@client` scenario.
- **SDK currently:** `alias(_:)` (`PostHog/PostHogSDK.swift:1830-1859`) still builds
  `let props = ["alias": alias]` (`:1847`) and never sets `properties.distinct_id`.
  `buildProperties` only adds `distinct_id` when `appendSharedProps` is false, which is the replay
  snapshot path (`PostHog/PostHogSDK.swift:807-810`). There is still no blank-alias guard:
  `alias("")` is enqueued. On iOS the source id always resolves through `getDistinctId()`, so the
  "missing previous distinct id" case can't happen. Unchanged from the previous audit. The spec
  changes since then (sdk-specs #75 rewrote the server scenarios as `@sdk:server` outlines) don't affect
  clients.
- **Backwards compatibility:** Backward-compatible. Adding `properties.distinct_id` and an
  empty-alias guard are additive.
- **Remediation:** Set `props["distinct_id"] = distinctId` in `alias(_:)` (or fix the spec scenario
  to match Behavior step 4). Optionally drop a blank `alias` with a log, as `identify()` does.

### n4 — Capture (🟡 Partial)
- **Spec requires:** new requirement "Capture drops null-valued object properties"
  (`openspec/specs/capture/spec.md`, added by sdk-specs #60, scenarios `@both`). Explicit nulls
  (Swift `NSNull()`) are omitted from custom properties, recursively and inside arrays. Null array
  elements stay at their index, emptied objects stay `{}`. The rule applies after `before_send` and
  on each disk serialization. Behavior step 2 and Error handling also say to drop events with an
  empty or invalid event name. Other new text is met or doesn't apply. UTC timestamp
  normalization is met. "If `before_send` throws, drop" is met (see Before Send Hook). The
  environment-sourced `$release_id` requirement (#80) applies only to "a server SDK that can read
  its process environment", and all its scenarios are `@server`.
- **SDK currently:**
  - **Nulls are serialized as JSON `null`.** `sanitizeDictionary` (`PostHog/Utils/DictUtils.swift:48`)
    keeps any value for which `isValidObject` returns true. `isValidObject`
    (`DictUtils.swift:106-128`) falls through to `JSONSerialization.isValidJSONObject([object])`,
    which is `true` for `NSNull`. Nested dictionaries and arrays holding `NSNull` are valid JSON
    objects too, so they pass through unchanged. `PostHogEvent.toJSON()`
    (`PostHog/Models/PostHogEvent.swift:92-96`) writes `properties` as-is, and the batch queue
    encodes it with `toJSONData(event.toJSON())` (`PostHog/QueueEndpoint+Factories.swift:28`). The
    disk record and the wire payload are the same bytes. The only `NSNull` handling in the tree is
    in the logs OTLP encoder (`PostHog/Logs/PostHogLogsOTLP.swift:27,91`), not in events. Checked
    with Foundation: `JSONSerialization` turns
    `["test": NSNull(), "nested": ["drop": NSNull()], "items": ["1", NSNull(), 2]]` into
    `{"items":["1",null,2],"nested":{"drop":null},"test":null}`. A Swift `nil` boxed in `Any` comes
    out as `null` too. The spec expects `{"nested":{},"items":["1",null,2]}`.
  - **Empty event names are not dropped.** `capture(_:...)` (`PostHog/PostHogSDK.swift:1390-1408`)
    goes straight to `captureInternal` (`:1554`). That function only checks `isEnabled()`, opt-out
    and queue presence. Neither it, `buildEvent` (`:1933`) nor `PostHogQueue.add`
    (`PostHog/PostHogQueue.swift:348-367`) checks for an empty name. A repo grep for
    `event.isEmpty`/`eventName.isEmpty` in `PostHog/` finds nothing. This was already true at
    `c0218386` but wasn't flagged in the previous audit.
  - **What is correct:** enrichment, envelope fields, and `timestamp` serialized as UTC with
    milliseconds (`PostHog/Utils/DateUtils.swift:19,39`). `before_send` runs before enqueue, and a
    raising Objective-C hook drops the event.
- **Backwards compatibility:** Backward-compatible. Omitting null-valued members only changes
  serialization. Public property types (`[String: Any]`) stay as they are, as the spec requires.
  Person properties set to `null` to clear a value would no longer be sent, but the requirement
  covers only custom event properties, so `$set`/`$set_once` handling needs a deliberate scope
  decision. Dropping empty event names only affects calls that are already invalid.
- **Remediation:** Strip `NSNull`-valued dictionary members recursively when serializing events.
  Keep `NSNull` array elements and keep emptied dictionaries as `{}`. Apply this after
  `runBeforeSend`, at the encode step, so hook-added nulls are covered too. Drop and log `capture`
  calls whose event name is empty or whitespace-only.

### n5 — Capture Exception (🟡 Partial)
- **Pending fix ([PostHog/posthog-ios#930](https://github.com/PostHog/posthog-ios/pull/930)):** `ignoredExceptionTypes` now applies on watchOS/visionOS. Still open: `NSNull` custom properties sent as JSON `null`.
- **Spec requires:** (amended since 0ea0aba) type/message live on `$exception_list[0].type`/`.value`;
  flat `$exception_type`/`$exception_message` are no longer required. New requirement "Exception
  capture drops null-valued custom object properties": caller properties whose value is null
  (Swift `NSNull()`) SHALL be omitted on the wire, recursively, while null array elements keep their
  positions. New optional requirement "Ignored exception types": where the option exists it SHALL
  default to empty and drop matching `$exception` events on **every** path (manual, autocapture/crash,
  generic `capture("$exception")`), matching every chain entry case-sensitively.
- **SDK currently:** The previous finding (no flat `$exception_type`/`$exception_message`) no longer
  counts as a gap under the amended spec. Frame ordering, chain ordering and real-stack preservation
  are still correct (`PostHog/ErrorTracking/PostHogExceptionProcessor.swift:122-207, 244-290`). Ignored types:
  `errorTrackingConfig.ignoredExceptionTypes` defaults to `[]`
  (`PostHog/ErrorTracking/PostHogErrorTrackingConfig.swift:120`). It is enforced in `captureInternal`
  for every `$exception`, including wrapper-built ones (`PostHog/PostHogSDK.swift:1578-1586`), and
  separately for crash reports (`PostHog/ErrorTracking/PostHogErrorTrackingAutoCaptureIntegration.swift:279-283`),
  with an exact, case-sensitive match on every `$exception_list[].type` (`:309-318`). Gap 1: on
  watchOS/visionOS the matcher is a stub that always returns `false`
  (`PostHogErrorTrackingAutoCaptureIntegration.swift:321-338`, outside the `#if os(iOS) || os(macOS) ||
  os(tvOS)` at `:10`). But `captureException` and the config option compile on every platform, so a
  listed type is still sent there. Gap 2: null-valued custom properties are not dropped.
  `captureExceptionEvent` merges caller properties as they are (`PostHog/PostHogSDK.swift:3239-3248`), and
  `sanitizeDictionary`/`isValidObject` treat `NSNull` as valid JSON
  (`PostHog/Utils/DictUtils.swift:48-66, 106-128`), so `{"test": NSNull()}` serializes as `"test":null`.
  The only `NSNull` filtering in the SDK is in the logs OTLP path (`PostHog/Logs/PostHogLogsOTLP.swift:27, 91`).
  The same root cause affects generic `capture`.
- **Backwards compatibility:** Backward-compatible. Dropping null members on the wire only shrinks
  the payload. Moving the ignore-list matcher out of the platform-guarded integration makes a
  documented option work where it is currently a silent no-op.
- **Remediation:** (1) Strip `NSNull`-valued dictionary members recursively, keeping array slots,
  in the event serialization/sanitize path used for both disk and wire. (2) Move
  `exceptionListMatchesIgnoredTypes` into platform-neutral code (for example
  `PostHogExceptionProcessor`) so `captureInternal` filters on watchOS/visionOS too.

### n6 — Flush (🟡 Partial)
- **Spec requires:** Behavior step 3: "Build and send batches until the queue is drained or a
  failure stops progress", with replay queues flushed as well (step 4).
- **SDK currently:** `flush()` (`PostHogSDK.swift:823-832`) flushes the events, replay, and logs
  queues. Each `PostHogQueue.flush()` (`PostHogQueue.swift:314-328`) takes a single window of
  `batchLimits.cap` entries (`:438`), and `consume` only continues to further prefixes inside that
  window (`:481-487`). Nothing re-takes from the queue head after a successful send. So with more
  than `maxBatchSize` (default 50) events queued, an explicit or background flush delivers one batch
  and leaves the rest for later timer, threshold, or reconnect triggers. The empty-queue and
  503-keeps-events acceptance scenarios pass (`:321-326`, `:156-164`). The code is unchanged; the
  previous audit missed this.
- **Backwards compatibility:** Backward-compatible. Looping the drain inside the existing
  single-flight claim changes only how many requests one flush issues.
- **Remediation:** In `consume`'s success path, once the window is exhausted, peek the next window
  instead of clearing `isFlushing`, bounded by the queue depth captured at flush start, and stop on
  the first failure.

### n7 — Get Feature Flag Payload (🟡 Partial)
- **Spec requires:** a canonical payload getter, cache-only, no `$feature_flag_called` by default.
  New since `0ea0aba`: serialized payloads that fail to decode (incl. `""`/whitespace) SHALL return
  the no-payload value (`nil`), MUST NOT return the raw string, and failures are logged; valid JSON
  keeps decoded types; an already-decoded payload string MUST NOT be JSON-decoded again.
- **SDK currently:** `getFeatureFlagPayload(_:)` (`PostHogSDK.swift:2591-2596`) is still
  `@available(*, deprecated, ...)` in favour of `getFeatureFlagResult(_:)`; it delegates with
  `sendEvent: false`, so no event is emitted (unchanged). Two new deviations, both in
  `makeFeatureFlagResult` (`PostHogRemoteConfig.swift:1106-1117`): (1) on a `JSONSerialization`
  failure it logs and then sets `payload = payloadValue`, returning the raw string; verified locally
  that `"{broken"`, `""` and `"   "` all throw, so all three spec inputs come back raw instead of
  `nil`. (2) Every cached `String` is decoded, including bootstrap payloads, which
  `PostHogBootstrapConfig.featureFlagPayloads` documents as "already-decoded"
  (`PostHogBootstrapConfig.swift:47-52`) and which are seeded into the same cache
  (`PostHogRemoteConfig.swift:143-145, 881`). A bootstrapped `"123"` or `"true"` therefore comes back
  as `123`/`true` (verified: both decode as fragments); `"hello"` stays correct only because it fails
  to decode. Valid serialized inputs (`"\"\""`, `false`, `0`, `null`, objects, arrays) decode
  correctly.
- **Backwards compatibility:** Returning `nil` instead of the raw string for malformed payloads is a
  behavior change for callers who read the raw string, but it only affects invalid payloads.
  Skipping re-decoding of bootstrapped strings changes what those callers get back for numeric- or
  boolean-looking strings.
- **Remediation:** In `makeFeatureFlagResult` (and the internal `getFeatureFlagPayload`,
  `PostHogRemoteConfig.swift:1052-1074`), return `nil` on a decode failure. Mark bootstrapped
  payloads as already decoded (for example, keep them out of the decode path or store them
  serialized) so they are not decoded twice. The deprecation is still a naming choice, not a defect.

### n8 — Get Feature Flag Result (🟡 Partial)
- **Spec requires:** structured result with key/enabled/variant/payload; `nil` for unknown flags.
  New: a malformed payload SHALL be represented as no payload, never its raw string, without
  changing key/enabled/variant; value-only and enabled APIs on the same path keep their values.
- **SDK currently:** Core scenarios pass (`PostHogSDK.swift:2477-2509`,
  `PostHogRemoteConfig.swift:1076-1139`). Key/enabled/variant are computed independently of the
  payload, so a decode failure never discards the result or changes `getFeatureFlag`/
  `isFeatureEnabled`. But the payload field carries the raw string on failure
  (`PostHogRemoteConfig.swift:1111-1113`), failing the `"blue"` × `"{broken"`/`""`/`"   "` rows.
  The `false` rows pass trivially because disabled flags never store payloads
  (`PostHogRemoteConfig.swift:1204-1211`). Previously ✅; the requirement is new.
- **Backwards compatibility:** `payload` becomes `nil` instead of a raw string only for invalid
  JSON. That changes behavior for anyone relying on the raw-string fallback.
- **Remediation:** Same fix as Get Feature Flag Payload: set `payload = nil` in the `catch` branch of
  `makeFeatureFlagResult`.

### n9 — Get Feature Flags (❌ Fail)
- **Spec requires:** a public bulk getter returning a flat key→value map (`Record<string,
  boolean|string>`), cache-only, with tracking suppressible.
- **SDK currently:** Still no public flat-map getter. `PostHogRemoteConfig.getFeatureFlags() ->
  [String: Any]?` (`PostHogRemoteConfig.swift:825`) is internal. The only public bulk API is
  `getAllFeatureFlags() -> [PostHogFeatureFlagResult]?` (`PostHogSDK.swift:2578-2583`), a structured
  array that emits no events. `PostHogFeatureFlagsLoaded.variants` (new, via `onFeatureFlags`)
  is a flat map, but only of enabled flags and only inside a callback, so it is not a getter.
  Unchanged from the previous audit.
- **Backwards compatibility:** Purely additive.
- **Remediation:** Add a public `getFeatureFlags() -> [String: Any]?` on `PostHogSDK` that exposes
  `remoteConfig.getFeatureFlags()`.

### n10 — Get Feature Flags And Payloads (❌ Fail)
- **Spec requires:** one call returning a flags map and a payloads map. New: each payload is
  decoded independently; malformed payloads are omitted or `nil`, never raw, without dropping the
  flag value or healthy sibling payloads; a valid JSON `""` is preserved.
- **SDK currently:** No such method (`grep -rn "getFeatureFlagsAndPayloads" PostHog/` → none).
  `getAllFeatureFlags()` (`PostHogSDK.swift:2578`) embeds a payload in each result, but it is
  built by the same `makeFeatureFlagResult`, so a malformed entry would come back raw
  (`PostHogRemoteConfig.swift:1100-1113`). Siblings are isolated, so other payloads are unaffected.
  Unchanged verdict.
- **Backwards compatibility:** Purely additive.
- **Remediation:** Add a public method returning both maps (for example, a struct with
  `featureFlags`/`featureFlagPayloads`), and build its payloads with the corrected decoder from Get
  Feature Flag Payload.

### n11 — Get Session ID (🟡 Partial)
- **Spec requires:** scenario "Session id rotates after inactivity timeout"
  (`openspec/specs/get-session-id/spec.md`, `acceptance/public/get-session-id.feature`). After the
  clock moves past the inactivity timeout, `getSessionId()` must return an id other than the
  previous one. The Requirement says implementations "MUST preserve the observable outcomes in
  the scenarios". Behavior step 5 names iOS's `readOnly` mode as allowed ("do not start a new
  session"), and Lifecycle says the next value after expiry "may be a new session id or no active
  session".
- **SDK currently:** `getSessionId()` (`PostHog/PostHogSDK.swift:454-460`) calls
  `sessionManager.getSessionId(readOnly: true)`. In `PostHogSessionManager.getSessionId`
  (`PostHog/PostHogSessionManager.swift:107-145`), `guard isNotReactNative(), !readOnly else {
  return currentSessionId }` (`:117`) returns before the inactivity and max-length expiry checks
  (`:127-138`). Nothing rotates the session on a timer. Rotation only happens on activity
  (`touchSession`, `:187-204`) or on the next non-read-only resolution when an event is built
  (`PostHog/PostHogSDK.swift:705-708`). So once the inactivity timeout has passed with no
  activity, `getSessionId()` returns the expired id. That is neither a new id nor "no active
  session", and the scenario fails. The code is unchanged since `c0218386`; the previous audit
  missed this. The other two scenarios pass: setup starts a session
  (`PostHog/PostHogSDK.swift:310`), and the getter returns the same id inside the timeout.
- **Backwards compatibility:** Backward-compatible for either fix. Clearing or rotating an expired
  session in the getter only changes the value returned after expiry, which today is already
  stale.
- **Remediation:** Have the read-only path check expiry without starting a session: return `nil`
  when `isExpired` is true for the activity or max-length threshold, as the spec's "no active
  session" option allows. Alternatively, rotate in the getter. Or, if the stale value is intended,
  get the spec scenario relaxed for read-only getters.

### n12 — Group (✅ Pass once [PostHog/posthog-ios#929](https://github.com/PostHog/posthog-ios/pull/929) merges; 🟡 at audited commit)
- **Pending fix ([PostHog/posthog-ios#929](https://github.com/PostHog/posthog-ios/pull/929)):** `group()` returns early with a log when `type` or `key` is empty. Whitespace-only values still pass, matching the spec's "non-empty" wording and `identify()`.
- **Spec requires:** blank or empty `groupType`/`groupKey` are rejected with a validation warning
  and don't change group state (`openspec/specs/group/spec.md:77`, scenario at `:131-136`).
- **SDK currently:** `group(type:key:groupProperties:)` (`PostHog/PostHogSDK.swift:2030-2052`) only
  checks `isEnabled()`, `isOptOutState()` and `requirePersonProcessing()`. It then calls
  `groups([type: key])` (`:2043`), which persists, and `groupIdentify(...)`. Empty `type`/`key` are
  stored and sent with no warning. Storage, `$groups` attachment through `dynamicContext()`
  (`:567-576`), and flag reload when a group changes (`:1861-1887`) are correct. Unchanged from
  the previous audit.
- **Backwards compatibility:** Backward-compatible. Validation only changes behavior for input
  that is already invalid.
- **Remediation:** Add `guard !type.isEmpty, !key.isEmpty else { hedgeLog(...); return }` at the
  top of `group(type:key:groupProperties:)`.

### n13 — Group Identify (✅ Pass once [PostHog/posthog-ios#929](https://github.com/PostHog/posthog-ios/pull/929) merges; 🟡 at audited commit)
- **Pending fix ([PostHog/posthog-ios#929](https://github.com/PostHog/posthog-ios/pull/929)):** The same `group()` guard covers `$groupidentify`, whose only caller is `group()`.
- **Spec requires:** `$groupidentify` with `$group_type`/`$group_key`/`$group_set`, and blank
  type/key rejected with a validation warning (`openspec/specs/group-identify/spec.md:64`,
  scenario at `:140-145`). iOS may omit a standalone public method (`:60`).
- **SDK currently:** Only a private `groupIdentify(type:key:groupProperties:)` exists
  (`PostHog/PostHogSDK.swift:1889-1925`), called only from `group()`, which the spec allows. The
  event shape is correct (`:1902-1909`). It has no blank check either, so an empty type/key from
  `group()` produces an invalid `$groupidentify`. Unchanged from the previous audit.
- **Backwards compatibility:** Backward-compatible. A guard in `group()` covers both contracts.
- **Remediation:** Same single guard as Group, since `groupIdentify` has no other caller.

### n14 — Is Feature Enabled (🟡 Partial)
- **Spec requires:** boolean mapping (`true`/variant → `true`, `false` → `false`) and suppressible
  tracking. Also: "The SDK SHALL accept a caller-supplied boolean default (`defaultValue`...) and
  SHALL return it whenever the flag has no value". A flag value, including `false`, wins over the
  default. The "allowed variation" covers only the *no-default* call (iOS may hard-code `false`).
- **SDK currently:** Mapping and tracking suppression are correct (`PostHogSDK.swift:2544-2562`).
  But the only overloads are `isFeatureEnabled(_:)` and `isFeatureEnabled(_:sendFeatureFlagEvent:)`.
  There is no `defaultValue` parameter anywhere in the public SDK
  (`grep -rn defaultValue PostHog/*.swift` → none), so the "resolves missing flags to the default"
  scenario with `default = true` cannot be expressed. This requirement predates the previous audit
  (spec unchanged since `8d250f1`); the earlier ✅ missed it. No code change.
- **Backwards compatibility:** Additive. A new optional `defaultValue: Bool = false` parameter (or
  an overload for ObjC) keeps current call sites unchanged.
- **Remediation:** Add `isFeatureEnabled(_ key: String, defaultValue: Bool = false,
  sendFeatureFlagEvent: Bool? = nil)` that returns `defaultValue` when `getFeatureFlag` yields `nil`.

### n15 — Opt In (🟡 Partial)
- **Spec requires:** canonical scenario "Opt out can clear local persistence when configured": opt-out
  called with local data clearing enabled clears persisted identity and super properties.
- **SDK currently:** `optIn()`/`optOut()` (`PostHog/PostHogSDK.swift:2731-2805`) guard on
  `isEnabled()`, no-op when already in the target state, persist under `optOutLock`, and install or
  uninstall integrations. New since the last audit: `optOut()` also unregisters the push subscription
  (`:2799`). `optIn()` re-requests the APNs token (`:2765-2773`). The SPI
  `persistOptOut` (`PostHog/PostHogConfig.swift:304`, default `true`) lets a host-owned consent store
  skip the disk write. The gap is unchanged: `optOut()` takes no parameter, and no config clears
  persisted distinct id or super properties on opt-out.
- **Backwards compatibility:** Backward-compatible. An optional `clearLocalStorage: Bool = false`
  parameter (or a config flag) keeps today's default behavior.
- **Remediation:** Add an optional clear-local-data parameter to `optOut()` that purges persisted
  identity and super properties from `PostHogStorage`.

### n16 — Reset (🟡 Partial)
- **Spec requires:** reset clears user-scoped state, including opt-out state (Behavior step 4,
  "State cleared by reset": "opt-out persistence"). Interactions says reset "should not be treated
  as a privacy-preserving alternative to opt-out". The bootstrap-seeding extension is optional
  (MAY).
- **SDK currently:** `reset()` (`PostHog/PostHogSDK.swift:860-907`) clears identity, super
  properties, groups, flag caches, the flag-called tracker (`:881-883`) and the person-properties
  hash. It rotates the session (`:884`), keeps the queue, reloads flags (`:893`) and notifies
  integrations (`:896`). `storage.reset(...)` deletes the persisted `.optOut` key
  (`PostHog/PostHogStorage.swift:511`), but `reset()` never clears the in-memory `config.optOut`
  that `isOptOutState()` (`:1220-1226`) and `isOptOut()` (`:2809-2815`) read. `optIn()` does clear
  it (`:2744`). So an opted-out user who calls `reset()` stays opted out until the next launch,
  when setup re-reads the now-missing key (`:274-277`). Unchanged from the previous audit. A newer
  `persistOptOut = false` mode (`PostHog/PostHogConfig.swift:304`, [#831](https://github.com/PostHog/posthog-ios/pull/831)) skips the persisted key
  entirely. In that mode reset already leaves opt-out alone, which is correct for a host that owns
  consent. The optional bootstrap-seeding extension is not implemented, which isn't a gap.
- **Backwards compatibility:** Backward-compatible signature-wise, but opted-out users who call
  `reset()` without restarting would see different runtime behavior, so it deserves a
  release-notes mention.
- **Remediation:** In `reset()`, when `config.persistOptOut` is true, set `config.optOut = false`
  under `optOutLock`, as `optIn()` does. Or get the spec to state explicitly that only persisted
  state is cleared.

### n17 — Shutdown (✅ Pass once [PostHog/posthog-ios#924](https://github.com/PostHog/posthog-ios/pull/924) merges; ❌ at audited commit)
- **Pending fix ([PostHog/posthog-ios#924](https://github.com/PostHog/posthog-ios/pull/924)):** `close()` now calls `flush()` on the event, replay and logs queues before stopping them (best-effort, not awaited). Satisfies the spec scenario; like `flush()` it sends one batch per queue (see n6).
- **Spec requires:** Behavior step 2, "Flush pending events … before tearing down workers/queues",
  and the `@both` scenario "Shutdown flushes queued events and disables future work" (the mock
  server receives "Save" and the queue is empty afterwards).
- **SDK currently:** `close()` (`PostHogSDK.swift:2820-2871`) sets `enabled = false` (`:2826`), then
  calls `queue?.stop()`, `replayQueue?.stop()`, and `logsQueue?.stop()` (`:2829-2831`) and nils
  all three, with no call to `flush()`. `PostHogQueue.stop()` (`PostHogQueue.swift:283-312`) only
  invalidates the timer and drops the reachability tokens. Queued events stay on disk for a future
  instance, but `close()` never attempts delivery. Idempotency (the `isEnabled()` guard), stopping
  workers (`reachability?.stopNotifier()` at `:2853`), blocking capture after close, and clearing
  the flag-called tracker (`:2857`) all match the spec. Unchanged from the previous audit.
- **Backwards compatibility:** Backward-compatible. A best-effort final flush before `stop()` is
  additive, and the `close()` doc comment promises nothing about dropping queued events.
- **Remediation:** Before stopping the queues, call `flush()` on each one as a bounded, best-effort
  final send (`consume` already refuses new prefixes once `stopped` is set,
  `PostHogQueue.swift:449`). Add a regression test that the mock server receives events queued
  before `close()`.

### n18 — Stop Session Recording (✅ Pass once [PostHog/posthog-ios#933](https://github.com/PostHog/posthog-ios/pull/933) merges; 🟡 at audited commit)
- **Pending fix ([PostHog/posthog-ios#933](https://github.com/PostHog/posthog-ios/pull/933)):** `stopSessionRecording()` calls `replayQueue?.flush()` after stopping the recorder; snapshots held by the minimum-duration/remote-config buffer stay held. Sends one batch, like `flush()`.
- **Spec requires:** per the acceptance scenario "Stop session recording finalizes pending replay
  data" (`acceptance/public/stop-session-recording.feature`, tagged `@client`): "pending replay data
  should be finalized before the recorder stops... and no new replay snapshots should be captured."
- **SDK currently:** Still unchanged. New captures stop correctly, but pending data is not
  finalized. `stopSessionRecording()` (`PostHog/PostHogSDK.swift:2953-2963`) only calls
  `replayIntegration.stop()`. `PostHogReplayIntegration.stop()`/`stopRecording()`
  (`PostHog/Replay/PostHogReplayIntegration.swift:392-423`) clears listeners and plugins and never
  calls `replayQueue.flush()`. Compare `PostHogSDK.flush()` (`PostHog/PostHogSDK.swift:823-832`),
  which flushes `queue`, `replayQueue` and `logsQueue`. Queued `$snapshot` events stay on disk until
  the next periodic or background flush.
- **Backwards compatibility:** Backward-compatible. Adding `replayQueue?.flush()` inside
  `stopSessionRecording()` is additive and changes no signature. `PostHogReplayQueue.flush()`
  already does nothing while the minimum-duration or remote-config hold is buffering
  (`PostHog/Replay/PostHogReplayQueue.swift:79-85`), so the ingestion gates are unchanged.
- **Remediation:** Call `replayQueue?.flush()` after `replayIntegration.stop()` in
  `PostHog/PostHogSDK.swift:2953-2963`.

### n19 — Exception Event Metadata (🟡 Partial)
- **Pending fix ([PostHog/posthog-ios#931](https://github.com/PostHog/posthog-ios/pull/931)):** Adds `exception_id`/`parent_id`, `chained`/`cause` on nested entries without copied `handled`, the 50-entry cap, `$exception_source` (`ios.crash_reporter`, `ios.metrickit_memory_exception` for OOM), `value: ""` for reason-less exceptions, makes `$exception_list`/`$debug_images` win over `captureException` caller properties, and skips UUID-less debug images. Still open: caller properties can still override `$exception_level`/`$exception_source`, deliberately — the level is hardcoded to `"error"` with no typed parameter, so the caller property is the only way to set it, and posthog-android/posthog-js also let callers win. Needs a typed level parameter or a spec change first. Outermost crash `mechanism.type` values (`signal`, `mach_exception`, …) stay as allowed by the extensible vocabulary.
- **Spec requires:** a canonical `$exception` envelope where every entry has a string `type`/`value`
  and a `mechanism`, with `exception_id` 0 on the outermost entry and unique ids plus `parent_id`,
  `type: "chained"` and `source` on nested entries. Also: at most 50 entries; nested `handled` omitted
  unless independently known (never copied from the outermost); `$exception_source` from
  capture-boundary knowledge (`ios.crash_reporter` for the native crash reporter, and
  `<technology>.<hook>` for other maintained integrations); application property bags MUST NOT
  override `$exception_list`/`$exception_level`/`$exception_source`/`$debug_images`; `$debug_images`
  entries need a non-empty `debug_id`, and images without one SHALL be omitted. New since 0ea0aba: a
  shared 1,000-member aggregate inspection budget, and flat `$exception_type`/`$exception_message`
  listed as legacy, non-authoritative input.
- **SDK currently:** `PostHogExceptionProcessor.swift` and `PostHogCrashReportProcessor.swift` have
  not changed since c0218386, and every previous gap is still present:
  - `grep -rn "exception_id\|parent_id\|exception_source\|chained" PostHog/` returns no hits. No
    linkage ids, no `mechanism.source`, and no `$exception_source` on any path.
  - Nested entries reuse the outermost `mechanismType` and `handled`
    (`PostHog/ErrorTracking/PostHogExceptionProcessor.swift:145-155, 194-204`, assigned at `:232`/`:281`).
  - The `NSUnderlyingErrorKey` walk has cycle detection but no 50-entry cap (`:136-141`, `:186-191`).
  - On manual capture, caller properties overwrite SDK-owned keys
    (`PostHog/PostHogSDK.swift:3243-3244`). The crash path gets precedence right
    (`PostHog/ErrorTracking/PostHogErrorTrackingAutoCaptureIntegration.swift:272`).
  - Images with a `nil` UUID are still emitted without `debug_id`: crash path
    (`PostHog/ErrorTracking/PostHogCrashReportProcessor.swift:249-258`), live-process path
    (`PostHog/ErrorTracking/Utils/PostHogDebugImageProvider.swift:97-100`), both serialized by
    `PostHogBinaryImageInfo.toDictionary` (`Models/PostHogBinaryImageInfo.swift:53`).

  New findings:
  - An `NSException` with an empty or `nil` `reason` gets no `value` key at all, because of
    `if let reason ..., !reason.isEmpty` (`PostHogExceptionProcessor.swift:260-262`). The envelope
    requires a string `value`, which may be empty.
  - The new iOS 27 OOM path ([#853](https://github.com/PostHog/posthog-ios/pull/853)) builds a terminating `fatal`/`handled: false` event but omits
    `$exception_source` (`PostHog/ErrorTracking/PostHogMemoryExceptionProcessor.swift:62-86`). It does
    filter UUID-less images correctly (`:39`).
  - The aggregate-budget requirement has no practical effect: iOS never reads
    `NSMultipleUnderlyingErrorsKey`, and flat `$exception_type`/`$exception_message` are never emitted.

  Still correct: a non-empty outermost-first list; `generic`/`handled: true`/`error` defaults for manual
  capture; `fatal`/`handled: false` on crash and OOM; per-entry `synthetic` follows the table (`true`
  for a current-stack replacement, `false` for an NSException's own stack); and no processor-owned
  properties are synthesized.
- **Backwards compatibility:** Backward-compatible. Linkage fields, `chained`/`source`,
  `$exception_source`, truncation, and an empty-string `value` are additive or corrective wire
  changes. Fixing precedence changes behavior only for callers who override reserved keys through
  `properties:`, which the spec forbids. Dropping UUID-less images only removes entries.
- **Remediation:** (1) In both `buildExceptionList` overloads, assign `exception_id` (0..n) and
  `parent_id` (i-1), and set `type: "chained"` and `source: "cause"` on nested entries, omitting
  their `handled`. (2) Cap the chain at 50 entries. (3) Set `$exception_source = "ios.crash_reporter"`
  on crash reports, and an `ios.<hook>` value on the OOM reporter. (4) In `captureExceptionEvent`,
  strip `$exception_list`/`$exception_level`/`$exception_source`/`$debug_images` from caller
  properties before merging. (5) Skip images with `uuid == nil`. (6) Emit `"value": ""` when an
  NSException has no reason.

### n20 — Feature Flag Cache (🟡 Partial)
- **Spec requires:** cache reads/writes, persistence, and clearing on reset. New since `0ea0aba`:
  cached payload reads SHALL NOT expose invalid JSON (incl. empty/whitespace) as a raw string. They
  SHALL log the failure and treat the payload as absent without touching the flag value or siblings.
  Already-decoded strings MUST NOT be decoded again. Internal caches MAY stay serialized.
- **SDK currently:** Core cache behavior is unchanged and correct. Payloads are stored serialized
  under `.enabledFeatureFlagPayloads` (`PostHogRemoteConfig.swift:919-926`), which is allowed. The
  read path breaks the new rule: on a decode failure `makeFeatureFlagResult`
  (`PostHogRemoteConfig.swift:1106-1117`) returns the raw string. Bootstrapped payloads, documented
  as already decoded (`PostHogBootstrapConfig.swift:47-52`), share that cache
  (`PostHogRemoteConfig.swift:881`) and are decoded again on read. Reads make no network request.
  Previously ✅; the requirement is new.
- **Backwards compatibility:** Only invalid payloads and bootstrapped numeric/boolean-looking
  strings change.
- **Remediation:** Return `nil` on decode failure, and keep bootstrapped payloads out of the
  string-decode path (see Get Feature Flag Payload).

### n21 — Feature Flag Called Tracker (✅ Pass once [PostHog/posthog-ios#928](https://github.com/PostHog/posthog-ios/pull/928) merges; 🟡 at audited commit)
- **Pending fix ([PostHog/posthog-ios#928](https://github.com/PostHog/posthog-ios/pull/928)):** Adds `$referring_domain`, the five `utm_*` keys, `gad_source`, `mc_cid`, `gclid` and `fbclid` to the minimal allowlist; `$referrer` stays excluded. posthog-js keeps a longer click-id list.
- **Spec requires:** dedupe `$feature_flag_called` per flag/value, re-emit on change, clear on reset
  and shutdown. A server-gated minimal-event mode (`minimalFlagCalledEvents` plus `has_experiment ==
  false`) whose allowlist covers session-attribution keys: `$referring_domain` and the
  campaign/click-id params the SDK registers (`utm_*`, `gad_source`, `mc_cid`, `gclid`/`fbclid`).
- **SDK currently:** Dedupe in `reportFeatureFlagCalled` (`PostHogSDK.swift:2643-2717`), cleared on
  `reset()` (`PostHogSDK.swift:881-883`) and `close()` (`PostHogSDK.swift:2856-2858`). The gate fails
  safe and is persisted with the flags (`PostHogRemoteConfig.swift:543, 1156-1160`, cleared at
  `1233`). `minimalFeatureFlagCalledProperties` (`PostHogSDK.swift:2615-2641`) still has no
  `$referring_domain`, `utm_*`, `gad_source`, `mc_cid`, `gclid` or `fbclid`. iOS still registers none
  of these as super properties: `$referring_domain` appears only on the deep-link event
  (`AppLifeCycle/PostHogDeepLinkHelper.swift:24`). The gap is literal but has no effect today.
  Unchanged from the previous audit, apart from line numbers.
- **Backwards compatibility:** Additive; it only adds keys back into minimized events.
- **Remediation:** Add the session-attribution keys to `minimalFeatureFlagCalledProperties`.

### n22 — HTTP Client (✅ Pass once [PostHog/posthog-ios#926](https://github.com/PostHog/posthog-ios/pull/926) merges; 🟡 at audited commit)
- **Pending fix ([PostHog/posthog-ios#926](https://github.com/PostHog/posthog-ios/pull/926)):** Flags requests now also retry `NotConnectedToInternet`, `CannotFindHost`, `DNSLookupFailed` and `SecureConnectionFailed`; refused connections stay fail-fast. Certificate-validation errors are not retried (posthog-android#828 retries them via `SSLException`).
- **Spec requires:** flag requests SHALL retry transient transport failures, naming "network
  error, connection reset/lost, timeout, DNS/socket/TLS transport failure". The updated text adds
  "DNS, TLS, timeout, and connection reset/lost failures still retry". A refused connection SHALL
  NOT be retried (new). Flag requests retry only 502/504, with one retry by default and 300ms
  doubling backoff.
- **SDK currently:** `isRetryableFlagsError` (`PostHogApi.swift:478-484`) returns true only for
  `NSURLErrorTimedOut` and `NSURLErrorNetworkConnectionLost`. DNS failures
  (`NSURLErrorCannotFindHost`, `NSURLErrorDNSLookupFailed`), TLS failures
  (`NSURLErrorSecureConnectionFailed`), and `NSURLErrorNotConnectedToInternet` fail on the first
  attempt (`:397-409`). The new refused-connection rule is met: `NSURLErrorCannotConnectToHost` is
  not retried. Status retries (502/504 only, `:486-488`), the default budget
  (`featureFlagRequestMaxRetries = 1`, `PostHogConfig.swift:36`), and the backoff
  (`0.3 * 2^(n-1)` capped at 30s, `PostHogApi.swift:474-476`) match. The code is unchanged since
  [#674](https://github.com/PostHog/posthog-ios/pull/674); the previous ✅ missed the DNS/TLS gap.
- **Backwards compatibility:** Backward-compatible. Widening the retryable error set adds at most
  one bounded retry per flags request.
- **Remediation:** Add `NSURLErrorCannotFindHost`, `NSURLErrorDNSLookupFailed`,
  `NSURLErrorSecureConnectionFailed` (and the related `-12xx` TLS codes), and
  `NSURLErrorNotConnectedToInternet` to `isRetryableFlagsError`. Keep
  `NSURLErrorCannotConnectToHost` non-retryable.

### n23 — Persistent Storage (🟡 Partial)
- **Spec requires:** canonical scenario "Storage failures do not crash SDK calls": when storage
  writes fail, the call does not throw **and the SDK records a storage warning**.
- **SDK currently:** `PostHogStorage` wraps its I/O in `do`/`catch` and falls back on unreadable or
  corrupt data (`PostHog/PostHogStorage.swift:365-373` read, `:376-393` write, `:396-424` JSON
  encode/decode). A write failure only calls `hedgeLog` (`:391`). `hedgeLog` is a plain `print` that
  does nothing unless debug logging is on (`PostHog/Utils/Hedgelog.swift:10-20`), so there is no
  distinct, observable storage-warning signal. The storage commits since c0218386 ([#803](https://github.com/PostHog/posthog-ios/pull/803) iCloud backup
  exclusion, [#807](https://github.com/PostHog/posthog-ios/pull/807), [#817](https://github.com/PostHog/posthog-ios/pull/817), [#893](https://github.com/PostHog/posthog-ios/pull/893)) did not change this.
- **Backwards compatibility:** Backward-compatible. A dedicated warning channel is additive.
- **Remediation:** Give storage write failures their own warning signal (a distinct log level that
  is always emitted, a counter, or a delegate hook), separate from the debug-only `hedgeLog`.

### n24 — Session Replay Privacy (❌ Fail)
- **Spec requires:** elements tagged with a no-capture marker (`ph-no-capture`, `postHogMask(...)`)
  are masked even when broad category masking is off. A no-capture element and all its descendants
  must be left out of the snapshot. Native wireframe replay must mask sensitive text and drop
  sensitive images before serialization (Behavior 2 and 4; scenario "Replay privacy excludes
  no-capture elements"). The new "Browser replay network body scrubber replacement" requirement is
  browser-only.
- **SDK currently:** The no-capture leak in the default wireframe mode (`screenshotMode = false`,
  `PostHog/Replay/PostHogSessionReplayConfig.swift:51`) is still present.
  `toWireframe` (`PostHog/Replay/PostHogReplayIntegration.swift:1432-1566`) has no generic
  `isNoCapture()` check. The marker is checked only inside the per-widget helpers
  (`isTextInputSensitive`/`isImageViewSensitive`/`isSwiftUIImageSensitive`, `:1362-1430`).
  `isNoCapture()` reads only the view's own accessibility identifier and label
  (`PostHog/Replay/UIView+Util.swift:72-100`), and the subview loop (`:1556-1563`) always recurses.
  So a plain container tagged `ph-no-capture` still has its child labels, images and inputs
  serialized unmasked. `toWireframe` also never reads the SwiftUI `postHogMask()` reporter registry
  (`PostHog/SwiftUI/PostHogMaskViewModifier.swift:60-117`), which only the screenshot path uses.
  A root SwiftUI hosting controller is skipped entirely in wireframe mode
  (`PostHog/Replay/PostHogReplayIntegration.swift:1695-1698`), but SwiftUI embedded under a UIKit
  root is not. Screenshot mode masks the subtree correctly (`findMaskableWidgets`, `:1100-1121`).
  Correction to the previous note: the current spec does not say secure-entry masking beats an
  explicit unmask. It says explicit unmask markers take precedence, and secure-entry masking only
  beats *disabled broad text masking*. The code now checks `isNoMask()` first on purpose (`:943`),
  and that matches the spec. The network plugin records only URL, method, status, duration and body
  size (`PostHog/Replay/NetworkSample.swift:12-20`). No headers or bodies, so the new browser
  network requirement does not apply.
- **Backwards compatibility:** The fix adds no API and changes no signature. It does change what
  apps that tag container views with `ph-no-capture` record today, so ship it with a clear
  changelog or security note.
- **Remediation:** In `toWireframe`, when `view.isNoCapture()` is set (or an ancestor carried it),
  emit an opaque placeholder wireframe for the view and do not recurse into its subviews, matching
  `findMaskableWidgets`. Also apply the SwiftUI mask registry in wireframe mode. Add wireframe
  regression tests for both.

### n25 — Bootstrap (🟡 Partial)
- **Spec requires:** (optional, MAY) a client SDK that owns a session id MAY accept
  `bootstrap.sessionID` (UUIDv7), adopt it, and derive the session start from it. An invalid
  value SHALL log an error and fall back to a generated id (`openspec/specs/bootstrap/spec.md:143-158`).
  `acceptance/public/bootstrap.feature:201-211` has the matching scenarios, untagged.
- **SDK currently:** Every SHALL requirement is met. Fresh-install identity seeding is in
  `PostHog/PostHogStorageManager.swift:47-70`. Identified-bootstrap reconciliation is in
  `PostHog/PostHogSDK.swift:376-416`. Flag/payload seeding, enabled-only serving, and
  complete-response replacement are in `PostHog/PostHogRemoteConfig.swift:131-153,562-575,872-882`.
  Bootstrap is cleared on reset (`PostHogRemoteConfig.swift:1240-1247`). `$used_bootstrap_value`
  enrichment is at `PostHogRemoteConfig.swift:893-908`. The flags-loaded notification fires at
  setup (`PostHog/PostHogSDK.swift:356`), and the public `onFeatureFlags` listener was added in
  [#897](https://github.com/PostHog/posthog-ios/pull/897). `PostHogBootstrapConfig` (`PostHog/PostHogBootstrapConfig.swift:28-52`) still has only
  `distinctId`, `isIdentifiedId`, `featureFlags` and `featureFlagPayloads`, and
  `PostHogSessionManager.swift` never mentions bootstrap. That makes this a spec-permitted (MAY)
  omission. It is rated 🟡 to match the matrix convention for posthog-android, posthog-flutter and
  posthog-react-native. Unchanged from the previous audit.
- **Backwards compatibility:** Backward-compatible. An optional `sessionID` field is additive.
- **Remediation:** Add optional `sessionID` bootstrap support, with UUIDv7 validation and the
  start timestamp taken from the id, if parity with posthog-js is wanted.

### n26 — Session Replay Debug Properties (🟡 Partial)
- **Pending fix ([PostHog/posthog-ios#932](https://github.com/PostHog/posthog-ios/pull/932)):** Fixes (c): events report `disabled` when there is no session id, matching `isSessionReplayActive()`. Still open: (a) caller-supplied `$session_id` start time, (b) backdated events.
- **Spec requires:** four required keys on every non-`$snapshot` event (`$recording_status`,
  event and linked-flag trigger statuses, internal buffer length). An optional bundle
  (`$sdk_debug_session_start`, flush hold reason, pending trigger conditions, capture mode), sent
  only on `$`-prefixed events other than `$feature_flag_called`/`$snapshot`, at most once per 30 s
  wall-clock window. The window starts at acceptance and uses a single claim. Also:
  `$sdk_debug_pending_queue_size` on every non-`$snapshot` event, and a `disabled` fallback when no
  integration is installed. The crash-context snapshot must carry the full bundle and never move
  the window. Plus:
  (a) `$sdk_debug_session_start` "MUST never describe" a different session than the event's own
  `$session_id`. For a caller-supplied id it must come from the UUIDv7 timestamp, and be omitted
  when the id is not UUIDv7.
  (b) An event whose explicit timestamp is before the current session's start "MUST NOT" carry the
  current process's live state. It gets the persisted snapshot or none of the keys.
  (c) `$recording_status: active` SHALL imply `isSessionReplayActive()` returns `true`.
- **SDK currently:** First audit. Most of the contract is implemented:
  - The required and optional tiers, with eligibility decided on the original name and carried
    across `beforeSend` by a claim marker (`PostHog/PostHogSDK.swift:627-688`, `:751-773`,
    `:1933-1959`).
  - A single non-expiring claim, committed on queue store and released on drop, dedup or failed
    store (`:1971-2008`).
  - `close()` clears the window (`:2837-2840`).
  - Debug values override caller and super properties (`:761`, `:813`).
  - The minimal flag envelope is filtered to its allowlist (`:1624-1628`).
  - The `disabled` fallback, with capture mode only on iOS (`:744-753`).
  - The crash context is built read-only with the full bundle and the point-in-time keys stripped
    (`:3352-3381`). Crash and OOM reports bypass `buildProperties` (`skipBuildProperties: true`,
    `PostHog/ErrorTracking/PostHogErrorTrackingAutoCaptureIntegration.swift:289-295`,
    `PostHog/ErrorTracking/PostHogMemoryExceptionReporter.swift:74-79`).
  - In the integration, status, hold reason, capture mode and trigger statuses are computed from
    one `bufferingLock` read (`PostHog/Replay/PostHogReplayIntegration.swift:1888-1942`).

  Gaps:
  (a) `$sdk_debug_session_start` always comes from `sessionManager.sessionStartTimestampSnapshot`
  (`PostHog/PostHogSDK.swift:755-757`), even when the caller supplied a different `$session_id`
  (`:705-708`). There is no UUIDv7 derivation and no omission.
  (b) `buildProperties` never compares the event timestamp with the session start (`:704-773`).
  A public `capture(..., timestamp:)` (`:1390-1397`) dated before the current session starts still
  gets live `$recording_status` and `$sdk_debug_*` values.
  (c) `debugProperties()` reports `active` from `isEnabled`, the flag and the hold state only
  (`PostHog/Replay/PostHogReplayIntegration.swift:1901-1906`). `isSessionReplayActive()` also
  requires a non-empty session id (`PostHog/PostHogSDK.swift:3030-3032`). When a backgrounded
  session times out, `clearSession` sets the id to nil (`PostHog/PostHogSessionManager.swift:127-130`).
  `handleSessionChanged` returns early on a nil id (`PostHog/Replay/PostHogReplayIntegration.swift:491-493`),
  so later events carry `active` while the getter returns `false`.
  Not flagged: `$sdk_debug_error_capturing_properties`, because the iOS build cannot throw, and
  the browser-only keys and drop counters.
- **Backwards compatibility:** Backward-compatible. These are internal property-build changes with
  no API or signature change. Affected events only lose or correct diagnostic keys.
- **Remediation:**
  (a) When `propSessionId` is non-empty and differs from the manager's id, take the session start
  from the UUIDv7 timestamp, or omit it when the id is not v7.
  (b) Skip the required keys and the bundle when `timestamp` is earlier than the current session
  start.
  (c) Report `disabled` when the read-only session id is nil or empty, mirroring the getter.
  Add one test per scenario.
