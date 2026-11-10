# posthog-react-native — SDK Compliance

**Repo:** [PostHog/posthog-react-native](https://github.com/PostHog/posthog-react-native) (archived; code lives in `packages/react-native` + `packages/react-native-plugin` of the `posthog-js` monorepo)
**Audited commit:** `3ddaa65402896c91dcb7b04cfe433e0b1d2f3313` ([commit](https://github.com/PostHog/posthog-js/commit/3ddaa65402896c91dcb7b04cfe433e0b1d2f3313)) — audited on 2026-10-19. **Nine rows re-audited on 2026-11-10 for `@posthog/react-native-plugin` 3.0** at `210bf35d8c19a15003d0643999ae63bcc2102fb6` ([commit](https://github.com/PostHog/posthog-js/commit/210bf35d8c19a15003d0643999ae63bcc2102fb6), head of [PostHog/posthog-js#5194](https://github.com/PostHog/posthog-js/pull/5194)) — see [react-native-plugin 3.0](#react-native-plugin-30-re-audit-2026-11-10)
**Audited against sdk-specs commit:** `c72e367` (2026-10-19 rows); `752f899` plus [#146](https://github.com/PostHog/sdk-specs/pull/146) at `d387ab79`, treated as merged, for the nine plugin 3.0 rows
**Summary:** 31 ✅ · 26 🟡 · 2 ❌ · 5 ➖ · 0 ❓ (64 rows; 2026-10-19 at `3ddaa654` scored 29/27/3/5/0; previous full audit 2026-08-06 at `e1efa57` scored 31/23/2/2/1 on 59 rows)

**Repo layout (unchanged, re-confirmed):** `PostHog/posthog-react-native` is archived; the SDK lives at
`packages/react-native/src` (`PostHog extends PostHogCore`, `posthog-rn.ts`, now 3,345 lines — up from
2,900 at the last audit) and shares `packages/core/src` with `packages/browser` and `packages/node`.
Because react-native extends the full client-side `PostHogCore` rather than the stateless base
`packages/node` uses, it is scored as a client SDK: ambient-identity primitives that posthog-node
scores ➖ N/A are genuine contracts here.

**Why the 2026-10-19 run:** rotation priority 1 — this was the stalest pointer in the matrix (2026-08-06) and
the intended third pick of the 2026-10-12 run. The monorepo moved **802 commits** between
`e1efa57` and `3ddaa654`.

**Scope of the 2026-10-19 audit.** All 64 rows were scored. The five contracts missing from the previous
59-row file (Capture AI, Evaluate Flags, Exception Event Metadata, Session Replay Debug Properties,
MCP Analytics) were audited from scratch. Every previously non-Pass row was re-read against current
code at this commit; the Pass rows were re-checked against the spec text that has merged since
2026-08-06 (PRs #103, #108, #110, #114, and the payload-decoding requirement), which is where all
four new downgrades come from.

## react-native-plugin 3.0 re-audit (2026-11-10)

`@posthog/react-native-plugin` 3.0 ([PostHog/posthog-js#5194](https://github.com/PostHog/posthog-js/pull/5194))
moves the native layer to posthog-ios 4.0 and posthog-android 4.0. Session replay, native crash reports,
fatal JavaScript crashes reported natively and push opens run in those SDKs, and their events go to capture
v1. Events captured in JavaScript still go to `/batch` through `posthog-react-native`. The native behavior
these rows rely on was read at the 4.0 release branches, posthog-ios `e27cbe4cb` and posthog-android
`aaa23d39`. Source references in this section and in the notes it updates are at posthog-js `210bf35d8`
unless they say otherwise.

**Scope.** Nine rows were re-audited: the six session replay rows, Opt In, Capture Exception and Exception
Event Metadata. Every other row carries forward from 2026-10-19 at `3ddaa654`. Spec changes on `main` since
then also touch rows outside this scope, which the next full audit must re-verify:

- **Capture:** #193 adds "Empty variant is not an active feature flag" and names posthog-js core and
  react-native as a known gap (a `""` flag is still listed in `$active_feature_flags`). The `$lib` pair rule
  of #146 doesn't reach JS events, which still go to `/batch`; for native-delivered events see below.
- **Get Feature Flag Result, Get Feature Flags, On Feature Flags:** #193 reads an empty variant as disabled.
- **Feature Flag Called Tracker:** #203 renames `$feature_flag_variant` to `$feature_flag_variant_key`.
- **Surveys:** #102 writes the last-seen survey date on show. Surveys render in JS: the plugin turns native
  surveys off, also when another package enables posthog-ios's Surveys trait (PostHog/posthog-js#5639,
  `packages/react-native-plugin/ios/PosthogReactNativePlugin.swift:375-381`), so native survey fixes such as
  PostHog/posthog-ios#1049 don't reach RN.
- **Remote Config** (#198, `quotaLimited`) and **Identify** and **Consent Gating** (#167, identify keeps
  running while opted out).

| Contract | 2026-10-19 | Plugin 3.0 | Why |
|---|---|---|---|
| Is Session Replay Active | 🟡 | ✅ | The getter reads native `isSessionReplayActive()`, which in 4.0 reports a running recorder for this session, and JS stops the native recorder whenever its linked-flag, event-trigger or consent gate holds replay off ([n18](#n18)) |
| Opt In | ✅ | ✅ | Meets #138: JS owns the session id and rotates it before native restarts replay, and the restart follows what the app wanted at opt-out. Meets #199 through the native SDKs: a native crash recorded while opted out is dropped, and one recorded while opted in waits for opt-in ([n32](#n32)) |
| Session Replay Debug Properties | ❌ | 🟡 | Required and optional tiers, the 30 s window from acceptance, `screenshot` capture mode, the minimal `$feature_flag_called` strip and backdated events conform; the SDK-computed keys overwrite registered and caller values ([n24](#n24)) |
| Session Replay Ingestion Controls | 🟡 | 🟡 | Sampling and minimum-duration buffering run in posthog-ios 4.0 and posthog-android 4.0. Gap: RN hands native the cached project sample rate as a local rate, so a changed project rate doesn't apply until the next launch ([n25](#n25)) |
| Session Replay Privacy | 🟡 | ✅ | 4.0 records masked screenshots only, so the posthog-ios wireframe leak this row inherited is gone; RN exposes only a mask marker, so an unmask-precedence gap can't arise ([n26](#n26)) |
| Start Session Recording | ✅ | ✅ | Unchanged; a start while opted out doesn't change what opt-in restores |
| Stop Session Recording | 🟡 | 🟡 | posthog-ios 4.0 flushes the replay queue on stop; posthog-android 4.0 still doesn't ([n29](#n29)) |
| Capture Exception | ✅ | ✅ | JS-captured exceptions are unchanged; native crash reports and natively reported fatal JS crashes go through native capture v1, and Android now stamps a fatal JS crash on the SDK clock ([n33](#n33)) |
| Exception Event Metadata | 🟡 | 🟡 | The shared `@posthog/core` gaps ([n7](#n7)) are unchanged; #205's job-retry rule has no RN integration to apply to |

**Native events on capture v1.** The plugin configures both native SDKs with the library name
`posthog-react-native` and the JS SDK's version (`packages/react-native-plugin/ios/PosthogReactNativePlugin.swift:440-443`,
`packages/react-native-plugin/android/src/main/java/com/posthogreactnativeplugin/PosthogReactNativePluginModule.kt:207-210`),
as #146 requires of a wrapper whose events a native SDK delivers. #146's "Events name their own library"
applies to these events, not to JS events on `/batch`. Both native SDKs fill the pair from that configured
identity. At posthog-ios `e27cbe4cb`, `fillLibraryIdentity` (`PostHog/PostHogSDK.swift:701-711`) reads `sdkInfo()`, built
from `postHogSdkName` and `postHogVersion` (`PostHog/PostHogContext.swift:149-154`). At posthog-android `aaa23d39`,
`fillLibraryIdentity` (`posthog/src/main/java/com/posthog/internal/PostHogLibraryIdentity.kt:13-29`) reads
`getSdkInfo()`, built from `config.sdkName` and `config.sdkVersion` (`PostHogAndroidContext.kt:47-53`). So a native event without `$lib` gets `posthog-react-native` with the JS
version, a `posthog-react-native` event without a version gets the JS version, and another library's `$lib`
keeps its own version. This is recorded, not scored: Capture is outside this re-audit. Delivery, headers, retry
and redirect behavior are the native SDKs' and are scored in their audits.

**Not scored: `$app_language`.** Plugin 3.0 turns off native language detection and sends the language set
with `posthog.setAppLanguage()` (posthog-react-native 4.86.0+) on native events. The spec for
`$app_language` ([#172](https://github.com/PostHog/sdk-specs/pull/172)) is still open.

## Movement on 2026-10-19

**Improvements (3):**

- **Feature Flag Called Tracker 🟡→✅.** The previous audit said the client never persisted the
  server's `minimalFlagCalledEvents` gate. At this commit `PostHogCore` stores it and reads it back,
  so the minimal envelope is produced — see [n8](#n8).

- **Capture Exception 🟡→✅.** The previous audit's sole finding was "no flat
  `$exception_type`/`$exception_message`, only `$exception_list`". sdk-specs PR
  [#103](https://github.com/PostHog/sdk-specs/pull/103) retired exactly that requirement, making
  `$exception_list` canonical. The shared builder's behaviour is unchanged and is now correct. Same
  clearance as posthog-python saw last cycle.
- **Session Replay Privacy ❓→🟡.** Resolved — see [n26](#n26).

**Downgrades on new spec text (4), no code regression:**

- **Setup ✅→🟡** — `projectToken` ([n27](#n27)). PR [#108](https://github.com/PostHog/sdk-specs/pull/108)
  names React Native's `apiKey` prop by name.
- **Get Feature Flag Payload / Get Feature Flag Result / Get Feature Flags And Payloads ✅→🟡** —
  the shared `parsePayload` returns the raw malformed string instead of the no-payload sentinel
  ([n10](#n10), [n11](#n11), [n12](#n12)). The same requirement moved posthog-ios and posthog-go rows
  in earlier runs.

**New rows (5):** Capture AI ➖, Evaluate Flags ➖, MCP Analytics ➖ (all three are `server`-scoped
capabilities and RN is not in any of their applicability tables), Exception Event Metadata 🟡
([n7](#n7)), Session Replay Debug Properties ❌ ([n24](#n24)).

**One requirement RN now passes that it previously did not have to:** PR
[#114](https://github.com/PostHog/sdk-specs/pull/114)'s caller-property precedence. Client
`enrichProperties` (`packages/core/src/posthog-core.ts:229-238`) spreads `...userProperties` **last**,
over persisted props, session props, and SDK context, with an explicit comment saying so. The
client/server split is real: the stateless base still stamps common properties last
(`posthog-core-stateless.ts:627-631`), which is the documented server order. Capture stays 🟡 only
on its pre-existing empty-event-name gap.

**Also passing on first contact:** the refused-connection rule from PR
[#110](https://github.com/PostHog/sdk-specs/pull/110) — `isRetryableFlagsFetchError`
(`posthog-core-stateless.ts:208-221`) excludes `ECONNREFUSED`. RN inherits node's clean pass here.

## Matrix

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Alias | 🟡 | [n1] |
| 2 | Application Lifecycle | 🟡 | [n2] |
| 3 | Autocapture | 🟡 | [n3] |
| 4 | Before Send Hook | ✅ | |
| 5 | Bootstrap | 🟡 | [n4] |
| 6 | Capture | 🟡 | [n5] |
| 7 | Capture AI | ➖ | |
| 8 | Capture Exception | ✅ | [n33] |
| 9 | Consent Gating | ✅ | |
| 10 | Create Person Profile | ✅ | |
| 11 | Debug | ✅ | |
| 12 | Device ID Generator | 🟡 | [n6] |
| 13 | Evaluate Flags | ➖ | |
| 14 | Event Batcher | ✅ | |
| 15 | Exception Event Metadata | 🟡 | [n7] |
| 16 | Exception Steps | ✅ | |
| 17 | Feature Flag Cache | ✅ | |
| 18 | Feature Flag Called Tracker | ✅ | [n8] |
| 19 | Flag Definition Loader | ➖ | |
| 20 | Flush | 🟡 | [n9] |
| 21 | Get Anonymous ID | ✅ | |
| 22 | Get Distinct ID | ✅ | |
| 23 | Get Feature Flag | ✅ | |
| 24 | Get Feature Flag Payload | 🟡 | [n10] |
| 25 | Get Feature Flag Result | 🟡 | [n11] |
| 26 | Get Feature Flags | ✅ | |
| 27 | Get Feature Flags And Payloads | 🟡 | [n12] |
| 28 | Get Session ID | ✅ | |
| 29 | Group | 🟡 | [n13] |
| 30 | Group Identify | 🟡 | [n14] |
| 31 | HTTP Client | 🟡 | [n15] |
| 32 | Identify | 🟡 | [n16] |
| 33 | Is Feature Enabled | ✅ | |
| 34 | Is Opt Out | ❌ | [n17] |
| 35 | Is Session Replay Active | ✅ | [n18] |
| 36 | Local Feature Flag Evaluator | ➖ | |
| 37 | Logs | 🟡 | [n19] |
| 38 | MCP Analytics | ➖ | |
| 39 | On Feature Flags | 🟡 | [n20] |
| 40 | Opt In | ✅ | [n32] |
| 41 | Persistent Storage | 🟡 | [n21] |
| 42 | Register | ✅ | |
| 43 | Reload Feature Flags | ✅ | |
| 44 | Remote Config | ✅ | |
| 45 | Reset | ✅ | |
| 46 | Reset Group Properties For Flags | ✅ | |
| 47 | Reset Person Properties For Flags | ✅ | |
| 48 | Retry Queue | 🟡 | [n22] |
| 49 | Screen | 🟡 | [n23] |
| 50 | Session Manager | ✅ | |
| 51 | Session Replay Debug Properties | 🟡 | [n24] |
| 52 | Session Replay Ingestion Controls | 🟡 | [n25] |
| 53 | Session Replay Privacy | ✅ | [n26] |
| 54 | Set Group Properties For Flags | ✅ | |
| 55 | Set Person Properties | ✅ | |
| 56 | Set Person Properties For Flags | ✅ | |
| 57 | Setup | 🟡 | [n27] |
| 58 | Shutdown | 🟡 | [n28] |
| 59 | Start Session Recording | ✅ | |
| 60 | Stop Session Recording | 🟡 | [n29] |
| 61 | Surveys | 🟡 | [n30] |
| 62 | Traces | ❌ | [n31] |
| 63 | Tracing Headers | ✅ | |
| 64 | Unregister | ✅ | |

## Notes

### n1 — Alias (🟡 Partial)
- **Spec requires:** `both`. Acceptance scenario "Alias is dropped when required identities are missing" (`acceptance/public/alias.feature`, `@both`): if either the current distinct id or the alias target is missing/empty, drop the call — zero enqueued events, a validation warning logged.
- **SDK currently:** Unchanged from the previous audit, re-read at this commit. `alias()` (`packages/core/src/posthog-core.ts:458-469`) gates only on `_requirePersonProcessing`, then calls `aliasStateless()` (`posthog-core-stateless.ts:671-690`), which builds and enqueues `$create_alias` with no emptiness check on either `alias` or `distinctId`. RN adds no override. Same shared-core defect as posthog-node n4.
- **Backwards compatibility:** Backward-compatible — an early return with a warning only changes calls that today enqueue a malformed event.
- **Remediation:** Add a presence/emptiness guard in `posthog-core.ts`'s `alias()`. One fix in `@posthog/core` remediates react-native, browser, and node.

### n2 — Application Lifecycle (🟡 Partial)
- **Spec requires:** Install/update detection against persisted version/build with `previous_version`/`previous_build`; `Application Opened` commonly carrying a `from_background` flag; no repeated `Application Backgrounded` while already backgrounded; install/update markers survive `reset()`.
- **SDK currently:** `captureAppLifecycleEvents()` (`packages/react-native/src/posthog-rn.ts:3290-3340`). Install/update detection and the `reset()` preservation of the installed markers are correct. Two of the three previously-recorded gaps persist at this commit: (1) `Application Opened` (`:3325`) still carries no `from_background` — grep for `from_background` across `packages/react-native/src` returns zero hits; (2) the `AppState` listener that fires `Application Backgrounded` (`:3334`) still has no "already backgrounded" de-dup guard. The listener-leak observation from the previous audit is unchanged and remains a documented, deliberate tradeoff rather than a spec violation, so it is no longer counted as a gap.
- **Backwards compatibility:** Backward-compatible — adding a boolean property and a de-dup flag are additive/internal.
- **Remediation:** Add `from_background` to `Application Opened`/`Application Became Active`; track an `isInBackground` flag and skip the redundant emission.

### n3 — Autocapture (🟡 Partial)
- **Spec requires:** Walk element ancestry on a touch/click, build a sanitized `$elements` array, emit `$autocapture` with `$event_type` and screen context; respect no-capture markers; never capture sensitive control values.
- **SDK currently:** `packages/react-native/src/autocapture.tsx` (273 lines), dispatched from `PostHogProvider`'s `onTouchEndCapture` into `posthog.autocapture(eventType, elements, …)` (`:267`). `ph-no-capture` is correctly honoured per ancestor (`:177`, configurable via `noCaptureProp`). **Improved since the last audit:** `eventType` is no longer a hardcoded literal — it is now a typed `'touch' | 'click'` parameter (`:127`, `:143`). Its `'touch'` default is correct: `autocapture/spec.md:98` requires `$event_type: touch` for mobile taps and reserves `click` for browser clicks, including React Native Web. **Unchanged gap:** no defence-in-depth for secure/password inputs — grep for `secure`/`password` across `autocapture.tsx` still returns zero hits; only the generic `propsToCapture` allowlist (`:150`) gates capture, with no explicit exclusion for a `TextInput` with `secureTextEntry`.
- **Backwards compatibility:** Backward-compatible — a `secureTextEntry` skip is purely additive.
- **Remediation:** Keep the `'touch'` default for native taps. Add an unconditional skip for `secureTextEntry`/password-like props regardless of `propsToCapture`.

### n4 — Bootstrap (🟡 Partial)
- **Spec requires:** Apply bootstrap identity only when no persisted identity exists; reconcile explicitly on conflict; bootstrapped flags/payloads SHALL take precedence over flags persisted from a previous session; SDKs owning a session manager MAY accept a bootstrapped `sessionID`.
- **SDK currently:** `setupBootstrap()` (`packages/core/src/posthog-core.ts:97-146`), called from `posthog-rn.ts:562`. The no-overwrite guards (`:105-121`) are correct. Both previously-recorded gaps persist verbatim at this commit: (1) no reconciliation branch — a bootstrapped id that conflicts with a persisted one is silently skipped with no warning; (2) the flag merge at `:135-140` is `{ ...normalizedBootstrapFeatureFlagDetails.flags, ...currentFeatureFlagDetails.flags }`, so **previously-persisted flags win over the fresh bootstrap value** — the inverse of the spec. The `Bootstrap` config type still has no `sessionId` field even though RN owns a real session manager (`getSessionId()` override, `posthog-rn.ts:1654+`).
- **Backwards compatibility:** Backward-compatible — reversing a spread order, adding a warning branch, and adding an optional field are all non-breaking, though the merge-order reversal is an observable behaviour change worth a changelog note.
- **Remediation:** Swap the merge order so bootstrap wins; add a conflict warning; add an optional UUIDv7 `sessionId` to the bootstrap config.

### n5 — Capture (🟡 Partial)
- **Spec requires:** `both`. Enrich with distinct id/timestamp/uuid/`$lib`/super properties/`$groups`; silent drop on opt-out with no network call; validate that `event` is non-empty; run the `before_send` chain with exceptions logged.
- **SDK currently:** Enrichment, opt-out gating, and the before-send chain are all correct and were re-read at this commit. **Property precedence is now correct** per PR [#114](https://github.com/PostHog/sdk-specs/pull/114): `enrichProperties` (`packages/core/src/posthog-core.ts:229-238`) spreads `...userProperties` after persisted props, session props, and SDK context, and `mergeCommonEventProperties` is overridden on the client (`:242-247`) to fill gaps rather than overwrite the caller — the opposite of the stateless base's server order. RN's `getCommonEventProperties()` override (`posthog-rn.ts:763-770`) layers screen/app properties without breaking that. **Remaining gap, unchanged:** nothing in `capture()`, `captureStateless()`, or `buildPayload()` validates that `event` is a non-empty string — an empty-string event name is enqueued and sent. Same shared-core gap as posthog-node n5.
- **Backwards compatibility:** Backward-compatible — rejecting an empty event name with a warning is additive.
- **Remediation:** Add a non-empty-string check for `event` at the top of `captureStateless()` in `@posthog/core`, logging and returning early.

### n6 — Device ID Generator (🟡 Partial)
- **Spec requires:** A stable, independently-generated device identifier distinct from the anonymous/distinct id, surviving `reset()` by default.
- **SDK currently:** `getDeviceId()` (`packages/react-native/src/posthog-rn.ts:1477+`). Unchanged behaviour at this commit: the device id is lazily seeded by **copying the current `getAnonymousId()` value** rather than being generated independently, so on a fresh install the device id and anonymous id are the same value and the two identifiers are not independent as the spec intends. `PostHogPersistedProperty.DeviceId` is a react-native-only property, so this is a first-class contract here rather than N/A.
- **Backwards compatibility:** Needs deprecation path — changing the seeding strategy re-keys existing installs' device ids, so it has to ship behind a migration that keeps the already-persisted value for existing users and only changes the generation path for new installs.
- **Remediation:** Generate the device id from the UUIDv7 generator independently at first use; keep any already-persisted value untouched so existing installs do not re-key.

### n7 — Exception Event Metadata (🟡 Partial)
- **Spec requires:** Canonical `$exception_list` with a `mechanism` on every entry; `exception_id`/`parent_id` linkage; nested entries `type: 'chained'` with a `source`; omit optional fields that cannot be determined rather than writing `false`/`""`/`null`; cycle detection and at most 50 entries; a 1,000-member aggregate inspection budget; and (spec line 314) **application property bags MUST NOT override SDK-owned `$exception_list`, `$exception_level`, `$exception_source`, or `$debug_images`**.
- **SDK currently:** Audited from scratch on 2026-10-19; line references re-read at `210bf35d8` for the plugin 3.0 re-audit, with the same findings. `ErrorPropertiesBuilder.convertToExceptionList` (`packages/core/src/error-tracking/error-properties-builder.ts:119-159`) is substantially correct: `exception_id` is the entry index with `0` outermost, `parent_id` links nested entries, nested entries get `type: 'chained'` with `source: 'cause'` or `'member'`, `handled` is **not** copied onto nested entries, and `synthetic` is omitted when the coercer could not determine it. `MAX_EXCEPTIONS = 50` (`:20`) and `MAX_AGGREGATE_MEMBER_INSPECTIONS = 1000` (`:21`) are both enforced with a `seen` set for cycle detection (`:194`, `:212`, `:216`) — the spec's two numeric bounds are implemented exactly. RN's own integrations supply real metadata: `{ type: 'onuncaughtexception', handled: false }` (`packages/react-native/src/error-tracking/index.ts:419`) and `{ type: 'onunhandledrejection', handled: false }` (`:565-566`), and the fatal path passes `$exception_level: 'fatal'` (`posthog-rn.ts:493`). **Three gaps:** (1) no `$exception_source` is emitted anywhere — grep across `packages/core/src/error-tracking` and `packages/react-native/src` returns zero hits for the property; (2) `buildFromUnknown` hardcodes `$exception_level: 'error'` (`error-properties-builder.ts:55`), so the level is a fixed literal on every path except RN's fatal override rather than being derived from the boundary; (3) `captureExceptionInternal` merges as `{ ...exceptionProperties, ...finalAdditional }` (`posthog-rn.ts:2585-2600`), and core's `captureException` does the same (`posthog-core.ts:1431-1438`), so the **caller's generic property bag overrides SDK-owned `$exception_list` and `$exception_level`** — directly contrary to spec line 314. Gaps (1)–(3) are shared with posthog-node and posthog-js through the same `@posthog/core` package. #205's handled-state rule for framework job retries has nothing to apply to in RN, which has no job integration.
- **Backwards compatibility:** Backward-compatible for (1) and (2) — adding a property and deriving a level from the boundary are additive. **Needs deprecation path** for (3): callers may today rely on passing `$exception_level` through the property bag, and the spec itself asks for documented *typed* overrides instead, so the typed channel has to land before the generic one is ignored.
- **Remediation:** Emit `$exception_source` from the capture boundary; derive `$exception_level` from the boundary (fatal/error) rather than a literal; add typed `level`/`source`/`mechanism` override parameters, then stop letting the generic property bag win for the reserved keys. One fix in `@posthog/core` covers react-native, browser, and node.

### n8 — Feature Flag Called Tracker (✅ Pass)
- **Spec requires:** Dedupe `$feature_flag_called` per (flag, value), re-fire on value change, clear on `reset()` and shutdown, and honour the minimal-envelope allowlist.
- **SDK currently:** Re-read at this commit. The tracker (`flagCallReported`, `packages/core/src/posthog-core.ts:62`, read at `:1047`, written at `:1079-1080`) dedupes per `(flag, value)` correctly and is cleared on both `reset()` (`:151`) and `_shutdown()` (`:209`, in a `finally`). The minimal-envelope path is implemented in the stateless base (`minimizeFlagCalledEventProperties`, applied at `posthog-core-stateless.ts:569-575`). The gate is wired on the client too: the `/flags` handler stores `minimalFlagCalledEvents: res.minimalFlagCalledEvents === true` with the flag details (`packages/core/src/posthog-core.ts:894-900`), and `PostHogCore` overrides `isMinimalFlagCalledEventsEnabled()` to read that persisted field (`:967-968`), so react-native produces the minimal envelope when the project is gated into it. The previous audit's "gate never persisted" finding no longer holds at this commit. **Re-scored ✅ this run.**
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

### n9 — Flush (🟡 Partial)
- **Spec requires:** `both`. No-op on an empty queue; bypass batching timers; **on delivery failure the failed batch must remain queued for a later retry, not silently dropped** (the acceptance scenario simulates an HTTP 503 explicitly).
- **SDK currently:** `flush()` → `flushInternal(false)` (`packages/core/src/posthog-core-stateless.ts`), correct on the empty-queue and multi-batch-drain paths. **Gap, re-confirmed verbatim at this commit:** in the send catch handler (`posthog-core-stateless.ts:1735-1739`) the guard is `if (!(err instanceof PostHogFetchNetworkError)) { await persistQueueChange() }` — `persistQueueChange()` (`:1683-1708`) evicts the just-sent batch. A persistent 503 that exhausts the retry budget throws a `PostHogFetchHttpError`, not a network error, so the batch is evicted **as if delivered**. Only genuine network-level failures preserve the queue. The code comment explains the intent (avoid an endless loop on a permanently-malformed batch) but the classification is too coarse: it cannot distinguish "terminal 4xx" from "retryable-but-exhausted 5xx". RN's `flush()` drains the events pipeline only; logs are a separate pipeline (see [n19](#n19)).
- **Backwards compatibility:** Backward-compatible — narrowing the eviction condition to terminal (non-retryable) errors is internal.
- **Remediation:** In the catch handler, call `persistQueueChange()` only when the error is **not** retryable (`isPostHogFetchRetryableError` already exists at `posthog-core-stateless.ts:268`); keep the batch queued otherwise, bounded by the existing queue-size cap.

### n10 — Get Feature Flag Payload (🟡 Partial)
- **Spec requires:** `openspec/specs/get-feature-flag-payload/spec.md:163-169` — when a payload is serialized JSON the SDK SHALL decode it; **if decoding fails (including empty or whitespace-only input) the SDK SHALL return the known-flag/no-payload sentinel and MUST NOT return the raw string**, and parse failures SHALL be logged through SDK diagnostics. For JavaScript the malformed-payload result SHALL be `null`, not `undefined`.
- **SDK currently:** **Downgraded from ✅ this run on new spec text; the code is unchanged.** `getFeatureFlagPayload(key)` (`packages/core/src/posthog-core.ts:1110-1113`) reads `.payload` off the flag result, which is decoded by the shared `parsePayload` (`packages/core/src/featureFlagUtils.ts:109-119`):
  ```ts
  try { return JSON.parse(response) } catch { return response }
  ```
  On a decode failure it returns the **raw malformed string** to the caller and logs nothing — both halves of the requirement are missed. This is the same defect class that moved posthog-ios and posthog-go rows in earlier runs; here it is in shared `@posthog/core`, so posthog-js and posthog-node share it.
- **Backwards compatibility:** Needs deprecation path — a caller currently receiving the raw string back (and parsing it themselves, or treating it as a string payload) would start receiving `null`. The spec is explicit that the raw string is not a permitted result, so the change should land with a release note and ideally one release of a logged warning before the return value changes.
- **Remediation:** In `parsePayload`, return `null` on `JSON.parse` failure and log through the SDK logger; keep the non-string early return so already-decoded payloads are not double-parsed.

### n11 — Get Feature Flag Result (🟡 Partial)
- **Spec requires:** The structured result's `payload` field follows the same decoding contract as the standalone payload getter.
- **SDK currently:** **Downgraded from ✅ this run on new spec text; the code is unchanged.** `_getFeatureFlagResult` builds its `payload` from the same `parsePayload` helper described in [n10](#n10), so a malformed serialized payload surfaces on the result object as the raw string. The flag value, reason, and `$feature_flag_called` reporting on the result path are all correct.
- **Backwards compatibility:** Needs deprecation path — same reasoning and same single fix as [n10](#n10).
- **Remediation:** Fixing `parsePayload` closes this row, [n10](#n10), and [n12](#n12) together.

### n12 — Get Feature Flags And Payloads (🟡 Partial)
- **Spec requires:** The bulk map's payload values follow the same decoding contract, and SHALL agree with the single-key accessor.
- **SDK currently:** **Downgraded from ✅ this run on new spec text; the code is unchanged.** The bulk getter is correctly present and correctly shaped — the row's previous ✅ was about surface, which still holds — but it fills payload values through the same `parsePayload`, so a malformed payload appears as a raw string here too. The bulk map and the single-key accessor are at least *consistent* with each other, which is better than posthog-ruby's confirmed disagreement, but both are consistently wrong.
- **Backwards compatibility:** Needs deprecation path — same reasoning and same single fix as [n10](#n10).
- **Remediation:** As [n10](#n10).

### n13 — Group (🟡 Partial)
- **Spec requires:** Persist the group association, reload flags when the key changes, emit `$groupidentify` when new or when properties are supplied, and drop calls with a missing/empty group type or key with a warning.
- **SDK currently:** Re-read at this commit. `group()` (`packages/core/src/posthog-core.ts:513-534`) gets the persistence, the change detection, and the conditional `groupIdentify()` right. **Gap, unchanged:** zero validation of `groupType`/`groupKey` — a blank string is silently persisted into `$groups` and forwarded. RN's override (`posthog-rn.ts`) adds group-property caching for flag evaluation but calls `super.group()` first and adds no validation of its own.
- **Backwards compatibility:** Backward-compatible — an early return with a warning only affects calls that today persist a malformed association.
- **Remediation:** Validate both arguments at the top of `group()` in `@posthog/core`; one fix covers react-native, browser, and node.

### n14 — Group Identify (🟡 Partial)
- **Spec requires:** A standalone `groupIdentify()` emitting `$groupidentify` with `$group_type`/`$group_key`/`$group_set`; drop calls with a missing/empty type or key.
- **SDK currently:** Re-read at this commit. The standalone public method exists (`packages/core/src/posthog-core.ts:536-551`), is inherited unmodified by react-native, is correctly gated by `_requirePersonProcessing`, and builds the correct event shape via `groupIdentifyStateless()`. **Gap, unchanged:** no emptiness validation in either method, so an empty key still enqueues a malformed `$groupidentify`.
- **Backwards compatibility:** Backward-compatible — as [n13](#n13).
- **Remediation:** One shared validation helper used by both `group()` and `groupIdentify()`.

### n15 — HTTP Client (🟡 Partial)
- **Spec requires:** Platform-appropriate transport; gzip where supported; a `/flags` retry policy that retries transient transport conditions but **not** a refused connection (PR [#110](https://github.com/PostHog/sdk-specs/pull/110)); and an exponential retry schedule whose first retry is not sent before 300 ms and whose second is not sent before 600 ms after the first.
- **SDK currently:** RN's transport override is a one-line passthrough to global `fetch`. gzip is correctly gated off for react-native (`packages/core/src/gzip.ts`, `isGzipSupported()` notes RN lacks `CompressionStream`). **Refused-connection classification is correct and passes on first contact:** `isRetryableFlagsFetchError` (`posthog-core-stateless.ts:208-221`) returns `code !== 'ECONNREFUSED'` for network errors and otherwise retries only 502/504. **Gap, re-confirmed verbatim:** `retriable()` (`packages/core/src/utils/index.ts`) waits a **fixed** `props.retryDelay` on every attempt — there is no backoff multiplier in the loop at all — and the `/flags` call site (`posthog-core-stateless.ts:852`) overrides only `retryCount`/`retryCheck`, so it inherits the constructor's fixed `fetchRetryDelay ?? 3000` ms. RN adds no override, so it fails the same two timing scenarios posthog-node n20 fails.
- **Backwards compatibility:** Backward-compatible — changing a fixed delay to an exponential schedule is internal; the only observable effect is earlier first retries.
- **Remediation:** Make `retriable()` compute `retryDelay * 2 ** (i - 1)` (or take an explicit schedule) and set the `/flags` call site's base delay to 300 ms.

### n16 — Identify (🟡 Partial)
- **Spec requires:** Link the anonymous id via `$anon_distinct_id` on first identify; reload flags on identity change; treat a missing/empty distinct id as a no-op with a warning rather than as a property-only update.
- **SDK currently:** Re-read at this commit. The `$anon_distinct_id` handling, the flag reload on change, and the `$set`/`$set_once` extraction are correct, and RN adds a genuinely useful native-bridge identity sync. **Gap, unchanged:** `const idWasSupplied = !!distinctId` (`packages/core/src/posthog-core.ts:361`) collapses `''` and `undefined` into the same branch, so `identify('')` is silently treated as a property-only update instead of being rejected with a warning.
- **Backwards compatibility:** Backward-compatible — distinguishing empty-string from absent, and warning on the former, is additive.
- **Remediation:** Validate `distinctId` explicitly: absent → property-only update (current behaviour); present-but-blank → log a warning and return.

### n17 — Is Opt Out (❌ Fail)
- **Spec requires:** `client`. A callable `isOptOut()` (platform-cased) returning the current consent state — the acceptance scenarios call it as a method.
- **SDK currently:** Re-confirmed at this commit by grep across `packages/core` and `packages/react-native`: **no `isOptOut`/`isOptedOut` method exists anywhere in the monorepo.** The only public surface is the getter property `optedOut` (`packages/core/src/posthog-core-stateless.ts:493-495`), accessed as `sdk.optedOut`. Every other audited client SDK exposes a callable (iOS `isOptOut() -> Bool`, Android `isOptOut(): Boolean`, Flutter `isOptOut(): Future<bool>`). The capability is `client`-scoped, so posthog-node's ➖ carve-out does not apply to react-native, which extends the full client base.
- **Backwards compatibility:** Backward-compatible — adding an `isOptOut(): boolean` method that returns the existing getter is purely additive; the `optedOut` property can stay indefinitely.
- **Remediation:** Add `isOptOut(): boolean { return this.optedOut }` to `PostHogCore` (or `PostHogCoreStateless` behind the client classes), and document `optedOut` as the property alias.

### n18 — Is Session Replay Active (✅ Pass; was 🟡)
- **Spec requires:** A getter reporting whether replay is actively recording *this* session, reflecting the SDK's own ingestion-control decision; an `active` `$recording_status` implies the getter is true, and `disabled` implies false (`session-replay-debug-properties`, "Reconciliation with `is-session-replay-active`").
- **SDK currently (plugin 3.0, `210bf35d8`):** `isSessionReplayActive()` (`packages/react-native/src/posthog-rn.ts:2393-2415`) returns `false` when disabled, without the plugin, or when another project's client owns the native session, and otherwise returns the plugin's `isEnabled()`. That now calls `PostHogSDK.shared.isSessionReplayActive()` on iOS (`packages/react-native-plugin/ios/PosthogReactNativePlugin.swift:519-525`) and `PostHog.isSessionReplayActive()` on Android (`PosthogReactNativePluginModule.kt:252-258`), which in posthog-ios 4.0 requires a running recorder and a session (posthog-ios `e27cbe4cb` `PostHogSDK.swift:3977-3989`) and in posthog-android 4.0 is `sessionReplayHandler?.isActive() == true && isSessionActive()` (posthog-android `aaa23d39`, `PostHog.kt:3220-3226`). The 2026-10-19 gap was that the getter never consulted the JS gate. The JS gate now drives the native recorder directly: `_evaluateAndStartSessionReplayInternal` stops it while opted out or after the app stopped replay (`posthog-rn.ts:3620-3650`) and starts it only when the linked-flag and event-trigger gates pass, so a running native recorder means the JS gate passed. `$recording_status` reads the same native state (`:943-947`).
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

### n19 — Logs (🟡 Partial)
- **Spec requires:** An OTLP logs pipeline to `/i/v1/logs` with canonical `AnyValue` encoding (int64 as a string), severity mapping, rate capping, and a global `flush()` that includes the logs queue.
- **SDK currently:** Re-read at this commit. RN genuinely wires the full pipeline — `new PostHogLogs(...)` at `posthog-rn.ts:479`, with `captureLog()`, the `logger` getter, `flushLogs()`, mobile-tuned defaults in `logs-defaults.ts`, an `AppState`-driven background flush, a parallel drain in `_shutdown()`, and logs explicitly preserved across `reset()`. This is materially ahead of posthog-node, which has the transport but never constructs `PostHogLogs`. **Two deviations, both unchanged:** (1) integer `AnyValue` encoding emits raw JSON numbers rather than the canonical stringified int64, and nested objects fall back to `JSON.stringify` rather than a recursive `kvlistValue` (shared-core, identical across node/browser/react-native; the spec notes servers also accept a JSON number, which softens but does not remove the deviation); (2) **RN's public `flush()` drains only the events pipeline** — its own JSDoc at `posthog-rn.ts:977` states logs are flushed via `flushLogs()` — a deliberate design choice that still conflicts with the spec's "global `flush()` SHALL include the logs queue".
- **Backwards compatibility:** Backward-compatible — correcting the encoder is internal; making `flush()` also drain logs only adds work to a call that already awaits I/O.
- **Remediation:** Emit int64 as a string and add recursive `kvlistValue` encoding in `packages/core/src/logs`; have `flush()` await `flushLogs()` alongside the events drain (keeping `flushLogs()` as the narrow variant).

### n20 — On Feature Flags (🟡 Partial)
- **Spec requires:** Multi-subscriber registration, working unsubscribe, and — the scenario this row fails — a listener registered **after** flags have already loaded SHALL still be invoked with the already-known flags.
- **SDK currently:** Re-read verbatim at this commit: `onFeatureFlags()` (`packages/core/src/posthog-core.ts`) is `this.on('featureflags', async () => { const flags = this.getFeatureFlags(); if (flags) cb(flags) })`. The emitter fires only on future `emit()` calls — there is no replay-last-known-value path anywhere in `onFeatureFlags` or `SimpleEventEmitter`. A listener registered on a later screen is not invoked until the next reload. RN's own internal use happens to work only because it registers during init.
- **Backwards compatibility:** Backward-compatible — firing the callback once on registration when flags are already available is additive (a caller that registers before load sees no change).
- **Remediation:** In `onFeatureFlags`, if `getFeatureFlags()` already returns a value, schedule the callback once asynchronously before returning the unsubscribe function. The same fix clears posthog-ios's equivalent finding.

### n21 — Persistent Storage (🟡 Partial)
- **Spec requires:** Durable key/value persistence with failures surfaced through SDK diagnostics, not swallowed.
- **SDK currently:** Re-read at this commit. The implementation is strong: `PostHogRNStorage` (`packages/react-native/src/storage.ts`) keeps a synchronous in-memory cache so core's synchronous accessors never block, debounces and coalesces disk writes, and exposes `waitForPersist()` which is awaited at every durability-sensitive point (flush, `AppState` transitions, shutdown, opt-in/out, identify/reset). Init correctly awaits the preload before touching persisted state. **Gap, matching posthog-ios n19:** every failure path — write failure, scheduled-persist throw, corrupt-read silent reset, preload rejection — reports only through the console/logger and never through the SDK's diagnostics channel, so a host app cannot observe storage failure programmatically.
- **Backwards compatibility:** Backward-compatible — emitting an additional diagnostic event does not change any existing behaviour.
- **Remediation:** Emit a typed storage-failure diagnostic (the existing `_events` emitter) alongside the log line on each failure path.

### n22 — Retry Queue (🟡 Partial)
- **Spec requires:** Retryable failures keep the same events queued for a later attempt; non-retryable failures drop them; bounded queue with oldest-first eviction.
- **SDK currently:** Re-read at this commit. Retryable classification (`isPostHogFetchRetryableError`, `posthog-core-stateless.ts:268-272`), the 413 batch-halving path (`:1724-1732`), and overflow eviction are all correct, and post-flush removal is identity-based (UUID first, object identity as a legacy fallback, `:1683-1703`) — correctly avoiding the "concurrently captured events mistaken for the just-sent batch" failure mode. **Gap:** the same catch-handler classification described in [n9](#n9) — a retryable-but-exhausted 5xx/429 is evicted rather than retained.
- **Backwards compatibility:** Backward-compatible — as [n9](#n9).
- **Remediation:** One fix in the catch handler closes this row and [n9](#n9) together.

### n23 — Screen (🟡 Partial)
- **Spec requires:** Emit `$screen` with `$screen_name`; the explicit `name` argument wins over a caller-supplied `$screen_name` property; honour opt-out.
- **SDK currently:** Re-read at this commit (`posthog-rn.ts:1621-1638`). The payload is `{ ...properties, $screen_name: name }` — the explicit argument correctly wins on collision, the opposite outcome from posthog-ios's confirmed precedence bug and the one place RN is ahead of the mobile SDKs. `registerForSession({ $screen_name: name })` correctly seeds ambient session context. **Gap, unchanged:** `registerForSession` runs **before** any consent check and `screen()` has no `isDisabled`/opt-out guard of its own, relying entirely on `capture()`'s downstream gate — so calling `screen()` while opted out still mutates persisted session properties even though no event is sent.
- **Backwards compatibility:** Backward-compatible — adding the guard only changes behaviour for opted-out callers whose events are already dropped.
- **Remediation:** Check `isDisabled`/`optedOut` at the top of `screen()` and return before `registerForSession`.

### n24 — Session Replay Debug Properties (🟡 Partial; was ❌)
- **Spec requires:** `client`. Required keys (`$recording_status`, the two trigger statuses, `$sdk_debug_replay_internal_buffer_length`) on every non-`$snapshot` event; the optional bundle only on eligible SDK events, at most once per 30 s from acceptance; the queue-depth key on every event; the minimal `$feature_flag_called` envelope stripped; `$sdk_debug_replay_capture_mode` always `screenshot` on mobile (#197); and, per `openspec/specs/session-replay-debug-properties/spec.md:619-623` on `main`, "`$recording_status` and the `$sdk_debug_*` keys are properties the SDK sets itself, so they follow capture's **Caller-supplied event properties take precedence**: a registered (super) property of the same name overrides the SDK-computed value, a caller-supplied event property overrides both".
- **SDK currently (`210bf35d8`):** implemented since the 2026-10-19 audit (in `posthog-react-native`, not the plugin).
  - **Met.** `_sessionReplayDebugProperties()` (`packages/react-native/src/posthog-rn.ts:901-971`) builds every key on each capture from state only, takes `$recording_status`, the hold reason and the buffer length from the native map when known, computes the trigger statuses and pending conditions in JS, reports `$sdk_debug_pending_queue_size`, and sets `$sdk_debug_replay_capture_mode` to `screenshot` whenever the native replay module is present. A build failure keeps the queue depth and attaches only `$sdk_debug_error_capturing_properties` (`:962-968`). `processBeforeEnqueue` (`:3714-3765`) claims the optional bundle for `$`-prefixed events other than `$feature_flag_called` and `$snapshot` before `before_send` (`:3769-3784`), starts the 30 s window only when the event is accepted (`:3787-3795`), strips the debug keys from a minimal `$feature_flag_called` (`:883-892`) and from an event backdated before the session start (`:3833-3840`), and strips the JS snapshot from a fatal exception handed to native, which builds its own (`:3735-3742`).
  - **Gap: SDK values win over registered and caller values.** `_stampReplayDebugProperties` (`:883-896`) spreads the SDK-computed map after the event's properties, and that map writes every owned key, `undefined` when absent. A registered or caller-supplied `$recording_status` or `$sdk_debug_*` value is therefore replaced. The code comment says so: "The replay debug keys are SDK-owned, so they land after the caller's properties".
- **Backwards compatibility:** Backward-compatible — letting registered and caller values win only changes events whose caller set these keys.
- **Remediation:** Fill the debug keys only where the event's properties leave them unset, as the client precedence rule does for other SDK-set values.

### n25 — Session Replay Ingestion Controls (🟡 Partial)
- **Spec requires:** Linked-flag, event-trigger, sample-rate, and minimum-duration gating of replay ingestion, with restrictive (AND) combination on mobile.
- **SDK currently (plugin 3.0, `210bf35d8`):** the JS gates are unchanged: linked flag (all three shapes), event triggers after `before_send`, AND combination, persisted activation per session (`packages/react-native/src/posthog-rn.ts:3600-3615`). The two 2026-10-19 gaps were left to the native SDKs, and plugin 3.0's native SDKs implement both. RN validates the sample rate and passes it to native (`:3270-3305`; `packages/react-native-plugin/ios/PosthogReactNativePlugin.swift:409`, `PosthogReactNativePluginModule.kt:178`). posthog-ios 4.0 samples on the session id, with the local rate winning over the remote one, and buffers until the minimum duration is met (posthog-ios `e27cbe4cb` `PostHog/Replay/PostHogReplayIntegration.swift:463-470`, `:641-649`); posthog-android 4.0 keeps the session-keyed sampling decision (`shouldRecordSession`, posthog-android `aaa23d39` `PostHog.kt:3228`) and reports `below_minimum_duration` holds (`PostHogReplayIntegration.kt:3007`). posthog-android's own 🟡 on this row (event triggers matched on the pre-hook name) doesn't reach RN, whose triggers are matched in JS after `before_send`. **Gap:** without a local `sessionReplayConfig.sampleRate`, RN passes the project rate from the cached remote config (`posthog-rn.ts:3270-3284`) as the native SDK's local rate, and both native SDKs prefer a local rate over their fresh remote one (posthog-ios `PostHogReplayIntegration.swift:462-470`; posthog-android `PostHogRemoteConfig.kt:1464-1467`). Once native is set up RN doesn't reconfigure it (`posthog-rn.ts:3192-3198`, `:3650-3652`), so a project rate changed from 1 to 0 keeps sampling sessions in until the next launch, as RN's own log says (`:3313-3314`). The spec requires re-deciding when the sample rate changes.
- **Backwards compatibility:** Backward-compatible — following the current project rate is what an app without a local rate already expects.
- **Remediation:** Pass native only the app's local rate and let native read the project rate from its own remote config, or re-send the rate when remote config changes.

### n26 — Session Replay Privacy (✅ Pass; was 🟡)
- **Spec requires:** Mask text inputs, images, and sandboxed/secure views by default; honour `ph-no-capture` containers including their children; explicit unmask markers take precedence over explicit mask markers where an SDK offers both.
- **SDK currently (plugin 3.0, `210bf35d8`):** RN passes `maskAllTextInputs`, `maskAllImages` and `maskAllSandboxedViews`, all defaulting to `true`, and the plugin copies them onto the native config (`packages/react-native-plugin/ios/PosthogReactNativePlugin.swift:389-396`, `PosthogReactNativePluginModule.kt:166-177`). `PostHogMaskView` sets `accessibilityLabel="ph-no-capture"` (`packages/react-native/src/PostHogMaskView.tsx:42`). The 2026-10-19 🟡 came from posthog-ios's default wireframe mode recording the children of a `ph-no-capture` container. posthog-ios 4.0 and posthog-android 4.0 record masked screenshots only, so that path is gone. Both mask a `ph-no-capture` view and everything inside it: posthog-ios passes `maskChildren || view.isNoCapture()` down the walk (posthog-ios `e27cbe4cb` `PostHog/Replay/PostHogReplayIntegration.swift:917`, `:1077`), and posthog-android uses `insideNoCapture` (posthog-android `aaa23d39` `PostHogReplayIntegration.kt:1603-1606`, `:2875-2878`). An unmask marker winning or losing against a mask marker can't arise here, because RN has no unmask marker.
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

### n27 — Setup (🟡 Partial)
- **Spec requires:** `openspec/specs/setup/spec.md:163` and `:179` — the configuration option carrying the project token SHALL be named `projectToken` (platform-cased). An SDK still naming it `apiKey` SHALL **add `projectToken` and keep `apiKey` as a deprecated alias in the same release**, so the rename needs no major version; where a surface accepts both at once, `projectToken` SHALL win. The spec names React Native's `PostHogProvider` `apiKey` prop explicitly as one of two client SDKs that have not adopted it.
- **SDK currently:** **Downgraded from ✅ this run on new spec text (PR [#108](https://github.com/PostHog/sdk-specs/pull/108)); the code is unchanged.** `PostHogProvider`'s props still declare only `apiKey?: string` (`packages/react-native/src/PostHogProvider.tsx:25`), consumed at `:132` and `:157` (`new PostHog(apiKey ?? '', parsedOptions)`), with the JSDoc example at `:85` still showing `apiKey`. Grep for `projectToken` across `packages/react-native/src` returns zero hits. The positional `new PostHog(apiKey, options?)` constructor is explicitly **out** of scope per the spec ("their parameter name is not part of the contract"), so the provider prop is the whole of this finding.
- **Backwards compatibility:** Backward-compatible — the spec itself prescribes the non-breaking shape: add `projectToken`, keep `apiKey` as a deprecated alias in the same release, `projectToken` wins when both are passed.
- **Remediation:** Add `projectToken?: string` to `PostHogProviderProps`; resolve as `projectToken ?? apiKey`; mark `apiKey` `@deprecated` in TSDoc naming `projectToken` as the replacement, and log a warning when the alias is used; update the JSDoc example. Removal of `apiKey` is a later-major concern only.

### n28 — Shutdown (🟡 Partial)
- **Spec requires:** Flush pending work, then refuse further captures — events captured after shutdown SHALL NOT be enqueued.
- **SDK currently:** Re-read at this commit. The flush half is correct and RN's `_shutdown()` override is genuinely good: it drains the events and logs pipelines in parallel, clears exception-steps state, and bounds the logs flush to the smaller of the caller timeout and the configured termination budget; the `shutdownPromise` guard (`posthog-core-stateless.ts:2095-2104`) makes a concurrent second call safe. **Gap, unchanged and shared with posthog-node n15:** neither `shutdown()` nor `_shutdown()` ever sets a lasting "closed" flag. The only gates `enqueue()`/`sendImmediate()` check are the construction-time `disabled` option and the dynamic `optedOut` flag, so a `capture()` after `shutdown()` resolves is enqueued into a queue nothing will drain.
- **Backwards compatibility:** Backward-compatible — a post-shutdown capture is already lost; dropping it with a warning instead of silently queueing it is strictly clearer.
- **Remediation:** Set a `_hasShutdown` flag in `_shutdown()`'s `finally` and check it in `enqueue()`/`sendImmediate()`, logging a warning and returning.

### n29 — Stop Session Recording (🟡 Partial)
- **Spec requires:** Stop recording and finalize/flush any buffered replay data rather than discarding it.
- **SDK currently (plugin 3.0, `210bf35d8`):** `stopSessionRecording()` (`packages/react-native/src/posthog-rn.ts:2319-2332`) records that the app no longer wants replay (only while opted in) and calls the plugin's `stopRecording()` (`:2338-2372`), which calls `PostHogSDK.shared.stopSessionRecording()` on iOS (`packages/react-native-plugin/ios/PosthogReactNativePlugin.swift:615-622`) and `PostHog.stopSessionReplay()` on Android (`PosthogReactNativePluginModule.kt:391-399`). posthog-ios 4.0 flushes the replay queue after stopping (`replayQueue?.flush()`, posthog-ios `e27cbe4cb` `PostHogSDK.swift:3900-3918`). posthog-android 4.0 still doesn't: `stopSessionReplay()` only calls the handler's `stop()` (posthog-android `aaa23d39` `PostHog.kt:3298-3313`), and `stopRecording` clears capture state and sets the integration inactive with no replay-queue flush (`PostHogReplayIntegration.kt:2967-2987`). RN adds no flush of its own, so Android apps inherit the gap.
- **Backwards compatibility:** Backward-compatible — flushing before stopping is additive.
- **Remediation:** Flush the replay queue in posthog-android's `stopSessionReplay()`; optionally have RN await a bridged flush before resolving `stopSessionRecording()`.

### n30 — Surveys (🟡 Partial)
- **Spec requires:** Load definitions from remote config; exclude web-only-conditioned surveys on non-web SDKs; enforce eligibility (active status, device type, seen/repeat, wait period, linked/targeting flags); a single active prompt; emit `survey shown`/`sent`/`dismissed` (and `abandoned` where supported); do not display to an opted-out user.
- **SDK currently:** Re-read at this commit. A full display implementation in `packages/react-native/src/surveys/`, wired through `PostHogSurveyProvider` and `posthog-rn.ts`'s `getSurveys()`/`_handleSurveysFromRemoteConfig`. Web-only conditions (`conditions.url`/`conditions.selector`) are correctly and unconditionally excluded; eligibility covers active status, device type, seen/repeat, and linked/targeting/internal flags; the single-active-prompt rule is enforced by a single `activeSurvey` slot; the three core events carry dual-format response keys. **One gap is now fixed:** the display path gates on consent — `canCaptureSurvey(posthog)` (`surveys/survey-progress.ts:133-135`, `!posthog.optedOut && !posthog.isDisabled`) is checked at four points in `PostHogSurveyProvider.tsx` (`:179`, `:256`, `:274`, `:292`), closing the previous audit's "survey can still visually display to an opted-out user" finding. **Two gaps remain:** (1) no `"survey abandoned"` event anywhere in the codebase — the spec's "where supported" makes this allowed-but-real rather than a hard failure; (2) the wait-period repeat rule is still **commented out** — `getActiveMatchingSurveys.ts:54` is a commented `const surveyWaitPeriodInDays = survey.conditions?.seenSurveyWaitPeriodInDays`, so a configured `seenSurveyWaitPeriodInDays` has no effect and a dismissed survey can re-prompt sooner than configured.
- **Backwards compatibility:** Backward-compatible — honouring a condition that is already in the definition payload, and emitting an additional event, are both additive.
- **Remediation:** Uncomment and implement the wait-period check against the persisted last-seen timestamp (note sdk-specs PR [#102](https://github.com/PostHog/sdk-specs/pull/102): the period starts when the survey is *shown*); add `"survey abandoned"` on provider teardown with a partially-completed survey.

### n31 — Traces (❌ Fail)
- **Spec requires:** An OTLP span pipeline to `/i/v1/traces` with W3C `traceparent`/`tracestate` interop, the spec's configuration knobs at the spec's defaults, and spec-conformant retry classification.
- **SDK currently:** **Still unimplemented for react-native — but the shared machinery now exists, which materially changes the remediation.** Since the previous RN audit, `packages/core/src/traces/` has landed (PR [posthog-js#4579](https://github.com/PostHog/posthog-js/pull/4579), 2026-09-10): a full span/OTLP implementation (`span.ts`, `otlp.ts`, `traceparent.ts`, `ids.ts`, `config.ts`, `context.ts`, `sanitize.ts`), exported as `PostHogTraces` from `packages/core/src/index.ts:91`, with the transport `_sendTracesBatch` living on `PostHogCoreStateless` (`:1873`) — the very base class react-native extends. It is wired up only in `packages/node` (`packages/node/src/client.ts:155`, `:698-703`). Grep across `packages/react-native/src` for `traces`, `startSpan`, or `otlp` returns zero functional hits: react-native never constructs `PostHogTraces`, so it has the engine and the transport but no public span API.
- **Backwards compatibility:** Backward-compatible — adding a span API is purely additive.
- **Remediation:** Construct `PostHogTraces` in `posthog-rn.ts` the way `packages/node/src/client.ts:698-703` does, resolve the traces config through `packages/core/src/traces/config.ts`, expose the public span surface, and drain it from `_shutdown()` alongside events and logs. Because the transport is already on the shared base and RN already supplies a `fetch`, this is wiring rather than new subsystem work.

**Correction carried out of this audit (affects posthog-node, not react-native):** the 2026-10-12
posthog-node audit recorded Traces as ❌ with "no OTLP `/i/v1/traces` pipeline anywhere in the
monorepo". That was a false negative — the pipeline merged on 2026-09-10, four weeks before that
audit, and node is the one package that wires it. See the matching entry in
[README.md](README.md) and [posthog-node.md](posthog-node.md#n2).

### n32 — Opt In (✅ Pass)
- **Spec requires:** (`openspec/specs/opt-in/spec.md` on `main`) **#138** (`:143-251`): a mobile client SDK, React Native included, that stops replay while opted out SHALL start a new session before replay restarts on opt-in; "Where a wrapper owns the session id rather than the native SDK, the wrapper SHALL perform the rotation"; the restart follows whether the app wanted replay at opt-out (configured, or started with `startSessionRecording()` and not stopped since), not whether it was recording; a start or stop made while opted out doesn't change that; an app that launches opted out with replay enabled records on its first opt-in. **#199** (`:253-299`, and `optOut` step 5): React Native "through the native SDK" SHALL decide whether to send a crash reconstructed on a later launch from the consent state at crash time. A report recorded while opted out is never sent; a report recorded while opted in, found by an opted-out launch, stays in place and is delivered once the user opts in. Data accepted while opted in stays deliverable after opt-out.
- **SDK currently (`210bf35d8`):**
  - **Replay restart (#138).** RN owns the session id, and posthog-ios's own rotation is "a no-op under React Native, which owns the session id" (posthog-ios `e27cbe4cb` `PostHogSDK.swift:3651-3655`). `optIn()` (`packages/react-native/src/posthog-rn.ts:1474-1500`) rotates the session in JS and moves native onto it (`_rotateReplaySession`, `:2225-2233`) before native opts in, whenever the app wanted replay, then re-evaluates replay against the gates. Intent is `_sessionReplayWanted`: set from `enableSessionReplay` at setup (`:487`), set by `startSessionRecording()` (`:2134-2139`) and cleared by `stopSessionRecording()` (`:2319-2325`) only while opted in. `optOut()` (`:1519-1557`) stops replay and keeps that intent. An app that launches opted out has `_sessionReplayWanted` from its configuration, and its first `optIn()` takes the same path.
  - **Deferred crash reports (#199).** JS owns consent and hands it to native: setup passes `optOut` with `persistOptOut = false` (`packages/react-native-plugin/ios/PosthogReactNativePlugin.swift:422-425`, `PosthogReactNativePluginModule.kt:128-133`), and `optOut()`/`optIn()` call the native `optOut()`/`optIn()` (`_propagateNativeOptOut`, `posthog-rn.ts:1562-1576`; `PosthogReactNativePlugin.swift:590-598`, `PosthogReactNativePluginModule.kt:330-338`). Native comes up opted out on an opted-out launch when native crash capture, push or fatal JS capture is on (`posthog-rn.ts:3587-3588`). posthog-ios 4.0 uninstalls its integrations on `optOut()` (`PostHogSDK.swift:3701-3722`); the crash integration then marks the crash context (`markOptedOut()`, which also replaces the saved identity and properties, `PostHog/ErrorTracking/PostHogErrorTrackingAutoCaptureIntegration.swift:119-127`, `PostHogExceptionStepsBuffer.swift:158-161`), and the next install drops a marked report (`:267-270`). Pending reports are processed only on install, which runs only while opted in, so a consented report waits for opt-in. posthog-android 4.0 records opt-out intervals at an opted-out setup and on `optOut()` (`PostHogAndroid.kt:151-159`; `PostHogNativeCrashIntegration.kt:170-174`), closes them on install, and drops a native crash whose exit time falls in one (`:396-401`); its scan runs only from install, so a consented crash waits for opt-in. Fatal JS crashes handed to native are captured in-process and gated at capture time: JS skips native capture while opted out (`_isFatalJsCaptureNativeEnabled`, `posthog-rn.ts:3102-3107`), and posthog-ios rejects the call while opted out (`PosthogReactNativePlugin.swift:655-663`). Opt-out clears neither queue: core `optOut()` only persists the flag and the JS queue stays (`packages/core/src/posthog-core-stateless.ts:508-512`), and the native queues are kept (`posthog-rn.ts:1541-1545`).
  - Read from code; the acceptance scenarios were not run.
- **Backwards compatibility:** No change needed.
- **Remediation:** None.

### n33 — Capture Exception (✅ Pass)
- **Spec requires:** `$exception` events with a canonical `$exception_list`, sent through the normal capture pipeline.
- **SDK currently (plugin 3.0, `210bf35d8`):** exceptions captured in JS are unchanged and go to `/batch`. Native crash reports and fatal JS crashes the plugin hands to native (`_captureFatalAndChooseOwner`, `packages/react-native/src/posthog-rn.ts:3802-3820`; the JS debug snapshot is stripped first, `:3735-3742`) are captured by posthog-ios 4.0 and posthog-android 4.0 and sent through capture v1, labelled `posthog-react-native` (see "Native events on capture v1" above). On Android the fatal JS crash's timestamp, read from the device clock in JS, is moved onto the native SDK's clock before capture (`toSdkClock`, `packages/react-native-plugin/android/src/main/java/com/posthogreactnativeplugin/PosthogReactNativePluginModule.kt:460-466`, `:852-856`; PostHog/posthog-js#5605), so the server's clock-skew correction doesn't shift it. posthog-ios 4.0 omits `NSNull`-valued event properties instead of sending JSON `null` (PostHog/posthog-ios#1047), so a `null` property on a native-captured exception on iOS is left out. Whether a crash reconstructed on a later launch is sent follows the consent rule scored under Opt In ([n32](#n32)).
- **Backwards compatibility:** No change needed.
- **Remediation:** None.
