# posthog-flutter — SDK Compliance

**Repo:** [PostHog/posthog-flutter](https://github.com/PostHog/posthog-flutter)
**Audited commit:** `05b53dca5d579bf0dc5c0138f00c8c3836ab85f7` ([commit](https://github.com/PostHog/posthog-flutter/commit/05b53dca5d579bf0dc5c0138f00c8c3836ab85f7)) — audited on 2026-08-06
**Audited against sdk-specs commit:** `b59e8b430c83c5549fc396c8b092615b79d08dd4`
**Summary:** 20 ✅ · 22 🟡 · 6 ❌ · 5 ➖ · 6 ❓

Note on repo layout: `posthog-flutter` is a thin Dart wrapper, not an independent implementation.
The public Dart API lives at `posthog_flutter/lib/src/posthog.dart` (the `Posthog` singleton),
backed by `posthog_flutter_platform_interface.dart` (abstract interface),
`posthog_flutter_io.dart` (method-channel implementation used on iOS/Android/macOS/
Windows/Linux — almost every call is a thin `MethodChannel('posthog_flutter').invokeMethod(...)`
pass-through), and `posthog_flutter_web_handler.dart` (Web implementation, which forwards to
`window.posthog`, i.e. an already-initialized posthog-js instance, via `dart:js_interop`). Native
bridging code lives at `posthog_flutter/android/src/main/kotlin/com/posthog/flutter/
PosthogFlutterPlugin.kt` (delegates to the native `posthog-android` SDK, declared dependency
`com.posthog:posthog-android:[3.58.0,4.0.0)`) and `posthog_flutter/darwin/posthog_flutter/
Sources/posthog_flutter/PosthogFlutterPlugin.swift` (delegates to the native iOS `PostHog` SDK,
podspec requires `>= 3.69.0, < 4.0.0`). Because most capture/identity/flag-evaluation/queueing/
storage/HTTP mechanics are implemented **inside** the embedded native SDKs or posthog-js — not in
this repo — many contracts are marked ❓ Unknown for the parts that are pure native-SDK internals
this repo cannot inspect, while the Dart-layer's own call shape, defaults, guards, and config
plumbing (which _are_ inspectable and often diverge from spec) are graded directly. Where the
sibling `posthog-android` audit (`compliance/posthog-android.md`) already documents a gap in the
embedded native SDK and Flutter's Dart layer does nothing to compensate, that is noted as an
inherited gap rather than re-derived from scratch. Flutter also has substantial **independent**
Dart-side logic for: Dart exception processing (`lib/src/error_tracking/`), a full session-replay
pipeline that walks the Flutter widget tree, masks it, and screenshots it before handing snapshot
frames to the native SDK over the method channel (`lib/src/replay/`), native-view occlusion
bridging on Android (`android/.../PosthogFlutterPlugin.kt` occlusion detector), and native survey
rendering UI fed by native-SDK-supplied survey definitions (`lib/src/surveys/`). A separate
top-level package, `sdk_compliance_adapter/`, is a standalone black-box HTTP test-harness fake
(see its own `README.md`: exposes `/health /init /capture /flush /state /reset` on port 8080) built
to satisfy an external generic acceptance-test protocol — it is **not** part of the shipped
`posthog_flutter` package, and its own reimplementation of feature-flag evaluation, retries, and the
`$feature_flag_called` minimal-event allowlist does not reflect what the real SDK does. It was
excluded as evidence throughout this audit except where explicitly noted.

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Alias | 🟡 | [n1] |
| 2 | Application Lifecycle | ✅ | |
| 3 | Autocapture | 🟡 | [n2] |
| 4 | Before Send Hook | 🟡 | [n3] |
| 5 | Bootstrap | 🟡 | [n4] |
| 6 | Capture | ✅ | |
| 7 | Capture Exception | 🟡 | [n5] |
| 8 | Consent Gating | 🟡 | [n6] |
| 9 | Create Person Profile | ➖ | [n7] |
| 10 | Debug | 🟡 | [n8] |
| 11 | Device ID Generator | ➖ | [n9] |
| 12 | Event Batcher | ❓ | [n10] |
| 13 | Exception Steps | ✅ | |
| 14 | Feature Flag Cache | ✅ | |
| 15 | Feature Flag Called Tracker | ❓ | [n11] |
| 16 | Flag Definition Loader | ➖ | [n12] |
| 17 | Flush | 🟡 | [n13] |
| 18 | Get Anonymous ID | ❌ | [n14] |
| 19 | Get Distinct ID | ✅ | |
| 20 | Get Feature Flag | 🟡 | [n15] |
| 21 | Get Feature Flag Payload | ✅ | |
| 22 | Get Feature Flag Result | ✅ | |
| 23 | Get Feature Flags | ❌ | [n16] |
| 24 | Get Feature Flags And Payloads | ❌ | [n17] |
| 25 | Get Session ID | ✅ | |
| 26 | Group | 🟡 | [n18] |
| 27 | Group Identify | ➖ | [n19] |
| 28 | HTTP Client | ❓ | [n20] |
| 29 | Identify | ✅ | |
| 30 | Is Feature Enabled | 🟡 | [n21] |
| 31 | Is Opt Out | ✅ | |
| 32 | Is Session Replay Active | ✅ | |
| 33 | Local Feature Flag Evaluator | ➖ | [n22] |
| 34 | Logs | 🟡 | [n23] |
| 35 | On Feature Flags | 🟡 | [n24] |
| 36 | Opt In | 🟡 | [n25] |
| 37 | Persistent Storage | ❓ | [n26] |
| 38 | Register | 🟡 | [n27] |
| 39 | Reload Feature Flags | ✅ | |
| 40 | Remote Config | ❓ | [n28] |
| 41 | Reset | ✅ | |
| 42 | Reset Group Properties For Flags | ✅ | |
| 43 | Reset Person Properties For Flags | ✅ | |
| 44 | Retry Queue | ❓ | [n29] |
| 45 | Screen | 🟡 | [n30] |
| 46 | Session Manager | ✅ | |
| 47 | Session Replay Ingestion Controls | ✅ | |
| 48 | Session Replay Privacy | 🟡 | [n31] |
| 49 | Set Group Properties For Flags | ✅ | |
| 50 | Set Person Properties | 🟡 | [n32] |
| 51 | Set Person Properties For Flags | ✅ | |
| 52 | Setup | 🟡 | [n33] |
| 53 | Shutdown | ❌ | [n34] |
| 54 | Start Session Recording | 🟡 | [n35] |
| 55 | Stop Session Recording | 🟡 | [n36] |
| 56 | Surveys | 🟡 | [n37] |
| 57 | Traces | ❌ | [n38] |
| 58 | Tracing Headers | ❌ | [n39] |
| 59 | Unregister | ✅ | |

## Notes

### n1 — Alias (🟡 Partial)
- **Spec requires:** the `acceptance/public/alias.feature` `@client` scenario requires the
  enqueued `$create_alias` event's properties to include both `alias` and `distinct_id`.
- **SDK currently:** `Posthog().alias({required String alias})`
  (`posthog_flutter/lib/src/posthog.dart:355`) →
  `PosthogFlutterIO.alias` (`posthog_flutter_io.dart:442-452`) sends only `{'alias': alias}` over
  the method channel; Android (`android/.../PosthogFlutterPlugin.kt:1635-1646`, calling
  `PostHog.alias(alias)`) and iOS (`darwin/.../PosthogFlutterPlugin.swift` `alias(...)`) both
  forward the single argument to the native SDK's own `alias()`, with no `distinct_id` added
  anywhere in the Dart or bridge layers. This is the same shape of gap flagged in the
  posthog-android audit (n1) — event-shape construction is fully delegated to the embedded native
  SDK, so this is inherited rather than independently introduced by the Dart layer.
- **Backwards compatibility:** Backward-compatible — adding `distinct_id` to the properties map is
  purely additive; could be fixed either upstream in posthog-android/posthog-ios or defensively in
  Flutter's own `PosthogFlutterIO.alias` before forwarding.
- **Remediation:** Add `'distinct_id'` alongside `'alias'` in the method-channel arguments and have
  both native bridges merge it into the `$create_alias` properties.

### n2 — Autocapture (🟡 Partial)
- **Spec requires:** per `openspec/specs/autocapture/spec.md` Applicability, generic UI-interaction
  autocapture (`$autocapture` events with `$elements_chain`) for client SDKs that can observe UI
  interactions in the host runtime — explicitly grounded in "browser DOM autocapture, React Native
  touch autocapture, and iOS/UIKit autocapture." The same section requires: "Client SDKs that only
  provide automatic screen-view or lifecycle capture, but no generic interaction autocapture,
  should document that generic interaction autocapture is unsupported."
- **SDK currently:** Flutter owns a full widget tree (it can observe UI interactions, unlike a
  pure headless SDK) but implements no generic tap/click autocapture pipeline. Exhaustive grep
  across `lib/`, `android/`, and `darwin/` for `$autocapture`/`elements_chain`/`captureTouches`/
  `captureElementInteractions` returns zero hits outside the unrelated **exception** autocapture
  config (`errorTrackingConfig.captureFlutterErrors` etc., a distinct capability). `posthog_observer.dart`
  is confirmed to only track screen/navigation events, not taps. Neither `README.md` nor
  `pubspec.yaml` documents generic interaction autocapture as unsupported, which the spec requires
  when a client SDK intentionally omits it.
- **Backwards compatibility:** Backward-compatible — this is a net-new feature gap, not a
  behavioral regression.
- **Remediation:** Either build a Flutter widget-tap autocapture pipeline (likely reusing the
  existing widget-tree-walk/element-parser machinery already built for session replay masking), or
  explicitly document the carve-out in the README as the spec requires.

### n3 — Before Send Hook (🟡 Partial)
- **Spec requires:** hooks run in an exception-tolerant chain (an exception in one hook should not
  drop the event — continue with the last-good value), consistently across every capture surface
  the SDK exposes.
- **SDK currently:** The events-level `beforeSend` chain (`posthog_flutter_io.dart:46-72`) is
  correctly fail-open: `catch (e) { printIfDebug(...); }` and the loop continues with the
  pre-callback `event`, not a drop. However this behavior is inconsistent across the SDK's two
  `beforeSend` mechanisms: the **logs**-specific hook in `Posthog().captureLog()`
  (`posthog.dart:299-313`) does the opposite — `catch (e) { debugPrint(...); return; }` drops the
  entire log record on any hook exception. This is self-acknowledged as intentional in
  `lib/src/utils/before_send.dart:6` ("Exceptions propagate so each caller applies its own policy
  (events continue, logs drop)"), but it is still a spec deviation for the logs surface, and
  creates a cross-capability inconsistency within the same SDK. Separately, the general `beforeSend`
  mechanism (for `capture`/`screen`/`captureException`) has zero wiring on Flutter Web —
  `posthog_flutter_web_handler.dart` contains no `beforeSend`/`BeforeSendCallback` references at
  all — while the logs-specific `PostHogLogsConfig.beforeSend` is documented as cross-platform.
  Only a debug-gated `printIfDebug`/`debugPrint` records a hook exception; there is no
  always-recorded structured warning.
- **Backwards compatibility:** Backward-compatible for all three — changing the logs catch branch
  to continue with the last-good record, wiring the general hook on web, and adding a
  non-debug-gated warning are all strictly additive/less-destructive than current behavior.
- **Remediation:** Make the logs `beforeSend` catch branch fail-open like the events one; wire
  general `beforeSend` support into the web handler; emit a warning that isn't gated behind debug
  mode.

### n4 — Bootstrap (🟡 Partial)
- **Spec requires:** pre-seeded identity/flags on first launch, and (optionally, per spec's
  permissive language) a bootstrap `sessionID` a client SDK that owns a session concept MAY adopt.
- **SDK currently:** Core identity/flag-bootstrap fields (`distinctId`, `isIdentifiedId`,
  `featureFlags`, `featureFlagPayloads`) are fully modeled in `PostHogConfig.bootstrap`
  (`posthog_config.dart:430-491`) and correctly bridged to both native platforms. Two gaps: (1) no
  `sessionID` field exists on the bootstrap config (mirrors posthog-android's n15, same optional
  omission); (2) bootstrap is explicitly documented as not applied on Flutter Web
  (`posthog_config.dart:212-214`, "the web SDK hooks onto an already-initialized posthog-js
  instance") with zero wiring in `posthog_flutter_web_handler.dart` — a caller who sets
  `config.bootstrap` on web silently gets no effect.
- **Backwards compatibility:** Backward-compatible — adding an optional `sessionID` field is purely
  additive; wiring bootstrap into the web path (translating to posthog-js's own bootstrap init
  option) is also additive, though currently unactionable without app code restructuring since web
  setup happens before Dart-side `setup()` runs.
- **Remediation:** Add optional `sessionID` bootstrap support; document (or implement) a web path
  for bootstrap translation to posthog-js's init-time bootstrap option.

### n5 — Capture Exception (🟡 Partial)
- **Spec requires:** per the `acceptance/public/capture-exception.feature` scenario, the captured
  `$exception` event carries top-level `$exception_type`/`$exception_message` properties in
  addition to the nested `$exception_list`.
- **SDK currently:** `DartExceptionProcessor.processException`
  (`lib/src/error_tracking/dart_exception_processor.dart:81-129`) builds `$exception_level` and
  `$exception_list` but never stamps top-level `$exception_type`/`$exception_message` (confirmed
  via full read — zero such keys). Crucially, both native bridges route the built properties
  through the generic `capture()` API rather than any native `captureException()` convenience path
  that might otherwise backfill these fields: Android `PosthogFlutterPlugin.kt:1932` calls
  `PostHog.capture("$exception", properties = properties, timestamp = timestamp)`; iOS
  `PosthogFlutterPlugin.swift:1625` calls `PostHogSDK.shared.capture("$exception", properties:
  properties, timestamp: timestamp)`. A repo-wide grep for `exception_type`/`exception_message`
  returns zero hits. This is a genuine Dart-layer/bridge-layer gap (both the processor and the
  bridge's API choice live in this repo), not a delegated omission. Frame ordering
  (outermost-first), exception-list cause chaining, and stack-trace preservation are all correctly
  implemented; optional source-context fields are correctly omitted per spec's OPTIONAL marking.
- **Backwards compatibility:** Backward-compatible — additively stamp
  `exceptionProps['$exception_type']`/`['$exception_message']` from the first `$exception_list`
  entry inside `DartExceptionProcessor.processException`.
- **Remediation:** Add the two top-level convenience properties in the Dart processor before
  forwarding to native `capture()`.

### n6 — Consent Gating (🟡 Partial)
- **Spec requires:** capture surfaces should not perform observable work (network, persistence,
  side-effecting hooks) while the user is opted out.
- **SDK currently:** Most capture surfaces correctly forward straight to native/browser SDKs
  without doing observable work first, which is the natively-gated, spec-compliant pattern (mirrors
  posthog-android's own ✅). Two exceptions found in the Dart layer itself: `captureLog()`
  (`posthog.dart:247, 281-328`) runs its own Dart-side `beforeSend` chain unconditionally with no
  `isOptOut()` check anywhere in the method, and its own doc comment (line 247) states "`captureLog`
  is not gated by remote config"; `addExceptionStep()` (`posthog.dart:821-836`) likewise has no
  Dart-side opt-out check. Both presumably get gated natively once the call reaches the native SDK,
  but that final gating point is unverifiable from this repo, and the Dart-side `beforeSend`
  chain/validation runs regardless of opt-out state either way.
- **Backwards compatibility:** Backward-compatible — adding an early-return `isOptOut()` check in
  `captureLog()`/`addExceptionStep()` before running Dart-side processing is additive.
- **Remediation:** Add an `isOptOut()` guard at the top of `captureLog()` and `addExceptionStep()`.

### n7 — Create Person Profile (➖ N/A)
- **Spec requires:** a `createPersonProfile()`-style method to force person-profile creation.
- **SDK currently:** No such method exists anywhere in `lib/`, `android/`, or `darwin/` (confirmed
  via exhaustive grep for `createPersonProfile`/`create_person_profile`). The spec's own
  **Applicability** section states this API "is present in the `posthog-js` family... Other
  audited client SDKs do not expose an equivalent public method" — explicitly scoping non-js-family
  client SDKs out, matching posthog-android's own ➖ N/A verdict for the identical reason. Flutter
  does have `PostHogConfig.personProfiles` (`posthog_config.dart:158-161`, an enum controlling
  ambient person-processing mode), but this is the passive config knob equivalent to posthog-js's
  own `personProfiles` init option, not the imperative escape-hatch method the spec defines — so it
  does not change the applicability verdict.
- **Backwards compatibility:** N/A — no remediation required per spec scope.

### n8 — Debug (🟡 Partial)
- **Spec requires:** per the spec's canonical signature `debug(enabled?: boolean)`, calling with no
  argument defaults to enabling debug mode (an explicit acceptance scenario).
- **SDK currently:** `Future<void> debug(bool enabled) => _posthog.debug(enabled);`
  (`posthog_flutter/lib/src/posthog.dart:399`) declares `enabled` as a required, non-nullable,
  non-defaulted parameter — `Posthog().debug()` with no argument is a Dart compile error today,
  not a runtime default-to-true behavior.
- **Backwards compatibility:** Backward-compatible — changing the signature to `debug(bool enabled
  = true)` only adds a default for currently-invalid (missing-argument) call sites; all existing
  callers that pass an explicit boolean are unaffected.
- **Remediation:** Give `enabled` a default value of `true`.

### n9 — Device ID Generator (➖ N/A)
- **Spec requires:** an internal, no-public-API identity-bootstrap component (per spec's own
  Applicability: "No single public API... Canonical internal operations look like `getAnonymousId`/
  `setAnonymousId`/`reset`").
- **SDK currently:** Flutter has no device-id concept or generation logic of its own anywhere in
  the Dart layer — this is fully delegated to the embedded native SDK (posthog-android/posthog-ios)
  or posthog-js, which is the spec-sanctioned pattern for a thin wrapper with no independent
  identity store. There is nothing to grade in this repo one way or the other for the generator
  itself.
- **Backwards compatibility:** N/A — delegation-only wrappers are within the spec's own scope for
  this internal component; no public surface to fix here.

### n10 — Event Batcher (❓ Unknown)
- **Missing evidence:** batching mechanics (threshold flush, max batch size, single-flush-in-flight
  guard, 413-triggered batch halving) are implemented entirely inside the embedded native SDKs
  (posthog-android/posthog-ios) or posthog-js — Flutter's Dart layer only plumbs config values
  (`flushAt`, `maxBatchSize`, `flushInterval`, `maxQueueSize` in `posthog_config.dart:99-118`)
  through to native `setup()` (`android/.../PosthogFlutterPlugin.kt:562-573`) with no independent
  Dart-side queue, buffer, or flush-timer implementation to inspect. This repo cannot verify the
  actual batching algorithm; posthog-android's own audit (n18) found a partial gap in the embedded
  Android SDK's batcher testability, but that is not independently confirmable from posthog-flutter
  and iOS/web-side behavior is entirely unknown from here.
- **Remediation:** N/A (nothing to fix in this repo); would require reviewing the resolved native
  SDK versions directly, out of scope for a posthog-flutter-only audit.

### n11 — Feature Flag Called Tracker (❓ Unknown)
- **Spec requires:** when the server signals `minimalFlagCalledEvents` (minimal-event mode), the
  minimized `$feature_flag_called` event must still retain an allowlist of session-attribution
  properties (`$referring_domain`, UTM params, `gclid`/`fbclid`) and static platform/OS identity
  properties — the exact category added to this spec by sdk-specs commit `b59e8b4` after the same
  gap was found missing in posthog-python and posthog-android.
- **SDK currently:** Confirmed definitively that the `$feature_flag_called` event and any allowlist
  logic are built 100% in native code, never in Dart. Exhaustive grep across all of
  `posthog_flutter/lib/` for `feature_flag_called`, `sendFeatureFlagEvent`, `minimalFlagCalledEvents`,
  `MINIMAL_FEATURE_FLAG_CALLED_PROPERTIES`, and `allowlist` finds only a doc-comment mention
  (`posthog.dart:705`) and the boolean pass-through config `sendFeatureFlagEvents`
  (`posthog_config.dart:123`), forwarded to native `sendFeatureFlagEvent`
  (`android/.../PosthogFlutterPlugin.kt:574-575`) / native `sendEvent` parameters
  (`getFeatureFlagResult`, `posthog_flutter_io.dart:700-703`). There is no dedup map, LRU cache, or
  minimal-event gate of any kind in Dart — this whole capability is delegated to posthog-android on
  Android, posthog-ios on iOS/macOS, and posthog-js on web. Per the sibling posthog-android audit
  (n19, commit `0d2b16b0`), posthog-android's own `MINIMAL_FEATURE_FLAG_CALLED_PROPERTIES`
  allowlist is missing exactly the session-attribution and platform-identity categories added by
  `b59e8b4`; since Flutter's Android target embeds `posthog-android:[3.58.0,4.0.0)` with no Dart-side
  compensating logic, this gap plausibly propagates to Flutter-on-Android — but the exact resolved
  version at build time, and the equivalent state of posthog-ios's allowlist, cannot be verified
  from the posthog-flutter repo alone. **Note:** the `sdk_compliance_adapter/lib/adapter_server.dart`
  package (`_featureFlagCalledProperties`, lines 577-603) does implement its own version of this
  allowlist, but that is a separate black-box test-harness fake unrelated to the shipped SDK's
  actual behavior — it does not count as evidence either way for this contract.
- **Missing evidence:** the resolved native-SDK versions' current allowlist contents (posthog-android,
  posthog-ios) at whatever version a given Flutter app actually pulls in.
- **Remediation:** Not fixable in this repo — Flutter has no code touching this event. Any fix must
  land in posthog-android/posthog-ios (posthog-js is reportedly already fixed); Flutter apps get the
  fix automatically via a native-dependency version bump, no Dart change required.

### n12 — Flag Definition Loader (➖ N/A)
- **Spec requires:** ETag-based polling of flag definitions for local evaluation, requiring a
  personal/admin API key.
- **SDK currently:** The spec's own Applicability section names Flutter explicitly: "Some client
  wrappers, such as Flutter, expose ordinary feature-flag preload settings without owning a
  separate local-evaluation definition loader." Confirmed: `PostHogConfig` has `preloadFeatureFlags`
  (`posthog_config.dart:139`) and no `personalApiKey`/ETag/poll-interval fields anywhere in the
  file; no `LocalEvaluationPoller`-equivalent exists in `lib/`, `android/`, or `darwin/`.
- **Backwards compatibility:** N/A — justified directly by the spec's own text naming Flutter as an
  example of the excluded wrapper pattern.

### n13 — Flush (🟡 Partial)
- **Spec requires:** `flush()` attempts immediate delivery of queued events; the spec's own
  surface-variant table lists posthog-js's public `flush(): Promise<void>`, which Flutter Web
  wraps a `window.posthog` instance of.
- **SDK currently:** Mobile/desktop `flush()` (`posthog.dart:736`, `posthog_flutter_io.dart:742-753`)
  correctly forwards to native `PostHog.flush()`. On Web, `posthog_flutter_web_handler.dart:367-370`
  has:
  ```dart
  case 'flush':
    // not supported on Web
    // analytics.callMethod('flush');
    break;
  ```
  This comment is factually stale — posthog-js has publicly exposed `flush(): Promise<void>` for
  some time (the same method the spec's surface-variant table cites) — but the Dart `PostHog`
  JS-interop extension class (`posthog_flutter_io.dart` web analog `posthog_flutter_web.dart`) never
  declares an `external` binding for it, so `Posthog().flush()` on Flutter Web is a silent no-op
  today, not delegated to the underlying JS SDK's real capability.
- **Backwards compatibility:** Backward-compatible — adding an `external void flush()` JS-interop
  binding and wiring the `'flush'` case to call it is purely additive; today's silent no-op simply
  becomes a real flush.
- **Remediation:** Add the missing JS-interop binding and wire the web `'flush'` case to it.

### n14 — Get Anonymous ID (❌ Fail)
- **Spec requires:** per Applicability, a client-side ambient-identity accessor; "some audited
  client SDKs implement the same underlying concept internally but do not expose it as a public
  method" — a permissive allowance, but posthog-android (which Flutter embeds on Android) itself
  passes this contract (marked ✅ in `compliance/posthog-android.md` #8) by exposing it publicly.
- **SDK currently:** No `getAnonymousId()` (or any variant) exists anywhere in `posthog.dart`,
  `posthog_flutter_platform_interface.dart`, `posthog_flutter_io.dart`,
  `posthog_flutter_web_handler.dart`, or either native plugin bridge (confirmed via exhaustive
  grep). `posthog_config.dart:350` carries a standing developer TODO acknowledging the gap: `//
  TODO: missing getAnonymousId, captureDeepLinks integrations`. Since the underlying native SDK
  Flutter embeds on Android already exposes this method publicly, this is a pure Flutter-bridge
  omission, not an inherited limitation.
- **Backwards compatibility:** Backward-compatible — adding a new `Future<String?> getAnonymousId()`
  method plus a new method-channel case on both native platforms is purely additive.
- **Remediation:** Add the missing public method and wire it through the platform interface, io,
  and web implementations plus both native bridges.

### n15 — Get Feature Flag (🟡 Partial)
- **Spec requires:** the canonical client signature includes a per-call `options?: {
  sendFeatureFlagEvent?: boolean }` override (scenario "Getter can suppress feature flag called
  tracking (@both)").
- **SDK currently:** `getFeatureFlag(String key): Future<Object?>` (`posthog.dart:696-697`,
  `posthog_flutter_platform_interface.dart:203-205`) matches the spec's documented Flutter surface
  variant exactly for the base signature, but has no per-call suppression parameter anywhere in the
  chain: `posthog_flutter_io.dart:661-672` (`invokeMethod('getFeatureFlag', {'key': key})` — no
  `sendEvent` field), Android `PosthogFlutterPlugin.kt:1487-1498` (always default
  `sendFeatureFlagEvent`), web handler `posthog_flutter_web_handler.dart:333-337` (no options
  passed to `posthog.getFeatureFlag`). Only the global `PostHogConfig.sendFeatureFlagEvents` toggle
  exists — no way to suppress tracking for a single call. (By contrast, `getFeatureFlagResult` does
  support a per-call `sendEvent` parameter correctly — see #22.)
- **Backwards compatibility:** Backward-compatible — adding an optional named parameter (e.g.
  `getFeatureFlag(String key, {bool sendEvent = true})`) is purely additive.
- **Remediation:** Add the missing per-call suppression parameter, mirroring `getFeatureFlagResult`.

### n16 — Get Feature Flags (❌ Fail)
- **Spec requires:** applicability `both`; client SDKs MUST expose a bulk key→value getter
  (`openspec/specs/get-feature-flags/spec.md`, with a `@client`-tagged acceptance scenario).
- **SDK currently:** No such method exists anywhere in the Dart public API, platform interface, io
  implementation, or web implementation. Exhaustive grep of `posthog.dart`,
  `posthog_flutter_platform_interface.dart`, `posthog_flutter_io.dart`,
  `posthog_flutter_web_handler.dart` for a bulk, no-argument `getFeatureFlags` returns zero matches
  — only the singular `getFeatureFlag(key)` exists. This is a genuine Dart-layer gap, not
  delegation: the underlying native SDKs almost certainly expose bulk getters (posthog-android has
  `getAllFeatureFlags()`, itself only 🟡 Partial per its own audit), but Flutter's wrapper never
  surfaces any bulk map-returning API — callers have no way to get "all flags as a map" without
  calling `getFeatureFlag` once per already-known key.
- **Backwards compatibility:** Backward-compatible — pure feature addition; nothing existing
  changes.
- **Remediation:** Add `Future<Map<String, Object>?> getFeatureFlags()`, threaded through the
  platform interface, io/web implementations, and both native bridges (which would need a new
  method-channel case delegating to the native SDK's own bulk getter).

### n17 — Get Feature Flags And Payloads (❌ Fail)
- **Spec requires:** applicability `both`; a bulk getter returning `{flags, payloads}` together,
  with empty (not null) maps when no flags are known.
- **SDK currently:** Same result as Get Feature Flags — no equivalent method exists anywhere in the
  Dart source; grep for "AndPayloads" across `lib/` returns zero matches. This is a Dart-layer gap,
  fixable in this repo; the native SDKs likely expose richer combined getters (e.g.
  posthog-android's `getAllFeatureFlags(): List<FeatureFlagResult>?`) that Flutter never wraps into
  a combined flags+payloads call.
- **Backwards compatibility:** Backward-compatible — additive new method.
- **Remediation:** Add `Future<({Map<String,Object> flags, Map<String,Object> payloads})>
  getFeatureFlagsAndPayloads()` (or equivalent), returning empty maps rather than null per spec.

### n18 — Group (🟡 Partial)
- **Spec requires:** `group(type, key, properties)` MUST reject blank/empty `type`/`key`.
- **SDK currently:** `Posthog().group({required groupType, required groupKey, groupProperties})`
  (`posthog.dart:568-577`) and `PosthogFlutterIO.group` (`posthog_flutter_io.dart:634-658`) perform
  no blank-string validation of their own — Dart's `required String` only blocks `null`, not
  `""`. Android (`PosthogFlutterPlugin.kt:1785-1798`, using Kotlin `!!` for presence, not
  blank-checking) and iOS (`PosthogFlutterPlugin.swift:1504-1518`, `as? String`, same) both only
  check argument *presence*, not blank/empty — mirroring the identical gap flagged in
  posthog-android's own audit (n6). Since Flutter's Dart layer adds no validation of its own on top
  of what it forwards, an empty-string `groupType`/`groupKey` passes through untouched.
- **Backwards compatibility:** Backward-compatible — add an early-return blank-check guard in
  `Posthog().group()`; purely additive since it only changes behavior for currently-malformed
  (blank) input.
- **Remediation:** Add shared blank `groupType`/`groupKey` validation in the Dart layer, matching
  the fix recommended for posthog-android.

### n19 — Group Identify (➖ N/A)
- **Spec requires:** the spec's own documented client-side variant: "iOS/Android/Unity: no
  standalone public `groupIdentify` in the audited client SDKs; `group(...)` emits `$groupidentify`
  internally."
- **SDK currently:** Flutter has no standalone public `groupIdentify` method (confirmed via grep
  across `posthog.dart` and `posthog_flutter_platform_interface.dart`) — `group()` is the sole
  public entry point and internally triggers `$groupidentify` natively, matching the exact pattern
  the spec documents as acceptable for mobile-style client SDKs.
- **Backwards compatibility:** N/A — no remediation required per spec's own documented carve-out.

### n20 — HTTP Client (❓ Unknown)
- **Missing evidence:** Flutter has no Dart-side HTTP client dependency at all for the SDK's own
  event/flag/log traffic (confirmed via full read of `pubspec.yaml` — no `http`, `dio`, or
  `package:http` import anywhere under `lib/`). All network-bound SDK operations are delegated
  through the method channel to the native SDKs (or to posthog-js on web), whose HTTP client
  internals (connection reuse, compression, timeout handling, gzip) are not inspectable from this
  repo.
- **Remediation:** N/A (nothing to fix in this repo for the SDK's own transport); would require
  reviewing the resolved posthog-android/posthog-ios/posthog-js versions directly.

### n21 — Is Feature Enabled (🟡 Partial)
- **Spec requires:** the canonical client signature includes `options?: { sendFeatureFlagEvent?:
  boolean, defaultValue?: boolean }`; two required scenarios test caller-supplied default value
  behavior.
- **SDK currently:** `isFeatureEnabled(String key): Future<bool>` (`posthog.dart:425`,
  `posthog_flutter_platform_interface.dart:156-158`) matches the spec's documented Flutter surface
  variant for the base signature. Two gaps against the full contract: (1) no per-call
  `sendFeatureFlagEvent` suppression exists anywhere in `posthog_flutter_io.dart:536-549` or the web
  handler; (2) no `defaultValue` parameter exists at all — the method hardcodes `false` on
  missing/unsupported-platform (`posthog_flutter_io.dart:536-539`), which the spec explicitly
  sanctions as one valid variation ("SDKs whose boolean API hard-code false for missing values...
  Flutter"), but the inability for a caller to pass a `true` override default is not covered by that
  allowance, and the associated acceptance scenario cannot be exercised at all on Flutter.
- **Backwards compatibility:** Backward-compatible — add optional named parameters (`sendEvent`,
  `defaultValue`) with current behavior preserved as the default.
- **Remediation:** Add the missing per-call `sendEvent` and `defaultValue` parameters.

### n22 — Local Feature Flag Evaluator (➖ N/A)
- **Spec requires:** local (in-process) rule-based flag evaluation using a personal/admin API key.
- **SDK currently:** The spec's Applicability section names Flutter explicitly: "Some client
  wrappers, such as Flutter, do not own a separate evaluator and instead delegate evaluation to
  underlying native/browser SDKs," and its Behavior section spells out exactly which methods
  delegate — `isFeatureEnabled`, `getFeatureFlag`, `getFeatureFlagPayload`, `getFeatureFlagResult`,
  `reloadFeatureFlags` — a verbatim match for what this audit independently confirmed in
  `posthog_flutter_io.dart`/`posthog_flutter_web_handler.dart`. No rule-matching engine exists in
  Dart.
- **Backwards compatibility:** N/A — justified directly by the spec's own explicit Flutter
  carve-out.

### n23 — Logs (🟡 Partial)
- **Spec requires:** severity levels, attribute handling, and (per the general beforeSend contract
  referenced by this spec) a fail-open hook chain that continues with the last-good value on
  exception.
- **SDK currently:** `captureLog(body, level=info, attributes, traceId, spanId, traceFlags)`
  (`posthog.dart:281-328`) and the `logger` facade (`lib/src/logs/posthog_logger.dart:34-56`,
  covering all six severities) are otherwise correctly implemented — default level, whitespace-body
  dropping both pre- and post-`beforeSend`, and documented pass-through-only trace-correlation
  fields all match spec intent. The one deviation (see also n3): the logs-specific `beforeSend`
  catch branch at `posthog.dart:309-313` drops the record entirely on any hook exception, rather
  than falling back to the last-good value as the events-level hook correctly does
  (`posthog_flutter_io.dart:66-69`) — a self-acknowledged, deliberate design choice
  (`lib/src/utils/before_send.dart:6`) that nonetheless deviates from spec and is inconsistent with
  the SDK's own events-hook behavior.
- **Backwards compatibility:** Backward-compatible — changing the catch branch to continue with the
  last-good `record` value is strictly less destructive than the current drop; no signature change.
- **Remediation:** Align the logs `beforeSend` catch branch with the events one (fail-open, not
  fail-drop).

### n24 — On Feature Flags (🟡 Partial)
- **Spec requires:** the spec explicitly documents Flutter's shape (`PostHogConfig(onFeatureFlags:
  ...)`, "Android, Flutter, and Unity primarily expose a readiness signal with no direct payload"),
  but also requires late-registered listeners to fire immediately with current values if flags are
  already loaded, and an unsubscribe mechanism.
- **SDK currently:** `PostHogConfig.onFeatureFlags` (`posthog_config.dart:221`) is a single mutable
  field, wired in `posthog_flutter_io.dart:207` (io) and the web handler's JS-interop registration
  — matching the spec's documented base shape correctly. But it is not a multi-subscriber registry
  (setting a new callback silently overwrites the previous one, with no way to remove it and have
  none fire), and no code path anywhere immediately invokes a newly-set `onFeatureFlags` if flags
  are already loaded — it only fires on the next native/JS flag-load event
  (`posthog_flutter_io.dart:84-86`). This exactly mirrors posthog-android's own 🟡 Partial (n8) on
  the same requirement.
- **Backwards compatibility:** Needs deprecation path — adding true multi-listener semantics with
  immediate-fire-on-late-registration changes today's "callback set once, fires only on next load"
  contract; ship with a changelog note.
- **Remediation:** Add `addOnFeatureFlagsListener`/`removeOnFeatureFlagsListener` APIs alongside the
  existing single-field config, firing synchronously on registration if flags are already loaded.

### n25 — Opt In (🟡 Partial)
- **Spec requires:** the canonical signature `optIn()`/`optOut()`; the spec's surface-variant table
  lists js-core, iOS, Android, and Unity all using `optIn`/`optOut` naming (with browser using
  `opt_in_capturing`/`opt_out_capturing`) — Flutter is not listed as a documented naming variant at
  all.
- **SDK currently:** Flutter uses `enable()`/`disable()` (`posthog.dart:369-389`) rather than
  `optIn()`/`optOut()` — a naming divergence larger than any surface variant the spec documents
  for other SDKs, and not one the spec explicitly sanctions for Flutter. Functionally, `disable()`/
  `enable()` correctly gate capture and persist immediately via native delegation. Also missing
  (mirroring posthog-android's n9): no optional clear-persisted-storage-on-opt-out parameter exists
  (`disable()` takes zero parameters, `posthog_flutter_platform_interface.dart`).
- **Backwards compatibility:** Needs deprecation path for naming — renaming or adding aliased
  `optIn()`/`optOut()` methods now, without removing `enable()`/`disable()`, is additive; actually
  renaming would be breaking. The missing clear-on-opt-out parameter is Backward-compatible on its
  own (optional additive parameter).
- **Remediation:** Consider adding `optIn()`/`optOut()` as documented aliases for
  `enable()`/`disable()` for cross-SDK naming consistency; add an optional
  clear-persisted-storage parameter to `disable()`.

### n26 — Persistent Storage (❓ Unknown)
- **Missing evidence:** storage-failure handling (must not crash SDK calls, must log a storage
  warning) is implemented entirely inside the embedded native SDKs or posthog-js — Flutter's Dart
  layer owns no persistent storage of its own for capture/identity/flag state (confirmed no
  `SharedPreferences`/`NSUserDefaults`/local-file usage for SDK state in `lib/`, only for
  Dart-widget-local concerns unrelated to this contract). This repo cannot verify the storage-write
  failure path inside the native SDKs.
- **Remediation:** N/A (nothing to fix in this repo); posthog-android's own audit already found a
  gap here (n22) which may or may not still be present in whatever version a given Flutter app
  resolves.

### n27 — Register (🟡 Partial)
- **Spec requires:** (permissive language, "MAY reject") blank/empty keys should not silently
  persist as stray super properties.
- **SDK currently:** `Posthog().register(String key, Object value)` (`posthog.dart:407-408`) and
  `PosthogFlutterIO.register` (`posthog_flutter_io.dart:714-727`) perform no blank-key validation
  before forwarding to native `PostHog.register(key, value)` (Android, only checking key presence
  via `!!`) / `PostHogSDK.shared.register(...)` (iOS) — an empty-string key would silently persist,
  mirroring the identical gap flagged in posthog-android's own audit (n10).
- **Backwards compatibility:** Backward-compatible — add a blank-key guard in `Posthog().register()`;
  the spec's validation language here is permissive, so this is a minor, purely additive gap.
- **Remediation:** Add blank-key rejection to `register()`.

### n28 — Remote Config (❓ Unknown)
- **Missing evidence:** remote-config fetch/caching/gating mechanics live entirely inside the
  embedded native SDKs or posthog-js. Flutter's Dart layer only plumbs a handful of related config
  values (e.g. `sessionReplay`, `surveys`, feature-flag toggles) through to native `setup()` — there
  is no independent Dart-side remote-config client, cache, or gating logic to inspect.
- **Remediation:** N/A (nothing to fix in this repo); would require reviewing the resolved native
  SDK versions directly.

### n29 — Retry Queue (❓ Unknown)
- **Missing evidence:** retry/backoff mechanics for failed network sends live entirely inside the
  embedded native SDKs or posthog-js — no independent Dart-side retry queue, backoff algorithm, or
  batch-halving logic exists in `lib/` (confirmed via the same grep sweep used for Event Batcher and
  HTTP Client). Not inspectable from this repo.
- **Remediation:** N/A (nothing to fix in this repo).

### n30 — Screen (🟡 Partial)
- **Spec requires:** the explicit screen-name argument MUST win over any conflicting `$screen_name`
  supplied via the `properties` map.
- **SDK currently:** `PosthogFlutterIO.screen` (`posthog_flutter_io.dart:352-364`) builds
  `propsWithScreenName = {PostHogPropertyName.screenName: screenName, ...?properties}` — the
  `...?properties` spread comes **after** the explicit `screenName` key, so a caller-supplied
  `$screen_name` inside `properties` silently overwrites the `screenName` argument, the opposite of
  the spec's precedence rule. This is a genuine, isolated Dart-layer bug: `Posthog().capture()`
  (`posthog.dart:215-218`) demonstrates the SDK already knows the correct pattern elsewhere
  (`containsKey` check before injecting), making this an inconsistency rather than a fundamental
  design gap.
- **Backwards compatibility:** Needs deprecation path — flipping the merge order
  (`{...?properties, PostHogPropertyName.screenName: screenName}`) is safe for typical callers but
  changes observable behavior for any caller currently relying on `properties['$screen_name']`
  overriding the argument; call out in a changelog.
- **Remediation:** Apply the explicit `screenName` argument after merging caller `properties`, not
  before, mirroring `capture()`'s existing pattern.

### n31 — Session Replay Privacy (🟡 Partial)
- **Spec requires:** elements explicitly tagged no-capture MUST be excluded from replay output;
  password-field masking precedence should be consistent; masking must fail closed.
- **SDK currently:** Flutter's own Dart-side replay pipeline (`lib/src/replay/`) is a substantial,
  independent implementation (screenshot capture + element-tree masking, not a pass-through) with
  several concrete gaps: (1) **no no-capture marker exists at all** — exhaustive grep for
  `no.?capture`/`PostHogNoCapture` returns zero hits; `posthog_mask_widget.dart:28-59` only supports
  masking, not full exclusion from the captured tree. (2) **no general unmask primitive** for
  text/image content — grep for "unmask" finds only doc comments about disabling global masking;
  `PostHogPlatformView`'s privacy override (`posthog_platform_view.dart:42-54`) is limited to
  embedded platform views/webviews, not general content. (3) **password-field detection is
  inconsistent between the two internal parsing paths**: `element_data.dart:44-61` masks an
  obscured `TextField` unconditionally, while `element_object_parser.dart:38-65` only masks it when
  `maskAllTexts` is `false` (line 55: `shouldMask = !maskAllTexts && isObscured`) — and neither path
  recognizes `TextFormField.obscureText` (documented in-code as inaccessible from the widget,
  `element_object_parser.dart:49-54`), so an obscured `TextFormField` with `maskAllTexts=false` can
  go unmasked. (4) a soft fail-closed gap: `screenshot_capturer.dart:580-597` — a mid-capture
  element-walk failure only skips *drawing* masks, not *sending* the screenshot, a plausible
  unmasked-screenshot-delivery path less strict than the web canvas masking path's explicit
  skip-the-frame discipline (`web_canvas_mask_provider.dart:646-649`). Full-subtree traversal and
  the majority of fail-closed behavior (`posthog_mask_controller.dart:59-131`) are otherwise
  correctly implemented.
- **Backwards compatibility:** Backward-compatible for adding no-capture/unmask primitives (net-new
  API). Backward-compatible for the password/`TextFormField` fix and the mid-capture-failure-abort
  fix (both narrow currently-unmasked edge cases without a signature change).
- **Remediation:** Add a no-capture marker and general unmask primitive; align the two internal
  parsing paths' password-detection logic; make a mid-capture failure abort the send, not just the
  mask-drawing step.

### n32 — Set Person Properties (🟡 Partial)
- **Spec requires:** calling with both property maps null/empty should be a no-op (no event/call
  emitted).
- **SDK currently:** `Posthog().setPersonProperties(...)` (`posthog.dart:169-176`) and
  `PosthogFlutterIO.setPersonProperties` (`posthog_flutter_io.dart:264-289`) forward directly to the
  method channel with no Dart-side guard — when both maps are null, the Dart layer still calls
  `invokeMethod('setPersonProperties', {})` with an empty arguments map rather than short-circuiting
  before the channel call. Whether the native SDK itself then no-ops on empty input is unverifiable
  from this repo, though posthog-android's own compliance doc marks the equivalent contract ✅,
  suggesting the end-to-end behavior is probably fine — but the Dart wrapper's own defensive guard is
  simply missing, unlike the closely related `setPersonPropertiesForFlags`
  (`posthog.dart:462-464`, which does have `if (userProperties.isEmpty) return;`).
- **Backwards compatibility:** Backward-compatible — adding an early-return when both maps are
  null/empty is purely additive and matches the pattern already used by the sibling
  `setPersonPropertiesForFlags` method in the same file.
- **Remediation:** Add the same empty-input no-op guard used elsewhere in the file.

### n33 — Setup (🟡 Partial)
- **Spec requires:** (implied lifecycle hygiene) re-initialization should be handled gracefully —
  either idempotent or explicitly warned/deduplicated.
- **SDK currently:** No double-init guard exists anywhere in the Dart/plugin bridging layer —
  repeated `Posthog().setup()` calls unconditionally re-run `_installFlutterIntegrations` and
  re-invoke native `setup` (`posthog.dart:61-95`); Android's `PosthogFlutterPlugin.kt` `setup()`
  method has no already-initialized check of its own either. Whether the embedded native SDKs
  themselves no-op or warn on repeat setup is unverifiable from this repo — this is a real
  Dart-layer gap regardless, since Flutter's error-tracking auto-capture integration re-installs
  itself on every call.
- **Backwards compatibility:** Backward-compatible — adding an idempotency guard (or at least a
  debug warning) around repeated `setup()` calls is additive and only changes today's
  unconditional-reinstall behavior, which was likely never intentionally relied upon.
- **Remediation:** Track whether `setup()` has already run and warn or no-op on a second call,
  consistent with how other lifecycle methods (e.g., `close()`) treat instance state.

### n34 — Shutdown (❌ Fail)
- **Spec requires:** `shutdown`/`close()` SHALL flush pending events before tearing down so queued
  data is not lost (spec's Behavior item 2, "Flush pending events. Attempt to send queued events
  immediately before tearing down workers/queues").
- **SDK currently:** `Posthog().close()` (`posthog.dart:844-854`) never calls `flush()` before
  delegating — it clears Dart-side state (`_config`, `_currentScreen`,
  `PostHogInternalEvents.sessionRecordingActive`) and calls `_posthog.close()` directly.
  `PosthogFlutterIO.close()` (`posthog_flutter_io.dart:836-846`) sends only
  `invokeMethod('close')` with no preceding flush call. On Web, `close` is explicitly a no-op
  (`posthog_flutter_web_handler.dart:372-375`, `// not supported on Web`) — calling
  `Posthog().close()` on Flutter Web does nothing at all, not even a best-effort delegated close.
  This compounds a matching, independently-confirmed gap in the embedded native SDK: per
  `compliance/posthog-android.md` (n12), `PostHog.close()` on Android also never calls `flush()`
  internally — so on Android the gap exists at both the Dart wrapper level and the native SDK
  level, meaning there is no point in the pipeline where a flush is guaranteed before teardown.
- **Backwards compatibility:** Backward-compatible — adding `await _posthog.flush();` before
  `_posthog.close()` in `PosthogFlutterIO.close()` is purely additive; no signature change, and it
  only makes shutdown actually deliver pending events as specified. The Web no-op could also be
  upgraded to at least attempt a best-effort close.
- **Remediation:** Call `flush()` (bounded by a reasonable timeout) before invoking native `close()`
  in the Dart layer; consider giving Flutter Web's `close` a real (if partial) implementation
  instead of a bare no-op.

### n35 — Start Session Recording (🟡 Partial)
- **Spec requires:** session recording should remain inactive (or fail visibly) while opted out, and
  the SDK's own local state should reflect actual replay state.
- **SDK currently:** `startSessionRecording({resumeCurrent = true})` (`posthog.dart:871-874`)
  delegates correctly to native/web, but unconditionally sets
  `PostHogInternalEvents.sessionRecordingActive.value = true` immediately after the native call
  regardless of whether native actually started recording (e.g., if native silently refuses due to
  opt-out — a real, confirmed behavior pattern per the sibling posthog-android audit, n13). If
  native declines to start, Flutter's own mirrored state still flips to "active," and the Dart-side
  `ChangeDetector`/`ScreenshotCapturer` replay machinery begins running regardless — a Dart-layer
  inconsistency independent of whatever the native SDK itself does.
- **Backwards compatibility:** Backward-compatible — gating the local state flip on a success
  signal from native (or adding a Dart-side `isOptOut()` check before flipping it) is additive.
- **Remediation:** Only set `sessionRecordingActive.value = true` after confirming native actually
  started recording, or add a local `isOptOut()` guard.

### n36 — Stop Session Recording (🟡 Partial)
- **Spec requires:** stopping session recording should finalize/flush pending replay data rather
  than discard it.
- **SDK currently:** `stopSessionRecording()` (`posthog.dart:881-884`) delegates correctly and is
  idempotent, but `ScreenshotCapturer.cancel()` (`lib/src/replay/screenshot/screenshot_capturer.dart:90-92`
  and cancellation checks at lines 492-497, 523-530, 573-578) **discards** any in-flight frame
  (`completer.complete(null)`) rather than finishing and shipping it — contradicting the spirit of
  "finalize pending replay data" for Flutter's own capture pipeline specifically (native-side flush
  semantics on the native SDK's own side of `stopSessionReplay` are separately unverifiable from
  this repo).
- **Backwards compatibility:** Backward-compatible — awaiting a final in-flight frame's completion
  before cancelling is additive and only affects the tail latency of `stopSessionRecording()`, not
  its signature.
- **Remediation:** Let an in-flight capture finish and ship before tearing down the capturer, rather
  than discarding it on cancel.

### n37 — Surveys (🟡 Partial)
- **Spec requires:** per the `@client` acceptance scenario (`surveys.feature`), non-web/native SDKs
  MUST exclude surveys whose only display-targeting conditions are web-only (`url`/`selector`).
- **SDK currently:** Flutter has a rich, independent Dart-side survey-rendering UI
  (`lib/src/surveys/survey_service.dart`, `widgets/`) but implements **zero** eligibility filtering
  of its own — no active/date-window, device-type, seen-state, wait-period, linked-flag, or
  event-activation checks anywhere in `survey_service.dart`. Critically, the Dart survey model
  itself has **no `conditions`, `url`, or `selector` field at all**
  (`lib/src/surveys/models/posthog_display_survey.dart` — confirmed via full grep of the model
  directory); `PostHogFlutterSurveysDelegate.kt` (Android) and `PostHogDisplaySurvey+Dict.swift`
  (iOS) are pure serializers registered directly as the native SDK's own `surveysConfig.surveysDelegate`
  (`android/.../PosthogFlutterPlugin.kt:620-628`) — meaning native's own eligibility engine is the
  sole gate, and Flutter has no field or logic to catch a web-only-conditioned survey even if it
  tried. Per the sibling posthog-android audit (n25), the embedded native SDK's own eligibility
  engine has this exact url/selector gap, so the failure mode is inherited and additionally
  unfixable from the Dart side alone, since the Dart model doesn't even carry the relevant fields.
- **Backwards compatibility:** Needs deprecation path — adding a filter is additive to the API
  surface but a user-visible behavior change (some currently-shown inert surveys would stop
  displaying); requires adding a `conditions` field to the Dart model plus a filter step, and
  ideally fixing the same root cause upstream in the embedded native SDKs.
- **Remediation:** Add `conditions`/`url`/`selector` fields to the Dart survey model and filter
  out web-only-conditioned surveys before rendering; coordinate with the equivalent fix needed in
  posthog-android/posthog-ios.

### n38 — Traces (❌ Fail)
- **Spec requires:** OpenTelemetry-shaped span/trace capture (`startSpan`/`withSpan`/
  `getActiveSpan`/`beforeSpanSend`, OTLP `resourceSpans`/`scopeSpans` payload) shipped to `POST
  {host}/i/v1/traces`.
- **SDK currently:** Zero implementation anywhere in the repo. Exhaustive case-insensitive grep for
  `startSpan|withSpan|getActiveSpan|beforeSpanSend|resourceSpans|scopeSpans|maxLiveSpans|
  maxSpanAgeMs|/i/v1/traces` across all `.dart`, `.kt`, and `.swift` files returns zero matches. The
  only trace-adjacent surface is the `traceId`/`spanId`/`traceFlags` correlation fields on
  `captureLog` (`posthog.dart:285-287`), which the spec explicitly treats as distinct pass-through
  metadata, not a tracing API. This mirrors posthog-android's own independently-audited ❌ Fail
  (n26) — since Flutter embeds posthog-android/posthog-ios for native transport, the absence is
  consistent top-to-bottom: neither the underlying native SDKs nor the Dart layer implement any
  part of this capability.
- **Backwards compatibility:** Backward-compatible — the spec states tracing SHALL be off until a
  `traces` config is provided (pre-GA), so the entire surface is wholly new; nothing existing needs
  to change.
- **Remediation:** Net-new implementation, blocked upstream on posthog-android/posthog-ios shipping
  traces first, since Flutter is a thin pass-through wrapper with no independent OTLP/HTTP pipeline
  of its own to build this on top of directly.

### n39 — Tracing Headers (❌ Fail)
- **Spec requires:** applicability `both` (client injects W3C `traceparent`/distinct-id/session-id
  headers on outgoing HTTP requests; server extracts them).
- **SDK currently:** Exhaustive grep for `tracingHeaders|tracing_headers|X-POSTHOG-DISTINCT-ID|
  X-POSTHOG-SESSION-ID|traceparent` across all Dart/Kotlin/Swift files returns zero matches.
  Critically, `pubspec.yaml` confirms Flutter has **no Dart-side HTTP client dependency at all** —
  no `http`, `dio`, or `package:http` import anywhere under `lib/`. All of Flutter's own
  network-bound SDK operations go through the method channel to native code, not through Dart HTTP
  calls, so even though the embedded posthog-android SDK itself supports tracing headers (✅ per its
  own audit) for *its own* OkHttp-based traffic, that has no bearing on a Flutter *application's*
  own HTTP requests (made via the app's own `http`/`dio`/`HttpClient` usage), which never pass
  through posthog-android at all. `PostHogConfig` (946 lines, read in full) has no
  `tracingHeaders`/hostname-allowlist config field to even opt an app into this.
- **Backwards compatibility:** Backward-compatible — the spec requires this feature disabled by
  default with an explicit hostname allow-list, so the entire config surface and any HTTP
  interceptor would be wholly new; nothing existing changes.
- **Remediation:** Add a `tracingHeaders`/hostname-allowlist config option to `PostHogConfig`, plus
  a Dart-side HTTP client wrapper/interceptor (e.g. for `package:http`'s `Client` or `dio`
  interceptors) that a Flutter app would need to adopt explicitly, reading `getDistinctId()`/
  `getSessionId()` at request time — this is a Flutter-specific gap that the embedded native SDKs
  cannot solve on Flutter's behalf, since they never see the app's own HTTP traffic.
