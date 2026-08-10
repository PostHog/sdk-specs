# posthog-js — SDK Compliance

**Repo:** [PostHog/posthog-js](https://github.com/PostHog/posthog-js)
**Audited commit:** `34a34f3dbf7dcca94f35e10f3dabab50bb3b8b19` ([commit](https://github.com/PostHog/posthog-js/commit/34a34f3dbf7dcca94f35e10f3dabab50bb3b8b19)) — audited on 2026-08-10
**Audited against sdk-specs commit:** `2036abde806bc6598c100f8c5d25ba7c608e0eea`
**Summary:** 25 ✅ · 19 🟡 · 12 ❌ · 3 ➖ · 0 ❓

Note on repo layout: this is a pnpm monorepo. The npm package `posthog-js` (the web/browser SDK under audit) lives at `packages/browser/src/`, sharing primitives with `packages/browser-common/src/` and the shared `packages/core/src/` (the latter also backs the Node/React Native SDKs). Confirmed this run: the browser `PostHog` class (`packages/browser/src/posthog-core.ts:403`, `class PostHog implements PostHogInterface`) does **not** extend `PostHogCore`/`PostHogCoreStateless` from `@posthog/core` — it is a structurally separate implementation. Several methods that exist on `PostHogCore` (used by Node and by `packages/react-native`/`packages/web`) are therefore genuinely absent from the browser class, not merely hidden — this was independently re-confirmed by exhaustive grep across `packages/browser/src` and `packages/browser-common/src` for every gap noted below. The local clone is a depth-1 shallow clone (no history prior to HEAD), so this audit is based entirely on direct inspection of the current tree, not a diff against the prior audited commit.

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Alias | 🟡 | [n1] |
| 2 | Capture | 🟡 | [n2] |
| 3 | Capture Exception | ✅ | |
| 4 | Create Person Profile | ✅ | |
| 5 | Debug | ✅ | |
| 6 | Exception Steps | ❌ | [n3] |
| 7 | Flush | ❌ | [n4] |
| 8 | Get Anonymous ID | ❌ | [n5] |
| 9 | Get Distinct ID | ✅ | |
| 10 | Get Feature Flag | ✅ | |
| 11 | Get Feature Flag Payload | 🟡 | [n6] |
| 12 | Get Feature Flag Result | ✅ | |
| 13 | Get Feature Flags | ❌ | [n7] |
| 14 | Get Feature Flags And Payloads | ❌ | [n8] |
| 15 | Get Session ID | 🟡 | [n9] |
| 16 | Group | ❌ | [n10] |
| 17 | Group Identify | ❌ | [n11] |
| 18 | Identify | ✅ | |
| 19 | Is Feature Enabled | ✅ | |
| 20 | Is Opt Out | ✅ | |
| 21 | Is Session Replay Active | ✅ | |
| 22 | On Feature Flags | ✅ | |
| 23 | Opt In | 🟡 | [n12] |
| 24 | Register | ✅ | |
| 25 | Reload Feature Flags | 🟡 | [n13] |
| 26 | Reset | ✅ | |
| 27 | Reset Group Properties For Flags | 🟡 | [n14] |
| 28 | Reset Person Properties For Flags | ✅ | |
| 29 | Screen | ❌ | [n15] |
| 30 | Set Group Properties For Flags | ✅ | |
| 31 | Set Person Properties | ✅ | |
| 32 | Set Person Properties For Flags | ✅ | |
| 33 | Setup | ✅ | |
| 34 | Shutdown | 🟡 | [n16] |
| 35 | Start Session Recording | 🟡 | [n17] |
| 36 | Stop Session Recording | ✅ | |
| 37 | Unregister | ✅ | |
| 38 | Application Lifecycle | ➖ | [n18] |
| 39 | Autocapture | 🟡 | [n19] |
| 40 | Before Send Hook | ❌ | [n20] |
| 41 | Consent Gating | 🟡 | [n21] |
| 42 | Device ID Generator | ✅ | |
| 43 | Event Batcher | ❌ | [n22] |
| 44 | Feature Flag Cache | ✅ | |
| 45 | Feature Flag Called Tracker | ✅ | |
| 46 | Flag Definition Loader | ➖ | [n23] |
| 47 | HTTP Client | ❌ | [n24] |
| 48 | Local Feature Flag Evaluator | ➖ | [n25] |
| 49 | Persistent Storage | 🟡 | [n26] |
| 50 | Remote Config | 🟡 | [n27] |
| 51 | Retry Queue | 🟡 | [n28] |
| 52 | Session Manager | 🟡 | [n29] |
| 53 | Session Replay Ingestion Controls | 🟡 | [n30] |
| 54 | Session Replay Privacy | 🟡 | [n31] |
| 55 | Surveys | 🟡 | [n32] |
| 56 | Logs | 🟡 | [n33] |
| 57 | Traces | ❌ | [n34] |
| 58 | Tracing Headers | ✅ | |
| 59 | Bootstrap | ✅ | |

## Notes

### n1 — Alias (🟡 Partial)
- **Spec requires:** `alias(alias, original?)` emits `$create_alias`; when a required identity is missing/invalid, the SDK records a validation warning and drops the call rather than sending a malformed event.
- **SDK currently:** `packages/browser/src/posthog-core.ts:3465-3488`. There is no runtime guard rejecting a missing/empty `alias` argument. If `alias` is `undefined`/`''` at call time, `alias === original` is false, so the code proceeds to `capture('$create_alias', { alias: undefined, distinct_id: original })` with no logged warning — enqueuing a malformed alias event. No test coverage exists for this path. (New finding this run — not in the prior audit, which marked this contract ✅.)
- **Backwards compatibility:** Backward-compatible — adding an emptiness/type guard with a logged warning only narrows an already-broken edge case; no documented behavior changes.
- **Remediation:** Add a guard in `alias()` that rejects an empty/non-string `alias` with a logged warning before calling `capture()`.

### n2 — Capture (🟡 Partial)
- **Spec requires:** `capture(event, properties?, options?)` validates a non-empty event-name string, merges caller properties over super/persisted properties, supports a per-call `distinct_id` override and `disable_geoip`/`send_feature_flags` options, batches by count (`flush_at`) as well as time, and never throws to the caller (including from a throwing `before_send` hook).
- **SDK currently:** Re-verified against current code — every prior-audit gap is still present verbatim. `capture()` (`packages/browser/src/posthog-core.ts:1365-1584`) checks `isUndefined(event_name) || !isString(event_name)` (line 1382); `isString` only checks `typeof`, so an empty string `''` still passes. `CaptureOptions` (`packages/types/src/capture.ts:54-127`) still has no `distinct_id`, `disable_geoip`, or `send_feature_flags` fields (confirmed via full read of the type and zero grep hits in `packages/browser/src`). `RequestQueue.enqueue()` (`request-queue.ts:28-34`) is still purely timer-based (`DEFAULT_FLUSH_INTERVAL_MS=3000ms`, clamped 250-5000ms) with no count threshold. `_runBeforeSend()` (`posthog-core.ts:4406-4451`) still calls `fn(beforeSendResult)` (line 4421) with no surrounding try/catch, and `capture` is still not in the `safewrapClass` allowlist (only `identify`, line 4509).
- **Backwards compatibility:** Backward-compatible — an empty-string-name check, a try/catch defensive wrapper, and additive `disable_geoip`/`send_feature_flags`/distinct-id-override options are all non-breaking additions.
- **Remediation:** Unchanged from prior audit: add event-name emptiness validation; wrap `capture()`'s property-enrichment/before_send steps in try/catch; consider count-based flush threshold and the missing per-call options.

### n3 — Exception Steps (❌ Fail)
- **Spec requires:** The buffer of recorded exception steps (`addExceptionStep`) SHALL persist across captures and across identity changes, rotating only by byte-budget eviction, and SHALL be cleared only on a clean launch or when the SDK is closed/shut down — explicitly NOT on capture (spec: "Attach semantics and buffer lifetime," scenario "Steps persist across captures": steps A,B,C → capture 1 carries `[A,B,C]` → record D → capture 2 carries `[A,B,C,D]`).
- **SDK currently:** `packages/browser/src/posthog-exceptions.ts:158-159` and `:165` — `this._exceptionStepsBuffer.clear()` is called both on successful `$exception` capture and on capture failure. This directly contradicts the spec's explicit persist-across-captures requirement: a second exception captured after the first will not carry any steps recorded before the first exception, failing the spec's own worked scenario. Buffer mechanics otherwise (FIFO, byte-budget eviction, oversized-single-step rejection, synchronous append, UTF-8 byte counting, not cleared by `reset()`/`identify()`) are correctly implemented in `packages/core/src/error-tracking/exception-steps.ts`. This is a newly-identified issue not covered by the prior audit (which rated this contract ✅ without deep inspection of buffer-clearing semantics).
- **Backwards compatibility:** Breaking (behaviorally) but safe to fix — removing the erroneous `.clear()` calls only makes MORE steps available on subsequent exceptions than before; no caller could be relying on the buffer being empty after a capture, since that contradicts the documented/intended contract. Classify as Backward-compatible to fix.
- **Remediation:** Remove the `.clear()` calls at `posthog-exceptions.ts:158-159,165`; only clear the buffer on `close()`/shutdown or fresh instance construction.

### n4 — Flush (❌ Fail)
- **Spec requires:** A public `flush(): Promise<void>` that drains the outgoing event queue on demand, no-ops on an empty queue, and is retry-safe.
- **SDK currently:** Re-confirmed: `packages/types/src/posthog.ts` (the full public interface, ~729 lines) has no `flush` entry. `grep -n "flush("` across `packages/browser/src`/`packages/browser-common/src` matches only private/internal `_flush()` methods on `RetryQueue`/`heatmaps.ts`, and unrelated sub-client flushes (`this.logs?.flushLogs`, `this.metrics?.flush`). `shutdown()` (see n16) exists now but is a one-way teardown, not a repeatable drain-and-continue `flush()`.
- **Backwards compatibility:** Backward-compatible — no existing symbol occupies `flush` on `PostHog`; purely additive.
- **Remediation:** Add a public `flush(): Promise<void>` that force-drains `_requestQueue`/`_retryQueue` without disposing subsystems.

### n5 — Get Anonymous ID (❌ Fail)
- **Spec requires:** A public accessor (canonically `getAnonymousId()`) returning the device/anonymous-scoped identity independent of the current `distinct_id`, stable across `identify()`.
- **SDK currently:** Re-confirmed via exhaustive grep: zero matches for `getAnonymousId`/`get_anonymous_id`/`anonymousId` in `packages/browser/src` or `packages/browser-common/src`. `packages/core/src/posthog-core.ts:306` does implement `getAnonymousId()` (backs Node/RN via `PostHogCore`), but the browser class does not extend that class (confirmed this run — see repo-layout note), so this is not inherited. Browser only tracks `$device_id` internally, never exposed as a documented getter.
- **Backwards compatibility:** Backward-compatible — purely additive.
- **Remediation:** Expose `getAnonymousId(): string` on the browser `PostHog` class returning the persisted `$device_id`.

### n6 — Get Feature Flag Payload (🟡 Partial)
- **Spec requires:** A stable, canonical `getFeatureFlagPayload(key)` API.
- **SDK currently:** Unchanged from prior audit. `packages/browser/src/posthog-featureflags.ts:815-824` still marked `@deprecated` ("This method will be removed in a future version"), also deprecated at the `posthog-core.ts:2073-2074` delegate. Behaviorally correct (returns payload, `undefined` for unknown keys, no `$feature_flag_called` emission).
- **Backwards compatibility:** Backward-compatible — behavior already matches spec; fix is to not remove/un-deprecate it.
- **Remediation:** Unchanged: reconsider deprecation for cross-SDK parity or coordinate deprecation across all SDKs and update the canonical spec in lockstep.

### n7 — Get Feature Flags (❌ Fail)
- **Spec requires:** A bulk getter `getFeatureFlags(): Record<string, boolean | string> | undefined`.
- **SDK currently:** Re-confirmed: no `getFeatureFlags()` (bare, no-key) exists in `packages/browser/src` or `packages/browser-common/src`. `getAllFeatureFlags(): FeatureFlagResult[]` (`posthog-featureflags.ts:487-499`, delegate `posthog-core.ts:2120-2121`) remains the only bulk API, returning an array of `{key,enabled,variant,payload}` objects (different shape, includes payloads). `getFeatureFlags()` does exist on `PostHogCore` (`packages/core/src/posthog-core.ts:1131`), used by react-native/web packages, but not inherited by browser's `PostHog` class.
- **Backwards compatibility:** Backward-compatible — additive.
- **Remediation:** Unchanged: add `getFeatureFlags(): Record<string,boolean|string> | undefined` derived from internal `getFlagVariants()`.

### n8 — Get Feature Flags And Payloads (❌ Fail)
- **Spec requires:** A bulk getter returning `{ flags, payloads }`.
- **SDK currently:** Re-confirmed: zero matches for `getFeatureFlagsAndPayloads` in `packages/browser/src`/`packages/browser-common/src`. Exists only on `PostHogCore`/`PostHogCoreStateless` (`packages/core/src/posthog-core.ts:1170`, `posthog-core-stateless.ts:899/926/936`), not reachable from browser.
- **Backwards compatibility:** Backward-compatible — additive, buildable from existing internal `getFlagVariants()`/`getFlagPayloads()`.
- **Remediation:** Unchanged.

### n9 — Get Session ID (🟡 Partial)
- **Spec requires:** A getter returning the active session id, remaining stable within idle timeout, rotating after idle timeout or max session length.
- **SDK currently:** Re-confirmed unchanged: `get_session_id()` (`packages/browser/src/posthog-core.ts:3380`) always calls `checkAndGetSessionAndWindowId(true)` (readOnly). In `sessionid.ts`, idle-rotation is unconditionally skipped when `readOnly=true` (confirmed via property test `sessionid.property.test.ts:134`); max-session-length rotation is not gated on `readOnly` and still works via this getter (confirmed via `sessionid.property.test.ts:161-183`). A background `setTimeout`-armed idle timer set at construction can still eventually null the session even under pure read-only polling, but that's a passive background mechanism rather than something driven by `get_session_id()` itself.
- **Backwards compatibility:** Needs deprecation path — forcing idle-bookkeeping on every getter call would change observed stability for passive/read-only pollers.
- **Remediation:** Unchanged: document read-only semantics explicitly, or add an opt-in activity-updating variant.

### n10 — Group (❌ Fail)
- **Spec requires:** `group(groupType, groupKey, properties?)` should no-op for disabled SDKs, opted-out users, or `person_profiles: 'never'` clients, in addition to validating type/key presence.
- **SDK currently:** Re-confirmed via direct read of `packages/browser/src/posthog-core.ts:2936-2975` — `group()` still has no `_requirePersonProcessing`/opt-out guard at all (contrast with `identify`, `alias`, `createPersonProfile`, `setGroupPropertiesForFlags`, all of which guard). `this.register({ $groups: {...} })` unconditionally mutates in-memory persistence state regardless of `person_profiles: 'never'` or opt-out; only the downstream `capture(EVENT_GROUPIDENTIFY, ...)` call is gated indirectly via `is_capturing()`. Upgraded from 🟡 Partial (prior audit) to ❌ Fail this run: the missing guard is a complete absence of a documented gating mechanism present on every structurally similar method, not a partial implementation.
- **Backwards compatibility:** Backward-compatible — adding the guard only narrows behavior in the `never`/opted-out edge case.
- **Remediation:** Add `_requirePersonProcessing('posthog.group')` guard at the top of `group()`.

### n11 — Group Identify (❌ Fail)
- **Spec requires:** A standalone `groupIdentify(groupType, groupKey, groupProperties?, options?)` public method that emits `$groupidentify` without necessarily mutating ambient `$groups` membership.
- **SDK currently:** Re-confirmed: no standalone `groupIdentify` exists on the browser `PostHog` class or in `packages/browser-common`; `$groupidentify` is only reachable via `group()`'s internal, unguarded `capture(EVENT_GROUPIDENTIFY, ...)` call. `packages/core/src/posthog-core.ts:536-551` implements a correctly-guarded standalone `groupIdentify()` (used by Node/RN only, not inherited by browser).
- **Backwards compatibility:** Backward-compatible — additive.
- **Remediation:** Add a standalone, guarded `groupIdentify()` method on the browser `PostHog` class.

### n12 — Opt In (🟡 Partial)
- **Spec requires:** Opt-out/opt-in persist across restarts, gate future capture, and support clearing local persistence on opt-out when configured.
- **SDK currently:** `optOut`/`optIn` (`packages/browser/src/posthog-core.ts` ~L4071-4182) correctly persist via `consent.optInOut(...)` and gate future capture via `is_capturing()`; integrations restart correctly on opt-in. New finding this run: `opt_out_capturing()` (line 4148) takes no parameters at all — no options object, no data-clearing flag anywhere in `posthog-core.ts`/`consent.ts`/`types.ts`. The only adjacent knob, `opt_out_persistence_by_default`, only prevents *future* writes; it does not wipe existing identity/super-properties. This fully fails the spec's "opt-out can clear local persistence when configured" scenario. `reset()` does correctly clear the stored consent key with a documented footgun warning (`RESET_CONSENT_WARN`).
- **Backwards compatibility:** Backward-compatible — adding an opt-in `clear_data`-style parameter to `optOut()` is additive.
- **Remediation:** Add an optional data-clearing parameter/config to `opt_out_capturing()` that wipes identity/super-property persistence when set.

### n13 — Reload Feature Flags (🟡 Partial)
- **Spec requires:** Per the spec's "Surface variants" table, `posthog-js core / browser: reloadFeatureFlags(options?: { cb?: (err?, flags?) => void }): void`.
- **SDK currently:** New finding this run: the actual signature is zero-parameter — `reloadFeatureFlags(): void { this.featureFlags?.reloadFeatureFlags() }` (`posthog-core.ts:2174-2176`, `posthog-featureflags.ts:557`). No callback support exists; callers must use `onFeatureFlags` instead. All behavioral requirements (debounced, single-in-flight with one queued pending reload via `_requestInFlight`/`_additionalReloadRequested`, identity/groups/properties included in the request, cache preserved on failure, listeners fired on success) are correctly implemented and verified.
- **Backwards compatibility:** Backward-compatible — adding an optional `cb` parameter is additive.
- **Remediation:** Add the optional `{ cb }` parameter for spec/documentation parity, or update the spec's surface-variant table if the callback was intentionally dropped in favor of `onFeatureFlags`.

### n14 — Reset Group Properties For Flags (🟡 Partial)
- **Spec requires:** Canonical signature `resetGroupPropertiesForFlags(groupType?, reloadFeatureFlags?)`, guarded the same way as its sibling `setGroupPropertiesForFlags`.
- **SDK currently:** New finding this run: `packages/browser/src/posthog-core.ts:3093-3097` — `resetGroupPropertiesForFlags(group_type?)` has no `_requirePersonProcessing` guard (asymmetric with `setGroupPropertiesForFlags` immediately above it at lines 3074-3079, which is guarded) and takes no `reloadFeatureFlags` parameter — clearing the cache never triggers an automatic reload; callers must reload manually.
- **Backwards compatibility:** Backward-compatible — adding the guard and an additive optional parameter are non-breaking.
- **Remediation:** Add the `_requirePersonProcessing` guard and an optional `reloadFeatureFlags` parameter (default `true`) mirroring `setGroupPropertiesForFlags`.

### n15 — Screen (❌ Fail)
- **Spec requires:** A public `screen(name, properties?, options?)` method capturing a `$screen` event with `$screen_name`, applicable to `client` SDKs generally (spec's surface-variants table lists react-native/iOS/Android/Unity but does not exclude web).
- **SDK currently:** Re-confirmed: no method named `screen` exists anywhere in `packages/browser/src` or `packages/browser-common/src` (exhaustive grep, excluding unrelated `window.screen` viewport references). Only `$pageview` autocapture exists, a structurally different, automatic, non-caller-named concept. Notably, `packages/react-native/src/posthog-rn.ts:1444-1489` **does** implement a fully spec-compliant `screen()` (verified this run) — confirming the capability is a deliberate, implemented pattern elsewhere in the same monorepo, just not ported to browser.
- **Backwards compatibility:** Backward-compatible — adding `screen()` as a thin wrapper around `capture('$screen', {$screen_name: name, ...})` is purely additive.
- **Remediation:** Unchanged: add a `screen()` method for parity with mobile/RN SDKs and SPA route-as-screen use cases.

### n16 — Shutdown (🟡 Partial)
- **Spec requires:** `shutdown()` flushes pending events and stops accepting new work; post-shutdown captures should not be silently enqueued; delivery failures during the shutdown flush should be recorded.
- **SDK currently:** Re-verified. `shutdown()` (`posthog-core.ts:3258-3276`) still never resets `__loaded` to `false` (exhaustive grep of all `__loaded` write sites shows it's only ever set at construction/init, lines 534/669) — `capture()`'s guard (line 1372: `if (!this.__loaded || ...)`) still passes after `shutdown()`, so post-shutdown captures are still silently enqueued, directly contradicting the spec. `_requestQueue.unload()`/`_retryQueue.unload()` (`request-queue.ts:36-49`, `retry-queue.ts:163-196`) still hard-code `transport: 'sendBeacon'` for the final drain, which returns only a boolean success-to-queue indicator with no delivery-failure warning path. Both prior-audit gaps confirmed unchanged. (The headline structural fact that `shutdown()` exists at all is unchanged from the prior audit too — it was already present in that audit, added via PR #4053 for parity with posthog-node; no regression, no fix.)
- **Backwards compatibility:** Needs deprecation path for flipping `__loaded`/pausing the queue post-shutdown — some callers may depend on capture-after-shutdown not throwing. Unknown/architecturally constrained for the sendBeacon delivery-visibility gap.
- **Remediation:** Unchanged: set `__loaded = false` (or an equivalent flag) at the end of `shutdown()`.

### n17 — Start Session Recording (🟡 Partial)
- **Spec requires:** `startSessionRecording(override?)` activates recording idempotently, respecting opt-out, with override behavior applying only to the next attempt.
- **SDK currently:** Re-confirmed unchanged. `posthog-core.ts:3594-3627` — override side effects (`overrideSampling`/`overrideLinkedFlag`/`overrideTrigger`, plus a `sessionManager?.checkAndGetSessionAndWindowId()` call) run unconditionally before the opt-out-gated final decision (`_isRecordingEnabled`, `session-recording.ts:114-119`) executes via `set_config`. The JSDoc at line 3592 (`true` shorthand sets only `sampling`+`linked_flag`) is still stale — the code at lines 3597-3603 actually sets all four override flags including `url_trigger`/`event_trigger`. Idempotency and the final opt-out gate are correctly implemented.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** Unchanged: gate override-persistence writes behind the same opt-out check; fix the stale JSDoc.

### n18 — Application Lifecycle (➖ N/A)
- **Justification:** Re-confirmed via exhaustive search (`"Application Installed/Updated/Opened/Backgrounded"`, lifecycle-event sweep) across `packages/browser/src`, `packages/browser-common/src`, `packages/core/src` — zero relevant matches. This spec targets mobile/native install/update/open/background lifecycle events with persisted version markers, a concept with no meaningful web analogue. Confirmed unaffected by this cycle's changes.

### n19 — Autocapture (🟡 Partial)
- **Spec requires:** Configurable knobs (`customLabelProp`/`maxElementsCaptured`/`propsToCapture`), screen-name context on captured events, sensitive-data redaction, debounce for high-frequency inputs.
- **SDK currently:** Re-confirmed unchanged. `customLabelProp`/`maxElementsCaptured`/`propsToCapture` still absent from browser's `AutocaptureConfig` (`packages/types/src/posthog-config.ts:26-102`) — these exist only in `packages/react-native`. `$screen_name` still never emitted on `$autocapture` events (zero grep hits in browser/browser-common); browser substitutes generic `$current_url`/`$pathname`. No explicit debounce mechanism exists, though this is largely moot in practice since listeners are on `submit`/`change`/`click`/`copy`/`cut` (not `input`), so native `change` semantics naturally avoid high-frequency firing for sliders specifically. Sensitive-field exclusion and `$elements_chain` construction remain solid.
- **Backwards compatibility:** Backward-compatible — additive config knobs and properties.
- **Remediation:** Unchanged: add the missing config knobs; consider a `$screen_name`/`$pathname`-derived property for cross-SDK parity.

### n20 — Before Send Hook (❌ Fail)
- **Spec requires:** `before_send` hook execution must never crash the caller; a throwing hook should be caught, logged, and the pipeline should keep the last good event.
- **SDK currently:** Re-confirmed unchanged and upgraded from 🟡 Partial (prior audit) to ❌ Fail this run: `_runBeforeSend()` (`packages/browser/src/posthog-core.ts:4406-4451`) still has no try/catch around `fn(beforeSendResult)` (line 4420/4421), and `capture` is still not in the `safewrapClass` allowlist (only `identify`, line 4509). Directly contrasted this run against `packages/core/src/posthog-core.ts:1724-1745` (js-core, used by Node/React Native), which DOES wrap each hook call in try/catch, keeps the last good result, and logs via `this._logger.error` — confirming this is a genuine, unmitigated, and asymmetric gap specific to the browser package (the equivalent safety net exists elsewhere in the same monorepo but isn't shared). Given the spec's explicit, unconditional "must never crash the caller" framing and a directly comparable working reference implementation sitting in the same repo, this is reclassified as a clean Fail rather than Partial.
- **Backwards compatibility:** Backward-compatible — wrapping the hook call in try/catch is purely additive defensive code.
- **Remediation:** Wrap each `fn(beforeSendResult)` call in `_runBeforeSend()` in try/catch, mirroring the js-core implementation.

### n21 — Consent Gating (🟡 Partial)
- **Spec requires:** Consent state changes gate capture and other side effects; drops should be logged/observable; consent restoration should be race-free.
- **SDK currently:** `ConsentManager.isOptedOut()` (`consent.ts:38-47`) correctly folds tri-state consent/DNT/cookieless modes, and `capture()` short-circuits correctly before any enqueue (`posthog-core.ts:1377-1379`). New findings this run: (1) the opted-out branch is a bare `return` with no `logger.warn`/debug message, unlike the adjacent `!__loaded` branch which does log — no drop reason is ever surfaced. (2) Gating is inconsistent beyond events: `identify()` still writes to persistence unconditionally regardless of opt-out; persistence writes are only opt-out-gated when `opt_out_persistence_by_default` is explicitly configured (default `false`). Consent restoration itself is synchronous and race-free.
- **Backwards compatibility:** Backward-compatible — adding a logged drop-reason is additive; tightening persistence gating by default would need a staged rollout (Needs deprecation path) since it changes default behavior for existing opted-out users' local state.
- **Remediation:** Log a debug/warn message when a capture is dropped due to opt-out; consider gating persistence writes on opt-out by default (behind a flag initially).

### n22 — Event Batcher (❌ Fail)
- **Spec requires:** Batching with both a count-based threshold (`flushAt`) and time-based threshold, a `maxBatchSize` cap, request-size awareness, and 413-specific shrink-and-retry.
- **SDK currently:** Re-confirmed unchanged in full: `RequestQueue.enqueue()` (`request-queue.ts:28-34`) has no count threshold, only the 3000ms (clamped 250-5000ms) timer; `_formatQueue()` (lines 93-108) still drains the entire queue as one request per batch key with no `maxBatchSize` cap; no 413-specific handling anywhere in `request-queue.ts`/`retry-queue.ts`/`request.ts`. The spec-compliant batching engine in `packages/core/src/posthog-core-stateless.ts` is confirmed (via grep for cross-references) never imported by `packages/browser`.
- **Backwards compatibility:** Needs deprecation path — changing request-shaping/timing could affect integrations depending on current behavior.
- **Remediation:** Unchanged: port batching logic from `posthog-core-stateless.ts`.

### n23 — Flag Definition Loader (➖ N/A)
- **Justification:** Re-confirmed via exhaustive grep for `personal_api_key`, `local_evaluation`, `flag_definition`, etc. across `packages/browser/src`, `packages/browser-common/src`, `packages/core/src` — zero matches (only unrelated test-fixture noise). No browser-safe way to hold a personal/project secret key; this capability exists only in `packages/node`, out of scope.

### n24 — HTTP Client (❌ Fail)
- **Spec requires:** Feature-flag evaluation requests retry transient transport failures and HTTP 502/504 with a bounded default retry and exponential backoff (300ms→600ms).
- **SDK currently:** Re-confirmed unchanged: `_callFlagsEndpoint` (`packages/browser/src/posthog-featureflags.ts:604-740`) makes exactly one `_send_request()` call (line 663) with no retry loop and no 502/504 branching — every non-200 status uniformly becomes `FeatureFlagError.apiError(...)`. The spec-compliant implementation (`isRetryableFlagsFetchError`, `fetchWithRetry`, exponential 300ms/600ms backoff) genuinely exists in `packages/core/src/posthog-core-stateless.ts:192-206,743` but zero references from `packages/browser` confirm it isn't used there. Upgraded from 🟡 Partial (prior audit) to ❌ Fail this run: there is no partial retry mechanism at all for this specific, spec-mandated behavior — the base request infrastructure (transport fallback, compression) working correctly doesn't offset the complete absence of the specifically-required retry policy.
- **Backwards compatibility:** Backward-compatible — additive retry wrapper.
- **Remediation:** Add a 1-retry, 300ms→600ms exponential-backoff wrapper around the flags-endpoint request for transient errors and 502/504.

### n25 — Local Feature Flag Evaluator (➖ N/A)
- **Justification:** Re-confirmed, including the new starts_with/ends_with requirement added since the last audit: exhaustive grep for `starts_with`, `ends_with`, `not_starts_with`, `not_ends_with`, `icontains`, cohort/rollout-hashing logic across `packages/browser/src`, `packages/browser-common/src`, `packages/core/src` — zero matches. The browser SDK is confirmed to be a pure "consume the server's evaluated response" client with no local rule-matching engine of any kind; the new string-operator requirement is N/A for the identical underlying reason as the pre-existing local-evaluator requirements (no local evaluator exists to add operators to).

### n26 — Persistent Storage (🟡 Partial)
- **Spec requires:** A defined fallback chain reaching memory as a true last resort; `null` treated as removal; durable storage of queued outgoing events.
- **SDK currently:** Re-confirmed unchanged: `_buildStorage()` (`posthog-persistence.ts:186-237`) still falls back `localPlusCookieStore` → terminal `cookieStore`, never automatically reaching `memoryStore` (only via explicit `persistence: 'memory'` config). `_setProp` (line ~878/879) still stores literal `null` rather than deleting the key; only `unregister()` deletes. The outgoing event queue (`request-queue.ts:12`, `retry-queue.ts:44`) remains a plain in-memory array with no durable backing beyond `sendBeacon`-on-unload. Additionally confirmed this run: storage-write-failure warnings only surface when `config.debug` is true (default `false`), so failures are silent by default — a gap beyond what the prior audit flagged.
- **Backwards compatibility:** Needs deprecation path — changing `null`-via-`register()` semantics or adding automatic memory fallback could change subtle existing behavior.
- **Remediation:** Unchanged, plus: consider surfacing storage-write-failure warnings regardless of `debug` mode.

### n27 — Remote Config (🟡 Partial)
- **Spec requires:** Single, deduplicated in-flight config load; a clean config cache that is cleared on `reset()`.
- **SDK currently:** Re-confirmed: `RemoteConfigLoader` (`remote-config.ts`, full 153-line file read) still has no `_isLoading`/in-flight-dedup guard — `load()` runs unconditionally on every call. `session-recording.ts:363` still constructs a second, separate `new RemoteConfigLoader(this._instance).load()` distinct from the canonical instance at `posthog-core.ts:1133`, confirmed via direct grep this run — this is a real, uncoordinated second loader that can race the primary one, though it's scoped to a staleness-refresh path rather than blind duplication. `reset()` still preserves `SESSION_RECORDING_REMOTE_CONFIG` across the persistence clear (`posthog-core.ts:3141-3182`) — re-assessed this run as a deliberate, documented design choice for replay continuity (not an oversight), so this sub-point is downweighted but still a real, contestable deviation from a strict reading of the spec.
- **Backwards compatibility:** Backward-compatible for the in-flight guard/loader-reuse fix (internal correctness only). Needs deprecation path if the reset()-preserves-replay-config behavior is ever changed, since it's intentional.
- **Remediation:** Unchanged: add an in-flight guard; have session-recording reuse the primary loader instance.

### n28 — Retry Queue (🟡 Partial)
- **Spec requires:** A bounded retry queue, 429 treated as retryable, `Retry-After` honored, 413-specific shrink-and-retry.
- **SDK currently:** Re-confirmed unchanged, all four gaps verbatim: `_enqueue()` (`retry-queue.ts:105-124`) still has no capacity cap. The retry-classification conditional at line 82 (`response.statusCode !== 200 && (response.statusCode < 400 || response.statusCode >= 500)`) still puts 429 in the dropped, non-retryable 4xx bucket. No `Retry-After` header parsing exists anywhere (the separate `rate-limiter.ts` mechanism reads a JSON body field with a hardcoded 60s cooldown, unrelated to HTTP headers). No 413-specific shrink-and-retry. Real exponential backoff with jitter (`pickNextRetryDelay`, lines 26-33: 3000ms base × 2^retries, capped 30min, ±50% jitter) remains correctly implemented.
- **Backwards compatibility:** Needs deprecation path — changing drop/retry timing for 429/queue-cap could affect existing integrations; should ship with a permissive default.
- **Remediation:** Unchanged.

### n29 — Session Manager (🟡 Partial)
- **Spec requires:** Session creation/reuse, idle-timeout rotation, max-length rotation, cross-tab consistency, explicit reset.
- **SDK currently:** New finding this run (previously bundled under Get Session ID only, now assessed as its own contract): `sessionid.ts`'s `checkAndGetSessionAndWindowId(readOnly=false, ...)` computes `sessionPastMaximumLength` unconditionally (not gated on `readOnly`), but `activityTimeout` (idle-rotation) is fully skipped when `readOnly=true` (`!noSessionId && !readOnly && this._sessionHasBeenIdleTooLong(...)`), and the idle timer is only re-armed on non-readOnly calls — though the constructor arms a background timer once unconditionally at init, so idle rotation can still eventually fire passively even under pure getter-polling. Core rotation logic (max-length, cross-tab, explicit `reset()`) is correctly implemented and verified. This is the same underlying mechanism flagged under Get Session ID (n9) but assessed here as an internal-behavior contract in its own right — downgraded from ✅ (prior audit) to 🟡 Partial since the idle-rotation gap is a genuine, code-verified deviation from full spec compliance, not merely a getter-level nuance.
- **Backwards compatibility:** Needs deprecation path — same reasoning as n9.
- **Remediation:** Same as n9: document semantics or add an activity-updating read path.

### n30 — Session Replay Ingestion Controls (🟡 Partial)
- **Spec requires:** Evaluating a linked feature flag for replay gating should report a flag call (`$feature_flag_called`); URL-trigger activation should release the "interaction hold" alongside event triggers.
- **SDK currently:** Re-confirmed both gaps unchanged: linked-flag resolution still uses a passive `onFeatureFlags(...)` subscription (`triggerMatching.ts:391-430`) over already-cached flag state, never calling `getFeatureFlag()`/`isFeatureEnabled()` (the only two call sites that emit `$feature_flag_called`, `posthog-featureflags.ts:949`) — so linked-flag evaluation for replay gating is still never reported as a flag call. Confirmed this run that "only event triggers release the interaction hold" is a **deliberate, explicitly-commented design decision** in `lazy-loaded-session-recorder.ts` ("URL and linked-flag activations never release — they fire without a human present"), not an oversight — still a literal spec deviation but with documented intent. New finding: no validation/clamping of `minimumDurationMilliseconds` (unlike `sampleRate`, which has `_validateSampleRate`).
- **Backwards compatibility:** Backward-compatible — both fixes only add new cases, no removal of existing capability.
- **Remediation:** Unchanged, plus: validate/clamp `minimumDurationMilliseconds` with a warning on malformed input.

### n31 — Session Replay Privacy (🟡 Partial)
- **Spec requires:** Config-driven masking (inputs, text selectors, block selectors), markup-level opt-outs, network-request redaction (headers/paths/keywords) before any custom hook runs, client-over-remote precedence.
- **SDK currently:** New finding this run (downgraded from ✅ in prior audit, which did not inspect this deeply): the network redaction pipeline (`config.ts:265-361`) correctly runs header/path/size cleaning before the user's `maskCapturedNetworkRequestFn`, but the keyword/content deny-list scrub (`scrubPayloads`) only runs in the no-custom-hook branch (line 350) — when a user supplies a custom `maskCapturedNetworkRequestFn`, body content is header/path/size-cleaned but never keyword-scrubbed before reaching the hook, a partial deviation from the spec's redaction-ordering requirement. Config surface (`maskAllInputs`, `maskTextSelector`, `blockSelector`, `maskInputOptions`, `recordHeaders`, `recordBody`), markup controls (`ph-no-capture`, `ph-mask`, `ph-ignore-input`), and client-over-remote masking precedence are all correctly implemented and passed to the externally-loaded rrweb recorder. The DOM mask-traversal implementation itself lives entirely in the separate `@posthog/rrweb-record` fork, outside this repo's scope (N/A for that specific sub-requirement, not a gap).
- **Backwards compatibility:** Backward-compatible — running `scrubPayloads` before the custom hook unconditionally is additive/corrective.
- **Remediation:** Apply `scrubPayloads` keyword scrubbing before invoking `maskCapturedNetworkRequestFn`, not only in its absence.

### n32 — Surveys (🟡 Partial)
- **Spec requires:** Opt-out should prevent survey fetch/display (not just the resulting event); `reset()` should clear all seen/in-progress/abandoned survey state; `survey abandoned` should carry the same `$set` marker as `sent`/`dismissed`.
- **SDK currently:** Re-confirmed all three gaps unchanged: `posthog-surveys.ts:125` still only checks `consent.isOptedOut()` inside the `cookieless_mode` branch — in standard mode, surveys are still fetched from `/api/surveys/` and rendered for opted-out users; only the resulting `capture()` is suppressed downstream. `reset()`'s storage sweep (`posthog-surveys.ts:91-110`) still only clears `SURVEY_SEEN_PREFIX`/`SURVEY_IN_PROGRESS_PREFIX`, never `SURVEY_ABANDONED_PREFIX` (`utils/survey-utils.ts:20`), even though `sendSurveyAbandonedEvent` writes a permanent dedupe flag under that prefix. `sendSurveyAbandonedEvent` (`surveys-extension-utils.tsx:533-535`) still has no `$set` marker, unlike `sendSurveyEvent`/`dismissedSurveyEvent` (lines 435-449, 494-500).
- **Backwards compatibility:** Needs deprecation path for the opt-out fetch/display gating fix (visible behavior change for opted-out users). Backward-compatible for the `reset()` sweep and `$set` marker fixes.
- **Remediation:** Unchanged.

### n33 — Logs (🟡 Partial)
- **Spec requires:** Correctly-ordered/monotonic timestamps, durable/persisted queue surviving reload where feasible, standard OTLP attribute encoding, gzip `Content-Encoding` signaling, retry policy including 408/`Retry-After` handling.
- **SDK currently:** New findings this run (downgraded from ✅ in prior audit, which did not inspect this deeply): (1) `packages/core/src/logs/logs-utils.ts:100-102` builds `timeUnixNano` as `String(Date.now()) + '000000'` — no monotonic tie-breaking, so two same-millisecond logs get identical timestamps. (2) `posthog-logs.ts:72-73` is explicitly in-memory only ("do not survive a page reload"), and the queue is wiped on `reset()` (`posthog-logs.ts:181-187`, `this._queue = []`), contradicting a "queue preserved across reset" expectation. (3) Integer attributes emit as numeric `intValue` rather than stringified int64, and objects are `JSON.stringify`'d into `stringValue` rather than recursive `kvlistValue` (`logs-utils.ts:57-58,68-71`) — partial OTLP attribute-encoding deviation. (4) `os.name`/`os.version` resource attributes never emitted. (5) Compression is signaled only via a `?compression=` query param, never a `Content-Encoding: gzip` header. (6) HTTP 408 is misclassified as non-retriable/dropped; no `Retry-After` handling; retries indefinitely via re-arm rather than a bounded `maxRetries`-drop. Core pipeline (public API, gating order, severity mapping, envelope shape, transport, `beforeSend` — fully implemented on web contrary to the spec's "web MAY omit" allowance) is otherwise solid. Confirmed `posthog-conversations-types.ts` (a support-chat widget data model) is unrelated to logs/OTLP.
- **Backwards compatibility:** Backward-compatible for timestamp/attribute-encoding/compression-header/retry fixes (internal correctness). Needs deprecation path for making the queue durable-by-default or preserved-across-reset, since that changes observable behavior on reload/reset.
- **Remediation:** Add a monotonic nanosecond tie-breaker; consider preserving the queue across `reset()` (not necessarily across page reload); align attribute encoding with OTLP int64/kvlistValue conventions; set `Content-Encoding: gzip`; treat 408 as retryable and honor `Retry-After`.

### n34 — Traces (❌ Fail)
- **Spec requires:** A generic APM tracing capability — `startSpan`/`withSpan`, W3C traceparent interop, OTLP span data model, transport to `POST {host}/i/v1/traces`.
- **SDK currently:** Re-confirmed unchanged across the entire monorepo (not just browser): exhaustive grep for `startSpan`, `withSpan`, `traceparent`, `resourceSpans`, `/i/v1/traces`, `getActiveSpan` — zero hits anywhere, including `packages/browser`, `packages/core`, and `packages/ai`. `packages/ai/src/otel/` is confirmed categorically different: it filters/exports only AI-generation spans (name/attributes starting `gen_ai.`/`llm.`/`ai.`/`traceloop.`) from an externally-supplied OTel SDK to `/i/v0/ai/otel` (not `/i/v1/traces`), with an explicit doc comment that all other spans are silently dropped — no span creation API of its own. `captureTraceFeedback`/`captureTraceMetric` (`posthog-core.ts:4476-4500`) only attach feedback/metrics to an externally-generated `$ai_trace_id`, no span creation. The `posthog-conversations-types.ts`/`extensions/conversations/` surface (new since the prior audit) is confirmed this run to be an unrelated live-chat/support-widget data model (`Message`, TipTap rich text, `Ticket` types) with zero trace/span relevance.
- **Backwards compatibility:** Backward-compatible — wholly new, opt-in feature.
- **Remediation:** Unchanged: implement a generic tracing/span API and OTLP `/i/v1/traces` transport, using the `logs` pipeline as an architectural template.
