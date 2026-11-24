# posthog-kmp — SDK Compliance

**Repo:** [PostHog/posthog-kmp](https://github.com/PostHog/posthog-kmp)
**Audited commit:** `0a88aa7490c4bc51fb263c7f3619d62d838658a4` ([commit](https://github.com/PostHog/posthog-kmp/commit/0a88aa7490c4bc51fb263c7f3619d62d838658a4)), tag `1.0.0` — first audit, 2026-11-23
**Audited against sdk-specs commit:** `795b69f`; re-checked at `44fe27a`, whose one later spec change (#233, local flag evaluation) is server-only and moves no row
**Summary:** 16 ✅ · 35 🟡 · 8 ❌ · 11 ➖ · 0 ❓ (70 rows; first audit). On the shared 69-row basis (without Get Remote Config Payload, ➖): 16 ✅ · 35 🟡 · 8 ❌ · 10 ➖.

**Why this run:** posthog-kmp has no compliance file yet. 1.0.0 is its first stable release.

**Row count.** The root `README.md` table at `795b69f` lists **70** capabilities: Get Remote Config Payload
(sdk-specs #220) joined after the 69-row files were written. It is "Server SDKs only" and is ➖ here.

**Scope.** posthog-kmp is a Kotlin Multiplatform facade. Its own code is the public API in
`commonMain` (`posthog-kmp/src/commonMain/kotlin/com/posthog/kmp/PostHog.kt`, `PostHogConfig.kt`,
`PostHogModels.kt`, `PostHogBeforeSend.kt`), plus one bridge per target that maps config, converts
values and forwards each call. Every row was scored on what KMP owns — API shape, config forwarding,
type conversion across the bridge, Kotlin exception capture, `$lib`/`$lib_version`, and logic in
`commonMain` — and otherwise inherits the delegate's status from `compliance/posthog-android.md`,
`compliance/posthog-ios.md` and `compliance/posthog-js.md`. Native behaviour that changed was checked
in posthog-android at `android-v4.0.2`/`core-v7.0.2` and posthog-ios at `4.0.3` (the pinned versions)
with `git show`, and posthog-js at the installed `1.435.8` package. Paths below are relative to
`posthog-kmp/src/` unless they start with `gradle/`.

## Platforms

| Target | Implementation | Delegate (pinned at 1.0.0) |
|---|---|---|
| Android | `androidMain` + shared `jvmCommonMain` → `PostHogAndroid.with(application, config)` (`androidMain/.../PostHog.android.kt:15-68`) | posthog-android **4.0.2** (`gradle/libs.versions.toml:9`, Gradle may resolve higher) |
| JVM (desktop/server process) | `jvmMain` + `jvmCommonMain` → `com.posthog.PostHog.with(coreConfig)` with KMP-owned file preferences, queue paths and device context (`jvmMain/.../PostHog.jvm.kt:24-65`, `PostHogFilePreferences.kt`, `PostHogJvmContext.kt`) | posthog-android's pure-JVM core `com.posthog:posthog` **7.0.2** (`gradle/libs.versions.toml:12`) |
| iOS (x64, arm64, simulator arm64), macOS arm64 | `appleMain` → `PostHogSDK.shared` via SwiftPM interop (`appleMain/.../PostHog.apple.kt:47-92`); booleans rebuilt as `CFBoolean` (`NativeProperties.apple.kt`); Kotlin `Throwable` → `NSException` (`KotlinThrowableNSException.kt`) | posthog-ios **4.0.3**, pinned `exact` (`gradle/libs.versions.toml:14`, `posthog-kmp/build.gradle.kts:80`) |
| JS (browser + Node), Wasm/JS (browser) | `jsMain` (`dynamic`) and `wasmJsMain` (`external interface PostHogJsApi`) → `posthog.init(...)` | posthog-js **1.435.8** npm (`gradle/libs.versions.toml:15`); not on capture v1 |

JVM rows inherit posthog-android's core behaviour (`compliance/posthog-android.md`) except where KMP
replaces a piece (storage, context). macOS inherits posthog-ios minus replay, autocapture and
surveys, which KMP ignores there with a debug log (`macosArm64Main/.../PlatformCapture.macos.kt:8-15`).
Where the paths disagree, the row is 🟡 and the note says which path fails. A row is ❌ when KMP's
public API lacks the capability on every target.

`$lib`/`$lib_version` are `posthog-kmp` / `1.0.0` on every target: `sdkName`/`sdkVersion` on Android
and JVM (`androidMain/.../PostHog.android.kt:30-31`, `jvmMain/.../PostHog.jvm.kt:26-27`,
`PostHogJvmContext.kt:25-30`), `PostHogSDK.setSdkName` before setup on Apple
(`appleMain/.../PostHog.apple.kt:49`), `_overrideSDKInfo` after `init` on web
(`jsMain/.../PostHog.js.kt:76-79`, `wasmJsMain/.../PostHog.wasmJs.kt:39`).

## Matrix

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | AI Datasets | ➖ | server SDKs only |
| 2 | AI Scorers | ➖ | server SDKs only |
| 3 | Offline Evaluations | ➖ | server SDKs only |
| 4 | Logs | ❌ | [n1] KMP-owned |
| 5 | Traces | ❌ | [n2] |
| 6 | MCP Analytics | ➖ | `server` add-on package |
| 7 | Tracing Headers | ❌ | [n3] KMP-owned |
| 8 | Alias | 🟡 | [n4] |
| 9 | Bootstrap | ❌ | [n5] KMP-owned |
| 10 | Capture | 🟡 | [n6] KMP-owned + web |
| 11 | Capture AI | ✅ | [n7] |
| 12 | Capture Exception | 🟡 | [n8] KMP-owned |
| 13 | Create Person Profile | ➖ | Applicability: posthog-js family only; KMP has no such method |
| 14 | Debug | 🟡 | [n39] KMP-owned |
| 15 | Emails | ➖ | server SDKs only |
| 16 | Exception Steps | ❌ | [n9] KMP-owned |
| 17 | Flush | 🟡 | [n10] |
| 18 | Get Anonymous ID | ✅ | [n11] |
| 19 | Get Distinct ID | ✅ | |
| 20 | Get Feature Flag | ✅ | per-call `sendFeatureFlagEvent`, default from config (`commonMain/.../PostHog.kt:335-337`, `:612-614`) |
| 21 | Get Feature Flag Payload | 🟡 | [n12] |
| 22 | Get Feature Flag Result | 🟡 | [n12] |
| 23 | Get Feature Flags | 🟡 | [n13] |
| 24 | Get Feature Flags And Payloads | 🟡 | [n13] |
| 25 | Evaluate Flags | ➖ | server SDKs |
| 26 | Get Remote Config Payload | ➖ | **new row**: "Server SDKs only" (#220) |
| 27 | Get Session ID | 🟡 | [n14] |
| 28 | Group | 🟡 | [n15] |
| 29 | Group Identify | 🟡 | [n15] |
| 30 | Identify | ✅ | [n16] |
| 31 | Is Feature Enabled | ✅ | `isFeatureEnabled(key, defaultValue, sendFeatureFlagEvent)`; empty variant reads disabled on every path |
| 32 | Is Opt Out | ✅ | |
| 33 | Is Session Replay Active | ❌ | [n17] KMP-owned |
| 34 | On Feature Flags | 🟡 | [n41] JS/Wasm lose listeners across `close`/`setup` |
| 35 | Opt In | 🟡 | [n18] |
| 36 | Register | 🟡 | [n19] |
| 37 | Reload Feature Flags | ✅ | [n20] |
| 38 | Reset | 🟡 | [n21] |
| 39 | Reset Group Properties For Flags | 🟡 | [n22] |
| 40 | Reset Person Properties For Flags | ✅ | |
| 41 | Screen | ✅ | [n23] |
| 42 | Set Group Properties For Flags | ✅ | |
| 43 | Set Person Properties | 🟡 | [n40] KMP-owned (web) |
| 44 | Set Person Properties For Flags | ✅ | |
| 45 | Setup | 🟡 | [n24] KMP-owned |
| 46 | Shutdown | 🟡 | [n25] |
| 47 | Start Session Recording | ❌ | [n17] KMP-owned |
| 48 | Stop Session Recording | ❌ | [n17] KMP-owned |
| 49 | Unregister | ✅ | |
| 50 | Application Lifecycle | ✅ | [n26] |
| 51 | Autocapture | 🟡 | [n27] KMP-owned |
| 52 | Before Send Hook | ✅ | [n28] |
| 53 | Consent Gating | 🟡 | [n29] |
| 54 | Device ID Generator | ✅ | |
| 55 | Event Batcher | 🟡 | [n30] |
| 56 | Exception Event Metadata | 🟡 | [n31] |
| 57 | Experiment Exposure | ➖ | every delegate requests `/flags/?v=2` (posthog-android, posthog-ios per their files; posthog-js 1.435.8 `dist/module.js` `"/flags/?v=2"`) |
| 58 | Feature Flag Cache | 🟡 | [n12] (web) |
| 59 | Feature Flag Called Tracker | 🟡 | [n32] |
| 60 | Flag Definition Loader | ➖ | server SDKs |
| 61 | HTTP Client | 🟡 | [n33] |
| 62 | Local Feature Flag Evaluator | ➖ | server SDKs |
| 63 | Persistent Storage | 🟡 | [n34] KMP-owned (JVM) + inherited |
| 64 | Remote Config | 🟡 | [n33] |
| 65 | Retry Queue | 🟡 | [n33] |
| 66 | Session Manager | 🟡 | [n14] |
| 67 | Session Replay Debug Properties | 🟡 | [n35] |
| 68 | Session Replay Ingestion Controls | 🟡 | [n36] KMP-owned (web) + inherited |
| 69 | Session Replay Privacy | 🟡 | [n37] |
| 70 | Surveys | 🟡 | [n38] |

## Notes

<a id="n1"></a>

### n1 — Logs (❌ Fail)
- **Spec requires:** "The SDK SHALL expose two equivalent entry points: a `captureLog` method accepting a `body` …" (`openspec/specs/logs/spec.md`, Requirement: Public capture API).
- **SDK currently:** `PostHog` (`commonMain/.../PostHog.kt:30-603`) has no `captureLog` or logger facade, and `PostHogConfig` (`commonMain/.../PostHogConfig.kt:34-191`) has no logs options; `captureLogs` is the iOS/web replay console option. Both delegates already ship the pipeline (posthog-android ✅, posthog-ios 🟡 — `compliance/posthog-android.md`, `compliance/posthog-ios.md`), but `posthog-android` is an `implementation` dependency (`posthog-kmp/build.gradle.kts:130`), so apps can't reach it through KMP.
- **Backwards compatibility:** Additive.
- **Remediation:** Add `PostHog.captureLog(body, level, attributes)` and a `logs { }` config block forwarding to `PostHogConfig.logs` (Android/JVM) and posthog-ios's logs config; no-op with a debug log on JS/Wasm until posthog-js's logs API is wired.

<a id="n2"></a>

### n2 — Traces (❌ Fail)
- **Spec requires:** a span API (`startSpan`/`withSpan`) shipped as OTLP to `/i/v1/traces` (`openspec/specs/traces/spec.md`, Purpose).
- **SDK currently:** No span API in `commonMain/.../PostHog.kt:30-603`; no delegate implements it either (posthog-android n23, posthog-ios n2, posthog-js all ❌).
- **Backwards compatibility:** Additive.
- **Remediation:** Wait for the native implementations, then forward.

<a id="n3"></a>

### n3 — Tracing Headers (❌ Fail)
- **Spec requires:** "The SDK SHALL provide an opt-in way for client applications to inject PostHog tracing headers into outgoing requests to configured application backend hostnames." (`openspec/specs/tracing-headers/spec.md:188-191`)
- **SDK currently:** Both mobile delegates implement it behind a config list — posthog-android `PostHogConfig.tracingHeaders` (`posthog/src/main/java/com/posthog/PostHogConfig.kt:388` at `android-v4.0.2`) and posthog-ios `tracingHeaders` (`PostHog/PostHogConfig.swift:420` at `4.0.3`) — but KMP neither exposes nor forwards it: `toAndroidConfig()` (`androidMain/.../PostHog.android.kt:27-68`), JVM setup (`jvmMain/.../PostHog.jvm.kt:25-45`) and Apple setup (`appleMain/.../PostHog.apple.kt:50-85`) never set it, and the web options (`jsMain/.../PostHog.js.kt:34-72`) don't set posthog-js's tracing-header option. Falsified: no other config path or public API reaches it, and the native dependency isn't re-exported.
- **Backwards compatibility:** Additive.
- **Remediation:** Add `PostHogConfig.Builder.tracingHeaders: List<String>?` (default `null`) and forward it on Android/JVM/Apple, and to posthog-js's equivalent option on web. Android also needs the OkHttp interceptor from posthog-android to be reachable (re-export it or document adding the dependency).

<a id="n4"></a>

### n4 — Alias (🟡 Partial)
- **Spec requires:** the `@both` scenario "Alias is dropped when required identities are missing" — a blank alias is dropped with a validation warning (as quoted in `compliance/posthog-ios.md` n3).
- **SDK currently:** `PostHog.alias(alias, eventOptions)` forwards with no blank check (`commonMain/.../PostHog.kt:153-155`). Android/JVM forward a blank alias too: posthog-android `android-v4.0.2` (`posthog/src/main/java/com/posthog/PostHog.kt:2129-2158`, unchanged in 4.0.3) has no blank-alias guard (as `posthog-flutter.md` notes); Apple inherits posthog-ios n3 (blank alias accepted); web inherits posthog-js n1 (no empty-alias guard).
- **Backwards compatibility:** Backward-compatible — only affects calls that produce a malformed event today.
- **Remediation:** Reject a blank `alias` in `commonMain` with a warning, which fixes every target at once.

<a id="n5"></a>

### n5 — Bootstrap (❌ Fail)
- **Spec requires:** "The SDK SHALL accept an optional `bootstrap` configuration at setup that seeds identity and feature-flag state before any network request completes," carrying `distinctId`, `isIdentifiedId`, `featureFlags`, `featureFlagPayloads` (`openspec/specs/bootstrap/spec.md`, Requirement: Bootstrap configuration surface).
- **SDK currently:** `PostHogConfig` has no `bootstrap` (`commonMain/.../PostHogConfig.kt:34-60`); the web bridges hard-code an empty one (`jsMain/.../PostHog.js.kt:43`, `wasmJsMain/.../PostHog.wasmJs.kt:30-31`). Every delegate supports it (posthog-android `PostHogConfig.bootstrap` at `PostHogConfig.kt:304`, posthog-ios 🟡 n25, posthog-js ✅).
- **Backwards compatibility:** Additive.
- **Remediation:** Add a `bootstrap { distinctId; isIdentifiedId; featureFlags; featureFlagPayloads }` builder and forward it to each delegate (posthog-js: `bootstrap: { distinctID, isIdentifiedID, featureFlags, featureFlagPayloads }`).

<a id="n6"></a>

### n6 — Capture (🟡 Partial)
- **Spec requires:** "a custom property value in one of the following categories SHALL serialize as a JSON array … The SDK MUST NOT serialize such a value as an empty object, as JSON `null`, or as a string representation of the container" (Kotlin row: `Set` implementations) (`openspec/specs/capture/spec.md:1362-1376`); and an SDK that omits null members "SHALL apply the cleanup recursively to nested objects" (`:236`).
- **SDK currently (KMP-owned):**
  - **JS: `Long` property values are sent as objects.** `toJsValue()` passes every non-map, non-list value through unchanged (`jsMain/.../PostHog.js.kt:525-532`). On Kotlin/JS a `Long` is a `kotlin.Long` instance (`function Long(low, high) { this.low_1 = low; this.high_1 = high }` in the stdlib this toolchain emits — `build/js/packages/posthog-kmp-posthog-kmp-test/kotlin/kotlin-kotlin-stdlib.js:2217-2222`, Kotlin 2.4.21, no BigInt mode in `posthog-kmp/build.gradle.kts`), with no `toJSON`, so `capture("x", mapOf("ms" to 5L))` reaches posthog-js as `{"low_1":5,"high_1":0}`. Falsified: no conversion of `Long` exists anywhere in `jsMain` (only the capture timestamp is converted, `:110-112`), and no JS test covers it. Wasm converts every `Number` to a JS number (`wasmJsMain/.../PostHog.wasmJs.kt:446`), so only JS is affected.
  - **Wasm: `Set` (and any other non-map/list value) becomes a string.** `toJsAny()` falls back to `toString().toJsString()` (`wasmJsMain/.../PostHog.wasmJs.kt:442-454`), so `setOf("a","b")` is sent as `"[a, b]"` — the "string representation of the container" the spec forbids. On JS a Kotlin `Set` serializes through `AbstractMutableCollection.toJSON` as an array.
  - **Apple: `Set` is dropped.** `appendNative` hands every non-map, non-list value to `addObject(value)` uncopied (`appleMain/.../NativeProperties.apple.kt:79`), so a Kotlin `Set` reaches posthog-ios as an `NSSet`. posthog-ios 4.0.3 drops it: `isValidObject` accepts only arrays and dictionaries as containers and `sanitizeInvalidValue` converts only `URL`, `Date`, dictionaries and `[Any]` (`PostHog/Utils/DictUtils.swift:48-88`, `:211-230`), the #215 gap scored in [posthog-ios.md n4](posthog-ios.md#n4).
  - **Web: nested nulls kept.** `commonMain` drops only top-level null values (`commonMain/.../PostHog.kt:616-620`); native delegates drop nested ones themselves, but posthog-js sends nested `null`s, so the web wire is half-cleaned.
- **Inherited:** Android, JVM ✅ (posthog-android); Apple inherits posthog-ios n4 (🟡, `Set`/`NSSet` dropped, #215); web inherits posthog-js n2.
- **Backwards compatibility:** Backward-compatible — fixes wire values that PostHog can't use today.
- **Remediation:** In `jsMain` `toJsValue()`, convert `is Long -> toDouble()` (and `is Set<*>`/`Collection` → array); in `wasmJsMain` `toJsAny()`, map `is Collection<*>` → array before the `toString()` fallback; in `appleMain` `NativeProperties.apple.kt`, convert `is Set<*>` to an array in `appendNative` before the `addObject` fallback; make `dropNullValues()` recursive for the web targets.

<a id="n7"></a>

### n7 — Capture AI (✅ Pass)
- **Spec note:** Applicability is "`server`, and client SDKs on capture v1 that ship an AI method." Android/JVM/Apple forward `captureAi()` and its four options to the native AI lanes (`jvmCommonMain/.../PostHog.jvmCommon.kt:69-80`, `:129-143`; `appleMain/.../PostHog.apple.kt:69-77`, `:179-197`), both ✅ in their files. The web targets are not on capture v1, so out of scope; `captureAi()` there returns `null` and sends nothing, with a debug log (`jsMain/.../PostHog.js.kt:128-137`), as the KDoc and CHANGELOG state.

<a id="n8"></a>

### n8 — Capture Exception (🟡 Partial)
- **Spec requires:** "`$exception_list[0]` MUST be the exception the SDK caught …, and each cause/inner/wrapped exception MUST be appended after its wrapper in unwrap order, so the root cause is the last element." (`openspec/specs/capture-exception/spec.md:190-193`); for an ignore list, "Matching SHALL consider every exception in the chain" (`:377-378`).
- **SDK currently (KMP-owned):**
  - **Apple flattens the cause chain into one entry.** `Throwable.toNSException()` builds a single `NSException` whose `reason` is the message plus `"Caused by: <type>: <msg>"` lines and whose `callStackReturnAddresses` concatenate the root's and every cause's addresses (`appleMain/.../KotlinThrowableNSException.kt:47-76`, `:127-133`); `userInfo` is `nil`. posthog-ios 4.0.3 walks a chain only through `userInfo[NSUnderlyingErrorKey]` (`PostHog/ErrorTracking/PostHogExceptionProcessor.swift:124-150` at `4.0.3`), so manual `captureException()` and Kotlin crashes on iOS/macOS send a one-element `$exception_list` whose frames mix several stacks. Consequence: an `ignoredExceptionTypes` entry that matches only a cause never drops the event on Apple (Android matches the whole chain).
  - **Wasm drops the cause chain.** `createJsError(simpleName, message, stackTraceToString())` (`wasmJsMain/.../PostHog.wasmJs.kt:362-374`, `:485-486`) builds a plain `Error` with no `cause`, folding causes into the stack text.
- **Inherited:** Android/JVM ✅ (posthog-android n40), JS ✅ (Kotlin/JS `Throwable` is a JS `Error`, passed through at `jsMain/.../PostHog.js.kt:380-388`).
- **Backwards compatibility:** Backward-compatible — changes only `$exception_list` shape for chained exceptions; issue grouping for chained Kotlin exceptions on Apple may change once.
- **Remediation:** On Apple, build one `KotlinThrowableNSException` per link and chain them with `userInfo = [NSUnderlyingErrorKey: causeException]`, each with its own filtered addresses; on Wasm, set `cause` on the created `Error` recursively.

<a id="n9"></a>

### n9 — Exception Steps (❌ Fail)
- **Spec requires:** Requirement "Public exception-step API" — `addExceptionStep(message, properties?)` records a step in the instance buffer (`openspec/specs/exception-steps/spec.md`).
- **SDK currently:** No `addExceptionStep` in `commonMain/.../PostHog.kt:30-603`; the gap is acknowledged in code: "TODO: Add exceptionSteps when PostHog.addExceptionStep is available in the common API." (`commonMain/.../PostHogConfig.kt:241`). posthog-android ✅, posthog-ios 🟡 and posthog-js ❌ in their files.
- **Backwards compatibility:** Additive.
- **Remediation:** Add `PostHog.addExceptionStep(message, properties)` forwarding to posthog-android/posthog-ios (and posthog-js when it ships one), plus the `exceptionSteps` options in `errorTracking { }`.

<a id="n10"></a>

### n10 — Flush (🟡 Partial)
- **Spec requires:** Behavior step 3, "Build and send batches until the queue is drained or a failure stops progress", replay queues included (as quoted in `compliance/posthog-ios.md` n6).
- **SDK currently:** `flush()` forwards on Android/JVM (✅) and Apple (inherits posthog-ios n6). posthog-js has no public flush (posthog-js n4); KMP drains its private queues with `_requestQueue?.unload()` / `_retryQueue?.unload()` (`jsMain/.../PostHog.js.kt:428-437`, `wasmJsMain/.../PostHog.wasmJs.kt:397-399`), which sends by `sendBeacon` with no completion or failure signal and depends on private posthog-js fields.
- **Backwards compatibility:** n/a.
- **Remediation:** Switch to a public posthog-js flush when one exists; until then document that web flush is best-effort.

<a id="n11"></a>

### n11 — Get Anonymous ID (✅ Pass)
- Android/JVM/Apple forward to the native getter (both ✅). posthog-js has no public getter (posthog-js n5, whose remediation is to return `$device_id`); KMP already reads `get_property("$device_id")` (`jsMain/.../PostHog.js.kt:390-392`, `wasmJsMain/.../PostHog.wasmJs.kt:377-379`), so every KMP target has the API.

<a id="n12"></a>

### n12 — Get Feature Flag Payload / Get Feature Flag Result / Feature Flag Cache (🟡 Partial)
- **Spec requires:** "If decoding fails, including for empty or whitespace-only serialized input, the SDK SHALL return the same sentinel used for a known flag without a payload" (`openspec/specs/get-feature-flag-payload/spec.md`, Requirement: Malformed serialized payloads return no payload). A dedicated payload getter MAY be omitted when the result getter returns the payload and takes `sendFeatureFlagEvent` (Requirement: Payload reads through the flag result getter).
- **SDK currently:** KMP has no `getFeatureFlagPayload`; `getFeatureFlagResult(key, sendFeatureFlagEvent = false)` returns the payload on every target (`commonMain/.../PostHog.kt:498-500`), which the spec permits. Android/JVM/Apple return `null` for a malformed payload (✅ in both files). On web, KMP reads `result.payload` from posthog-js (`jsMain/.../PostHog.js.kt:360-378`, `wasmJsMain/.../PostHog.wasmJs.kt:320-333`), and posthog-js 1.435.8 parses with `try{return JSON.parse(t)}catch(i){return t}` (`dist/module.js`), so a malformed payload comes back as the raw string. KMP's `featureFlagResult()` forces `enabled = false` for an empty variant on every path (`commonMain/.../PostHogModels.kt:225-226`).
- **Feature Flag Cache (row 58):** the same web gap fails "Cached payload decoding rejects malformed JSON" (`openspec/specs/feature-flag-cache/spec.md:143-162`, #170): invalid JSON "MUST NOT be exposed as a raw payload string" and the SDK "SHALL log parse failures". posthog-js 1.435.8's `parsePayload` (`packages/core/src/featureFlagUtils.ts:110-120`) returns the raw string without a log, and the web bridges forward it. Android/JVM/Apple ✅ (posthog-android n33, posthog-ios n20). `compliance/posthog-js.md` still shows ✅ only because it predates #170.
- **Backwards compatibility:** Changing the web payload to `null` for malformed JSON is a behaviour change for anyone reading the raw string.
- **Remediation:** Fix in posthog-js, or have the web bridges drop a payload that is a `String` posthog-js failed to parse (only possible by re-parsing the raw value).

<a id="n13"></a>

### n13 — Get Feature Flags / Get Feature Flags And Payloads (🟡 Partial)
- **Spec requires:** client canonical `getFeatureFlags(): Record<string, boolean | string> | undefined`; the recorded mobile variant "`getAllFeatureFlags()` returns a list of flag result objects (key, enabled, variant, payload), or `null` when flags are unavailable" (`openspec/specs/get-feature-flags/spec.md`, Surface variants), and "On SDKs where `getAllFeatureFlags()` returns a list of flag result objects (… KMP), each entry SHALL match what `get-feature-flag-result` returns" (`:167`).
- **SDK currently:** `getAllFeatureFlags(): Map<String, FeatureFlagResult>` (`commonMain/.../PostHog.kt:347-349`) — a key-to-result map, not the canonical key-to-value map nor the list the spec records for KMP. Entries match `getFeatureFlagResult` and read an empty variant as disabled (`PostHogModels.kt:225-226`). **KMP-owned deviation:** "unavailable" is indistinguishable from "no flags" because every bridge collapses `null` to `emptyMap()` (`jvmCommonMain/.../PostHog.jvmCommon.kt:224-228`, `appleMain/.../PostHog.apple.kt:283-287`, `jsMain/.../PostHog.js.kt:226-248`). Same 🟡 as posthog-android n9/n10 and posthog-ios n9/n10; web inherits posthog-js's malformed-payload string (n12).
- **Backwards compatibility:** Returning `null` would be breaking for 1.x callers; a separate "flags loaded" signal is additive.
- **Remediation:** Correct the spec's KMP surface note to "map of results", or return `Map<String, FeatureFlagResult>?` in 2.0; meanwhile document that an empty map can mean "not loaded".

<a id="n14"></a>

### n14 — Get Session ID / Session Manager (🟡 Partial)
- **Spec requires:** "Session id rotates after inactivity timeout" (`compliance/posthog-ios.md` n11); posthog-js n9/n29: "idle-timeout rotation, max-length rotation, cross-tab consistency, explicit reset".
- **SDK currently:** Pure forwarding (`jvmCommonMain/.../PostHog.jvmCommon.kt:282-284`, `appleMain/.../PostHog.apple.kt:358`, `jsMain/.../PostHog.js.kt:394-401`). Android/JVM ✅ (core rotates on 30 min idle / 24 h, `PostHogSessionManager.kt:121-122` at `core-v7.0.2`, so the JVM target rotates without a lifecycle); Apple inherits posthog-ios n11; web inherits posthog-js n9/n29.
- **Remediation:** Native/posthog-js fixes.

<a id="n15"></a>

### n15 — Group / Group Identify (🟡 Partial)
- **Spec requires:** "`group(type, key, properties)` MUST reject blank/empty `type`/`key` (context unchanged, warning logged)" (`openspec/specs/group/spec.md:128-136`, quoted in `compliance/posthog-android.md` n11; same for group identify, n12).
- **SDK currently:** `group()` forwards without validation (`commonMain/.../PostHog.kt:300-307`). Apple ✅; Android/JVM inherit posthog-android n11/n12; web inherits posthog-js n10/n11 (no opt-out / `person_profiles: 'never'` guard). No standalone `groupIdentify`, which the spec allows for iOS/Android-style clients.
- **Remediation:** Reject blank `type`/`key` in `commonMain` with a warning.

<a id="n16"></a>

### n16 — Identify (✅ Pass)
- **Spec requires:** while opted out, clients "MUST NOT capture or send the `$identify` or `$set` event, and MUST NOT update the person-properties dedup hash for an event it did not capture" (quoted in `compliance/posthog-android.md` n28).
- **SDK currently:** Forwarded (`jvmCommonMain/.../PostHog.jvmCommon.kt:153-165`). Android/JVM ✅: the pinned `android-v4.0.2` / `core-v7.0.2` (`bf387d47`) already includes PostHog/posthog-android#967, which records the person-properties hash only once the event is queued (`posthog/src/main/java/com/posthog/PostHog.kt:1305`, `:2536`), as in posthog-android n28. Apple and web ✅. Web drops identify's `eventOptions` (`jsMain/.../PostHog.js.kt:147-160`, `wasmJsMain/.../PostHog.wasmJs.kt:122-135`), as documented in the KDoc and CHANGELOG: posthog-js 1.435.8 isn't on capture v1 and its `identify` takes no event options, so they aren't scored on web here (as with Capture AI, [n7](#n7)).

<a id="n17"></a>

### n17 — Is Session Replay Active / Start Session Recording / Stop Session Recording (❌ Fail)
- **Spec requires:** canonical client signatures `startSessionRecording(control?)`, `stopSessionRecording()` and an `isSessionReplayActive()` getter; the start spec lists every client SDK's variant (`openspec/specs/start-session-recording/spec.md`, Surface variants), and is-session-replay-active notes "Flutter and React Native expose a unified replay-status getter over native/browser replay implementations" (Interactions).
- **SDK currently:** None of the three exists in `commonMain/.../PostHog.kt:30-603` (confirmed by grep of `commonMain` and the ABI dump `posthog-kmp/api/`). Replay can only be configured at setup (`PostHogConfig.Builder.sessionReplay { }`, `commonMain/.../PostHogConfig.kt:169-173`). Every delegate has all three (posthog-android `startSessionReplay`, posthog-ios ✅, posthog-js ✅/🟡).
- **Backwards compatibility:** Additive.
- **Remediation:** Add `startSessionReplay(resumeCurrent: Boolean = true)`, `stopSessionReplay()` and `isSessionReplayActive()` (posthog-android names), forwarding to each delegate; `false`/no-op on JVM and macOS.

<a id="n18"></a>

### n18 — Opt In (🟡 Partial)
- **Spec requires:** "Opt out can clear local persistence when configured"; "Deferred crash reports honour consent at crash time" (#199) (quoted in `compliance/posthog-ios.md` n15, `compliance/posthog-android.md` n14).
- **SDK currently:** Forwarded on every target (`jvmCommonMain/.../PostHog.jvmCommon.kt:286-296`, `appleMain/.../PostHog.apple.kt:360-368`, `jsMain/.../PostHog.js.kt:403-426`); inherits n14/n15/n12 of the delegates. On web, `optOut = true` is applied by calling `opt_out_capturing()` after `init()` (`jsMain/.../PostHog.js.kt:81-83`), which persists the opt-out in posthog-js storage rather than using its `opt_out_capturing_by_default` option.

<a id="n19"></a>

### n19 — Register (🟡 Partial)
- **Spec requires:** a registered super property is merged into later events like a property passed on the event (`openspec/specs/register/spec.md`), so it must reach the wire with the same value conversion as capture. Blank-key rejection is optional ("may reject", `register/spec.md:42`).
- **SDK currently (KMP-owned, JS):** `platformRegister` writes the raw Kotlin value with `props[key] = value` (`jsMain/.../PostHog.js.kt:176-180`) instead of `value.toJsValue()`, which capture and identify use (`:518-532`). A registered Kotlin `Map`, `List` or `Long` reaches `posthog.register` as a Kotlin runtime object (a `Long` as `{low_1, high_1}`, see [n6](#n6)). Wasm converts with `value.toJsAny()` (`wasmJsMain/.../PostHog.wasmJs.kt:150-154`). The only JS test registers a `String` (`jsTest/.../PostHogJsTest.kt:233`).
- **Inherited:** Android/JVM ✅ (posthog-android n16 is ✅: blank keys are MAY-level); Apple and Wasm ✅. `register(key, value)` drops a `null` value and forwards a blank key (`commonMain/.../PostHog.kt:186-189`), which the spec permits.
- **Backwards compatibility:** Backward-compatible — fixes values PostHog can't use today.
- **Remediation:** In `jsMain` `platformRegister`, write `props[key] = value.toJsValue()`, and add a JS test that registers a map, a list and a `Long`.

<a id="n20"></a>

### n20 — Reload Feature Flags (✅ Pass)
- KMP supplies the callback posthog-js lacks (posthog-js n13): on web it subscribes with `onFeatureFlags`, skips the synchronous pre-reload fire, and delivers the next load once (`jsMain/.../PostHog.js.kt:250-274`); before `init` the callback gets `errorsLoading = true`, matching the native targets.

<a id="n21"></a>

### n21 — Reset (🟡 Partial)
- **Spec requires:** "reset clears user-scoped state including opt-out persistence" (`compliance/posthog-ios.md` n16).
- **SDK currently:** Forwarded; Apple inherits posthog-ios n16; Android/JVM/web ✅.

<a id="n22"></a>

### n22 — Reset Group Properties For Flags (🟡 Partial)
- **Spec requires:** canonical `resetGroupPropertiesForFlags(groupType?, reloadFeatureFlags?)` (posthog-js n14).
- **SDK currently:** KMP fixes posthog-js's missing reload by calling `reloadFeatureFlags()` itself (`jsMain/.../PostHog.js.kt:353-358`). The remaining web gap is posthog-js's missing person-processing guard (posthog-js n14); native targets ✅.

<a id="n23"></a>

### n23 — Screen (✅ Pass)
- `screen(screenName, properties, eventOptions)` removes a caller `$screen_name` so the explicit name wins (`commonMain/.../PostHog.kt:113-119`). Native targets forward to `screen()` (✅). posthog-js has no screen API (posthog-js n15); KMP sends `$screen` with `$screen_name` itself (`jsMain/.../PostHog.js.kt:139-145`).

<a id="n24"></a>

### n24 — Setup (🟡 Partial)
- **Spec requires:** scenario "Repeated setup does not duplicate singleton state": after a second setup, "exactly one active SDK instance should exist for the default name" and "lifecycle observers should be installed at most once" (`openspec/specs/setup/spec.md`, Requirement: Canonical setup behavior). `projectToken` naming: met (`commonMain/.../PostHogConfig.kt:27-35`; `apiKey` removed in 1.0.0, a major).
- **SDK currently (KMP-owned):** On Android and JVM every `setup()` builds a new client with `PostHog.with(...)` (`androidMain/.../PostHog.android.kt:24`, `jvmMain/.../PostHog.jvm.kt:56`) and the `postHogInstance` setter replaces the old one without closing it (`jvmCommonMain/.../PostHog.jvmCommon.kt:8-14`). `PostHog.with` always creates a fresh instance (`PostHog.kt:3483-3487` at `core-v7.0.2`); its duplicate-token check only logs (`:344-346`). The orphaned first instance keeps running its flush timer and queue, and on Android it keeps the lifecycle/screen/deep-link integrations ("Default PostHog integrations are installed only on the first instance created", `PostHogAndroid.kt` KDoc at `android-v4.0.2`), so lifecycle events keep flowing through a client KMP no longer controls. Apple (`PostHogSDK.shared.setup` ignores a repeat) and web (`posthog.init` on the singleton) are not affected. Falsified: no guard in `PostHog.setup` (`commonMain/.../PostHog.kt:42-45`), no test for repeated setup.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** In `platformSetup` on Android/JVM, `close()` the previous instance before replacing it (as the missing-`Application` branch already does at `androidMain/.../PostHog.android.kt:20-21`), or ignore a repeat setup with a warning like posthog-ios.

<a id="n25"></a>

### n25 — Shutdown (🟡 Partial)
- **Spec requires:** shutdown flushes and stops accepting new work (posthog-js n16).
- **SDK currently:** `close()` forwards and drops the reference (`jvmCommonMain/.../PostHog.jvmCommon.kt:302-306`, `appleMain/.../PostHog.apple.kt:374-377` also uninstalls the Kotlin crash hook). Native ✅; web inherits posthog-js n16 (captures after `shutdown()` still enqueue).

<a id="n26"></a>

### n26 — Application Lifecycle (✅ Pass)
- `captureApplicationLifecycleEvents` (default `true`) is forwarded on Android and Apple (`androidMain/.../PostHog.android.kt:34`, `appleMain/.../PostHog.apple.kt:52`); both ✅. JVM desktop and web are outside the spec's applicability ("Browser/web and server SDKs … are outside this component's canonical scope").

<a id="n27"></a>

### n27 — Autocapture (🟡 Partial)
- **Spec requires:** "Client SDKs that can observe UI interactions in the host runtime" provide generic interaction autocapture (`openspec/specs/autocapture/spec.md`, Applicability).
- **SDK currently (KMP-owned):** `PostHogConfig.autocapture` ("Enable automatic event capture (platform dependent). Defaults to false.", `commonMain/.../PostHogConfig.kt:109-110`) is forwarded on iOS (`captureElementInteractions`, `iosMain/.../PlatformCapture.ios.kt:10`) and web (`autocapture`, `jsMain/.../PostHog.js.kt:39`), but **not on Android**: `toAndroidConfig()` never sets `PostHogAndroidConfig.captureElementInteractions` (`androidMain/.../PostHog.android.kt:27-68`; option at `PostHogAndroidConfig.kt:87` at `android-v4.0.2`, which captures View and Compose taps — posthog-android ✅). `autocapture = true` is silently ignored on Android with no log, unlike macOS which logs (`macosArm64Main/.../PlatformCapture.macos.kt:12-14`).
- **Backwards compatibility:** Backward-compatible — the default stays `false`.
- **Remediation:** Set `captureElementInteractions = config.autocapture` in `toAndroidConfig()`; optionally expose rage/dead-click options.

<a id="n28"></a>

### n28 — Before Send Hook (✅ Pass)
- One shared chain in `commonMain` (`commonMain/.../PostHogBeforeSend.kt:71-87`): callbacks run in order, `null` or a throw drops the event, and the debug-only log names the event and exception type only (`:93-94`). Each bridge runs it inside the delegate's hook on the built event (`jvmCommonMain/.../PostHog.jvmCommon.kt:82-111`, `appleMain/.../PostHog.apple.kt:94-120`, `jsMain/.../PostHog.js.kt:461-478`). Because KMP catches throws itself, web is fail-closed even though posthog-js's own `before_send` call is not wrapped (posthog-js n20).

<a id="n29"></a>

### n29 — Consent Gating (🟡 Partial)
- **Spec requires:** consent changes gate capture and side effects, observably and race-free (posthog-js n21).
- **SDK currently:** Native ✅; web inherits posthog-js n21.

<a id="n30"></a>

### n30 — Event Batcher (🟡 Partial)
- **Spec requires:** periodic flush on an injectable clock (posthog-android n6); count + time thresholds, `maxBatchSize`, 413 shrink (posthog-js n22).
- **SDK currently:** `flushAt`/`flushIntervalSeconds`/`maxQueueSize`/`maxBatchSize` forwarded on Android/JVM/Apple (`androidMain/.../PostHog.android.kt:43-46`, `appleMain/.../PostHog.apple.kt:56-59`) but have no web equivalent and are ignored there (`jsMain/.../PostHog.js.kt:34-72`). Apple ✅; Android/JVM inherit n6; web inherits posthog-js n22 (❌).

<a id="n31"></a>

### n31 — Exception Event Metadata (🟡 Partial)
- **Spec requires:** "KMP and other forwarding facades SHALL preserve the source emitted by the underlying wire-producing SDK rather than replace it with the facade name." (`openspec/specs/exception-event-metadata/spec.md:133`); plus the reserved-key and handled-state rules quoted in `compliance/posthog-ios.md` n19 / `compliance/posthog-android.md` n7.
- **SDK currently:** KMP sets no `$exception_source` or mechanism itself: manual capture forwards, and on Apple an unhandled Kotlin exception is re-raised as `NSException` so posthog-ios's crash reporter owns source, handled state and termination (`appleMain/.../KotlinThrowableNSException.kt:138-144`) — the KMP-specific rule is met. Inherits posthog-android n7, posthog-ios n19 and posthog-js's 🟡. The Apple chain flattening (n8) also removes nested-entry metadata.

<a id="n32"></a>

### n32 — Feature Flag Called Tracker (🟡 Partial)
- Forwarded; Android/JVM inherit posthog-android n8 (dedupe/minimal-event-mode gaps); Apple and web ✅.

<a id="n33"></a>

### n33 — HTTP Client / Remote Config / Retry Queue (🟡 Partial)
- **Spec requires:** `/flags` retry with 300→600 ms backoff (posthog-js n24); single deduplicated config load cleared on reset (n27); bounded retry queue honouring 429/`Retry-After`/413 (n28).
- **SDK currently:** Android/JVM/Apple ✅ in their files. Web inherits posthog-js n24 (❌), n27, n28.

<a id="n34"></a>

### n34 — Persistent Storage (🟡 Partial)
- **Spec requires:** "Storage failures do not crash SDK calls" — no throw and a recorded storage warning; scenario "Storage persists super properties" across a restart (`openspec/specs/persistent-storage/spec.md`).
- **SDK currently:** Android/Apple inherit posthog-android n15 / posthog-ios n23; web inherits posthog-js 🟡. **JVM is KMP-owned:** `PostHogFilePreferences` keeps state in memory and persists on a single **daemon** thread (`jvmMain/.../PostHogFilePreferences.kt:25-27`, `:88-100`), with atomic temp-file moves (`:102-121`) and logged failures — good — but nothing waits for pending writes: `close()` doesn't (`jvmCommonMain/.../PostHog.jvmCommon.kt:302-306`) and `awaitPendingWrites()` is used only by tests (`jvmMain/.../PostHogFilePreferences.kt:72-74`). A JVM app that registers or identifies and then exits can lose that write, so the next launch restores the older identity. Storage lives under `~/.posthog-kmp` (falls back to `java.io.tmpdir` with a log, `jvmMain/.../PostHog.jvm.kt:47-64`).
- **Remediation:** Make `PostHogFilePreferences` non-daemon or drain it from `close()`/a shutdown hook.

<a id="n35"></a>

### n35 — Session Replay Debug Properties (🟡 Partial)
- Forwarded; inherits posthog-android n17 and posthog-ios n26 (both 🟡). The pinned posthog-android 4.0.2 and posthog-ios 4.0.3 already include the "drop debug keys while replay is off" fixes. Web inherits posthog-js 🟡.

<a id="n36"></a>

### n36 — Session Replay Ingestion Controls (🟡 Partial)
- **Spec requires:** "The SDK SHALL capture session replay only when replay is enabled **both** locally (the SDK's replay configuration) **and** remotely … If either source disables replay, the SDK SHALL NOT record" (`openspec/specs/session-replay-ingestion-controls/spec.md:107`, scenario "Local config disables replay even when remote is active", `:117`).
- **SDK currently (KMP-owned, web):** KMP's local switch is `sessionReplay { }` — "Turns on session replay (Android and iOS) with the given options. Off unless you call this." (`commonMain/.../PostHogConfig.kt:169`), plus `enabled` (default `true`). On JS/Wasm KMP only adds `session_recording` options when replay is configured and enabled (`jsMain/.../PostHog.js.kt:58-68`, `wasmJsMain/.../PostHog.wasmJs.kt:36`) and never sets posthog-js's `disable_session_recording`, whose default is `false` (`disable_session_recording:!1` in posthog-js 1.435.8 `dist/module.js`). So on the web, leaving replay unconfigured or setting `enabled = false` still records whenever the project enables replay remotely. Android/JVM/Apple honour the local switch (`androidMain/.../PostHog.android.kt:56-66`, `iosMain/.../PlatformCapture.ios.kt:13-14`). Also inherits posthog-android n18 and posthog-js 🟡.
- **Backwards compatibility:** Behaviour change for web apps that currently get replay from the remote setting alone; call it out in the changelog.
- **Remediation:** Set `disable_session_recording = !(config.sessionReplay?.enabled ?: false)` in both web bridges, or document web as remote-controlled and adjust the KDoc.

<a id="n37"></a>

### n37 — Session Replay Privacy (🟡 Partial)
- **Spec requires:** "Android secure windows are recorded fully masked … posthog-kmp conforms once its pinned posthog-android version includes this behavior." (`openspec/specs/session-replay-privacy/spec.md:245-249`); no-capture elements masked (posthog-ios n24).
- **SDK currently:** **Android conforms** — the pinned posthog-android 4.0.2 records a `FLAG_SECURE` window as one mask without copying pixels and drops its touches (`posthog-android/src/main/java/com/posthog/android/replay/PostHogReplayIntegration.kt:846-854`, `:2543`, `:2677-2685` at `android-v4.0.2`). KMP forwards `maskAllTextInputs`/`maskAllImages` (defaults `true`). Apple inherits posthog-ios n24 (🟡, over-masks). **KMP-owned risk:** posthog-ios is pinned `exact("4.0.3")` (`posthog-kmp/build.gradle.kts:80`, `gradle/libs.versions.toml:14`), so apps can't take posthog-ios 4.0.4, which fixed GPU-capture leaks ("Mask the text of a `CATextLayer` under a `postHogMask()` extent with `captureMethod = .gpu`. Its glyphs were uploaded readable.", posthog-ios `CHANGELOG.md` 4.0.4). KMP exposes that capture method as `IosCaptureMethod.GPU` (`commonMain/.../PostHogConfig.kt:207-218`, forwarded at `iosMain/.../PlatformCapture.ios.kt:20-23`). Web ✅ (posthog-js).
- **Remediation:** Bump posthog-ios to 4.0.5 and consider a `from(...)` range instead of `exact(...)` so privacy patches reach apps without a KMP release.

<a id="n38"></a>

### n38 — Surveys (🟡 Partial)
- **Spec requires:** wait-period and undisplayable-question rules (posthog-android n22); opt-out prevents fetch/display, reset clears state (posthog-js n32).
- **SDK currently:** `surveys` forwarded on Android/iOS/web (`androidMain/.../PostHog.android.kt:39`, `iosMain/.../PlatformCapture.ios.kt:11`, `jsMain/.../PostHog.js.kt:72`); ignored on macOS/JVM. iOS ✅; Android inherits n22 (and displays only with `posthog-android-surveys-compose` on the classpath); web inherits posthog-js n32.

<a id="n39"></a>

### n39 — Debug (🟡 Partial)
- **Spec requires:** `debug(enabled?: boolean)`, where an omitted `enabled` defaults to `true` (`openspec/specs/debug/spec.md:18-21`), with the scenario "Debug defaults to enabled when called without an argument" (`:115-122`).
- **SDK currently (KMP-owned):** the `debug` config and `setDebug(enabled)` reach every target, but `setDebug(enabled: Boolean)` (`commonMain/.../PostHog.kt:600`) has no default and no zero-argument overload, so `PostHog.setDebug()` does not compile. posthog-flutter is 🟡 for the same missing default ([posthog-flutter.md n7](posthog-flutter.md#n7)).
- **Backwards compatibility:** Additive — existing calls pass `enabled` explicitly.
- **Remediation:** Declare `setDebug(enabled: Boolean = true)`.

<a id="n40"></a>

### n40 — Set Person Properties (🟡 Partial)
- **Spec requires:** "If both property dictionaries are missing or empty, do nothing", and "Empty inputs no-op" (`openspec/specs/set-person-properties/spec.md:39`, `:81`).
- **SDK currently (KMP-owned, web):** `setPersonProperties` (`commonMain/.../PostHog.kt:279-285`) has no empty-input guard, and both web bridges substitute an empty object when `userPropertiesToSet` is `null` (`jsMain/.../PostHog.js.kt:535-544`, `userProperties?.toJsObject() ?: js("{}")`; `wasmJsMain/.../PostHog.wasmJs.kt:410-419`, `?: createJsObject()`). posthog-js 1.435.8 returns early only when both arguments are falsy (`packages/browser/src/posthog-core.ts:3459-3461`), and `{}` is truthy, so `PostHog.setPersonProperties(null)` on web updates the flag person properties with a reload and sends an empty `$set` event. Android, JVM and Apple forward to native SDKs that are ✅ on this row. Web also drops `eventOptions`, which isn't scored on web here (see [n16](#n16)).
- **Backwards compatibility:** Backward-compatible — only calls with nothing to set change.
- **Remediation:** Return early in `commonMain` when both maps are `null` or empty, and pass `undefined` instead of `{}` in the web bridges.

<a id="n41"></a>

### n41 — On Feature Flags (🟡 Partial)
- **Spec requires:** "A runtime listener registration … SHALL stay active until the caller unsubscribes it, including across a `close()`/`setup()` cycle" (`openspec/specs/on-feature-flags/spec.md:178-180`, #161), which names posthog-js with no web carve-out.
- **SDK currently:** `onFeatureFlags()` returns a subscription on every target, and JS/Wasm queue listeners added before `init`. Android, JVM, iOS and macOS keep a registration across `close`/`setup` ✅. **JS/Wasm fail:** `close()` calls `PostHogJs.shutdown()` (`jsMain/.../PostHog.js.kt:439-445`, `wasmJsMain/.../PostHog.wasmJs.kt:401-403`); posthog-js 1.435.8's `shutdown()` destroys feature flags but leaves `__loaded` set (`packages/browser/src/posthog-core.ts:3958-3983`), so the next `init()` returns early (`:849-864`) and active listeners are never re-attached (`jsMain/.../PostHog.js.kt:86-90`). The KDoc says so (`commonMain/.../PostHog.kt:387-389`). `compliance/posthog-js.md` still shows ✅ only because it predates #161.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** Fix teardown/re-init in posthog-js, then re-attach active listeners on a later `setup()` in both web bridges.
