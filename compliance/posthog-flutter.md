# posthog-flutter — SDK Compliance

**Repo:** [PostHog/posthog-flutter](https://github.com/PostHog/posthog-flutter)
**Audited commit:** `07ee92df803655cde3ca9fc8640144736318dc3d` ([commit](https://github.com/PostHog/posthog-flutter/commit/07ee92df803655cde3ca9fc8640144736318dc3d)) — audited on 2026-10-26
**Audited against sdk-specs commit:** `b865140e489c191e96e402d12b557d6a586afd0e`
**Summary:** 19 ✅ · 25 🟡 · 6 ❌ · 8 ➖ · 6 ❓

**Repo layout changed since the last audit.** At `05b53dc` (2026-08-06) posthog-flutter was a thin
Dart wrapper over the native posthog-android / posthog-ios / posthog-js SDKs, which is why eleven of
its rows were ❓ or ➖ — the contracted behavior lived in code this repo does not contain. The package
has since moved under `posthog_flutter/` and grown a **first-party Dart implementation** at
`posthog_flutter/lib/src/core/` (`posthog_core.dart`, `posthog_core_stateless.dart`,
`feature_flags.dart`, `session_manager.dart`, `persistence.dart`, `file_storage.dart`, `uuid.dart`)
used for the new Windows/Linux desktop target, plus Dart-side surveys (`lib/src/surveys/`), error
tracking (`lib/src/error_tracking/`), replay (`lib/src/replay/`) and logs (`lib/src/logs/`).

That matters for how this file should be read: several contracts now have **two** implementations
behind one public Dart API — the native SDK on Android/iOS/Web, and the Dart core on desktop. This
run audited the Dart core only where the spec delta pointed at it (Capture, Session Replay Debug
Properties, Exception Event Metadata, Setup). The six rows that were ❓ because behavior was
unverifiable from this repo (Event Batcher, Feature Flag Called Tracker, HTTP Client, Persistent
Storage, Remote Config, Retry Queue) **stay ❓**: they are now partly verifiable here, but auditing
the new desktop core properly needs its own pass rather than a verdict inferred from a skim. That
pass is queued — see `compliance/README.md`.

**Scope of this run (2026-10-26):** a targeted re-audit of the rows the sdk-specs delta since
`75c8f5d` lands on, every prior ❌/❓ row, and the five contracts that had no row at all. Other rows
carry their 2026-08-06 verdict forward.

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Alias | 🟡 | [n1] |
| 2 | Application Lifecycle | ✅ |  |
| 3 | Autocapture | 🟡 | [n2] |
| 4 | Before Send Hook | 🟡 | [n3] |
| 5 | Bootstrap | 🟡 | [n4] |
| 6 | Capture | 🟡 | [n5] |
| 7 | Capture AI | ➖ | [n6] |
| 8 | Capture Exception | 🟡 | [n7] |
| 9 | Consent Gating | 🟡 | [n8] |
| 10 | Create Person Profile | ➖ | [n9] |
| 11 | Debug | 🟡 | [n10] |
| 12 | Device ID Generator | ➖ | [n11] |
| 13 | Evaluate Flags | ➖ | [n12] |
| 14 | Event Batcher | ❓ | [n13] |
| 15 | Exception Event Metadata | ❌ | [n14] |
| 16 | Exception Steps | ✅ |  |
| 17 | Feature Flag Cache | ✅ |  |
| 18 | Feature Flag Called Tracker | ❓ | [n15] |
| 19 | Flag Definition Loader | ➖ | [n16] |
| 20 | Flush | 🟡 | [n17] |
| 21 | Get Anonymous ID | ❌ | [n18] |
| 22 | Get Distinct ID | ✅ |  |
| 23 | Get Feature Flag | 🟡 | [n19] |
| 24 | Get Feature Flag Payload | ✅ |  |
| 25 | Get Feature Flag Result | ✅ |  |
| 26 | Get Feature Flags | ❌ | [n20] |
| 27 | Get Feature Flags And Payloads | ❌ | [n21] |
| 28 | Get Session ID | ✅ |  |
| 29 | Group | 🟡 | [n22] |
| 30 | Group Identify | ➖ | [n23] |
| 31 | HTTP Client | ❓ | [n24] |
| 32 | Identify | ✅ |  |
| 33 | Is Feature Enabled | 🟡 | [n25] |
| 34 | Is Opt Out | ✅ |  |
| 35 | Is Session Replay Active | ✅ |  |
| 36 | Local Feature Flag Evaluator | ➖ | [n26] |
| 37 | Logs | 🟡 | [n27] |
| 38 | MCP Analytics | ➖ | [n28] |
| 39 | On Feature Flags | 🟡 | [n29] |
| 40 | Opt In | 🟡 | [n30] |
| 41 | Persistent Storage | ❓ | [n31] |
| 42 | Register | 🟡 | [n32] |
| 43 | Reload Feature Flags | ✅ |  |
| 44 | Remote Config | ❓ | [n33] |
| 45 | Reset | ✅ |  |
| 46 | Reset Group Properties For Flags | ✅ |  |
| 47 | Reset Person Properties For Flags | ✅ |  |
| 48 | Retry Queue | ❓ | [n34] |
| 49 | Screen | 🟡 | [n35] |
| 50 | Session Manager | ✅ |  |
| 51 | Session Replay Debug Properties | 🟡 | [n36] |
| 52 | Session Replay Ingestion Controls | ✅ |  |
| 53 | Session Replay Privacy | 🟡 | [n37] |
| 54 | Set Group Properties For Flags | ✅ |  |
| 55 | Set Person Properties | 🟡 | [n38] |
| 56 | Set Person Properties For Flags | ✅ |  |
| 57 | Setup | 🟡 | [n39] |
| 58 | Shutdown | 🟡 | [n40] |
| 59 | Start Session Recording | 🟡 | [n41] |
| 60 | Stop Session Recording | 🟡 | [n42] |
| 61 | Surveys | 🟡 | [n43] |
| 62 | Traces | ❌ | [n44] |
| 63 | Tracing Headers | ❌ | [n45] |
| 64 | Unregister | ✅ |  |

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

### n5 — Capture (🟡 Partial)
- **Spec requires:** (spec change #114, `a86f68e`) "Caller-supplied event properties take precedence" —
  on a client SDK a property the caller passes on an event SHALL win over a registered (super)
  property **and over an SDK context property of the same key**, naming `$lib`, `$lib_version`, `$os`,
  `$app_version`, `$screen_width`, `$current_url`, `$screen_name`, `$feature/<key>` and
  `$active_feature_flags` explicitly. Only `$is_identified`, `$process_person_profile`, session ids,
  the replay debug keys and `$geoip_disable` may be set after the caller's properties.
- **SDK currently:** the native platforms are fine — posthog-android merges the caller last
  (`PostHog.kt:819-821`), and posthog-ios likewise. The **desktop Dart core inverts the order**:
  `PostHogCore._enrichProperties`
  (`posthog_flutter/lib/src/core/posthog_core.dart:141-161`) builds
  `{...props, ..._sessionProps, ...?properties, ...getContextProperties(), $timezone,
  ...getCommonEventProperties(), $session_id, ...}` — the SDK context and the common properties
  (`$lib`, `$lib_version`, …) are spread **after** the caller's `properties` and therefore overwrite
  them. The inversion is deliberate and documented: the `getContextProperties()` doc comment at
  `:122-125` states "It wins over registered and event properties of the same name: it describes the
  environment the SDK runs in." That was a defensible reading before #114; the merged requirement now
  says the opposite for client SDKs.
- **Backwards compatibility:** Needs deprecation path — the SDK's own documentation currently promises
  the opposite precedence, so flipping it is a documented, user-visible behavior change that needs a
  changelog entry even though the vast majority of callers never collide with a context key.
- **Remediation:** In `_enrichProperties`, spread `getContextProperties()`, `$timezone` and
  `getCommonEventProperties()` **before** `...?properties`, leaving `$session_id`,
  `$process_person_profile`, `$is_identified` and the debug block after it, and update the
  `getContextProperties()` doc comment.

### n6 — Capture AI (➖ N/A)
- **Spec requires:** an isolated `capture_ai` route to PostHog's AI ingestion endpoint.
- **SDK currently:** out of scope — `openspec/specs/capture-ai/spec.md` scopes the capability
  `server` and names only posthog-python and posthog-node. posthog-flutter is a client SDK and ships
  no `$ai_*` surface.
- **Backwards compatibility:** N/A — no remediation required per spec scope.

### n7 — Capture Exception (🟡 Partial)
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

### n8 — Consent Gating (🟡 Partial)
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

### n9 — Create Person Profile (➖ N/A)
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

### n10 — Debug (🟡 Partial)
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

### n11 — Device ID Generator (➖ N/A)
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

### n12 — Evaluate Flags (➖ N/A)
- **Spec requires:** a server-side `evaluateFlags(...)` snapshot API.
- **SDK currently:** out of scope — the spec states the capability "applies to server SDKs" and that
  client-side ambient-cache reads remain governed by `is-feature-enabled`. posthog-flutter has no
  server surface.
- **Backwards compatibility:** N/A — no remediation required per spec scope.

### n13 — Event Batcher (❓ Unknown)
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

### n14 — Exception Event Metadata (❌ Fail)
- **Spec requires:** `both` applicability. Canonical tree linkage via `mechanism.exception_id` /
  `parent_id`; every nested entry carries `type: "chained"` plus `mechanism.source` naming the parent
  edge; nested entries do **not** inherit the outermost `handled`; unknown `synthetic` is omitted
  rather than serialized as `false`; `mechanism.type` on the outermost entry uses a canonical capture
  category (`generic`, `onuncaughtexception`, `onunhandledrejection`, …) with the concrete integration
  named in event-level `$exception_source`; at most 50 entries; and `$exception_level` derived from a
  boundary default or a recognized source severity.
- **SDK currently:** `DartExceptionProcessor`
  (`posthog_flutter/lib/src/error_tracking/dart_exception_processor.dart`) is the Dart-side producer
  for every platform. Five contradictions:
  1. **No linkage at all.** Neither `exception_id` nor `parent_id` is ever emitted — the primary entry
     (`:80-88`) and each cause entry (`:174-182`) build a three-key mechanism of
     `{handled, synthetic, type}`. Without `exception_id` the event cannot express the tree the spec
     defines.
  2. **Nested entries inherit the outermost `handled` and `type`.** `_appendCauses` is passed the
     primary `handled` and `mechanismType` and stamps both onto every cause (`:106-117`, `:163-182`),
     where the spec requires `type: "chained"`, `source: "cause"`, and an omitted `handled` unless the
     runtime supplies an independent disposition.
  3. **`mechanism.source` is never emitted**, so the parent-edge relationship is unrepresented.
  4. **Non-canonical outermost `mechanism.type`.** The autocapture integration passes
     `PostHogException(mechanism: 'FlutterError' | 'PlatformDispatcher' | 'isolateError')`
     (`posthog_error_tracking_autocapture_integration.dart:165`, `:206`, `:239`). The spec says
     technology-specific integration identity belongs in `$exception_source`, not in `mechanism.type`,
     when a common semantic category describes the boundary — and `$exception_source` is never set
     anywhere in the repo.
  5. **`$exception_level` is the hardcoded literal `'error'`** (`:123`, commented "Never crashes, so
     always error") on every path, including the isolate/`PlatformDispatcher` boundaries where the
     failure did escape application code.
  Separately, the chain is capped at `maxExceptionChainLength = 10` (`:20`) rather than the spec's 50,
  and there is no aggregate-member inspection budget. Cycle detection via a `seen` set (`:170`) is
  correct, and `synthetic` on the primary entry is at least *derived* (`:74-79`) rather than constant,
  though it is always serialized even when provenance is unknown.
- **Backwards compatibility:** Backward-compatible — every item is producer-side serialization inside
  `dart_exception_processor.dart` and the autocapture integration's mechanism strings. The public
  `PostHogException` type would gain fields, not change meaning.
- **Remediation:** Assign `exception_id` depth-first from `0` with `parent_id` on nested entries; set
  nested `type` to `chained` and `source` to `cause`; stop copying `handled` down the chain; move
  `FlutterError`/`PlatformDispatcher`/`isolateError` out of `mechanism.type` into `$exception_source`
  (as `flutter.flutter_error`, `flutter.platform_dispatcher`, `flutter.isolate_error`) and use the
  canonical categories for `type`; derive `$exception_level` per boundary; and raise the chain cap to
  50.

### n15 — Feature Flag Called Tracker (❓ Unknown)
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

### n16 — Flag Definition Loader (➖ N/A)
- **Spec requires:** ETag-based polling of flag definitions for local evaluation, requiring a
  personal/admin API key.
- **SDK currently:** The spec's own Applicability section names Flutter explicitly: "Some client
  wrappers, such as Flutter, expose ordinary feature-flag preload settings without owning a
  separate local-evaluation definition loader." Confirmed: `PostHogConfig` has `preloadFeatureFlags`
  (`posthog_config.dart:139`) and no `personalApiKey`/ETag/poll-interval fields anywhere in the
  file; no `LocalEvaluationPoller`-equivalent exists in `lib/`, `android/`, or `darwin/`.
- **Backwards compatibility:** N/A — justified directly by the spec's own text naming Flutter as an
  example of the excluded wrapper pattern.

### n17 — Flush (🟡 Partial)
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

### n18 — Get Anonymous ID (❌ Fail)
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

### n19 — Get Feature Flag (🟡 Partial)
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

### n20 — Get Feature Flags (❌ Fail)
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

### n21 — Get Feature Flags And Payloads (❌ Fail)
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

### n22 — Group (🟡 Partial)
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

### n23 — Group Identify (➖ N/A)
- **Spec requires:** the spec's own documented client-side variant: "iOS/Android/Unity: no
  standalone public `groupIdentify` in the audited client SDKs; `group(...)` emits `$groupidentify`
  internally."
- **SDK currently:** Flutter has no standalone public `groupIdentify` method (confirmed via grep
  across `posthog.dart` and `posthog_flutter_platform_interface.dart`) — `group()` is the sole
  public entry point and internally triggers `$groupidentify` natively, matching the exact pattern
  the spec documents as acceptable for mobile-style client SDKs.
- **Backwards compatibility:** N/A — no remediation required per spec's own documented carve-out.

### n24 — HTTP Client (❓ Unknown)
- **Missing evidence:** Flutter has no Dart-side HTTP client dependency at all for the SDK's own
  event/flag/log traffic (confirmed via full read of `pubspec.yaml` — no `http`, `dio`, or
  `package:http` import anywhere under `lib/`). All network-bound SDK operations are delegated
  through the method channel to the native SDKs (or to posthog-js on web), whose HTTP client
  internals (connection reuse, compression, timeout handling, gzip) are not inspectable from this
  repo.
- **Remediation:** N/A (nothing to fix in this repo for the SDK's own transport); would require
  reviewing the resolved posthog-android/posthog-ios/posthog-js versions directly.

### n25 — Is Feature Enabled (🟡 Partial)
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

### n26 — Local Feature Flag Evaluator (➖ N/A)
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

### n27 — Logs (🟡 Partial)
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

### n28 — MCP Analytics (➖ N/A)
- **Spec requires:** an add-on package emitting the `$mcp_*` event family.
- **SDK currently:** out of scope — applicability is `server`, and the spec's package table lists only
  posthog-js, posthog-python, posthog-go and posthog-ruby ("not yet"). posthog-flutter is not listed
  and ships no MCP package.
- **Backwards compatibility:** N/A — no remediation required per spec scope.

### n29 — On Feature Flags (🟡 Partial)
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

### n30 — Opt In (🟡 Partial)
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

### n31 — Persistent Storage (❓ Unknown)
- **Missing evidence:** storage-failure handling (must not crash SDK calls, must log a storage
  warning) is implemented entirely inside the embedded native SDKs or posthog-js — Flutter's Dart
  layer owns no persistent storage of its own for capture/identity/flag state (confirmed no
  `SharedPreferences`/`NSUserDefaults`/local-file usage for SDK state in `lib/`, only for
  Dart-widget-local concerns unrelated to this contract). This repo cannot verify the storage-write
  failure path inside the native SDKs.
- **Remediation:** N/A (nothing to fix in this repo); posthog-android's own audit already found a
  gap here (n22) which may or may not still be present in whatever version a given Flutter app
  resolves.

### n32 — Register (🟡 Partial)
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

### n33 — Remote Config (❓ Unknown)
- **Missing evidence:** remote-config fetch/caching/gating mechanics live entirely inside the
  embedded native SDKs or posthog-js. Flutter's Dart layer only plumbs a handful of related config
  values (e.g. `sessionReplay`, `surveys`, feature-flag toggles) through to native `setup()` — there
  is no independent Dart-side remote-config client, cache, or gating logic to inspect.
- **Remediation:** N/A (nothing to fix in this repo); would require reviewing the resolved native
  SDK versions directly.

### n34 — Retry Queue (❓ Unknown)
- **Missing evidence:** retry/backoff mechanics for failed network sends live entirely inside the
  embedded native SDKs or posthog-js — no independent Dart-side retry queue, backoff algorithm, or
  batch-halving logic exists in `lib/` (confirmed via the same grep sweep used for Event Batcher and
  HTTP Client). Not inspectable from this repo.
- **Remediation:** N/A (nothing to fix in this repo).

### n35 — Screen (🟡 Partial)
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

### n36 — Session Replay Debug Properties (🟡 Partial)
- **Spec requires:** two tiers. The *required keys* (`$recording_status`,
  `$sdk_debug_replay_event_trigger_status`, `$sdk_debug_replay_linked_flag_trigger_status`,
  `$sdk_debug_replay_internal_buffer_length`) go on every captured event except `$snapshot`; a mobile
  SDK with no replay integration produces only `$recording_status: disabled`. Everything else is the
  *optional replay debug bundle*, which attaches only to eligible SDK events and only once per
  30-second throttle window. The queue-depth key has its own requirement. The minimal
  `$feature_flag_called` envelope strips `$recording_status` and every `$sdk_debug_*` key.
- **SDK currently:** split verdict.
  - On Android/iOS/Web the native SDK owns these properties; posthog-android now implements the full
    two-tier split (see [posthog-android.md](posthog-android.md)), so the wrapper inherits a
    conforming implementation there.
  - On the **desktop Dart core** the split is not implemented. `_enrichProperties`
    (`posthog_flutter/lib/src/core/posthog_core.dart:141-161`) unconditionally spreads
    `_sessionDebugProperties(now)` into **every** event, and that map (`:165-176`) is
    `{$sdk_debug_session_start, $sdk_debug_current_session_duration, $sdk_debug_pending_queue_size}`.
    `$sdk_debug_session_start` is an *optional-bundle* key by the spec's own enumeration, so it must
    be gated to eligible SDK events and throttled to once per 30 seconds; here it rides every custom
    event with no gate and no throttle. There is no `$snapshot` exclusion in the Dart path either.
  - What is correct on desktop: `PostHogDesktopClient` emits `$recording_status: 'disabled'`
    (`lib/src/posthog_desktop_client.dart:41`), which is exactly the "disabled shape" the spec
    prescribes for a platform with no replay integration, and the minimal `$feature_flag_called`
    envelope is rebuilt from an explicit allowlist after all SDK properties are merged
    (`lib/src/core/posthog_core_stateless.dart:228-237`), so the strip requirement holds.
- **Backwards compatibility:** Backward-compatible — gating and throttling keys that are already being
  sent only reduces payload; no public API changes.
- **Remediation:** In the Dart core, move `$sdk_debug_session_start` and
  `$sdk_debug_current_session_duration` behind the same eligible-event + 30-second-claim gate
  posthog-android and `@posthog/core` use, keep `$sdk_debug_pending_queue_size` on its own
  requirement, and skip the whole block for `$snapshot`.

### n37 — Session Replay Privacy (🟡 Partial)
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

### n38 — Set Person Properties (🟡 Partial)
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

### n39 — Setup (🟡 Partial)
- **Spec requires:** (spec change #108, `c2f09c1`) the project credential option SHALL be named
  `projectToken`, with any surviving `apiKey` spelling kept as a deprecated alias resolving to the same
  value and `projectToken` winning where both are accepted. Plus the pre-existing lifecycle hygiene
  expectation that re-initialization is idempotent or warned.
- **SDK currently:** the rename is **done and correct** — `PostHogConfig(String projectToken, …)` is
  positional and trimmed (`posthog_flutter/lib/src/posthog_config.dart:429-432`), `apiKey` survives as
  a `@Deprecated('Deprecated in favor of [projectToken]. This will be removed in the next major
  version.')` getter returning the same value (`:102-109`), and the platform-channel map carries both
  names so older native shims keep working (`:445-446`). A blank-token guard now also short-circuits
  `setup()` with a log (`lib/src/posthog.dart:70-76`). The residual gap is the one from the previous
  audit: there is still **no double-init guard** — a second `Posthog().setup()` unconditionally
  re-runs `_installFlutterIntegrations` and re-invokes the native `setup`
  (`lib/src/posthog.dart:70-99`). The harm is narrower than it was, because
  `_installFlutterIntegrations` now calls `_uninstallFlutterIntegrations()` first (`:102-104`) so the
  error-tracking integration no longer stacks, but the native side is still re-entered with no
  already-initialized check.
- **Backwards compatibility:** Backward-compatible — adding an idempotency guard or a debug warning is
  additive.
- **Remediation:** Track whether `setup()` has already run and warn or no-op on a second call.

### n40 — Shutdown (🟡 Partial)
- **Spec requires:** shutdown SHALL flush pending events before tearing down so queued data is not lost.
- **SDK currently:** improved but not closed. `Posthog().close()`
  (`posthog_flutter/lib/src/posthog.dart:927-942`) tears down the Dart-side integrations and delegates
  to the platform. On Android the delegate now flushes: posthog-android's `close()` calls `flush()`
  before stopping its queues (`PostHog.kt:619-620`), which was the original ❌. On
  **Windows/Linux** the Dart core makes "one attempt to send the queued events and waits for it for up
  to two seconds" (documented at `posthog.dart:920-926`), so events can still be stranded when that
  attempt times out — and when the application-support directory is unavailable the in-memory state is
  lost outright. iOS/Web were not re-verified this run.
- **Backwards compatibility:** Backward-compatible — making the desktop shutdown drain fully (or
  persist what it could not send) is additive.
- **Remediation:** On desktop, persist the unsent queue when the bounded flush attempt does not drain
  it, so the next `setup()` picks it up rather than relying on an in-memory buffer.

### n41 — Start Session Recording (🟡 Partial)
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

### n42 — Stop Session Recording (🟡 Partial)
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

### n43 — Surveys (🟡 Partial)
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

- **New gap found 2026-10-26 (spec change #93, `f238b16`):** "Surveys with undisplayable questions are
  not shown" explicitly binds wrappers — "SDKs that delegate display to a host UI layer (custom,
  wrapper, or framework-native renderers) SHALL apply the check on the shared path that feeds those
  renderers rather than in each renderer." posthog-flutter is exactly that case: the Dart layer renders
  display models (`posthog_flutter/lib/src/surveys/models/`, five supported question types) that the
  native SDK hands it, and neither side gates on question type — posthog-android's
  `getActiveMatchingSurveys` has no question-type filter (see
  [posthog-android.md](posthog-android.md)), and `survey_service.dart` adds none. A survey carrying a
  question type newer than the SDK is therefore partially displayed. **Backwards compatibility:**
  Backward-compatible. **Remediation:** Gate on the shared path that feeds the Dart renderers (and fix
  the underlying native filter), skipping the whole survey without writing a seen key.

### n44 — Traces (❌ Fail)
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

- **Re-verified 2026-10-26:** still no implementation. Unlike the `@posthog/core` family, which now
  ships a complete OTLP traces manager that posthog-node consumes, there is no span surface in
  `posthog_flutter/lib/` at all — the only `trace` references are the `traceId`/`spanId`/`traceFlags`
  passthrough parameters on `captureLog` (`lib/src/posthog.dart:277-281`), which correlate a log with
  a trace produced elsewhere rather than producing one.

### n45 — Tracing Headers (❌ Fail)
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

## Changes this run (2026-10-26)

| Contract | Was | Now | Why |
|---|---|---|---|
| Capture | ✅ | 🟡 | Downgraded on **new spec text**, not new code: spec change #114 made caller-supplied properties win over SDK context properties on client SDKs, and the desktop Dart core documents and implements the opposite order. See n for Capture. |
| Shutdown | ❌ | 🟡 | The underlying posthog-android `close()` now flushes, closing the original failure on the largest platform; the desktop path's bounded two-second attempt keeps this short of ✅. |
| Setup | 🟡 | 🟡 | Status unchanged but the reason narrowed: the `projectToken` rename (spec change #108) is fully implemented with a deprecated `apiKey` alias, and a blank-token guard was added. Only the double-init guard is still missing. |
| Exception Event Metadata | — | ❌ | New row. No tree linkage, inherited `handled`/`type` on causes, no `mechanism.source`, non-canonical mechanism categories with no `$exception_source`, hardcoded `$exception_level`, chain cap of 10 instead of 50. |
| Session Replay Debug Properties | — | 🟡 | New row. Native platforms inherit posthog-android's conforming two-tier split; the desktop Dart core sends optional-bundle keys on every event with no eligibility gate and no 30-second throttle. |
| Capture AI / Evaluate Flags / MCP Analytics | — | ➖ | New rows, all three server-scoped by their own applicability sections. |

Rows re-verified and left unchanged: Surveys (🟡, new undisplayable-question gap added to the note),
Traces (❌), Get Anonymous ID / Get Feature Flags / Get Feature Flags And Payloads (❌ — still absent
from the Dart API; `posthog_config.dart:417` still carries the standing `// TODO: missing
getAnonymousId`).

**Not re-verified this run, and why it matters:** the six ❓ rows (Event Batcher, Feature Flag Called
Tracker, HTTP Client, Persistent Storage, Remote Config, Retry Queue) were Unknown because the
behavior lived in native code outside this repo. That is now only half true — the desktop Dart core
implements all six — so these are no longer "unverifiable", merely unaudited. They are the single
largest block of unresolved cells in this matrix and are queued for a dedicated desktop-core pass.
