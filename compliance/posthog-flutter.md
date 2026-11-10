# posthog-flutter — SDK Compliance

**Repo:** [PostHog/posthog-flutter](https://github.com/PostHog/posthog-flutter)
**Audited commit:** `82123e6d8815c89a9f603b4f23e72d72494eee2b` ([commit](https://github.com/PostHog/posthog-flutter/commit/82123e6d8815c89a9f603b4f23e72d72494eee2b)), the head of the posthog_flutter 6.0 release PR [PostHog/posthog-flutter#637](https://github.com/PostHog/posthog-flutter/pull/637) — audited on 2026-11-10, before 6.0.0 is published
**Audited against sdk-specs commit:** `752f899` plus [#146](https://github.com/PostHog/sdk-specs/pull/146) at `23c2478` (capture v1, including #147's AI lane), treated as merged to `main`
**Summary:** 23 ✅ · 30 🟡 · 4 ❌ · 12 ➖ · 0 ❓ (69 rows; previous audit 2026-10-19 at `1032c102` (5.x) scored 21/29/6/8/0 on 64 rows)

**Why this run:** posthog_flutter 6.0 ([PostHog/posthog-flutter#637](https://github.com/PostHog/posthog-flutter/pull/637))
adopts posthog-ios 4.0 and posthog-android 4.0 (`Package.swift` pins `"4.0.0" ..< "5.0.0"`,
`android/build.gradle:70` pins `[4.0.0,5.0.0)`), sends events through capture v1 on every platform
except web, makes `beforeSend` synchronous and runs it on the event the native SDK built, and removes
the APIs deprecated in 5.x (`.changeset/v6-major-release.md`, `posthog_flutter/MIGRATION.md`).

**Scope.** All 64 rows were re-read at `82123e6`, and five rows were added for contracts the README
table carries (Experiment Exposure, AI Datasets, AI Scorers, Offline Evaluations, Emails). Where a
row's behaviour on iOS, macOS or Android comes from the native SDK, it was checked in posthog-ios at
`e27cbe4cb` and posthog-android at `aaa23d39`, the heads of their unreleased 4.0 branches
(`chore/v4-remove-deprecated`); some notes also cite those SDKs' compliance files for gaps that
didn't change. Windows and Linux run this repo's Dart core and are scored directly; web delegates to
posthog-js. Notes for rows whose Dart code and governing spec text did not change carry forward from
2026-10-19, with line references at `1032c102`; every rewritten note cites `82123e6`, with paths
relative to `posthog_flutter/`.

**Spec assumptions.** #146's capture v1 text at `23c2478` (which includes `15501ca`) is treated as merged, including two points
settled on that PR: a client SDK fills its own `$lib`/`$lib_version` pair after every other property
layer and before `beforeSend` (**Events name their own library**, the one exception to **Caller-supplied
event properties take precedence**), and a delivery lane with its own compression setting
(`capture-ai`) is outside `http-client`'s whole-client compression opt-out.

## Platforms

Every row is scored across three execution paths:

| Platform | Implementation | Where the behaviour lives |
|---|---|---|
| iOS / Android / macOS | `PosthogFlutterIO` — `MethodChannel('posthog_flutter')`; since 6.0 events are built by the native SDK (`buildEventForWrapper` / `buildEvent`), `beforeSend` runs on the built event in Dart, and the native SDK sends what it returns (`lib/src/posthog_flutter_io.dart:107-170`) | embedded native `posthog-ios` 4.x / `posthog-android` 4.x |
| Windows / Linux | `PosthogFlutterDesktop` → the Dart core (`lib/src/core/`), with its own capture v1 transport (`lib/src/core/capture_v1.dart`) and an AI lane | this repo, directly auditable |
| Web | `PosthogFlutterWeb` → `window.posthog` via `dart:js_interop` | `posthog-js` (not on capture v1) |

Where the paths disagree the row is 🟡 and the note says which platform fails.

## Movement this run

**Improved (6):**
- **Get Feature Flag 🟡→✅** ([n13](#n13)): `getFeatureFlag(key, {sendFeatureFlagEvent})` on every path.
- **Is Feature Enabled 🟡→✅** ([n20](#n20)): `isFeatureEnabled(key, {sendFeatureFlagEvent, defaultValue})`.
- **HTTP Client 🟡→✅** ([n19](#n19)): the Dart core no longer retries a refused `/flags` connection, backs
  off exponentially, and its capture v1 transport conforms. Separate `compression` and
  `captureAiCompression` options are what #146 now allows.
- **On Feature Flags 🟡→✅** ([n22](#n22)): `Posthog().onFeatureFlags()` returns a subscription, and
  posthog-ios 4.0 now drops a `/flags` load in flight across `reset()`, so no path delivers a load
  that `reset()` or `close()` discarded. Listeners never receive an empty variant (#193).
- **Get Feature Flags ❌→🟡** ([n16](#n16)) and **Get Feature Flags And Payloads ❌→🟡** ([n17](#n17)):
  `getAllFeatureFlags()` returns a list of flag results, the surface the spec records for flutter 6.0;
  it is still not the canonical map shape.

**Newly in scope (1):** **Capture AI ➖→🟡** ([n39](#n39)): #146 names posthog-flutter 6.0. The native
and Dart AI lanes conform, but on Windows/Linux AI events share capture's session-id gap ([n41](#n41)).

**Downgraded on new spec text (2):** **Identify ✅→🟡** ([n40](#n40)): the Dart core ignores `identify()`
while opted out, but #167 made opt-out "not a guard" for identify. **Capture ✅→🟡** ([n41](#n41)):
under #146, the Dart core replaces an empty or non-string caller `$session_id` with its own instead of
lifting or dropping it, and (`15501ca`) the migration guide doesn't yet show the
`process_person_profile: true` call option that keeps identity calls under a registered `false`.
Every path except web fills `$lib`/`$lib_version` as a pair after the
caller's properties, and leaves an empty variant out of `$active_feature_flags`.

**Same status, new or changed findings:** Get Feature Flag Payload and Get Feature Flag Result
([n14](#n14), [n15](#n15): `getFeatureFlagPayload()` is removed and payloads are read through
`getFeatureFlagResult(key, sendFeatureFlagEvent: false)`, which the spec permits; posthog-ios 4.0
returns no payload for malformed JSON, so only web still returns the raw string), Before Send Hook
([n3](#n3): the throwing-hook log line now has to name the event and omit the exception message),
Surveys ([n35](#n35): posthog-android still moves the last-seen survey date on submit and
dismiss, against #102; posthog-ios now writes it on show), Opt In ([n23](#n23): #138's replay restart
and #199's deferred crash consent are met through the native SDKs), Get Feature Flags ([n16](#n16):
on web, posthog-js reads an empty variant as enabled in the list), Session Replay Debug Properties
([n28](#n28): mobile events now carry the native bundle; the Dart core still sends session start and
duration on every desktop event), Event Batcher ([n8](#n8)), Retry Queue
([n38](#n38)), Group ([n18](#n18)), Alias ([n1](#n1)).

**New rows (5):** Experiment Exposure ➖ (every path requests `/flags/?v=2`: Dart core
`lib/src/core/posthog_core_stateless.dart:471`, posthog-ios `PostHogApi.swift:596-597`, posthog-android
`PostHogApi.kt:598`, and posthog-js likewise), AI Datasets ➖, AI Scorers ➖, Offline Evaluations ➖,
Emails ➖ (all server-only).

## Matrix

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Alias | 🟡 | [n1] |
| 2 | Application Lifecycle | ✅ | |
| 3 | Autocapture | 🟡 | [n2] |
| 4 | Before Send Hook | 🟡 | [n3] |
| 5 | Bootstrap | 🟡 | [n4] |
| 6 | Capture | 🟡 | [n41] |
| 7 | Capture AI | 🟡 | [n39] |
| 8 | Capture Exception | ✅ | [n5] |
| 9 | Consent Gating | 🟡 | [n6] |
| 10 | Create Person Profile | ➖ | |
| 11 | Debug | 🟡 | [n7] |
| 12 | Device ID Generator | ➖ | |
| 13 | Evaluate Flags | ➖ | |
| 14 | Event Batcher | 🟡 | [n8] |
| 15 | Exception Event Metadata | ❌ | [n9] |
| 16 | Exception Steps | ✅ | |
| 17 | Feature Flag Cache | ✅ | |
| 18 | Feature Flag Called Tracker | 🟡 | [n10] |
| 19 | Flag Definition Loader | ➖ | |
| 20 | Flush | 🟡 | [n11] |
| 21 | Get Anonymous ID | ❌ | [n12] |
| 22 | Get Distinct ID | ✅ | |
| 23 | Get Feature Flag | ✅ | [n13] |
| 24 | Get Feature Flag Payload | 🟡 | [n14] |
| 25 | Get Feature Flag Result | 🟡 | [n15] |
| 26 | Get Feature Flags | 🟡 | [n16] |
| 27 | Get Feature Flags And Payloads | 🟡 | [n17] |
| 28 | Get Session ID | ✅ | |
| 29 | Group | 🟡 | [n18] |
| 30 | Group Identify | ➖ | |
| 31 | HTTP Client | ✅ | [n19] |
| 32 | Identify | 🟡 | [n40] |
| 33 | Is Feature Enabled | ✅ | [n20] |
| 34 | Is Opt Out | ✅ | |
| 35 | Is Session Replay Active | ✅ | |
| 36 | Local Feature Flag Evaluator | ➖ | |
| 37 | Logs | 🟡 | [n21] |
| 38 | MCP Analytics | ➖ | |
| 39 | On Feature Flags | ✅ | [n22] |
| 40 | Opt In | 🟡 | [n23] |
| 41 | Persistent Storage | 🟡 | [n24] |
| 42 | Register | 🟡 | [n25] |
| 43 | Reload Feature Flags | ✅ | |
| 44 | Remote Config | 🟡 | [n26] |
| 45 | Reset | ✅ | |
| 46 | Reset Group Properties For Flags | ✅ | |
| 47 | Reset Person Properties For Flags | ✅ | |
| 48 | Retry Queue | 🟡 | [n38] |
| 49 | Screen | ✅ | [n27] |
| 50 | Session Manager | ✅ | |
| 51 | Session Replay Debug Properties | 🟡 | [n28] |
| 52 | Session Replay Ingestion Controls | ✅ | |
| 53 | Session Replay Privacy | 🟡 | [n29] |
| 54 | Set Group Properties For Flags | ✅ | |
| 55 | Set Person Properties | ✅ | [n30] |
| 56 | Set Person Properties For Flags | ✅ | |
| 57 | Setup | 🟡 | [n31] |
| 58 | Shutdown | 🟡 | [n32] |
| 59 | Start Session Recording | 🟡 | [n33] |
| 60 | Stop Session Recording | 🟡 | [n34] |
| 61 | Surveys | 🟡 | [n35] |
| 62 | Traces | ❌ | [n36] |
| 63 | Tracing Headers | ❌ | [n37] |
| 64 | Unregister | ✅ | |
| 65 | Experiment Exposure | ➖ | **new row**: applies to SDKs that read `/flags?v=4` records; every Flutter path requests `/flags/?v=2` |
| 66 | AI Datasets | ➖ | **new row**: server SDKs only |
| 67 | AI Scorers | ➖ | **new row**: server SDKs only |
| 68 | Offline Evaluations | ➖ | **new row**: server SDKs only |
| 69 | Emails | ➖ | **new row**: "Server SDKs only" — needs a secret key that must never reach a client |

## Notes

Notes [n2](#n2), [n4](#n4), [n5](#n5), [n7](#n7), [n10](#n10)–[n12](#n12), [n21](#n21), [n24](#n24)–[n27](#n27),
[n29](#n29), [n30](#n30), [n33](#n33), [n34](#n34), [n36](#n36) and [n37](#n37) carry forward from the
2026-10-19 audit: the Dart code they cite and the spec text that governs them are unchanged at
`82123e6`, and their status holds. Their line references are at `1032c102`; [n10](#n10) and
[n25](#n25) add one sentence each at `82123e6`. The other notes are rewritten for 6.0, and
[n39](#n39)–[n41](#n41) are new.

### n1 — Alias (🟡 Partial)
- **Spec requires:** the `@client` scenario (`acceptance/public/alias.feature:28-40`) wants `alias` and `distinct_id` in the `$create_alias` properties, and the `@both` scenario (`:42-50`) wants a call with a missing identity dropped with a validation warning.
- **SDK currently (`82123e6`):** `Posthog().alias({required String alias, options})` (`lib/src/posthog.dart:480-481`) forwards without a blank check, so the mobile paths rely on the native SDKs. posthog-android 4.0 now adds `distinct_id` (`PostHog.kt:2112-2141` at `aaa23d39`) but still accepts a blank alias; posthog-ios is 🟡 for the same reason (`compliance/posthog-ios.md` n3). Web forwards to posthog-js `alias()` (no empty-alias guard, `compliance/posthog-js.md` n1). Windows/Linux conform: the Dart core warns and ignores a blank alias and sends both properties.
- **Backwards compatibility:** Backward-compatible — rejecting a blank alias only affects calls that produce a malformed event today.
- **Remediation:** Reject a blank alias with a warning in `Posthog().alias()`, which covers every platform.

### n2 — Autocapture (🟡 Partial)
- **Spec requires:** Per `openspec/specs/autocapture/spec.md` Applicability, client SDKs that can observe UI interactions provide generic interaction autocapture (`$autocapture` with element context); client SDKs that only provide screen-view or lifecycle capture "should document that generic interaction autocapture is unsupported". `$rageclick` and similar extensions are supplemental to the core interaction path.
- **SDK currently:** Flutter owns a full widget tree but implements no generic tap/click autocapture. A grep of `lib/`, `android/src/main`, and `darwin/` for `$autocapture`, `elements_chain`, and `captureElementInteractions` returns zero hits; `PosthogObserver` (`lib/src/posthog_observer.dart`) only tracks screen/route events. New since the last audit: [#518](https://github.com/PostHog/posthog-flutter/pull/518) exposes iOS/Mac Catalyst rage-click autocapture through `PostHogConfig.rageClickConfig` (`posthog_config.dart:179-182`), forwarded by the darwin plugin to the native SDK — only the supplemental `$rageclick` path. Neither `README.md` nor the `PostHogConfig` docs say generic interaction autocapture is unsupported, which the spec requires when a client SDK omits it.
- **Backwards compatibility:** Backward-compatible — a net-new feature gap; new capture behaviour behind a config flag, or a README note, is additive.
- **Remediation:** Either build a Flutter widget-tap `$autocapture` pipeline (likely reusing the session-replay widget-tree walk and element parsers), or document the carve-out in the README as the spec requires.

### n3 — Before Send Hook (🟡 Partial)
- **Spec requires:** fail closed on a throwing hook: record a warning, stop the chain, drop the event. #146 adds: "The log line for a throwing hook SHALL name the dropped event and the exception type, and SHALL NOT include the exception message or any event content … A client SDK MAY print it only in debug mode, like its other logs." Layer order step 4: the SDK adds nothing after the hook, except it MAY re-impose the uuid.
- **SDK currently (`82123e6`):** callbacks are synchronous and run on the event the SDK built: on iOS, macOS and Android the native SDK builds it (`buildEvent`), Dart runs the callbacks and the native SDK sends what they return (`lib/src/posthog_flutter_io.dart:107-170`); Windows/Linux build it in the Dart core and queue what the callbacks return, keeping the prepared uuid (`lib/src/posthog_flutter_desktop.dart:753-881`); web runs them before posthog-js. A throw drops the event on every path (`lib/src/utils/before_send.dart:17-21`). Printing only under `kDebugMode` is now allowed for a client SDK, which retires the earlier finding. **Gap:** the log line is `'… beforeSend callback threw an exception; dropping event: $e'` (`before_send.dart:18-20`): it interpolates the exception, message included, and doesn't name the dropped event.
- **Backwards compatibility:** Backward-compatible — log text only.
- **Remediation:** Log the event name and `e.runtimeType` instead of `$e`.

### n4 — Bootstrap (🟡 Partial)
- **Spec requires:** Pre-seeded identity/flags applied only when nothing is persisted, with bootstrapped flags served until the first `/flags` response; optionally (MAY, `openspec/specs/bootstrap/spec.md:143-158`) a client SDK that owns a session id may accept `bootstrap.sessionID`.
- **SDK currently:** `PostHogBootstrapConfig` (`posthog_config.dart:499-560`) models `distinctId`, `isIdentifiedId`, `featureFlags`, and `featureFlagPayloads`, forwarded to the native iOS/Android SDKs (which own the precedence rules) and, on Windows/Linux, applied by the Dart core (`core/posthog_core.dart:61-67`, `:218-265`, `:693-735`). Two gaps remain: (1) no `sessionID` field exists on the bootstrap config — the same optional omission as `compliance/posthog-android.md` n4 and `compliance/posthog-ios.md` n25; (2) bootstrap is explicitly not applied on Flutter Web (`posthog_config.dart:273-275`, "configure `bootstrap` in your `posthog.init({...})` call instead"), because the web SDK hooks onto an already-initialized posthog-js instance. Setup now warns when `config.bootstrap` is set on web (`lib/posthog_flutter_web.dart:106-110`), but only via `printIfDebug`, so a release build still ignores it silently.
- **Backwards compatibility:** Backward-compatible — an optional `sessionID` field and an always-on web warning are both additive; wiring bootstrap into web is impractical because posthog-js is initialized before Dart `setup()` runs.
- **Remediation:** Add optional `sessionID` bootstrap support, forwarded to native and the Dart core; on web, log the "bootstrap not applied" warning outside debug builds.

### n5 — Capture Exception (✅ Pass)
- **Spec requires:** `captureException` emits a handled `$exception` whose type and message live on `$exception_list[0].type`/`.value`, with caller properties merged, non-standard thrown values normalized, frames and `$exception_list` outermost-first, an existing stack preserved over a synthesized one, and null-valued custom properties dropped. The flat `$exception_type`/`$exception_message` requirement was retired by PR [#103](https://github.com/PostHog/sdk-specs/pull/103).
- **SDK currently:** **The previously-recorded finding is retired.** The old note recorded that `DartExceptionProcessor.processException` never stamps top-level `$exception_type`/`$exception_message` and that both bridges route through generic `capture("$exception")`; that is still true, but PR #103 made those properties optional, so it no longer counts against the row. Everything else checks out at this commit: `Posthog().captureException(...)` (`lib/src/posthog.dart:816`) and `captureRunZonedGuardedError(...)` (`:839`) build the payload through `DartExceptionProcessor.processException` (`lib/src/error_tracking/dart_exception_processor.dart:23-131`), which sets `type`/`value` per entry, prefers the supplied stack before synthesizing one ([#626](https://github.com/PostHog/posthog-flutter/pull/626)), reverses frames to outermost-first, and lists causes outermost-first (`:107-118`); `PropertyNormalizer.normalize` (`lib/src/utils/property_normalizer.dart:9-40`) drops null-valued custom properties recursively before the channel. The envelope defects (no `exception_id`/`parent_id`, inherited `handled`, hardcoded `$exception_level`, caller override of reserved keys, chain cap of 10) are scored separately under [n9](#n9). No capture-exception-specific gap remains, so **this row is re-scored ✅ this run**, as posthog-android and posthog-react-native were on the same withdrawal.
- **Backwards compatibility:** Backward-compatible — no capture-exception-scoped change is required.
- **Remediation:** None in this capability beyond [n9](#n9).

### n6 — Consent Gating (🟡 Partial)
- **Spec requires:** while opted out, event-producing APIs return early without enqueueing, and consent gating runs before the before-send hook; wrapper-managed integrations and session replay are gated too.
- **SDK currently (`82123e6`):** Windows/Linux check opt-out before building the event or running `beforeSend` (`lib/src/posthog_flutter_desktop.dart:271`, `:344`, `:630`). On iOS, macOS and Android the native SDK builds the event first and `beforeSend` runs on what it returns (`lib/src/posthog_flutter_io.dart:139-170`), so native opt-out comes first. `optOut()` uninstalls Flutter error autocapture and leaves replay to the native SDK (`lib/src/posthog.dart:506-520`). A crash the native SDK reconstructs on a later launch follows the consent at crash time ([n23](#n23)). **Gaps:** (1) web `capture` runs `beforeSend` before posthog-js sees the event, with no opt-out check (`lib/posthog_flutter_web.dart:262-280`); (2) `captureLog()` runs the logs `beforeSend` chain with no opt-out check on any platform (`lib/src/posthog.dart:403-450`). Delivery is still blocked downstream; only the hook side effects leak.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** Check opt-out before running the web `beforeSend` chain and at the top of `captureLog()`.

### n7 — Debug (🟡 Partial)
- **Spec requires:** Per the canonical signature `debug(enabled?: boolean)`, calling with no argument defaults to enabling debug mode (`openspec/specs/debug/spec.md:18-21`; scenario "Debug defaults to enabled when called without an argument").
- **SDK currently:** `Future<void> debug(bool enabled) => _posthog.debug(enabled);` (`lib/src/posthog.dart:459`) declares `enabled` as a required, non-nullable, non-defaulted parameter — `Posthog().debug()` with no argument is a Dart compile error today, not a runtime default-to-true. The platform interface, IO (`posthog_flutter_io.dart:523`), web, and desktop (`posthog_flutter_desktop.dart:397`) implementations share the same signature.
- **Backwards compatibility:** Backward-compatible — changing the signature to `debug([bool enabled = true])` only adds a default for currently-invalid (missing-argument) call sites; existing callers that pass an explicit boolean are unaffected.
- **Remediation:** Give `enabled` a default value of `true`.

### n8 — Event Batcher (🟡 Partial)
- **Spec requires:** count- and time-based batching, a bounded queue with oldest-first eviction, and for capture v1 (#146) byte-aware batches of at most 5 MiB; a client SDK MAY halve a multi-event batch on 413.
- **SDK currently (`82123e6`):** Windows/Linux conform: batches are taken with `peek(maxBatchSize, maxBytes: captureV1MaxBatchBytes)` (`lib/src/core/posthog_core_stateless.dart:761`, 5 MiB at `lib/src/core/capture_v1.dart:10`), a full 5 MiB of queued bytes flushes like `flushAt` (`posthog_core_stateless.dart:616-622`), the queue evicts the oldest first, and a multi-event 413 halves the batch and `flushAt` (`:785-796`). posthog-ios 4.0 conforms. **Gap:** posthog-android 4.0 still runs its periodic flush on `java.util.Timer`, not the injectable clock (`PostHogQueue.kt:625-628` at `aaa23d39`; `compliance/posthog-android.md` n6). Web is posthog-js's batcher.
- **Backwards compatibility:** Backward-compatible — the fix is in posthog-android.
- **Remediation:** None in this repo; track posthog-android n6.

### n9 — Exception Event Metadata (❌ Fail)
- **Spec requires:** every `$exception_list` entry carries a `mechanism` with a unique `exception_id` (`0` outermost); nested entries carry `parent_id`, `mechanism.type: chained` and a `mechanism.source`; `handled` is not invented for nested entries; at most 50 entries; application properties MUST NOT override `$exception_list`, `$exception_level` or `$exception_source`.
- **SDK currently (`82123e6`):** unchanged in substance. `lib/src/error_tracking/dart_exception_processor.dart` still has no `exception_id` or `parent_id`; causes inherit the outermost `handled` (`:210`); `$exception_level` is the literal `'error'` and no `$exception_source` is sent (`:148`); caller properties are spread last, so they override SDK-owned keys (`:150`); and `maxExceptionChainLength = 10` (`:20`).
- **Backwards compatibility:** **Needs deprecation path** — stopping the property bag from overriding `$exception_level` needs a typed override first.
- **Remediation:** Assign `exception_id`/`parent_id` depth-first, set `mechanism.type: 'chained'` and a source on causes, stop propagating `handled`, derive the level and send `$exception_source`, raise the cap to 50, add typed overrides, then stop the bag from overriding reserved keys.

### n10 — Feature Flag Called Tracker (🟡 Partial)
- **Spec requires:** Dedupe `$feature_flag_called` per (flag, value), re-fire on value change, clear on `reset()`, and honour the minimal-envelope allowlist.
- **SDK currently:** **Resolved from ❓ Unknown.** The Dart core implements the tracker directly: `_flagCallReported` is a `Map<String, Set<PostHogFeatureFlagValue?>>` (`posthog_core.dart:25-26`), the dedup check is `!(_flagCallReported[key]?.contains(flagValue) ?? false)` (`:780`) — keyed on the value, so a changed value correctly re-fires — the set is populated after reporting (`:815`), `$feature_flag_called` is captured at `:838`, and the whole map is cleared on reset (`:82`). Failure cases are recorded for the event (`:888`). The Dart core also implements the minimal envelope on desktop: `core/feature_flag_utils.dart:25` parses the server's `minimalFlagCalledEvents` gate from the `/flags` response, `posthog_core.dart:652` persists it with the flag details and `:120-121` reads it back, and `posthog_core_stateless.dart:229-236` keeps only `minimalFeatureFlagCalledProperties` (`feature_flag_utils.dart:70`) on non-experiment `$feature_flag_called` events, so desktop passes. **Why 🟡:** the mobile path is the embedded native tracker, which `compliance/posthog-android.md` n8 records as 🟡 (posthog-ios is ✅). At `aaa23d39` posthog-android's minimal allowlist (`PostHogStateless.kt:929-951`) still has no OS/runtime identity properties, and no path reads config version 2 records (every path requests `/flags/?v=2`), so #203's `$feature_flag_variant_key` attribution doesn't arise.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** None in the Dart core; track the Android half under posthog-android n8.

### n11 — Flush (🟡 Partial)
- **Spec requires:** `both`. No-op on an empty queue; drain immediately; a failed batch stays queued.
- **SDK currently (`82123e6`):** Windows/Linux flush both capture v1 lanes through the Dart core; iOS, macOS and Android call the native `flush()`. **Gap, unchanged:** on web, `case 'flush':` in `lib/src/posthog_flutter_web_handler.dart:522-525` has the delegating call commented out, so `flush()` resolves without doing anything.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** Delegate to `window.posthog` or log that flush is unsupported on web.

### n12 — Get Anonymous ID (❌ Fail)
- **Spec requires:** `client`. A getter returning the SDK's anonymous identifier.
- **SDK currently:** Re-confirmed at this commit: the public API list in `lib/src/posthog.dart` has `getDistinctId()` (`:380`) and `getSessionId()` (`:948`) but **no `getAnonymousId()`** on any platform path. The standing `// TODO` recorded by the previous audit is still the only trace of it.
- **Backwards compatibility:** Backward-compatible — a new getter is additive.
- **Remediation:** Add `Future<String> getAnonymousId()` to the platform interface, implemented over the method channel on mobile, from `PostHogPersistedProperty.anonymousId` in the Dart core on desktop, and over `window.posthog` on web.

### n13 — Get Feature Flag (✅ Pass)
- **Spec requires:** `getFeatureFlag(key, options?: { sendFeatureFlagEvent?: boolean })`, with a per-call way to turn off `$feature_flag_called`.
- **SDK currently (`82123e6`):** `getFeatureFlag(String key, {bool? sendFeatureFlagEvent})` (`lib/src/posthog.dart:1056-1058`); `null` follows `PostHogConfig.sendFeatureFlagEvent` on iOS, macOS, Android, Windows and Linux. Web leaves an omitted option to posthog-js, which then sends the event whatever the Flutter config says (`lib/src/posthog_flutter_web_handler.dart:136-150`; `packages/browser-common/src/feature-flags.ts:1419` at posthog-js `5e31f126d`), as the spec records for Flutter (`openspec/specs/get-feature-flag-result/spec.md:81`); an explicit `false` still suppresses it. Every path passes it through: the method channel (`lib/src/posthog_flutter_io.dart:973-990`), web (`lib/posthog_flutter_web.dart:632-642`, posthog-js options at `lib/src/posthog_flutter_web_handler.dart:486-491`) and the Dart core (`lib/src/posthog_flutter_desktop.dart:592-601`).
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

### n14 — Get Feature Flag Payload (🟡 Partial)
- **Spec requires:** a cache-only payload read with no `$feature_flag_called`; malformed JSON is no payload. "A client SDK MAY omit a dedicated payload getter when its flag result getter … returns the payload and accepts a per-call `sendFeatureFlagEvent` option. posthog-ios 4.0, posthog-android 4.0 and posthog_flutter 6.0 do this." (`openspec/specs/get-feature-flag-payload/spec.md:236`)
- **SDK currently (`82123e6`):** `getFeatureFlagPayload()` is removed; the read is `getFeatureFlagResult(key, sendFeatureFlagEvent: false)?.payload` ([n15](#n15)). The malformed-payload rule holds on Windows/Linux (`lib/src/core/feature_flags.dart`, `parsePayload`), on iOS/macOS through posthog-ios 4.0 (`compliance/posthog-ios.md` n7, ✅) and on Android through posthog-android 4.0. **Gap on web:** the result comes from posthog-js, which returns a malformed payload as its raw string ([n15](#n15)).
- **Backwards compatibility:** Backward-compatible — only invalid payloads change.
- **Remediation:** Same as [n15](#n15).

### n15 — Get Feature Flag Result (🟡 Partial)
- **Spec requires:** a structured result (`key`, `enabled`, `variant`, `payload`), `null` for an unknown flag, malformed payloads as no payload, and a per-call `sendFeatureFlagEvent`; (#193) a flag whose value is `""` reads as disabled, `enabled: false` with `variant: ""`.
- **SDK currently (`82123e6`):** `getFeatureFlagResult(key, {sendFeatureFlagEvent})` (`lib/src/posthog.dart:1079-1084`) follows `PostHogConfig.sendFeatureFlagEvent` when the option is omitted, except on web, which leaves it to posthog-js ([n13](#n13)). Payloads are no payload for malformed, empty or whitespace JSON on iOS/macOS (posthog-ios 4.0, `compliance/posthog-ios.md` n8, ✅), Android and Windows/Linux. An empty variant gives `enabled: false, variant: ""` on Windows/Linux (`lib/src/core/posthog_core.dart:1135-1139`), iOS/macOS (`PostHogRemoteConfig.swift:1184-1192` at `e27cbe4cb`), Android (`PostHogRemoteConfig.kt:1344-1348` at `aaa23d39`) and web, where posthog-js's browser `getFeatureFlagResult` sets `enabled: !!flagValue` and Flutter passes the result through (`lib/src/utils/channel_serialization.dart:176-188`). **Gap on web:** that pass-through (`lib/src/posthog_flutter_web_handler.dart:143-150`) also copies `payload` unchanged, and posthog-js's `parsePayload` returns a malformed payload as its raw string, with no log (`packages/browser-common/src/feature-flags.ts:1531`, `packages/core/src/featureFlagUtils.ts:110-120` at posthog-js `5e31f126d`; `packages/browser-common/tests/feature-flags-behavior.spec.ts:665-684` expects it).
- **Backwards compatibility:** Backward-compatible — only invalid payloads change.
- **Remediation:** Fix `parsePayload` in posthog-js, or return no payload on web when posthog-js hands back a string that isn't valid JSON.

### n16 — Get Feature Flags (🟡 Partial)
- **Spec requires:** a bulk getter returning every known flag as a key → value map. The spec records "**iOS (4.0+), Android (4.0+), flutter (6.0+):** `getAllFeatureFlags()` returns a list of flag result objects (key, enabled, variant, payload), or `null` when flags are unavailable, instead of a key-to-value map" (`openspec/specs/get-feature-flags/spec.md:59`).
- **SDK currently (`82123e6`):** `getAllFeatureFlags()` (`lib/src/posthog.dart:1106-1107`) on every path (`lib/src/posthog_flutter_io.dart:1016`, `lib/posthog_flutter_web.dart:661`, `lib/src/posthog_flutter_desktop.dart:614`), never sending `$feature_flag_called`. It is the recorded surface, but not the canonical map shape, so the row is 🟡 as for posthog-ios 4.0. (#193) Each entry matches `getFeatureFlagResult` on iOS/macOS (`getAllFeatureFlagResults`, `PostHogRemoteConfig.swift:1168-1182` at `e27cbe4cb`), Android (`PostHog.kt:2776-2785` at `aaa23d39`) and Windows/Linux (`lib/src/core/posthog_core.dart:1145-1152`). **Gap on web:** Flutter returns posthog-js's `getAllFeatureFlags()` unchanged (`lib/src/posthog_flutter_web_handler.dart:497-505`), and posthog-js builds each entry with `getEnabledFromValue`, which reads `""` as enabled (`packages/browser-common/src/feature-flags.ts:871-883`, `packages/core/src/featureFlagUtils.ts:158-160` at posthog-js `5e31f126d`).
- **Backwards compatibility:** Backward-compatible — a map-returning getter would be additive, and reading `""` as disabled on web changes only flags that are off everywhere else.
- **Remediation:** Optionally add a map view. On web, set `enabled: false` for a `""` entry in Flutter, or fix it in posthog-js.

### n17 — Get Feature Flags And Payloads (🟡 Partial)
- **Spec requires:** a combined getter returning flags and their decoded payloads.
- **SDK currently (`82123e6`):** `getAllFeatureFlags()` ([n16](#n16)) returns each flag's decoded payload with its value, which the spec records as the flutter 6.0 surface; it is not the canonical combined shape, and on web an empty variant is listed as enabled ([n16](#n16)) and a malformed payload is the raw string (`packages/browser-common/src/feature-flags.ts:880` at posthog-js `5e31f126d`, [n15](#n15)).
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** Same as [n16](#n16) and [n15](#n15).

### n18 — Group (🟡 Partial)
- **Spec requires:** `group(type, key, properties)` MUST reject a blank `type` or `key`, leaving group state unchanged and logging a warning.
- **SDK currently (`82123e6`):** `Posthog().group(...)` (`lib/src/posthog.dart:892-903`) does no blank check. iOS/macOS now pin posthog-ios 4.x, which rejects blank values (`compliance/posthog-ios.md` n12, ✅), and Windows/Linux reject them in the Dart core. **Gap:** posthog-android 4.0's `group()` (`PostHog.kt:2525-2550` at `aaa23d39`) still has no blank check (`compliance/posthog-android.md` n11).
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** Add a blank `groupType`/`groupKey` guard in `Posthog().group()`.

### n19 — HTTP Client (✅ Pass)
- **Spec requires:** gzip by default with one declared `Content-Encoding` and a whole-client opt-out, which (#146) doesn't cover a delivery lane with its own compression setting; a `/flags` retry that skips a refused connection and doesn't retry before 300 ms; and, for capture v1 (#146), the capture URLs, the token only as `Authorization: Bearer`, the capture v1 headers on every attempt, and only same-origin 307/308 redirects, at most five.
- **SDK currently (`82123e6`):** Windows/Linux: `_isRetryableFlagsError` excludes a refused connection (`lib/src/core/posthog_core_stateless.dart:58-60`, `:90-96`, `ECONNREFUSED`/`WSAECONNREFUSED`/`ERROR_CONNECTION_REFUSED`); `/flags` retries start at 300 ms and double up to 30 s (`:129-130`, `retriable` in `lib/src/core/utils/utils.dart:13-40`). Capture requests send `Authorization: Bearer`, `PostHog-Sdk-Info`, `PostHog-Attempt`, `PostHog-Request-Id` and `PostHog-Request-Timestamp` (`posthog_core_stateless.dart:887-893`), and `_fetchCaptureV1` follows only same-origin 307/308, at most 5 (`:948-976`, `:137`), with `followRedirects = false` on the request. `PostHogConfig.compression` (gzip by default, `none` to opt out, `lib/src/posthog_config.dart:217`) covers `/flags` and the analytics lane (`posthog_core_stateless.dart:172`, `:194`, `:986`), and `captureAiCompression` sets the AI lane alone (`:211`), as #146 now allows. iOS, macOS and Android use the native 4.0 transports (HTTP Client ✅ in both audits). Web uses posthog-js's transport and is not on capture v1.
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

### n20 — Is Feature Enabled (✅ Pass)
- **Spec requires:** a boolean getter accepting a caller-supplied default; the spec lists "**flutter:** `isFeatureEnabled(key, {sendFeatureFlagEvent, defaultValue}): Future<bool>`".
- **SDK currently (`82123e6`):** `isFeatureEnabled(String key, {bool? sendFeatureFlagEvent, bool? defaultValue})` (`lib/src/posthog.dart:683-687`), passed through on web (`lib/posthog_flutter_web.dart:552-565`) and the Dart core (`lib/src/posthog_flutter_desktop.dart:525-533`); an empty-string variant reads as disabled (`lib/src/core/posthog_core.dart:1175-1180`).
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

### n21 — Logs (🟡 Partial)
- **Spec requires:** Capture-time gates evaluated in order — (1) SDK not enabled/initialized, (2) user opted out, (3) blank body, (4) `beforeSend` returned null / blanked the body / threw, (5) rate cap — returning before `beforeSend` when an earlier gate fails (`openspec/specs/logs/spec.md:45-65`); a throwing `beforeSend` drops the record with a diagnostic naming `beforeSend` (`:377-381`).
- **SDK currently:** `Posthog().captureLog(...)` (`lib/src/posthog.dart:301-348`) and the `logger` facade (`lib/src/logs/posthog_logger.dart:35-56`, all six severities) default to `info` and drop blank bodies both before (`:309`) and after (`:336`) `beforeSend`. The previously-recorded deviation — the logs `beforeSend` catch branch drops the record on a throw (`:329-331`) instead of continuing with the last-good value — is **now compliant**: the logs and before-send-hook specs are fail-closed. **Remaining gap — gate order:** the Dart layer runs the caller's `beforeSend` chain (`:321-334`) without any opt-out check; opt-out is only applied after the record reaches native `PostHog.captureLog` (Android `PosthogFlutterPlugin.kt:1796-1814`), so hooks run for opted-out users, against gate (2) and the "gates short-circuit in order" scenario (see also [n6](#n6)). Encoding, transport, and rate capping live in the embedded SDKs, not this repo: posthog-android (Logs ✅), posthog-ios (Logs 🟡, n1), and posthog-js on web. Windows/Linux `captureLog` is a documented no-op (`posthog_flutter_desktop.dart:333-341`).
- **Backwards compatibility:** Backward-compatible — an early return for opted-out users skips only hooks whose record would have been dropped anyway.
- **Remediation:** Check `await _posthog.isOptOut()` at the top of `captureLog()`, before the blank-body check and the `beforeSend` loop.

### n22 — On Feature Flags (✅ Pass; was 🟡)
- **Spec requires:** a listener registration that also serves late registrations, stays active across `close()`/`setup()` until unsubscribed, and "Loads discarded by reset or close reach no listener"; (#193) a payload-carrying listener leaves a flag whose value is `""` out of the keys and variants it receives.
- **SDK currently (`82123e6`):** `PostHogConfig.onFeatureFlags` is replaced by `Posthog().onFeatureFlags(callback)` returning a `PostHogFeatureFlagsSubscription` (`lib/src/posthog.dart:745-751`). A late listener gets the last load in a microtask (`lib/src/feature_flags_listeners.dart:26-39`), and `reset()`/`close()` forget the last load and bump a generation (`:62-67`). The native plugins tag each load with the generation they last received (`darwin/.../PosthogFlutterPlugin.swift:146-150`), and Dart drops a load sent before the native SDK got the reset (`lib/src/posthog_flutter_io.dart:260-271`). A load already in flight inside the native SDK when `reset()` runs no longer reaches Flutter: posthog-ios 4.0 drops it before it writes the cache or notifies listeners (`PostHogRemoteConfig.swift:493-497`, `:820-829` at `e27cbe4cb`, PostHog/posthog-ios#1048), and posthog-android 4.0 binds each load's listener notification to the generation at its start (`PostHog.kt:253-260` at `aaa23d39`). Web drops loads from an earlier `setup()` or `close()` in Dart (`lib/posthog_flutter_web.dart:195-217`), and posthog-js bumps a request generation on `reset()`. `PostHogFeatureFlagsLoaded` keeps only `true` and non-empty variants on every path (`lib/src/feature_flags_loaded.dart:39-48`), so listeners never receive an empty variant.
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

### n23 — Opt In (🟡 Partial)
- **Spec requires:** persisted opt-in/opt-out that gates capture; "Opt out can clear local persistence when configured"; on mobile (#138) opt-in restarts the replay the app wanted at opt-out, in a new session; and (#199) a crash the SDK reconstructs on a later launch follows the consent at crash time: never sent when recorded while opted out, kept and sent after opt-in when recorded while opted in.
- **SDK currently (`82123e6`):** `optOut()`/`optIn()` (`lib/src/posthog.dart:506-541`; `enable()`/`disable()` are removed). Replay restart meets #138 on iOS, macOS and Android: `optOut()` leaves stopping replay to the native SDK, so native records whether the app wanted replay (`:515-519`), and native opt-in rotates the session before restarting (posthog-ios 4.0 `optIn()`, posthog-android 4.0 `PostHog.kt:1956-1995` at `aaa23d39`). Dart restarts its screenshot pipeline only when it was running at opt-out, and starts a fresh replay session for it (`:532-540`). Deferred crash reports come from the native SDKs, which Flutter enables through `captureNativeExceptions` and, on Android, `captureNativeCrashes` (`lib/src/posthog_config.dart:1097`, `:1121`). Both meet #199: posthog-ios marks the crash context at opt-out and drops a marked report (`PostHogErrorTrackingAutoCaptureIntegration.swift:119-125`, `:267-270` at `e27cbe4cb`), and leaves an earlier report on disk while opted out because its integrations aren't installed until opt-in; posthog-android records opt-out intervals and drops a native crash whose time falls in one (`PostHogNativeCrashIntegration.kt:171-174`, `:372-400` at `aaa23d39`, PostHog/posthog-android#952). **Gap:** `optOut()` still takes no clear-local-data option on any path, as in posthog-ios and posthog-android.
- **Backwards compatibility:** Backward-compatible with an optional parameter.
- **Remediation:** Add an optional clear-local-data option to `optOut()`.

### n24 — Persistent Storage (🟡 Partial)
- **Spec requires:** Durable key/value persistence that never throws into the host app, with failures surfaced through SDK diagnostics.
- **SDK currently:** **Resolved from ❓ Unknown.** `core/file_storage.dart` (444 lines) is a real, carefully-specified implementation for desktop and its header comment reads like a spec of its own: persisted properties in a single `posthog_data.json` snapshot; each queued event its own UUIDv7-named file in `posthog_queue/` so queueing one event does not rewrite the others; an OS file lock (`posthog.lock`) so a second app instance reads the snapshot but cannot overwrite the first's identity and consent; **"Storage never throws into the host app"** with an explicit `isDegraded` memory-only mode on read failure that refuses to overwrite good persisted data; and atomic replace via temp-file-plus-rename (`_writeAtomically`, `:436`) so a crash never leaves a half-written file. The documented limitations are honest (no `fsync`, so the newest writes can be lost on a crash; the lock may not hold on network filesystems). **Why 🟡:** desktop only — mobile persistence is the native SDKs', recorded 🟡 under `compliance/posthog-android.md` n15 and `compliance/posthog-ios.md` n23, and web is `posthog-js`'s.
- **Backwards compatibility:** Backward-compatible — nothing in this repo needs to change.
- **Remediation:** No action in posthog-flutter for the desktop path. Track the mobile half under posthog-android n15 and posthog-ios n23.

### n25 — Register (🟡 Partial)
- **Spec requires:** Register a super property merged into later events, with a per-event value winning; implementations MAY reject invalid input such as empty keys (`openspec/specs/register/spec.md:42`), so blank keys should not silently persist as stray super properties.
- **SDK currently:** `Posthog().register(String key, Object value)` (`lib/src/posthog.dart:467-468`) and `PosthogFlutterIO.register` (`posthog_flutter_io.dart:714-727`) forward the key with no blank check, and so does every other path: Android `PosthogFlutterPlugin.kt:1989` (presence-only `!!`, inheriting `compliance/posthog-android.md` n16 🟡), web `posthog_flutter_web_handler.dart:384-389`, and desktop `posthog_flutter_desktop.dart:401-402` → `core/posthog_core_stateless.dart:388-393`. An empty-string key silently persists as a super property. Per-event properties correctly win over registered ones on desktop (`core/posthog_core.dart:152-154`).
- **6.0 (`82123e6`):** `registerOptions()`/`unregisterOptions()` (`lib/src/posthog.dart:594-605`) register capture options next to super properties. #146 (`openspec/specs/capture/spec.md:860`, `:1100` at `23c2478`) names them for posthog_flutter 6.0 on every platform except web and has registered layers reach identify, alias, group identify and `$set`, which Flutter does; capture options are scored under Capture ([n41](#n41)), so they don't change this row, and the blank-key finding above still holds on every path.
- **Backwards compatibility:** Backward-compatible — a blank-key guard only affects invalid input; the spec's validation language is permissive, so this is a minor gap.
- **Remediation:** Add blank-key rejection to `Posthog().register()`.

### n26 — Remote Config (🟡 Partial)
- **Spec requires:** Fetch and apply the project's remote configuration, gating replay and surveys from it.
- **SDK currently:** **Resolved from ❓ Unknown.** On mobile the native SDK handles it and `compliance/posthog-android.md` records Remote Config ✅, so that path is satisfied. **On desktop it is absent:** grep for `remote_config`, `remoteConfig`, and `/array/` across `posthog_flutter/lib/src/` returns **zero** hits, so the Dart core never fetches remote config and desktop clients run on local configuration only — no server-side replay or survey gating. (The `minimalFlagCalledEvents` gate is unaffected: it arrives on the `/flags` response, which the Dart core does read — see [n10](#n10).)
- **Backwards compatibility:** Backward-compatible — adding a config fetch at startup is additive; clients that currently see no remote gating would start honouring it, which is the intended behaviour.
- **Remediation:** Add a remote-config fetch to the Dart core's startup path and apply it to the same switches the native SDKs gate on.

### n27 — Screen (✅ Pass)
- **Spec requires:** Emit `$screen` with `$screen_name`, with the explicit name argument winning over a caller-supplied `$screen_name` in `properties`.
- **SDK currently:** **The previously-recorded Dart-layer bug is fixed.** The old finding was that `PosthogFlutterIO.screen` built `{screenName: …, ...?properties}`, so a caller's `$screen_name` overwrote the argument. [#614](https://github.com/PostHog/posthog-flutter/pull/614) reversed the order: `posthog_flutter_io.dart:359-364` now spreads `...?properties` first and sets `$screen_name: screenName` last, before `beforeSend` runs. Web (`posthog_flutter_web_handler.dart:258-265`) and desktop (`posthog_flutter_desktop.dart:285-325`) also let the argument win, and the embedded native SDKs' own Screen rows are ✅ (`compliance/posthog-android.md`, `compliance/posthog-ios.md`). No remaining Screen-specific gap was found at this commit; the opt-out ordering of the Dart `beforeSend` on mobile/web is a Consent Gating concern ([n6](#n6)). **This row is re-scored ✅ this run.**
- **Backwards compatibility:** Backward-compatible — the #614 fix changed observable behavior only for callers who relied on `properties['$screen_name']` overriding the argument.
- **Remediation:** None outstanding for this contract.

### n28 — Session Replay Debug Properties (🟡 Partial)
- **Spec requires:** `$recording_status` and the three `$sdk_debug_replay_*` trigger/buffer keys on every event except `$snapshot`, a throttled optional bundle on SDK events, and (#197) `$sdk_debug_replay_capture_mode` always `screenshot` on mobile. An SDK with no replay integration sends only `$recording_status: disabled`.
- **SDK currently (`82123e6`):** the Dart layer adds no `$sdk_debug_replay_*` keys. On iOS, macOS and Android events are now built by the native SDK (`buildEvent` / `capture`), so they carry posthog-ios's and posthog-android's bundles, including `screenshot` for the Flutter host; posthog-ios 4.0 is 🟡 here (`compliance/posthog-ios.md` n26): at `e27cbe4cb` `$sdk_debug_session_start` still comes from the session manager even when the event carries a caller-supplied `$session_id`, and a backdated event still gets live state (`PostHogSDK.swift:764-765`). Windows/Linux have no replay and send `$recording_status: disabled` (`lib/src/posthog_desktop_client.dart:42-46`). **Gap on Windows/Linux:** the Dart core also adds `$sdk_debug_session_start`, `$sdk_debug_current_session_duration` and `$sdk_debug_pending_queue_size` to every event, custom events included (`_sessionDebugProperties`, `lib/src/core/posthog_core.dart:195`, `:253-261`; `test/core/posthog_core_test.dart:89-110` expects them on a custom event). No SDK may attach the duration (`openspec/specs/session-replay-debug-properties/spec.md:564-565`), and custom events carry none of the optional bundle (`:132-139`, `:164-170`); the queue-depth key is allowed. Web inherits posthog-js (🟡, `compliance/posthog-js.md` n36). Not verified: whether the native trigger statuses reflect Flutter's Dart capture pipeline.
- **Backwards compatibility:** Backward-compatible — removes debug properties only.
- **Remediation:** In the Dart core, stop sending `$sdk_debug_current_session_duration`, and send `$sdk_debug_session_start` only on `$`-prefixed events, at most every 30 seconds. Track posthog-ios n26 and posthog-js n36.

### n29 — Session Replay Privacy (🟡 Partial)
- **Spec requires:** Mask text, images, and sensitive inputs by default; honour explicit mask and unmask markers; elements marked no-capture MUST be excluded with all their descendants; password/sensitive input masking takes precedence over disabled broad masking; mask-discovery failures MUST fail closed (skip the snapshot).
- **SDK currently:** Flutter owns a screenshot-only masking pipeline in Dart (`lib/src/replay/`). Three of the four previously-recorded findings are fixed at this commit: (1) a general unmask primitive now exists — `PostHogUnmaskWidget` (`lib/src/replay/mask/posthog_unmask_widget.dart:34-60`, [#574](https://github.com/PostHog/posthog-flutter/pull/574)) — and its regions are subtracted from global and explicit masks (`lib/src/replay/element_parsers/element_data.dart:38-62`, `lib/src/replay/mask/unmask_rects.dart`); (2) the two parsing paths no longer disagree on password fields: both use one shared `isSensitiveTextInput()` (`lib/src/replay/mask/sensitive_text_input.dart:73-105` — `obscureText`, sensitive keyboard types, and autofill hints on `EditableText`/`TextField`/`CupertinoTextField`), which runs before and regardless of `maskAllTexts` (`lib/src/replay/element_parsers/element_object_parser.dart:34-43`), marks the whole subtree sensitive (`lib/src/replay/mask/widget_elements_decipher.dart:43-55`), and so masks an obscured `TextFormField` through its inner `TextField` even with `maskAllTexts=false` (#574); (3) a failed widget-mask or platform-view walk now drops the frame instead of sending it unmasked (`lib/src/replay/screenshot/screenshot_capturer.dart:706-716`, `:778-791`; `lib/src/replay/mask/posthog_mask_controller.dart:81-106`; [#530](https://github.com/PostHog/posthog-flutter/pull/530)). **Remaining gap: there is still no no-capture marker** — no `no.?capture`/`PostHogNoCapture` hits anywhere in `lib/`. The only exclusion primitive is `PostHogMaskWidget` (`lib/src/replay/mask/posthog_mask_widget.dart:33-65`), and a `PostHogUnmaskWidget` nested at any depth inside it reveals that region (`posthog_unmask_widget.dart:14-20`, `element_data.dart:57-62`), so no marker guarantees that an element and its descendants are excluded. Secondary: on Flutter Web, default `maskAllTexts`/`maskAllImages` do not mask canvas frames until a mask/unmask widget mounts or `posthog.init` declares `canvasCapture.maskRegionsFn` (`lib/src/posthog_config.dart:778-782`, `lib/src/replay/mask/canvas_mask_registration_web.dart:15-31`); this is documented, and canvas recording itself is opt-in.
- **Backwards compatibility:** Backward-compatible for a no-capture widget that unmask cannot override (net-new API). Turning canvas masking on by default on Flutter Web when `maskAllTexts`/`maskAllImages` are set changes what web replays show, so it should ship with a changelog note.
- **Remediation:** Add a `PostHogNoCaptureWidget`-style marker that always masks its full subtree and ignores nested `PostHogUnmaskWidget`; consider enabling web canvas masking by default when global masking is on.

### n30 — Set Person Properties (✅ Pass)
- **Spec requires:** Set person properties without identify, emitting the `$set`/`$set_once` shape; calling with both maps null/empty is a no-op (no event/call emitted) and does not throw.
- **SDK currently:** `Posthog().setPersonProperties(...)` (`lib/src/posthog.dart:187-194`) and `PosthogFlutterIO.setPersonProperties` (`posthog_flutter_io.dart:263-289`) still have no Dart-side empty-input guard — with both maps null the Dart layer still calls `invokeMethod('setPersonProperties', {})` rather than short-circuiting, unlike the sibling `setPersonPropertiesForFlags` (`lib/src/posthog.dart:522`). The previous audit could not verify the native side; it now can, and every downstream path no-ops on empty input: posthog-android's `setPersonProperties` returns when both are null/empty (Set Person Properties ✅ in `compliance/posthog-android.md`), posthog-ios is ✅, posthog-js returns early on web, and the desktop core returns early (`core/posthog_core.dart:963-967`). So nothing observable happens; the missing Dart guard is hygiene, not a contract gap. **This row is re-scored ✅ this run.**
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** Optional: add the same empty-input early return used by `setPersonPropertiesForFlags` to skip the useless channel call.

### n31 — Setup (🟡 Partial)
- **Spec requires:** the project credential named `projectToken`; lifecycle hygiene on re-initialization.
- **SDK currently (`82123e6`):** `PostHogConfig.apiKey` and the `API_KEY` manifest/Info.plist key are removed; `setup()` skips a blank or `phx_` token with one log line (`lib/src/utils/project_token.dart:5-17`, `lib/src/posthog.dart:76-79`) and reinstalls Flutter integrations without stacking them. **Gap, unchanged:** no double-init guard or warning: a second `setup()` re-runs the whole path and native setup.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** Warn or no-op on a second `setup()` without an intervening `close()`.

### n32 — Shutdown (🟡 Partial)
- **Spec requires:** flush pending events before tearing down.
- **SDK currently (`82123e6`):** `Posthog().close()` (`lib/src/posthog.dart:1282-1298`) does no flush of its own and delegates. Android and iOS flush in their native `close()`; Windows/Linux make one bounded send attempt of up to two seconds (`lib/src/posthog_flutter_desktop.dart:676`). **Gap, unchanged:** web `close` is a no-op with the delegating call commented out (`lib/src/posthog_flutter_web_handler.dart:526-529`).
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** Implement web `close` and add a bounded Dart-side flush before delegating.

### n33 — Start Session Recording (🟡 Partial)
- **Spec requires:** Recording stays inactive while opted out, and the SDK's own local state reflects actual replay state.
- **SDK currently:** `startSessionRecording({bool resumeCurrent = true})` (`lib/src/posthog.dart:964-977`) delegates to native/web, then sets `PostHogInternalEvents.sessionRecordingActive.value = true` unconditionally (`:976`), with no success signal and no `isOptOut()` check. That flag starts the Dart `ChangeDetector`/`ScreenshotCapturer` pipeline, so if native declines to start — posthog-ios ignores `startSessionRecording` while opted out (the comment at `lib/src/posthog.dart:432-433` says so) — Flutter's mirrored state still flips to "active" and Dart-side capture runs anyway. On Android the embedded SDK has no opt-out guard of its own on start (`compliance/posthog-android.md` n20, ❌). [#606](https://github.com/PostHog/posthog-flutter/pull/606) fixed the opt-out side only: `optOut()` now clears the flag and stops native replay (`:399-418`), and `optIn()` restarts it after native re-enables (`:423-438`); an explicit `startSessionRecording()` while opted out still flips the flag.
- **Backwards compatibility:** Backward-compatible — gating the local state flip on a success signal from native (or adding a Dart-side `isOptOut()` check before flipping it) is additive.
- **Remediation:** Only set `sessionRecordingActive.value = true` after confirming native actually started recording (for example by reading `isSessionReplayActive()` after the call), or add a local `isOptOut()` guard.

### n34 — Stop Session Recording (🟡 Partial)
- **Spec requires:** Stopping session recording finalizes/flushes pending replay data rather than discarding it.
- **SDK currently:** `stopSessionRecording()` (`lib/src/posthog.dart:981-984`) delegates correctly and is idempotent, but clearing `sessionRecordingActive` makes `PostHogWidget` call `ScreenshotCapturer.cancel()`, which **discards** any in-flight frame — the `_cancelled`/generation checks inside the capture complete it with `null` (`lib/src/replay/screenshot/screenshot_capturer.dart`) rather than finishing and shipping it — contradicting "finalize pending replay data" for Flutter's own capture pipeline. Native-side finalization depends on the embedded SDK: posthog-ios flushes on stop (`compliance/posthog-ios.md` n18, ✅ via posthog-ios#933); posthog-android does not (`compliance/posthog-android.md` n21, 🟡).
- **Backwards compatibility:** Backward-compatible — letting a final in-flight frame finish before cancelling only affects the tail latency of `stopSessionRecording()`, not its signature.
- **Remediation:** Let an in-flight capture finish and ship before tearing down the capturer, rather than discarding it on cancel.

### n35 — Surveys (🟡 Partial)
- **Spec requires:** native SDKs exclude surveys whose only display conditions are web-only (`url`/`selector`); the popup delay (#121), where a survey dropped before display is not marked seen and sends no event; and (#102) "Submit and dismiss SHALL NOT move the date" — the device-wide last-seen survey date is written on show.
- **SDK currently (`82123e6`):** Flutter renders surveys for the native survey engines (`PostHogFlutterSurveysDelegate.kt`, `PostHogDisplaySurvey+Dict.swift`) and reports shown, response and closed back to them. Its own popup delay (`lib/src/surveys/survey_service.dart:14-125`) drops a survey still waiting without calling `onClosed` (`:219-231`), so the native "closed before shown" path is never hit from Flutter. Seen keys and the last-seen date are written by the native SDKs. posthog-ios 4.0 now writes the date on show (`handleSurveyShown`, `PostHogSurveyIntegration.swift:529-537` at `e27cbe4cb`) and no longer on submit or dismiss (`setSurveySeen`, `:395-401`; PostHog/posthog-ios#1049). posthog-android 4.0 excludes web-only surveys (`PostHogSurveysIntegration.kt:215-222`, `:267-269` at `aaa23d39`). **Gap:** posthog-android 4.0 writes the date on show and again in `setSurveySeen` (`PostHogSurveysIntegration.kt:1188-1203`), which runs on close (`:457`) and on submit (`:994`), so on Android the wait period runs from the close. Windows/Linux have no surveys.
- **Backwards compatibility:** Backward-compatible — the wait period only gets shorter by the time a survey stays on screen.
- **Remediation:** None in this repo; track the posthog-android fix and raise the floor once it ships.

### n36 — Traces (❌ Fail)
- **Spec requires:** An OTLP span pipeline to `/i/v1/traces` with W3C `traceparent`/`tracestate` interop.
- **SDK currently:** Re-confirmed at this commit — no implementation. Grep for `startSpan`, `traceparent`, and `i/v1/traces` across `posthog_flutter/lib/` returns only unrelated matches in the stack-trace parser. The Dart core now has its own HTTP transport and batching, so the substrate a traces pipeline would sit on does exist, but nothing is built on it.
- **Backwards compatibility:** Backward-compatible — net-new, pre-GA capability.
- **Remediation:** Build the span pipeline over the Dart core's existing `_fetchWithRetry` transport, following `packages/core/src/traces/` in the posthog-js monorepo as the reference implementation.

### n37 — Tracing Headers (❌ Fail)
- **Spec requires:** Inject `traceparent`/`tracestate` into outbound application HTTP requests.
- **SDK currently:** Re-confirmed at this commit — zero hits for `traceparent` or `tracestate` anywhere in `posthog_flutter/lib/`. The previous audit's reasoning still holds: Flutter has no Dart-side HTTP client of its own through which app traffic flows, so there is nothing to intercept without the app opting in.
- **Backwards compatibility:** Backward-compatible — any solution is opt-in.
- **Remediation:** Ship an opt-in `package:http` interceptor (and a Dio interceptor) that stamps the headers, rather than attempting transparent interception.

### n38 — Retry Queue (🟡 Partial)
- **Spec requires:** (#146, durable client queue) retry exactly 404/408/429/500/502/503/504, network errors and `retry` results; 1–30 s backoff with jitter; `Retry-After` as a floor capped at 30 s; no attempt limit allowed; retries resend only the failed request's events.
- **SDK currently (`82123e6`):** Windows/Linux conform: `isRetriableCaptureV1Status` (`lib/src/core/capture_v1.dart:31-38`), `captureRetryDelay` (1 s doubling to 30 s, ±25% jitter, `Retry-After` floor capped at 30 s, `lib/src/core/posthog_core_stateless.dart:73-88`), a transient failure keeps the batch and backs off (`:807-815`), only `retry` uuids stay queued and resend under the same request identity (`:817-849`, `:862-876`), and a 404 keeps events queued with one always-on warning (`:799-806`). iOS and Android retry a capture v1 404 too and conform (Retry Queue ✅ in both 4.0 audits). **Gap:** web uses posthog-js's `RetryQueue`, which drops a 429 (`compliance/posthog-js.md` n28).
- **Backwards compatibility:** Inherits posthog-js n28's verdict (Needs deprecation path).
- **Remediation:** None in this repo; clears with posthog-js n28.

### n39 — Capture AI (🟡 Partial; was ➖)
- **Spec requires:** #146 (with #147) extends Applicability to "posthog-flutter 6.0 (`captureAi`: native on iOS, macOS and Android, its own Dart lane on Windows and Linux)". AI events ride their own lane to `/i/v1/ai/events` with lane-scoped compression, queue capacity and timeout; the whole event is capped at 8 MiB + 64 KiB (a larger configured cap is clamped or refused); batches are byte-aware at 5 MiB; client SDKs start their durable queue at launch; null-valued properties are dropped as in capture.
- **SDK currently (`82123e6`):** `captureAi()` (`lib/src/posthog.dart:313-348`) returns the event's uuid. On iOS, macOS and Android it goes through the native `captureAi` (posthog-ios 4.0 and posthog-android 4.0 AI lanes); Flutter drops null-valued properties before the channel (`PropertyNormalizer`, `lib/src/posthog_flutter_io.dart:595-620`), and posthog-ios 4.0 now omits them as well (PostHog/posthog-ios#1047). Windows/Linux have a separate lane (`lib/src/core/posthog_core_stateless.dart:197-218`): `captureAiMaxQueueSize` (default 100), `captureAiTimeout` (default 60 s), `captureAiCompression` (default gzip, separate from the whole-client `compression`, which #146 allows), `captureAiMaxEventBytes` clamped to 8 MiB + 64 KiB with a warning, and a 50 MiB disk cap (`lib/src/core/capture_v1.dart:12-27`). An oversized event is dropped with a name-and-size log (`posthog_core_stateless.dart:593-600`). Queues left from an earlier run are flushed at setup (`:220-232`). Web is outside Applicability; `captureAi` there logs and returns `null` (`lib/posthog_flutter_web.dart:324-336`). **Gap on Windows/Linux:** `captureAi` builds the event through the same `prepareEvent` as `capture` (`lib/src/posthog_flutter_desktop.dart:315`), so an empty or non-string caller `$session_id` is replaced, as in [n41](#n41); capture AI inherits capture's enrichment and wire rules.
- **Backwards compatibility:** Same as [n41](#n41).
- **Remediation:** Same as [n41](#n41).

### n40 — Identify (🟡 Partial; was ✅)
- **Spec requires:** (#167) "Opt-out is **not** a guard: an opted-out SDK still runs the rest of this flow. It updates local identity state (distinct id, anonymous id, `isIdentified`), updates person properties for flags, and reloads feature flags when the distinct id changes" (`openspec/specs/identify/spec.md:107`; scenarios "Identify while opted out …" at `:211-235`).
- **SDK currently (`82123e6`):** iOS, macOS and Android delegate to the native SDKs. **Gap on Windows/Linux:** the Dart core's `identify()` returns early while opted out (`if (_ignoredWhileOptedOut('posthog.identify')) return;`, `lib/src/core/posthog_core.dart:391`), so the distinct id doesn't change and flags aren't reloaded until opt-in.
- **Backwards compatibility:** Backward-compatible — the opted-out user's identity starts tracking what the app set.
- **Remediation:** Run identify's identity, flag-property and reload steps while opted out and skip only the event.

### n41 — Capture (🟡 Partial; was ✅)
- **Spec requires:** main's capture requirements plus #146's capture v1 contract for every SDK on capture v1: the wire shape and headers, per-event results, legacy option hoisting, `$lib`/`$lib_version` kept in properties and filled by the SDK as a pair after every other layer and before `beforeSend` (set both when `$lib` is unset, only the version when `$lib` is the SDK's own name, never the SDK's version on another library's `$lib`), session/window id lifting, blank distinct-id fallback, empty event names dropped, timestamps, and failing open on a blank or `phx_` token; (#193) a flag whose value is `""` stays out of `$active_feature_flags` while `$feature/<key>` keeps `""`; and (`15501ca`) registered layers reach `$identify`, `$create_alias`, `$groupidentify` and `$set`, a `process_person_profile: true` call option beats every layer, and "SDK docs and migration guides SHALL show that call option on an identity call as the way to keep identifying under a layered `false`" (`openspec/specs/capture/spec.md:1100` at `23c2478`).
- **SDK currently (`82123e6`):** iOS, macOS and Android send through posthog-ios 4.0 and posthog-android 4.0 capture v1; Flutter strips null-valued properties before the channel, and posthog-ios now omits them too. The plugins configure the native SDKs with `posthog-flutter` and its version (`darwin/.../PosthogFlutterPlugin.swift:546-547`, `android/.../PosthogFlutterPlugin.kt:908-909`), so the native fill treats `posthog-flutter` as the SDK's own name: posthog-ios fills the pair after the caller's properties (`fillLibraryIdentity`, `PostHogSDK.swift:701-710`, called at `:919-922` at `e27cbe4cb`) and posthog-android as the last step of `buildProperties` (`PostHog.kt:1013`, `internal/PostHogLibraryIdentity.kt:13-29` at `aaa23d39`), in the build `buildEventForWrapper` uses, so the Dart `beforeSend` sees the filled pair. Windows/Linux: `getCommonEventProperties` no longer sets `$lib` (`lib/src/core/posthog_core_stateless.dart:258`), and `_enrichProperties` fills the pair after the context, SDK, registered and caller layers (`_fillLibraryIdentity`, `lib/src/core/posthog_core.dart:206`, `:210-224`), before the desktop wrapper runs `beforeSend` (`lib/src/posthog_flutter_desktop.dart:765-814`). `captureV1Event` hoists the legacy option properties, keeps `$lib`/`$lib_version`, and lifts string `$session_id`/`$window_id` (other types dropped with a log naming the JSON type) (`lib/src/core/capture_v1.dart:59-115`); per-event results resend only `retry`, count `drop` by a sanitized `details` tag, and treat a 2xx without readable results as terminal (`:163-200`, `lib/src/core/posthog_core_stateless.dart:922-942`); `created_at` and the request id are kept across retries of the same uuids (`:862-876`). The desktop wrapper drops an empty event name and falls back to the prepared distinct id when a callback blanks it (`lib/src/posthog_flutter_desktop.dart:837-887`). `setup()` skips a blank or `phx_` token (`lib/src/utils/project_token.dart:5-17`). An empty variant stays out of `$active_feature_flags` on Windows/Linux (`lib/src/core/posthog_core.dart:139-145`), iOS/macOS (`PostHogSDK.swift:609-623` at `e27cbe4cb`) and Android (`PostHog.kt:916-928` at `aaa23d39`). Web uses posthog-js and is not on capture v1. **Gap on Windows/Linux:** `_enrichProperties` merges the caller's properties and then replaces an empty or non-string `$session_id` with the managed session id (`lib/src/core/posthog_core.dart:183-206`; `test/core/desktop_parity_regressions_test.dart:74-81` expects it for `''` and `42`), so `captureV1Event` never sees the caller's value. #146 lifts `''` as the top-level `session_id` and drops `42` with a warning (**Session and window ids are lifted only as strings**, `openspec/specs/capture/spec.md:1073-1075` at `23c2478`), and **Caller-supplied event properties take precedence** has no session-id exception. posthog-ios and posthog-android keep the caller's value (`PostHogSDK.swift:903-922` at `e27cbe4cb`, `PostHog.kt:984-1013` at `aaa23d39`). **Gap in the migration guide (every platform except web):** the SDK lets a registered `process_person_profile: false` reach identity calls and a call option override it, but `MIGRATION.md:409` says only that a registered option reaching `$identify`, `$create_alias` and `$groupidentify` gets them dropped, and shows no `process_person_profile: true` call option to keep them. This clears when [PostHog/posthog-flutter#718](https://github.com/PostHog/posthog-flutter/pull/718) lands.
- **Backwards compatibility:** Backward-compatible — only an empty or non-string caller `$session_id` changes; the guide fix is documentation.
- **Remediation:** Drop the replacement in `_enrichProperties` and let `captureV1Event` lift or drop the value, or settle a client fallback in #146. Merge posthog-flutter#718.
