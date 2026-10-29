# posthog-flutter — SDK Compliance

**Repo:** [PostHog/posthog-flutter](https://github.com/PostHog/posthog-flutter)
**Audited commit:** `1032c102934c4b0338282a0fd3dcff94f7c2db00` ([commit](https://github.com/PostHog/posthog-flutter/commit/1032c102934c4b0338282a0fd3dcff94f7c2db00)) — audited on 2026-10-19
**Audited against sdk-specs commit:** `c72e367`
**Summary:** 21 ✅ · 29 🟡 · 6 ❌ · 8 ➖ · 0 ❓ (64 rows; previous audit 2026-08-06 at `05b53dc` scored 20/22/6/5/6 on 59 rows)

**Why this run:** rotation priority 2 — equally stale with react-native (2026-08-06) and the holder of
**six of the seven ❓ Unknown cells the matrix carried** (posthog-react-native held the seventh).
Draining those was the stated reason to spend a slot here. **All six are now resolved to a definite
status** ([n8](#n8), [n10](#n10), [n19](#n19), [n24](#n24), [n26](#n26), and Retry Queue, [n38](#n38)), so
this file has **zero Unknown cells**. The matrix is not Unknown-free: this run also moved
posthog-node's Traces row to ❓ as a correction (see [posthog-node.md#n2](posthog-node.md#n2)).

## The architecture changed — this is no longer only a wrapper

The previous audit's six Unknowns all had the same cause: "most capture/identity/queueing/storage/
HTTP mechanics are implemented **inside** the embedded native SDKs, not in this repo." That premise
no longer holds in full. Since 2026-08-06 posthog-flutter has grown **its own pure-Dart core** —
`posthog_flutter/lib/src/core/` (`posthog_core.dart` 1,019 lines, `posthog_core_stateless.dart` 720,
`file_storage.dart` 444, `feature_flags.dart` 302, plus `session_manager.dart`, `persistence.dart`,
`event_emitter.dart`, `uuid.dart`, `utils/utils.dart`) driving a new `PosthogFlutterDesktop`
platform implementation (`posthog_flutter_desktop.dart`, 707 lines). The Dart `lib/` tree is now
**18,773 lines**.

Three execution paths now exist, and every row below is scored across all three:

| Platform | Implementation | Where the behaviour lives |
|---|---|---|
| iOS / Android / macOS | `PosthogFlutterIO` — `MethodChannel('posthog_flutter')` pass-through (the platform-interface default) | embedded native `posthog-ios` / `posthog-android` |
| **Windows / Linux (new)** | `PosthogFlutterDesktop` → the Dart core | **this repo, directly auditable** |
| Web | `PosthogFlutterWeb` → `window.posthog` via `dart:js_interop` | `posthog-js` |

Consequently an Unknown row typically resolves to 🟡: the Dart desktop implementation is auditable
and usually good, while the mobile path inherits whatever the sibling native audit records. Where
the two paths disagree the row is 🟡 and the note says which platform fails.

**The Dart core is strong work.** Two places it is ahead of every other SDK in this matrix:

- **Retry Queue on desktop.** `_doFlush` (`posthog_core_stateless.dart:491-552`) removes a batch from
  the queue **only when the error is not transient** (`if (!_isTransientFetchError(e)) queue.remove(...)`),
  honours `Retry-After` by pausing the flush timer, and re-arms the periodic flush so an offline
  failure does not strand the queue until the next capture. A persistent 503 stays queued — exactly
  what the spec requires, and exactly what posthog-js, posthog-node, and posthog-react-native all
  get wrong (see posthog-react-native [n9](posthog-react-native.md#n9)). The row as a whole is still
  🟡 because Flutter Web uses posthog-js's retry queue, which drops a 429 ([n38](#n38)).
- **Malformed feature-flag payloads.** `feature_flags.dart:9-12` documents and implements the rule
  verbatim: "A payload that is not valid JSON (an empty string included) is no payload: null is
  returned and the error goes to `onMalformed`." That is **both halves** of the requirement — the
  correct sentinel *and* the mandated diagnostic — which no other SDK in the matrix currently has:
  posthog-ios, posthog-go, and posthog-react-native return the raw malformed string, and
  posthog-php returns the right sentinel but logs nothing. **That is the desktop path only.** On
  iOS and macOS the payload comes from posthog-ios over the method channel, and posthog-ios still
  returns the raw malformed string (`compliance/posthog-ios.md` n7/n8), so Get Feature Flag Payload
  and Get Feature Flag Result move ✅→🟡 ([n14](#n14), [n15](#n15)).

**`projectToken` already adopted.** `posthog_config.dart:102-109` declares `projectToken` with
`apiKey` retained as a `@Deprecated` getter naming `projectToken` as the replacement — precisely the
shape `openspec/specs/setup/spec.md:179` prescribes. Flutter needs no action on PR
[#108](https://github.com/PostHog/sdk-specs/pull/108).

**Scope of this audit.** The five contracts missing from the previous 59-row file were audited from
scratch, and all six Unknown rows were resolved against newly-readable code. Every ❌ row and every
row the new Dart core touches was re-read at this commit. Rows whose Dart surface is unchanged and
which no merged spec text affects carry forward their previous scoring; the notes say where that is
the case.

## Movement this run

**Resolved Unknowns (6):** Event Batcher ❓→🟡, Feature Flag Called Tracker ❓→🟡, HTTP Client ❓→🟡,
Persistent Storage ❓→🟡, Remote Config ❓→🟡, Retry Queue ❓→🟡 ([n38](#n38); desktop and mobile pass, web inherits posthog-js's 429 gap).

**Re-scored to ✅ (3):** **Capture Exception 🟡→✅** ([n5](#n5); the flat-property finding was retired by
sdk-specs [#103](https://github.com/PostHog/sdk-specs/pull/103)), **Screen 🟡→✅** ([n27](#n27); fixed in
[#614](https://github.com/PostHog/posthog-flutter/pull/614)), and **Set Person Properties 🟡→✅** ([n30](#n30); every
downstream path no-ops on empty input).

**Improvement (1):** **Shutdown ❌→🟡** ([n32](#n32)). The Dart layer still does not flush before
delegating, but two of the three paths now flush anyway: desktop `close()` makes a bounded send
attempt, and the embedded `posthog-android` `PostHog.close()` **now calls `flush()`**
(`posthog/src/main/java/com/posthog/PostHog.kt:536-545`), fixing the native half of the previous
finding. Flutter Web remains a bare no-op, which is what keeps the row off ✅.

**Downgrades (2), both spec-driven:** **Get Feature Flag Payload ✅→🟡** ([n14](#n14)) and **Get
Feature Flag Result ✅→🟡** ([n15](#n15)). The malformed-payload rule (sdk-specs
[#71](https://github.com/PostHog/sdk-specs/pull/71)) merged after the previous audit. The Dart core
meets it on Windows/Linux, but iOS/macOS inherit posthog-ios's raw-string fallback.

**New rows (5):** Capture AI ➖, Evaluate Flags ➖, MCP Analytics ➖ (all `server`-scoped; Flutter is
in none of their applicability tables), **Exception Event Metadata ❌** ([n9](#n9)), **Session Replay
Debug Properties 🟡** ([n28](#n28)).

## Matrix

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Alias | 🟡 | [n1] |
| 2 | Application Lifecycle | ✅ | |
| 3 | Autocapture | 🟡 | [n2] |
| 4 | Before Send Hook | 🟡 | [n3] |
| 5 | Bootstrap | 🟡 | [n4] |
| 6 | Capture | ✅ | |
| 7 | Capture AI | ➖ | |
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
| 23 | Get Feature Flag | 🟡 | [n13] |
| 24 | Get Feature Flag Payload | 🟡 | [n14] |
| 25 | Get Feature Flag Result | 🟡 | [n15] |
| 26 | Get Feature Flags | ❌ | [n16] |
| 27 | Get Feature Flags And Payloads | ❌ | [n17] |
| 28 | Get Session ID | ✅ | |
| 29 | Group | 🟡 | [n18] |
| 30 | Group Identify | ➖ | |
| 31 | HTTP Client | 🟡 | [n19] |
| 32 | Identify | ✅ | |
| 33 | Is Feature Enabled | 🟡 | [n20] |
| 34 | Is Opt Out | ✅ | |
| 35 | Is Session Replay Active | ✅ | |
| 36 | Local Feature Flag Evaluator | ➖ | |
| 37 | Logs | 🟡 | [n21] |
| 38 | MCP Analytics | ➖ | |
| 39 | On Feature Flags | 🟡 | [n22] |
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

## Notes

Notes [n1](#n1)–[n7](#n7), [n11](#n11)–[n13](#n13), [n16](#n16)–[n18](#n18),
[n20](#n20)–[n23](#n23), [n25](#n25), [n27](#n27), [n29](#n29)–[n31](#n31), and
[n33](#n33)–[n37](#n37) carry forward the findings of the 2026-08-06 audit, re-verified against this
commit. Each says which earlier findings still hold, which are fixed (with the posthog-flutter PR that
fixed them), and which a spec change has retired. Three of them, [n5](#n5), [n27](#n27), and
[n30](#n30), no longer have a remaining gap and are re-scored ✅ this run (they keep their notes
as the record of what was fixed). Notes [n8](#n8), [n9](#n9), [n10](#n10), [n14](#n14), [n15](#n15),
[n19](#n19), [n24](#n24), [n26](#n26), [n28](#n28), and [n32](#n32) are new or substantially
rewritten this run.

### n1 — Alias (🟡 Partial)
- **Spec requires:** The `acceptance/public/alias.feature:28-40` `@client` scenario requires the enqueued `$create_alias` event's properties to include both `alias` and `distinct_id`, and the `@both` scenario at `:42-50` requires dropping the call with a validation warning when a required identity is missing. `openspec/specs/alias/spec.md:73` says audited mobile helpers need not duplicate `properties.distinct_id`, which conflicts with the `@client` scenario (the same conflict is recorded in `compliance/posthog-ios.md` n3).
- **SDK currently:** `Posthog().alias({required String alias})` (`lib/src/posthog.dart:375`) is a pass-through with no validation. On Android/iOS/macOS, `PosthogFlutterIO.alias` (`posthog_flutter_io.dart:442-452`) sends only `{'alias': alias}` over the method channel, and both bridges forward that single argument to the native `alias()` (Android `PosthogFlutterPlugin.kt:1824-1835`, iOS `PosthogFlutterPlugin.swift:1539-1552`) with no `distinct_id` added and no blank-alias guard anywhere in the Dart or bridge layers — inherited from the embedded SDKs (`compliance/posthog-android.md` n1 ❌, `compliance/posthog-ios.md` n3 🟡). On web, `posthog_flutter_web_handler.dart:295-298` forwards to posthog-js `alias()`, which adds `distinct_id` but has no empty-alias guard (`compliance/posthog-js.md` n1). Windows/Linux is compliant: the Dart core logs a warning and ignores a blank alias (`core/posthog_core.dart:404-415`) and `aliasStateless` sets both `properties.alias` and `properties.distinct_id` (`core/posthog_core_stateless.dart:281-297`).
- **Backwards compatibility:** Backward-compatible — adding `distinct_id` to the properties is additive, and an early return with a warning only affects calls that today produce a malformed event.
- **Remediation:** Reject a blank alias with a warning in `Posthog().alias()`, so every platform path is covered by one check; add `distinct_id` to the `$create_alias` properties (upstream in posthog-android/posthog-ios or in the Flutter bridges), or resolve the spec conflict in favour of `alias/spec.md:73`.

### n2 — Autocapture (🟡 Partial)
- **Spec requires:** Per `openspec/specs/autocapture/spec.md` Applicability, client SDKs that can observe UI interactions provide generic interaction autocapture (`$autocapture` with element context); client SDKs that only provide screen-view or lifecycle capture "should document that generic interaction autocapture is unsupported". `$rageclick` and similar extensions are supplemental to the core interaction path.
- **SDK currently:** Flutter owns a full widget tree but implements no generic tap/click autocapture. A grep of `lib/`, `android/src/main`, and `darwin/` for `$autocapture`, `elements_chain`, and `captureElementInteractions` returns zero hits; `PosthogObserver` (`lib/src/posthog_observer.dart`) only tracks screen/route events. New since the last audit: [#518](https://github.com/PostHog/posthog-flutter/pull/518) exposes iOS/Mac Catalyst rage-click autocapture through `PostHogConfig.rageClickConfig` (`posthog_config.dart:179-182`), forwarded by the darwin plugin to the native SDK — only the supplemental `$rageclick` path. Neither `README.md` nor the `PostHogConfig` docs say generic interaction autocapture is unsupported, which the spec requires when a client SDK omits it.
- **Backwards compatibility:** Backward-compatible — a net-new feature gap; new capture behaviour behind a config flag, or a README note, is additive.
- **Remediation:** Either build a Flutter widget-tap `$autocapture` pipeline (likely reusing the session-replay widget-tree walk and element parsers), or document the carve-out in the README as the spec requires.

### n3 — Before Send Hook (🟡 Partial)
- **Spec requires:** Fail closed on hook exceptions — catch the exception, **record a warning**, stop the chain, and drop the event (`openspec/specs/before-send-hook/spec.md`, "Before-send exceptions stop the chain and drop transformed events"). For Flutter the eligible paths are `capture()`, `screen()`, and `captureException()` (`spec.md:60`).
- **SDK currently:** Both previously-recorded inconsistencies are resolved. (1) The old note recorded that the events hook continued with the last-good value while the logs hook dropped the record; since [#542](https://github.com/PostHog/posthog-flutter/pull/542) `applyBeforeSend` (`lib/src/utils/before_send.dart:26-45`) drops the event on a throw (`:37-41`), and the spec is now fail-closed, so events and logs follow the same compliant policy. (2) The old note recorded no general `beforeSend` wiring on Flutter Web; since [#617](https://github.com/PostHog/posthog-flutter/pull/617) web runs it before `capture`, `screen`, and `captureException` (`lib/posthog_flutter_web.dart:35-46`), and desktop runs the same `applyBeforeSend` (`posthog_flutter_desktop.dart:608-634`). **Remaining gap (also previously recorded):** the hook-exception warning goes through `printIfDebug` (`before_send.dart:38`), which only prints under `kDebugMode` (`lib/src/util/logging.dart:4`), so in release builds a throwing privacy hook drops events with no record at all. The logs path uses ungated `debugPrint`.
- **Backwards compatibility:** Backward-compatible — emitting a warning outside debug builds is additive.
- **Remediation:** Log the hook-exception warning through a logger not gated on `kDebugMode` (for example one honouring `config.debug`, or an always-on warning line).

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
- **Spec requires:** When opted out, event-producing APIs return early without enqueueing or sending, and consent gating runs before the before-send hook (`openspec/specs/before-send-hook/spec.md:80`, "opted-out events are typically blocked before the hook is invoked"); wrapper-managed integrations and session replay are gated too.
- **SDK currently:** The Dart core implements this correctly for desktop: `optedOut` (`core/posthog_core_stateless.dart:177-197`) resolves a runtime decision, then the persisted value, then the configured default, and `capture`, `screen`, `captureException`, and `addExceptionStep` return early when opted out (`posthog_flutter_desktop.dart:248`, `:281`, `:488`, `:530`). Since the last audit, `optOut()`/`optIn()` also uninstall/reinstall the Dart error-autocapture integrations and stop/restart replay on mobile ([#636](https://github.com/PostHog/posthog-flutter/pull/636), [#606](https://github.com/PostHog/posthog-flutter/pull/606)). Of the two previously-recorded Dart-layer exceptions, `addExceptionStep()` (`lib/src/posthog.dart:891`) still has no Dart-side opt-out check but is now confirmed gated natively on Android and iOS; **`captureLog()` (`lib/src/posthog.dart:301-348`) still runs its own `beforeSend` chain unconditionally with no `isOptOut()` check on any platform**. The same ordering applies on Android/iOS/macOS and web for `capture`/`screen`/`captureException` (`posthog_flutter_io.dart:290-305`, `:366-371`, `:756-779`; `lib/posthog_flutter_web.dart:166-175`): the app's `beforeSend` callbacks run before the native/browser SDK drops the event. The enqueue/network outcome is correct; only the hook side effects leak.
- **Backwards compatibility:** Backward-compatible — an early opt-out return before Dart-side processing only stops hook invocations for events that are dropped anyway.
- **Remediation:** Track opt-out state in the Dart layer (cached from `optOut()`/`optIn()` and setup, rather than an `isOptOut()` channel round-trip per call) and return early in `captureLog()` and the IO/web `capture`, `screen`, and `captureException` before running `beforeSend`.

### n7 — Debug (🟡 Partial)
- **Spec requires:** Per the canonical signature `debug(enabled?: boolean)`, calling with no argument defaults to enabling debug mode (`openspec/specs/debug/spec.md:18-21`; scenario "Debug defaults to enabled when called without an argument").
- **SDK currently:** `Future<void> debug(bool enabled) => _posthog.debug(enabled);` (`lib/src/posthog.dart:459`) declares `enabled` as a required, non-nullable, non-defaulted parameter — `Posthog().debug()` with no argument is a Dart compile error today, not a runtime default-to-true. The platform interface, IO (`posthog_flutter_io.dart:523`), web, and desktop (`posthog_flutter_desktop.dart:397`) implementations share the same signature.
- **Backwards compatibility:** Backward-compatible — changing the signature to `debug([bool enabled = true])` only adds a default for currently-invalid (missing-argument) call sites; existing callers that pass an explicit boolean are unaffected.
- **Remediation:** Give `enabled` a default value of `true`.

### n8 — Event Batcher (🟡 Partial)
- **Spec requires:** Count- and time-based batching with configurable `flushAt`/batch size, a bounded queue with oldest-first eviction, and 413 handling that reduces the batch size rather than dropping the batch.
- **SDK currently:** **Resolved from ❓ Unknown.** The previous audit could not inspect this because it lived inside the native SDKs. The Dart core now implements it directly for desktop, and the implementation is good: `_flushAt`, `_maxBatchSize`, and `_maxQueueSize` are all config-driven and clamped to a minimum of 1 (`posthog_core_stateless.dart:112-114`); `_enqueue` flushes when `queue.length >= _flushAt` (`:423`) and evicts the overflow oldest-first (`:414`); `_scheduleFlush`/`_clearFlushTimer` (`:442-460`) provide the time-based path; and a 413 halves `_maxBatchSize` and retries the same batch rather than dropping it (`:522-526`). **Why 🟡 rather than ✅:** this covers Windows and Linux only. On iOS/Android the batcher is still the embedded native SDK's: `compliance/posthog-ios.md` records Event Batcher ✅, but `compliance/posthog-android.md` n6 records a 🟡; on Web it is posthog-js's. The contract is therefore not met on every platform path.
- **Backwards compatibility:** Backward-compatible — the fix is in the sibling SDKs, not in this repo.
- **Remediation:** No action in posthog-flutter. Track the Android half under posthog-android n6 and the web half under posthog-js; re-score to ✅ once the embedded SDKs' batcher rows clear.

### n9 — Exception Event Metadata (❌ Fail)
- **Spec requires:** Every entry in `$exception_list` SHALL carry a `mechanism` with a unique non-negative integer `exception_id` (`0` for the outermost), and every nested entry SHALL carry `parent_id`, `mechanism.type` equal to `chained`, and a `mechanism.source` describing the parent edge. `handled` describes capture disposition **at the relevant boundary** and MUST NOT be invented for a nested entry. Producers SHALL serialize at most **50** entries, retaining the outermost plus the first 49 nested in canonical depth-first order. Application property bags **MUST NOT** override SDK-owned `$exception_list`, `$exception_level`, or `$exception_source` (spec line 300).
- **SDK currently:** Audited from scratch against `lib/src/error_tracking/dart_exception_processor.dart`. What is right: a real `mechanism` object with `handled`, `synthetic`, and `type` (`:82-86`); genuine synthetic detection (`:73-78`); correct outermost-first cause ordering (`:107-118`); `thread_id` where available; and a cycle guard via a `seen` set (`:170`). **Four defects, any one of which blocks ✅, and together a Fail:** (1) **no `exception_id` and no `parent_id` anywhere** — grep returns zero hits for both across the whole repo, so the canonical tree linkage the spec makes mandatory on every entry is entirely absent and nested entries cannot be attributed to their parents; (2) **nested causes inherit the outermost `handled`** — `_appendCauses` passes the parent's value straight down (`:178`, `'handled': handled`), which is the invented capture-boundary metadata the spec forbids, and they also lack `type: 'chained'` and any `source`; (3) **`$exception_level` is a hardcoded literal** — `'$exception_level': 'error'` with the comment "Never crashes, so always error" (`:123`) — and **no `$exception_source` is emitted at all**; (4) **the caller's property bag overrides SDK-owned keys** — the result map is built as `{ '$exception_level': …, '$exception_list': …, if (properties != null) ...properties }` (`:120-125`), spreading caller properties **last**, so a caller passing `$exception_list` replaces the SDK's own. Separately, `maxExceptionChainLength = 10` (`:20`) truncates more aggressively than the spec's 50, discarding entries the spec says to retain.
- **Backwards compatibility:** **Needs deprecation path.** Defects (1), (2), and (3) are additive wire-format changes and are backward-compatible on their own. Defect (4) is not: a caller may today pass `$exception_level` through the generic property bag, and the spec asks for documented *typed* overrides instead, so the typed channel has to ship before the generic one stops winning.
- **Remediation:** Assign `exception_id` by depth-first index with `0` outermost and set `parent_id` plus `mechanism.type: 'chained'` and `mechanism.source: 'cause'` on every appended cause; stop propagating the parent's `handled` to causes (omit it rather than guessing); derive `$exception_level` from the capture boundary and emit `$exception_source`; raise `maxExceptionChainLength` to 50; and add typed level/source/mechanism parameters to `captureException`, then stop spreading the generic property bag over the reserved keys. The same work clears the mirror finding in `compliance/posthog-php.md` n5.

### n10 — Feature Flag Called Tracker (🟡 Partial)
- **Spec requires:** Dedupe `$feature_flag_called` per (flag, value), re-fire on value change, clear on `reset()`, and honour the minimal-envelope allowlist.
- **SDK currently:** **Resolved from ❓ Unknown.** The Dart core implements the tracker directly: `_flagCallReported` is a `Map<String, Set<PostHogFeatureFlagValue?>>` (`posthog_core.dart:25-26`), the dedup check is `!(_flagCallReported[key]?.contains(flagValue) ?? false)` (`:780`) — keyed on the value, so a changed value correctly re-fires — the set is populated after reporting (`:815`), `$feature_flag_called` is captured at `:838`, and the whole map is cleared on reset (`:82`). Failure cases are recorded for the event (`:888`). The Dart core also implements the minimal envelope on desktop: `core/feature_flag_utils.dart:25` parses the server's `minimalFlagCalledEvents` gate from the `/flags` response, `posthog_core.dart:652` persists it with the flag details and `:120-121` reads it back, and `posthog_core_stateless.dart:229-236` keeps only `minimalFeatureFlagCalledProperties` (`feature_flag_utils.dart:70`) on non-experiment `$feature_flag_called` events, so desktop passes. **Why 🟡:** the mobile path is the embedded native tracker, which `compliance/posthog-android.md` n8 records as 🟡 (posthog-ios is ✅).
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** None in the Dart core; track the Android half under posthog-android n8.

### n11 — Flush (🟡 Partial)
- **Spec requires:** `both`. No-op on an empty queue; drain immediately; a failed batch stays queued.
- **SDK currently:** `Posthog().flush()` (`lib/src/posthog.dart:804`) dispatches to the platform instance. Desktop's `flush()` (`posthog_flutter_desktop.dart:479`) routes into the Dart core's correct implementation (see [n38](#n38)). On mobile it is `invokeMethod('flush')` (`posthog_flutter_io.dart:743-752`). **The previously-recorded gap is unchanged and is on Web:** `posthog_flutter_web_handler.dart:400-402` has `case 'flush':` with the delegating call **commented out**, so `flush()` on Flutter Web is a silent no-op that resolves successfully while delivering nothing.
- **Backwards compatibility:** Backward-compatible — making a no-op actually call through only delivers events that the caller already asked to deliver.
- **Remediation:** Uncomment/implement the `window.posthog` flush delegation in the web handler, or make the no-op log a warning so it is not silent.

### n12 — Get Anonymous ID (❌ Fail)
- **Spec requires:** `client`. A getter returning the SDK's anonymous identifier.
- **SDK currently:** Re-confirmed at this commit: the public API list in `lib/src/posthog.dart` has `getDistinctId()` (`:380`) and `getSessionId()` (`:948`) but **no `getAnonymousId()`** on any platform path. The standing `// TODO` recorded by the previous audit is still the only trace of it.
- **Backwards compatibility:** Backward-compatible — a new getter is additive.
- **Remediation:** Add `Future<String> getAnonymousId()` to the platform interface, implemented over the method channel on mobile, from `PostHogPersistedProperty.anonymousId` in the Dart core on desktop, and over `window.posthog` on web.

### n13 — Get Feature Flag (🟡 Partial)
- **Spec requires:** The client signature `getFeatureFlag(key, options?: { sendFeatureFlagEvent?: boolean })`, with a per-call way to turn off `$feature_flag_called` tracking (scenario "Getter can suppress feature flag called tracking (@both)", `openspec/specs/get-feature-flag/spec.md:168-179`).
- **SDK currently:** `Posthog().getFeatureFlag(String key)` (`lib/src/posthog.dart:764-765`, `posthog_flutter_platform_interface.dart:203-205`) matches the spec's documented Flutter base signature, but no path has a per-call suppression parameter: `posthog_flutter_io.dart:661-672` sends only `{'key': key}`; Android `PosthogFlutterPlugin.kt:1676-1687` calls `PostHog.getFeatureFlag(featureFlagKey)` with default tracking; iOS `PosthogFlutterPlugin.swift:1356` calls `PostHogSDK.shared.getFeatureFlag(featureFlagKey)`; web `posthog_flutter_web_handler.dart:365-369` passes no options; desktop `posthog_flutter_desktop.dart:461-462` → `core/posthog_core.dart:864-868` always uses the global setting. PR [#636](https://github.com/PostHog/posthog-flutter/pull/636) only renamed that global toggle (`PostHogConfig.sendFeatureFlagEvent`, `posthog_config.dart:144`, with `sendFeatureFlagEvents` deprecated); it is still config-wide. By contrast `getFeatureFlagResult(key, {sendEvent})` (`lib/src/posthog.dart:785-789`) already supports per-call suppression on every path.
- **Backwards compatibility:** Backward-compatible — an optional named parameter (e.g. `getFeatureFlag(String key, {bool sendEvent = true})`) is purely additive.
- **Remediation:** Add the per-call suppression parameter to `getFeatureFlag`, threaded through like `getFeatureFlagResult` (`sendEvent` channel argument on iOS/Android, `send_event` option on web, `getFeatureFlagResult(key, sendEvent:)` on desktop).

### n14 — Get Feature Flag Payload (🟡 Partial)
- **Spec requires:** A cache-only payload getter that emits no `$feature_flag_called`. A serialized payload that is not valid JSON (including `""` and whitespace) SHALL return the no-payload value, MUST NOT return the raw string, and the failure is logged; valid JSON keeps its decoded type.
- **SDK currently:** **Correct on Windows/Linux only.** The desktop path (`posthog_flutter_desktop.dart:465-468`) reads `getFeatureFlagResult(key, sendEvent: false)?.payload` from the Dart core, whose `parsePayload` (`core/feature_flags.dart:9-21`) returns `null` on a `FormatException` and reports it through `onMalformed`, which is both halves of the rule. **iOS and macOS fail it:** `PosthogFlutterIO.getFeatureFlagPayload` (`posthog_flutter_io.dart:675-688`) is a bare `invokeMethod('getFeatureFlagPayload')`, and the darwin plugin answers with `PostHogSDK.shared.getFeatureFlagResult(featureFlagKey, sendFeatureFlagEvent: false)?.payload` (`darwin/posthog_flutter/Sources/posthog_flutter/PosthogFlutterPlugin.swift:1377-1389`). posthog-ios's `makeFeatureFlagResult` still sets `payload = payloadValue` when `JSONSerialization` throws (`PostHogRemoteConfig.swift:1106-1117`, unchanged on posthog-ios `main`), so `"{broken"`, `""`, and `"   "` reach Dart as the raw string — the defect recorded under `compliance/posthog-ios.md` n7. Flutter does not re-check the value on the way through. Android delegates to posthog-android, whose Get Feature Flag Payload row is ✅. The no-event half holds on every path (`sendFeatureFlagEvent: false` on iOS, `sendEvent: false` on desktop).
- **Backwards compatibility:** Backward-compatible in this repo — the fix belongs in posthog-ios. iOS/macOS callers that read the raw malformed string today will get `null` once posthog-ios ships it; that change only affects invalid payloads.
- **Remediation:** No change in posthog-flutter. Track under posthog-ios n7 (return `nil` in the `catch` branch of `makeFeatureFlagResult`), then raise the `PostHog` floor in `darwin/posthog_flutter.podspec` and `Package.swift` to the fixed release and re-score to ✅.

### n15 — Get Feature Flag Result (🟡 Partial)
- **Spec requires:** A structured result (`key`, `enabled`, `variant`, `payload`), `null` for an unknown flag. A malformed serialized payload SHALL be represented as no payload, never its raw string, without changing `key`/`enabled`/`variant`.
- **SDK currently:** **Correct on Windows/Linux only.** Desktop (`posthog_flutter_desktop.dart:471-476`) returns the Dart core's result, whose payload comes from the same `parsePayload` (`core/feature_flags.dart:9-21`) and is `null` for invalid JSON. On iOS/macOS, `PosthogFlutterIO.getFeatureFlagResult` (`posthog_flutter_io.dart:690-712`) maps the darwin plugin's reply (`PosthogFlutterPlugin.swift:1391-1410`, built from `PostHogSDK.shared.getFeatureFlagResult(...)`) through `PostHogFeatureFlagResult.fromMap`, which copies `payload` verbatim (`feature_flag_result.dart:64-74`). posthog-ios fills that field with the raw string on a decode failure (`compliance/posthog-ios.md` n8), so the `"{broken"`/`""`/`"   "` rows fail on iOS and macOS. `key`/`enabled`/`variant` are unaffected, and the per-call `sendEvent` flag is honoured on every path. Android delegates to posthog-android, whose Get Feature Flag Result row is ✅.
- **Backwards compatibility:** Backward-compatible in this repo — the fix belongs in posthog-ios, and only invalid payloads change.
- **Remediation:** No change in posthog-flutter. Track under posthog-ios n8, then raise the posthog-ios floor and re-score to ✅.

### n16 — Get Feature Flags (❌ Fail)
- **Spec requires:** A bulk getter returning all known flags as a key→value map.
- **SDK currently:** Re-confirmed at this commit — no bulk flag getter exists anywhere in the Dart API (`lib/src/posthog.dart` has only the single-key `getFeatureFlag`, `getFeatureFlagPayload`, and `getFeatureFlagResult`). The Dart core *does* hold the full flag map internally (`core/feature_flags.dart`), so the data is available; it is simply not exposed.
- **Backwards compatibility:** Backward-compatible — a new getter is additive.
- **Remediation:** Expose the Dart core's flag map through the platform interface and bridge it on mobile and web.

### n17 — Get Feature Flags And Payloads (❌ Fail)
- **Spec requires:** A combined getter returning flags and their decoded payloads.
- **SDK currently:** Re-confirmed at this commit — no combined getter under any name. Notably, the decoding half this contract depends on is already correct in the Dart core on desktop (see [n14](#n14)), so only the surface is missing there.
- **Backwards compatibility:** Backward-compatible — additive.
- **Remediation:** Add the combined getter alongside [n16](#n16)'s bulk getter, reusing the existing correct decode path.

### n18 — Group (🟡 Partial)
- **Spec requires:** `group(type, key, properties)` MUST reject a blank/empty `type` or `key`, leaving group state unchanged and logging a warning.
- **SDK currently:** `Posthog().group(...)` (`lib/src/posthog.dart:628-637`) and `PosthogFlutterIO.group` (`posthog_flutter_io.dart:635-658`) do no blank-string validation — Dart's `required String` only blocks `null`, not `""`. The native plugins check only argument presence: Android `PosthogFlutterPlugin.kt:1974-1987` (`!!`) and iOS `PosthogFlutterPlugin.swift:1651-1665` (`as? String`). The Android path inherits posthog-android's open gap (`compliance/posthog-android.md` n11, 🟡). posthog-ios fixed it upstream (`compliance/posthog-ios.md` n12, ✅ via posthog-ios#929), but Flutter still allows `PostHog >= 3.84.0` (`darwin/posthog_flutter.podspec:25`, `darwin/posthog_flutter/Package.swift:17`), so an older resolved version accepts empty values. Desktop already rejects blank values (`core/posthog_core.dart:445-449`), and web relies on posthog-js's own `!groupType || !groupKey` guard.
- **Backwards compatibility:** Backward-compatible — an early-return guard only changes behavior for already-invalid (blank) input.
- **Remediation:** Add a shared blank `groupType`/`groupKey` guard in `Posthog().group()` so mobile is covered whatever native version resolves, matching the desktop core.

### n19 — HTTP Client (🟡 Partial)
- **Spec requires:** Platform transport with gzip where supported; a `/flags` retry policy that retries transient transport conditions but **not a refused connection** (PR [#110](https://github.com/PostHog/sdk-specs/pull/110)); and a retry schedule whose first retry is not sent before 300 ms.
- **SDK currently:** **Resolved from ❓ Unknown.** The Dart core implements the transport directly for desktop and much of it is right: gzip is applied with a correct `Content-Encoding` header when configured (`posthog_core_stateless.dart:635-637`), a request timeout cancels the attempt (`:565-574`), `Retry-After` is parsed and honoured (`:650`), and the `/flags` retry budget and base delay are `1` retry at **300 ms** (`:79-80`) — matching the spec's first-retry floor, where posthog-js/node use a fixed 3,000 ms and fail it. **Gap:** `_isRetryableFlagsError` (`:56-58`) returns `true` for **any** `PostHogFetchNetworkError`, and `_fetchWithRetry` wraps every transport exception — a connection-refused `SocketException` included — into exactly that type (`:572-574`). A refused `/flags` connection is therefore retried, which PR [#110](https://github.com/PostHog/sdk-specs/pull/110) forbids. Separately, `retriable` (`core/utils/utils.dart:15-39`) waits a **fixed** `retryDelay` on each attempt with no backoff multiplier, so the `/batch/` path's three retries are all 3 s apart rather than escalating. On mobile the transport is the native SDK's, and both `compliance/posthog-android.md` and `compliance/posthog-ios.md` now record HTTP Client ✅, so the gap is desktop-only.
- **Backwards compatibility:** Backward-compatible — narrowing a retry predicate and adding a backoff multiplier are internal changes with no public surface.
- **Remediation:** In `_isRetryableFlagsError`, exclude a refused connection — inspect the wrapped `SocketException`'s `osError` and treat `ECONNREFUSED` as terminal (posthog-js's `isRetryableFlagsFetchError` is the reference); make `retriable` multiply `retryDelay` by `2 ** (i - 1)`.

### n20 — Is Feature Enabled (🟡 Partial)
- **Spec requires:** A boolean getter accepting a caller-supplied default.
- **SDK currently:** `Future<bool> isFeatureEnabled(String key)` (`lib/src/posthog.dart:485`) — re-confirmed at this commit, still **no `defaultValue` parameter**, so every miss collapses to a hardcoded `false`. Same shape as the confirmed findings on posthog-php, posthog-ruby, posthog-go, and posthog-dotnet.
- **Backwards compatibility:** Backward-compatible — an optional named parameter with the current value as its default changes nothing for existing callers.
- **Remediation:** Add `{bool defaultValue = false}` to `isFeatureEnabled` and thread it through the platform interface.

### n21 — Logs (🟡 Partial)
- **Spec requires:** Capture-time gates evaluated in order — (1) SDK not enabled/initialized, (2) user opted out, (3) blank body, (4) `beforeSend` returned null / blanked the body / threw, (5) rate cap — returning before `beforeSend` when an earlier gate fails (`openspec/specs/logs/spec.md:45-65`); a throwing `beforeSend` drops the record with a diagnostic naming `beforeSend` (`:377-381`).
- **SDK currently:** `Posthog().captureLog(...)` (`lib/src/posthog.dart:301-348`) and the `logger` facade (`lib/src/logs/posthog_logger.dart:35-56`, all six severities) default to `info` and drop blank bodies both before (`:309`) and after (`:336`) `beforeSend`. The previously-recorded deviation — the logs `beforeSend` catch branch drops the record on a throw (`:329-331`) instead of continuing with the last-good value — is **now compliant**: the logs and before-send-hook specs are fail-closed. **Remaining gap — gate order:** the Dart layer runs the caller's `beforeSend` chain (`:321-334`) without any opt-out check; opt-out is only applied after the record reaches native `PostHog.captureLog` (Android `PosthogFlutterPlugin.kt:1796-1814`), so hooks run for opted-out users, against gate (2) and the "gates short-circuit in order" scenario (see also [n6](#n6)). Encoding, transport, and rate capping live in the embedded SDKs, not this repo: posthog-android (Logs ✅), posthog-ios (Logs 🟡, n1), and posthog-js on web. Windows/Linux `captureLog` is a documented no-op (`posthog_flutter_desktop.dart:333-341`).
- **Backwards compatibility:** Backward-compatible — an early return for opted-out users skips only hooks whose record would have been dropped anyway.
- **Remediation:** Check `await _posthog.isOptOut()` at the top of `captureLog()`, before the blank-body check and the `beforeSend` loop.

### n22 — On Feature Flags (🟡 Partial)
- **Spec requires:** A listener invoked when flags load, including for a listener registered after flags are already available.
- **SDK currently:** `PostHogConfig.onFeatureFlags` (`OnFeatureFlagsCallback`, declared in `posthog_flutter_platform_interface.dart:12`) is a **single config-time callback**, not a registration API — so there is no way to add a listener later at all, and the late-registration scenario cannot be satisfied by construction. Carried forward, unchanged.
- **Backwards compatibility:** Backward-compatible — adding a registration method alongside the config callback is additive.
- **Remediation:** Add `onFeatureFlags(callback)` returning an unsubscribe handle, backed by the Dart core's `EventEmitter` (`core/event_emitter.dart`), firing immediately when flags are already loaded.

### n23 — Opt In (🟡 Partial)
- **Spec requires:** `optIn()`/`optOut()` that persist the decision and gate capture, plus the scenario "Opt out can clear local persistence when configured": opting out with local-data clearing enabled clears persisted identity and super properties (`openspec/specs/opt-in/spec.md:124-133`).
- **SDK currently:** The previously-recorded naming gap (`enable()`/`disable()` instead of `optIn()`/`optOut()`) is fixed by [#636](https://github.com/PostHog/posthog-flutter/pull/636): `Posthog().optOut()`/`optIn()` (`lib/src/posthog.dart:399`, `:423`), with `disable()`/`enable()` kept as `@Deprecated` forwarders (`:443`, `:449`). They gate capture and persist through native, posthog-js, or the desktop core, and [#606](https://github.com/PostHog/posthog-flutter/pull/606) stops replay on opt-out. **Still missing (mirroring posthog-android):** no way to clear persisted data on opt-out on any path. `optOut()` takes no parameters and `PostHogConfig` has no clear-on-opt-out option; the platform `disable()` (`posthog_flutter_platform_interface.dart:132`) carries no arguments; web calls `opt_out_capturing()` with no options (`posthog_flutter_web_handler.dart:360-361`); desktop `optOut()` only persists the flag (`core/posthog_core_stateless.dart:190-197`). The embedded SDKs have the same gap (`compliance/posthog-android.md` n14 🟡, `compliance/posthog-ios.md` n15 🟡).
- **Backwards compatibility:** Backward-compatible — an optional parameter (e.g. `optOut({bool clearLocalData = false})`) or a config flag keeps today's default.
- **Remediation:** Add an optional clear-local-data option to `optOut()` that purges persisted identity and super properties, delegating to native once posthog-android/posthog-ios add it and clearing desktop storage directly.

### n24 — Persistent Storage (🟡 Partial)
- **Spec requires:** Durable key/value persistence that never throws into the host app, with failures surfaced through SDK diagnostics.
- **SDK currently:** **Resolved from ❓ Unknown.** `core/file_storage.dart` (444 lines) is a real, carefully-specified implementation for desktop and its header comment reads like a spec of its own: persisted properties in a single `posthog_data.json` snapshot; each queued event its own UUIDv7-named file in `posthog_queue/` so queueing one event does not rewrite the others; an OS file lock (`posthog.lock`) so a second app instance reads the snapshot but cannot overwrite the first's identity and consent; **"Storage never throws into the host app"** with an explicit `isDegraded` memory-only mode on read failure that refuses to overwrite good persisted data; and atomic replace via temp-file-plus-rename (`_writeAtomically`, `:436`) so a crash never leaves a half-written file. The documented limitations are honest (no `fsync`, so the newest writes can be lost on a crash; the lock may not hold on network filesystems). **Why 🟡:** desktop only — mobile persistence is the native SDKs', recorded 🟡 under `compliance/posthog-android.md` n15 and `compliance/posthog-ios.md` n23, and web is `posthog-js`'s.
- **Backwards compatibility:** Backward-compatible — nothing in this repo needs to change.
- **Remediation:** No action in posthog-flutter for the desktop path. Track the mobile half under posthog-android n15 and posthog-ios n23.

### n25 — Register (🟡 Partial)
- **Spec requires:** Register a super property merged into later events, with a per-event value winning; implementations MAY reject invalid input such as empty keys (`openspec/specs/register/spec.md:42`), so blank keys should not silently persist as stray super properties.
- **SDK currently:** `Posthog().register(String key, Object value)` (`lib/src/posthog.dart:467-468`) and `PosthogFlutterIO.register` (`posthog_flutter_io.dart:714-727`) forward the key with no blank check, and so does every other path: Android `PosthogFlutterPlugin.kt:1989` (presence-only `!!`, inheriting `compliance/posthog-android.md` n16 🟡), web `posthog_flutter_web_handler.dart:384-389`, and desktop `posthog_flutter_desktop.dart:401-402` → `core/posthog_core_stateless.dart:388-393`. An empty-string key silently persists as a super property. Per-event properties correctly win over registered ones on desktop (`core/posthog_core.dart:152-154`).
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
- **Spec requires:** `client`. Four required keys on **every** captured event except `$snapshot` on all platforms — `$recording_status`, `$sdk_debug_replay_event_trigger_status`, `$sdk_debug_replay_linked_flag_trigger_status`, `$sdk_debug_replay_internal_buffer_length` — plus a throttled optional `$sdk_debug_*` bundle on SDK events, with all of them stripped from the minimal `$feature_flag_called` envelope. An SDK with no replay integration produces only `$recording_status: disabled`.
- **SDK currently:** Audited from scratch. **Partially present, and the part that exists is on the wrong axis.** The Dart core emits three debug keys on its own schedule — `$sdk_debug_session_start`, `$sdk_debug_current_session_duration`, and `$sdk_debug_pending_queue_size` (`core/posthog_core.dart:170-173`) — and the desktop client stamps `$recording_status: 'disabled'` (`posthog_desktop_client.dart:41`), which is the correct value for a platform with no replay integration. **None of the three cross-platform required replay keys exists**: grep for `sdk_debug_replay` across the repo returns zero hits, so `$sdk_debug_replay_event_trigger_status`, `$sdk_debug_replay_linked_flag_trigger_status`, and `$sdk_debug_replay_internal_buffer_length` are absent on every platform — including iOS and Android, where Flutter runs a substantial Dart-side replay pipeline (`lib/src/replay/`) and therefore has real values to report. `$recording_status` itself is emitted only on desktop, where replay does not exist; the mobile paths that *do* record emit no `$recording_status` from the Dart layer at all.
- **Backwards compatibility:** Backward-compatible — these are additive diagnostic properties on events the SDK already sends.
- **Remediation:** Attach `$recording_status` on the mobile paths from the state `PostHogInternalEvents.sessionRecordingActive` already tracks, and add the three `$sdk_debug_replay_*` keys sourced from the Dart replay pipeline's trigger state and `SnapshotManager`'s buffer depth; exclude `$snapshot` events; keep the desktop `disabled` value as-is.

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
- **Spec requires:** `openspec/specs/setup/spec.md:163`, `:179` — name the project credential `projectToken`, with any legacy `apiKey` retained as a deprecated alias; plus lifecycle hygiene on re-initialization.
- **SDK currently:** **The `projectToken` half now passes outright** — `posthog_config.dart:102-109` declares `final String projectToken` and keeps `String get apiKey => projectToken` behind a `@Deprecated` annotation naming `projectToken` as the replacement, which is exactly the non-breaking shape the spec prescribes. `setup()` also now rejects a blank token with a logged warning (`lib/src/posthog.dart:70-76`), and `_installFlutterIntegrations` calls `_uninstallFlutterIntegrations()` first (`:101-103`), so repeated setup no longer **stacks** error-tracking integrations — the specific harm the previous audit named. **Remaining gap:** there is still no explicit double-init guard or warning. A second `Posthog().setup()` silently re-runs the whole path, refreshes the mask-parser map, and re-invokes native `setup` over the method channel, and `PosthogFlutterPlugin.kt` has no already-initialized check of its own.
- **Backwards compatibility:** Backward-compatible — adding an idempotency guard or a debug warning is additive.
- **Remediation:** Track whether `setup()` has already run and warn (or no-op) on a second call without an intervening `close()`.

### n32 — Shutdown (🟡 Partial)
- **Spec requires:** Flush pending events before tearing down so queued data is not lost.
- **SDK currently:** **Improved from ❌.** The previous audit's finding had two halves and one of them is now fixed. **Still true:** `Posthog().close()` (`lib/src/posthog.dart:927-942`) clears Dart-side state and calls `_posthog.close()` with **no preceding flush**, and `PosthogFlutterIO.close()` (`posthog_flutter_io.dart:836-846`) sends only `invokeMethod('close')`. **Now fixed downstream:** the embedded `posthog-android` `PostHog.close()` calls `flush()` before tearing down (`posthog/src/main/java/com/posthog/PostHog.kt:536-545`, with the comment "flush pending events before tearing down so queued data isn't lost"), and `PostHogStateless.close()` calls `queue?.flushForShutdown()` (`PostHogStateless.kt:115-126`) — so on Android the flush does happen, inside the native SDK. posthog-ios's Shutdown row is ✅ after its 2026-10-08 refresh. **Newly covered:** desktop `close()` (`posthog_flutter_desktop.dart:535`) makes one bounded send attempt of up to two seconds, documented at `lib/src/posthog.dart:920-923`. **What keeps this off ✅:** Flutter Web's `close` is still a bare no-op — `posthog_flutter_web_handler.dart:404-406` has `case 'close':` with the delegating call commented out — so `close()` on Flutter Web does nothing at all, and the Dart layer itself still has no flush of its own as a safety net if a native SDK's behaviour regresses.
- **Backwards compatibility:** Backward-compatible — adding a bounded flush before `close()` only delivers events the caller already queued.
- **Remediation:** Implement Flutter Web's `close` (at minimum a best-effort delegation to `window.posthog`), and add a bounded `await flush()` in the Dart layer's `close()` so the guarantee does not depend on each embedded SDK.

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
- **Spec requires:** Per the `@client` acceptance scenario (`surveys.feature`), non-web/native SDKs MUST exclude surveys whose only display-targeting conditions are web-only (`url`/`selector`), alongside the other eligibility checks.
- **SDK currently:** Flutter has a full Dart survey UI (`lib/src/surveys/survey_service.dart`, `widgets/`) but still implements **no** eligibility filtering of its own; what it gained since the last audit is the `surveyPopupDelaySeconds` delay ([#627](https://github.com/PostHog/posthog-flutter/pull/627)) and partial-response resume ([#598](https://github.com/PostHog/posthog-flutter/pull/598)), neither of which is an eligibility gate. The Dart survey model still has **no `conditions`, `url`, or `selector` field** (`lib/src/surveys/models/posthog_display_survey.dart`). `PostHogFlutterSurveysDelegate.kt` (Android) and `PostHogDisplaySurvey+Dict.swift` (iOS) remain pure serializers registered as the native SDK's `surveysDelegate`, so the native eligibility engine is the sole gate. On iOS that gate now excludes web-only surveys (`compliance/posthog-ios.md` Surveys ✅); on Android it does not (`compliance/posthog-android.md` n22, 🟡), so Flutter Android shows such surveys and the Dart side cannot catch them because its model doesn't carry the fields. Windows/Linux have no survey support.
- **Backwards compatibility:** Needs deprecation path — the fix narrows eligibility with no API change, but some surveys currently shown on Android would stop displaying; ship with a changelog note.
- **Remediation:** Fix the url/selector exclusion upstream in posthog-android (n22) and raise Flutter's posthog-android floor to that release; optionally add `conditions`/`url`/`selector` to the Dart model as a defensive filter.

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
- **Spec requires:** Keep a failed batch queued on retryable failures — network errors, server errors, and `429` — and honour `Retry-After`.
- **SDK currently:** **Resolved from ❓ Unknown.** Desktop and mobile pass. On Windows/Linux, `_doFlush` (`posthog_core_stateless.dart:491-552`) removes a batch only when the error is not transient, honours `Retry-After` by pausing the flush timer, and re-arms the periodic flush, so a persistent 503 stays queued. On iOS/Android/macOS the embedded native SDKs handle it, and both `compliance/posthog-android.md` and `compliance/posthog-ios.md` record Retry Queue ✅. **Gap on Web:** Flutter Web forwards captures to `window.posthog`, so it uses posthog-js's `RetryQueue`, whose retry condition (`packages/browser/src/retry-queue.ts:94` at `6538babc`) is `statusCode !== 200 && (statusCode < 400 || statusCode >= 500)`. A 429 falls outside it and the event is dropped rather than retried — the same gap as `compliance/posthog-js.md` n28.
- **Backwards compatibility:** Inherits posthog-js n28's verdict (Needs deprecation path).
- **Remediation:** None in this repo; it clears when posthog-js n28 is fixed and Flutter Web picks up that posthog-js release.
