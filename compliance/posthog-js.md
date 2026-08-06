# posthog-js — SDK Compliance

**Repo:** [PostHog/posthog-js](https://github.com/PostHog/posthog-js)
**Audited commit:** `e1efa5725754aed1e2709e255e5abd607a276664` ([commit](https://github.com/PostHog/posthog-js/commit/e1efa5725754aed1e2709e255e5abd607a276664)) — audited on 2026-08-06
**Audited against sdk-specs commit:** `b59e8b430c83c5549fc396c8b092615b79d08dd4`
**Summary:** 34 ✅ · 15 🟡 · 7 ❌ · 3 ➖ · 0 ❓

Note on repo layout: this is a pnpm monorepo. The npm package `posthog-js` (the web/browser SDK under audit) lives at `packages/browser/src/`, sharing primitives with `packages/browser-common/src/` and `packages/core/src/` (the latter also backs the Node/React Native SDKs). All file paths below are relative to `/tmp/audit-posthog-js/` unless noted.

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Alias | ✅ | |
| 2 | Capture | 🟡 | [n1] |
| 3 | Capture Exception | ✅ | |
| 4 | Create Person Profile | ✅ | |
| 5 | Debug | ✅ | |
| 6 | Exception Steps | ✅ | |
| 7 | Flush | ❌ | [n2] |
| 8 | Get Anonymous ID | ❌ | [n3] |
| 9 | Get Distinct ID | ✅ | |
| 10 | Get Feature Flag | ✅ | |
| 11 | Get Feature Flag Payload | 🟡 | [n4] |
| 12 | Get Feature Flag Result | ✅ | |
| 13 | Get Feature Flags | ❌ | [n5] |
| 14 | Get Feature Flags And Payloads | ❌ | [n6] |
| 15 | Get Session ID | 🟡 | [n7] |
| 16 | Group | 🟡 | [n8] |
| 17 | Group Identify | 🟡 | [n9] |
| 18 | Identify | ✅ | |
| 19 | Is Feature Enabled | ✅ | |
| 20 | Is Opt Out | ✅ | |
| 21 | Is Session Replay Active | ✅ | |
| 22 | On Feature Flags | ✅ | |
| 23 | Opt In | ✅ | |
| 24 | Register | ✅ | |
| 25 | Reload Feature Flags | ✅ | |
| 26 | Reset | ✅ | |
| 27 | Reset Group Properties For Flags | ✅ | |
| 28 | Reset Person Properties For Flags | ✅ | |
| 29 | Screen | ❌ | [n10] |
| 30 | Set Group Properties For Flags | ✅ | |
| 31 | Set Person Properties | ✅ | |
| 32 | Set Person Properties For Flags | ✅ | |
| 33 | Setup | ✅ | |
| 34 | Shutdown | 🟡 | [n11] |
| 35 | Start Session Recording | 🟡 | [n12] |
| 36 | Stop Session Recording | ✅ | |
| 37 | Unregister | ✅ | |
| 38 | Application Lifecycle | ➖ | [n13] |
| 39 | Autocapture | 🟡 | [n14] |
| 40 | Before Send Hook | 🟡 | [n15] |
| 41 | Consent Gating | ✅ | |
| 42 | Device ID Generator | ✅ | |
| 43 | Event Batcher | ❌ | [n16] |
| 44 | Feature Flag Cache | ✅ | |
| 45 | Feature Flag Called Tracker | ✅ | |
| 46 | Flag Definition Loader | ➖ | [n17] |
| 47 | HTTP Client | 🟡 | [n18] |
| 48 | Local Feature Flag Evaluator | ➖ | [n19] |
| 49 | Persistent Storage | 🟡 | [n20] |
| 50 | Remote Config | 🟡 | [n21] |
| 51 | Retry Queue | 🟡 | [n22] |
| 52 | Session Manager | ✅ | |
| 53 | Session Replay Ingestion Controls | 🟡 | [n23] |
| 54 | Session Replay Privacy | ✅ | |
| 55 | Surveys | 🟡 | [n24] |
| 56 | Logs | ✅ | |
| 57 | Traces | ❌ | [n25] |
| 58 | Tracing Headers | ✅ | |
| 59 | Bootstrap | ✅ | |

## Notes

### n1 — Capture (🟡 Partial)
- **Spec requires:** `capture(event, properties?, options?)` validates a non-empty event-name string, merges caller properties over super/persisted properties, supports a per-call `distinct_id` override and `disable_geoip`/`send_feature_flags` options, batches by count (`flush_at`) as well as time, and never throws to the caller (including from a throwing `before_send` hook).
- **SDK currently:** `capture()` (`packages/browser/src/posthog-core.ts:1365`) only checks `isUndefined(event_name) || !isString(event_name)` (line 1382) — an empty string `''` passes and is captured. There is no per-call `distinct_id` override, and no `disable_geoip`/`send_feature_flags` options in the browser `CaptureOptions` type (`packages/types/src/capture.ts` — confirmed absent). Batching in `RequestQueue` (`packages/browser/src/request-queue.ts`) is purely timer-based (`DEFAULT_FLUSH_INTERVAL_MS` 3000ms, clamped 250–5000ms); there is no count-based `flushAt` threshold (that only exists in `packages/core/src/posthog-core-stateless.ts:341`, used by Node/RN, not by the browser capture path). `capture()` has no try/catch and is not in the `safewrapClass` allowlist (`posthog-core.ts:4509`, only `identify` is wrapped), so exceptions in property enrichment or a throwing `before_send` hook propagate to the caller.
- **Backwards compatibility:** Backward-compatible — an empty-string-name check, a try/catch defensive wrapper, and additive `disable_geoip`/`send_feature_flags`/distinct-id-override options are all non-breaking additions.
- **Remediation:** Add event-name emptiness validation; wrap `capture()` body (or at least the property-enrichment and before_send steps) in try/catch with a logged warning; consider adding count-based flush threshold and the missing per-call options for cross-SDK parity.

### n2 — Flush (❌ Fail)
- **Spec requires:** A public `flush(): Promise<void>` that drains the outgoing event queue on demand, no-ops on an empty queue, and is retry-safe.
- **SDK currently:** No `flush()` method exists anywhere on the browser `PostHog` class or the shared `packages/types/src/posthog.ts` interface (verified directly: `grep -n "flush(" packages/browser/src/posthog-core.ts` only matches `this.metrics?.flush('sendBeacon')`, an unrelated LLM-metrics sub-client). The main event pipeline (`RequestQueue`/`RetryQueue`) exposes only `enqueue()`/`enable()`/`unload()`; `RetryQueue`'s flush is private. `shutdown()` (added per posthog-js CHANGELOG for PR #4053, explicitly "for parity with posthog-node") is the closest analog but tears down the client rather than draining-and-continuing.
- **Backwards compatibility:** Backward-compatible — no existing symbol occupies the `flush` name on `PostHog`; adding it (e.g., delegating to `_requestQueue`/`_retryQueue` drain logic without tearing down the client) is purely additive.
- **Remediation:** Add a public `flush(): Promise<void>` that forces an immediate drain of `_requestQueue`/`_retryQueue` without disposing subsystems, resolving once in-flight requests complete or fail terminally.

### n3 — Get Anonymous ID (❌ Fail)
- **Spec requires:** A public accessor (canonically `getAnonymousId()`) that returns the device/anonymous-scoped identity independent of the current (possibly identified) `distinct_id`, remaining stable across `identify()`.
- **SDK currently:** Exhaustive search of `packages/browser/src/*.ts` for `getAnonymousId`, `get_anonymous_id`, `anonymousId` returns zero matches. The browser SDK fuses "anonymous id" and `distinct_id` pre-identify into one persisted field; the closest related concept, `$device_id`, is only reachable through the generic internal `get_property(DEVICE_ID)` helper, never exposed as a documented public method. By contrast, `@posthog/core` (`packages/core/src/posthog-core.ts:306`, backing Node/React Native) does implement `getAnonymousId()`. This is specifically a browser-package gap.
- **Backwards compatibility:** Backward-compatible — adding a new public `getAnonymousId()` (returning `$device_id`, i.e. the persisted pre-identify anonymous id) is purely additive and does not affect existing callers.
- **Remediation:** Expose a `getAnonymousId(): string` method on the browser `PostHog` class returning the persisted `$device_id`/pre-identify distinct id, matching the shared-core SDKs' surface.

### n4 — Get Feature Flag Payload (🟡 Partial)
- **Spec requires:** A stable, canonical `getFeatureFlagPayload(key): JsonValue | null | undefined` API returning the payload for a flag.
- **SDK currently:** `getFeatureFlagPayload(key)` (`packages/browser/src/posthog-featureflags.ts:820-824`) is marked `@deprecated` ("removed in a future version") in favor of `getFeatureFlagResult(key, {send_event:false}).payload`. Behaviorally it still satisfies all three acceptance scenarios (returns payload for a matched flag, returns `undefined` with no throw for an unknown flag, does not emit `$feature_flag_called`) — the deviation is purely in the API's deprecated/soon-to-be-removed status contradicting the spec's framing of this as a first-class stable method.
- **Backwards compatibility:** Backward-compatible — the method already behaves per spec; the fix is simply to not remove it (or to un-deprecate it) since other SDKs treat it as canonical.
- **Remediation:** Reconsider the deprecation of `getFeatureFlagPayload` for cross-SDK parity, or coordinate the deprecation across all SDKs simultaneously so the canonical spec is updated in lockstep.

### n5 — Get Feature Flags (❌ Fail)
- **Spec requires:** A bulk getter, canonically `getFeatureFlags(): Record<string, boolean | string> | undefined`, returning a flat key→value map of all currently cached flags (no payloads).
- **SDK currently:** No method named `getFeatureFlags()` exists (`grep -rn "getFeatureFlags\b"` across `packages/browser/src` and `packages/types/src` finds none). The only bulk API is `getAllFeatureFlags(): FeatureFlagResult[]` (`packages/browser/src/posthog-featureflags.ts:487-499`, also `posthog-core.ts:2120-2121`), which returns an array of structured `{key, enabled, variant, payload}` objects — a different shape that also includes payloads, contradicting the spec's "do not return payloads" expectation for this specific getter.
- **Backwards compatibility:** Backward-compatible — adding a new `getFeatureFlags()` that maps `getAllFeatureFlags()`'s results into a `Record<string, boolean|string>` (dropping payloads) is purely additive; existing `getAllFeatureFlags()` is untouched.
- **Remediation:** Add `getFeatureFlags(): Record<string, boolean|string> | undefined` derived from the existing internal `getFlagVariants()`.

### n6 — Get Feature Flags And Payloads (❌ Fail)
- **Spec requires:** A bulk getter returning both flags and payloads together, canonically shaped `{ flags: Record<string, boolean|string>, payloads: Record<string, unknown> }`.
- **SDK currently:** No method named `getFeatureFlagsAndPayloads` (or equivalent) exists anywhere in the repo (`grep -rn "getFeatureFlagsAndPayloads\|FeatureFlagsAndPayloads"` — zero matches across all packages). `getAllFeatureFlags()` combines flags+payloads but as a per-flag array of result objects, not the spec's two-map shape.
- **Backwards compatibility:** Backward-compatible — could be added as a new method built from the already-implemented (but unexposed on `PostHog`) internal `getFlagVariants()`/`getFlagPayloads()` (`posthog-featureflags.ts:501-547`), without touching any existing API.
- **Remediation:** Add `getFeatureFlagsAndPayloads()` returning `{flags, payloads}` derived from the existing internal helpers.

### n7 — Get Session ID (🟡 Partial)
- **Spec requires:** A getter that returns the active session id, creating one if absent, remaining stable within the idle timeout, and rotating after the idle timeout or max session length elapses.
- **SDK currently:** `get_session_id()` (`packages/browser/src/posthog-core.ts:3379-3381`) calls `SessionIdManager.checkAndGetSessionAndWindowId(readOnly=true)`. Because it always passes `readOnly=true`, the idle-rotation branch (`sessionid.ts:388-389`: `activityTimeout = !noSessionId && !readOnly && ...`) is unconditionally `false` for this call path, and the idle-timer is only (re-)armed on non-read-only calls (`sessionid.ts:449-451`). So if `get_session_id()` is the *only* activity being observed, the session never idle-rotates purely from being read — confirmed against `playwright/mocked/cross-tab-session.spec.ts`, which deliberately drives rotation tests through the internal (non-read-only) manager call rather than the public getter. Max-session-length rotation (24h) is *not* gated on `readOnly`, so that rotation path does still work correctly even under read-only polling.
- **Backwards compatibility:** Needs deprecation path — making `get_session_id()` itself force idle-rotation-eligible bookkeeping would change existing consumers' observed session-id stability under passive/read-only polling (e.g., dashboards or analytics wrappers calling it repeatedly without expecting it to affect rotation timing); should be introduced as a clearly versioned/opt-in change.
- **Remediation:** Document the read-only semantics explicitly, or add an opt-in variant that also updates the idle-activity timestamp when called.

### n8 — Group (🟡 Partial)
- **Spec requires:** `group(groupType, groupKey, properties?)` should no-op (guard) for disabled SDKs, opted-out users, or clients configured to never process persons/groups, in addition to validating type/key presence.
- **SDK currently:** `group()` (`packages/browser/src/posthog-core.ts:2936-2975`) validates `groupType`/`groupKey` and correctly dedups `$groupidentify` emission, but has no `_requirePersonProcessing`/opt-out guard at the top — unlike `identify()`, `alias()`, `createPersonProfile()`, and even `setGroupPropertiesForFlags()` (line 3075), all of which call `_requirePersonProcessing(...)` first. `group()` unconditionally persists the `$groups` mapping into `this.persistence` regardless of `person_profiles: 'never'` or opt-out state. The resulting `$groupidentify` *event* is still suppressed downstream by `capture()`'s opt-out gate, but the local state mutation is not gated.
- **Backwards compatibility:** Backward-compatible — adding a `_requirePersonProcessing`/opt-out guard only narrows behavior for the `never`/opted-out edge case; normal-mode callers are unaffected.
- **Remediation:** Add the same `_requirePersonProcessing('posthog.group')` guard used elsewhere at the top of `group()`.

### n9 — Group Identify (🟡 Partial)
- **Spec requires:** A standalone `groupIdentify(groupType, groupKey, groupProperties?, options?)` public method (per the spec's surface-variant table for posthog-js-core/react-native) that emits `$groupidentify` without necessarily mutating ambient `$groups` membership.
- **SDK currently:** No standalone `groupIdentify` method exists on the browser `PostHog` class (`groupIdentify`/`group_identify` in `posthog-core.ts` appear only as a local variable name inside `group()`, line 2956). `$groupidentify` can only be triggered by calling `group(...)`, which always mutates `$groups` persistence as a side effect. `@posthog/core` (`packages/core/src/posthog-core.ts:536`, used by Node/React Native) does implement a standalone `groupIdentify()` — this is specifically a browser-package gap.
- **Backwards compatibility:** Backward-compatible — adding a new `groupIdentify(groupType, groupKey, groupProperties?, options?)` method that emits `$groupidentify` without touching `$groups` persistence is purely additive.
- **Remediation:** Add a standalone `groupIdentify()` method on the browser `PostHog` class for cross-SDK parity.

### n10 — Screen (❌ Fail)
- **Spec requires:** A public `screen(name, properties?, options?)` method that captures a `$screen` event with `$screen_name` and merges custom properties, updating an ambient "current screen" context.
- **SDK currently:** No method literally named `screen` exists anywhere in `packages/browser/src` (confirmed via exhaustive grep of the `PostHog` class and type definitions; the only `screen` hits are unrelated `window.screen` viewport references in `scroll-manager.ts`). The closest analogue, `$pageview` autocapture (`posthog-core.ts:1103-1135, 4308-4338`, `extensions/history-autocapture.ts:95`), injects `$pathname`/`$current_url` into *all* events uniformly, not via a dedicated screen-tracking call, and `PageViewManager._currentPageview` (`page-view.ts:33`) is a weaker, reload-resetting in-memory context than the spec's persistent current-screen-context requirement. No `$screen`/`$screen_name` event or property is ever emitted.
- **Backwards compatibility:** Backward-compatible — adding a `screen(name, properties?)` method that wraps `capture('$screen', {$screen_name: name, ...properties})` and updates an ambient current-screen property would be purely additive with no impact on existing `$pageview` behavior.
- **Remediation:** Add a `screen()` method as a thin wrapper emitting `$screen`/`$screen_name`, for parity with mobile SDKs and any web use cases (e.g. SPA route-as-screen tracking) that want the canonical event name.

### n11 — Shutdown (🟡 Partial)
- **Spec requires:** `shutdown()` flushes pending events and stops accepting new work; capture calls after shutdown should not be silently enqueued; delivery failures during the shutdown flush should be recorded.
- **SDK currently:** `shutdown()` (`packages/browser/src/posthog-core.ts:3258-3276`) stops the remote-config poller, disposes the browser-client adapter and session recording, flushes logs/metrics via `sendBeacon`, and calls `_requestQueue.unload()`/`_retryQueue.unload()`. However it never sets `__loaded = false` (that flag is only ever set false in the constructor, `posthog-core.ts:534`, and never reset elsewhere) and never pauses `_requestQueue`; a `capture()` call issued after `shutdown()` passes all guards, is enqueued, and is later sent on the ~3s timer — contradicting the expectation that post-shutdown captures are not silently accepted. Additionally, `unload()` sends exclusively via `navigator.sendBeacon()`, which is fire-and-forget with no HTTP status visibility, so no delivery-failure warning can be logged from that path even in principle.
- **Backwards compatibility:** Needs deprecation path for the accept-after-shutdown fix — flipping `__loaded`/pausing the queue post-shutdown is a behavior change some callers may inadvertently depend on (e.g. frameworks calling `shutdown()` defensively while still holding a reference to the instance); should ship with a changelog callout even if not a major bump. The sendBeacon delivery-visibility gap is architecturally constrained (Unknown — would require moving shutdown's transport away from sendBeacon, trading off unload reliability).
- **Remediation:** Set `__loaded = false` (or an equivalent "shut down" flag checked by `capture()`) at the end of `shutdown()` so subsequent capture calls are rejected/no-op with a warning, consistent with `setup()`'s guard pattern.

### n12 — Start Session Recording (🟡 Partial)
- **Spec requires:** `startSessionRecording(override?)` activates recording idempotently, respecting opt-out, with any override behavior applying only to the "next attempt."
- **SDK currently:** `startSessionRecording()` (`packages/browser/src/posthog-core.ts:3594-3627`) correctly implements idempotency and opt-out gating (`SessionRecording._isRecordingEnabled`, `session-recording.ts:114-119`, ORs in `consent.isOptedOut()`) for the final start/stop decision. However, the override side effects (`overrideSampling`/`overrideLinkedFlag`/`overrideTrigger`) persist override flags *before* the opt-out/enablement check runs and are not themselves gated by opt-out — only the final decision is. Also, the JSDoc comment (`posthog-core.ts:3592`, "`true` is shorthand for `{ sampling: true, linked_flag: true }`") is stale — passing `true` actually sets all four override flags including `url_trigger`/`event_trigger`.
- **Backwards compatibility:** Backward-compatible — fixing the stale doc comment or tightening opt-out gating around the override-persistence writes are additive/non-breaking changes.
- **Remediation:** Gate the override-persistence writes behind the same opt-out check as the final start decision; correct the JSDoc.

### n13 — Application Lifecycle (➖ N/A)
- **Justification:** The spec targets mobile/native app install/update/open/background lifecycle events with persisted version/build markers — concepts with no meaningful web analogue (a browser page has no installable binary, version metadata, or OS-level foreground/background signal in the same sense). posthog-js does have partial-overlap web mechanisms — `beforeunload`/`pagehide` flush-on-exit (`packages/browser/src/posthog-persistence.ts:168-169`), session idle/max-length rotation (`sessionid.ts`), and `$pageview`/`$pageleave` duration tracking (`page-view.ts`) — but these address flush-on-exit and session lifetime, not install/update/open/background analytics events with persisted version markers, which is the actual subject of this spec. Confirmed via code inspection (not assumption) that no `Application Installed/Updated/Opened/Backgrounded`-equivalent exists in `packages/browser/src` (those events only exist in `packages/react-native*`).

### n14 — Autocapture (🟡 Partial)
- **Spec requires:** Autocapture with configurable knobs including something like `customLabelProp`/`maxElementsCaptured`/`propsToCapture`, screen-name context on captured events, sensitive-data redaction, and debounce for high-frequency inputs.
- **SDK currently:** Core autocapture (click/change/submit/copy/cut listeners, `autocapture.ts:320-336`), sensitive-field exclusion (password/hidden inputs, `sensitiveNameRegex`, Luhn-validated credit-card/SSN scanning — `autocapture-utils.ts:459-604`), and `$elements_chain` construction (`autocapture-utils.ts:700-789`) are all solidly implemented. However, there is no `customLabelProp`/`maxElementsCaptured`/`propsToCapture` config surface (only a hardcoded `MAX_DOM_ANCESTOR_DEPTH=1000` safety bound), and no `$screen_name` property is ever emitted alongside `$autocapture` (confirmed zero repo-wide hits) — the acceptance scenario explicitly expects `$screen_name` in emitted properties. No explicit debounce exists for high-frequency controls like sliders (relies incidentally on native `change`, not `input`, event semantics).
- **Backwards compatibility:** Backward-compatible — adding the missing config knobs and an optional URL/route-based screen-name-equivalent property are additive; no existing behavior needs to change.
- **Remediation:** Add `maxElementsCaptured`/`customLabelProp`/`propsToCapture` config options; consider adding a `$screen_name` (or `$pathname`-derived equivalent) property to `$autocapture` events for cross-SDK property parity.

### n15 — Before Send Hook (🟡 Partial)
- **Spec requires:** `before_send` hook execution must never crash the caller; a throwing hook should be caught, logged, and the pipeline should keep the last good event.
- **SDK currently:** `_runBeforeSend()` (`packages/browser/src/posthog-core.ts:4406-4451`, invoked from `capture()` at line 1556) correctly implements array-chaining in registration order and stop-on-drop semantics, plus extra safety (warns and drops if a hook strips an ingestion-required property like `token`). However there is no try/catch around the hook invocation itself (`fn(beforeSendResult)`, line 4421) — a throwing hook propagates uncaught through `_runBeforeSend()` → `capture()` → the caller, since `capture` is not in the `safewrapClass` allowlist (only `identify` is wrapped, line 4509). This directly contradicts the spec's "keeps the last good event and continues... does NOT crash capture" requirement and the corresponding acceptance scenario.
- **Backwards compatibility:** Backward-compatible — wrapping the hook call in try/catch that logs a warning and falls back to the pre-call event is purely additive defensive code with no change to documented success-path behavior.
- **Remediation:** Wrap each `fn(beforeSendResult)` call in `_runBeforeSend()` in try/catch, logging a warning and continuing with the last good result on throw.

### n16 — Event Batcher (❌ Fail)
- **Spec requires:** Batching with both a count-based threshold (`flushAt`) and a time-based threshold, a `maxBatchSize` cap that splits a large queue into bounded requests, request-size awareness, and 413-specific shrink-and-retry handling.
- **SDK currently:** The real browser capture path (`capture()`/`identify()`/`alias()`) enqueues into `RequestQueue` (`packages/browser/src/request-queue.ts`), wired via `posthog-core.ts:738-739`. `RequestQueue.enqueue()` (lines 28-34) has no count-based threshold at all — only a timer (`DEFAULT_FLUSH_INTERVAL_MS=3000ms`, clamped 250–5000ms). `_formatQueue()` (lines 93-108) drains the *entire* queue as one request on every timer tick — no `maxBatchSize` cap, no serialized-size check, and no 413-specific shrink-and-retry logic anywhere in `request-queue.ts`/`retry-queue.ts`/`request.ts` (confirmed via grep). A more complete batching engine satisfying most of these requirements exists in `packages/core/src/posthog-core-stateless.ts` (used by Node/React Native, and narrowly by the browser SDK's internal `logs`/`metrics` sub-clients) but is not used for ordinary `posthog.capture()` calls.
- **Backwards compatibility:** Needs deprecation path — adding genuine `flushAt`/`maxBatchSize` thresholds changes request-shaping/timing behavior that some integrations may depend on (e.g. request-count assumptions in test harnesses or backend rate expectations); should ship behind a new config default and be validated before becoming default-on.
- **Remediation:** Port (or share) the batching logic from `posthog-core-stateless.ts` into the browser `RequestQueue`, adding count-based flush, a batch-size cap, and 413 shrink-and-retry.

### n17 — Flag Definition Loader (➖ N/A)
- **Justification:** This spec describes fetching full flag *definitions* (rollout rules/conditions) via a personal/project secret API key so a server SDK can evaluate flags locally without a network round-trip per user. A browser cannot safely hold a personal/project secret key. Confirmed via code inspection (not assumption): zero hits for `personal_api_key`, `local_evaluation`, or an ETag-polling definitions loader anywhere in `packages/browser/src` or `packages/core/src`; the equivalent (`PostHogFeatureFlagsPoller`) exists only in the separate server package `packages/node/src/extensions/feature-flags/feature-flags.ts`, out of scope for this browser-SDK audit. All browser flag requests go through the public-token remote-evaluation `/flags/?v=2` endpoint.

### n18 — HTTP Client (🟡 Partial)
- **Spec requires:** Feature-flag evaluation requests retry transient transport failures and HTTP 502/504 with a bounded default (1 retry) and exponential backoff (300ms→600ms).
- **SDK currently:** Endpoint construction, JSON+gzip/base64 compression, and fetch→XHR→sendBeacon transport fallback are all solid (`request.ts:116-141, 492-517`; `posthog-featureflags.ts:660`). However `_callFlagsEndpoint` (`posthog-featureflags.ts:604-740`) makes exactly one `_send_request()` call with no retry loop and no 502/504 branching (confirmed via grep — zero hits for "502", "504", "retriesPerformedSoFar" in that file). The only related mechanism is an unrelated circuit breaker (`MAX_CONSECUTIVE_FLAGS_STATUS_ZERO_FAILURES=3`) that stops future *reloads* after repeated `statusCode===0` failures, not a per-request retry. The closest sibling implementation (`packages/core/src/posthog-core-stateless.ts`, Node/RN) also deviates from spec — it retries with a flat 3000ms delay, not the spec's exponential 300ms→600ms.
- **Backwards compatibility:** Backward-compatible — adding a bounded retry-with-backoff wrapper around `_callFlagsEndpoint`'s single request call is purely additive and only changes behavior on requests that currently fail outright.
- **Remediation:** Add a 1-retry, 300ms→600ms exponential-backoff wrapper around the flags-endpoint request, scoped to transient transport errors and 502/504.

### n19 — Local Feature Flag Evaluator (➖ N/A)
- **Justification:** Local rollout-percentage hashing, cohort matching, and condition evaluation against a full flag-definition set is a server-SDK concept requiring the (server-only) flag definitions from n17. Confirmed via code inspection: no such logic exists in `packages/browser/src` or `packages/browser-common/src`; all flag values are computed server-side and only read/cached by the browser SDK (see Feature Flag Cache, #44, which is PASS).

### n20 — Persistent Storage (🟡 Partial)
- **Spec requires:** A defined fallback chain (e.g. localStorage → cookie → memory) with memory as a true last-resort fallback; treating a `null`/deleted property value as removal; and durable storage of queued outgoing events.
- **SDK currently:** Token-namespaced keys, lazy load-then-cache, defensive JSON-parse-failure handling, and non-throwing write failures are all solid (`posthog-persistence.ts`, `storage.ts`). However: (1) the localStorage→cookie→memory chain does not reach `memoryStore` automatically — unsupported localStorage falls to a `localStorage+cookie` hybrid then plain cookie; memory is only used via explicit `persistence: 'memory'` config (`posthog-persistence.ts:186-237`). (2) Setting a property to `null` via `register()` does not remove it from storage — `_setProp` (`posthog-persistence.ts:879`) literally stores `null`; only a separate `unregister()`/`_deleteProp` call deletes a key. (3) Queued outgoing events live only in an in-memory array (`request-queue.ts:12`), not durably persisted to localStorage/cookie — a hard crash/tab-kill loses pending events beyond what `sendBeacon`-on-unload salvages.
- **Backwards compatibility:** Needs deprecation path — changing `null`-via-`register()` to delete the key, or adding a true memory-store automatic fallback, could change subtle behavior some integrations may rely on (e.g. code that stores a literal `null`) and should be tested/flagged carefully; a durable event queue would need to ship as a new opt-in mode to avoid behavior-change risk.
- **Remediation:** Consider making `register(key, null)` delete the key (with a deprecation warning first); consider a true automatic memory-store fallback; evaluate whether a durable (localStorage-backed) outgoing-event queue is worth the complexity for crash-resilience parity.

### n21 — Remote Config (🟡 Partial)
- **Spec requires:** Single, deduplicated in-flight config load; a clean config cache that is cleared on `reset()`.
- **SDK currently:** The `/array/{token}/config` fetch, extension fan-out, and non-throwing cached-fallback failure handling are all solid (`remote-config.ts`). However: (1) `RemoteConfigLoader` has no `_isLoading`/in-flight-dedup guard, and `session-recording.ts:363` spins up a *second, uncoordinated* `RemoteConfigLoader` instance that can race the primary one (contrast with `/flags` loading, which does dedupe via `_reloadDebouncer`). (2) `reset()` deliberately preserves `SESSION_RECORDING_REMOTE_CONFIG` across the full persistence clear (`posthog-core.ts:3154-3182`, an explicit documented carve-out for replay continuity), contradicting a strict "clears config-derived caches on reset" reading. (3) No unified config cache — persistence is fragmented per-feature.
- **Backwards compatibility:** Backward-compatible for adding an in-flight-load guard and reusing a single `RemoteConfigLoader` instance (internal correctness fix, no public API change). Needs deprecation path for changing the reset()-preserves-replay-config behavior, since it's a deliberate design choice existing integrations may rely on for replay continuity across reset.
- **Remediation:** Add an in-flight guard to `RemoteConfigLoader` and have session-recording reuse the primary loader instance rather than creating its own.

### n22 — Retry Queue (🟡 Partial)
- **Spec requires:** A bounded retry queue (drops/caps when capacity exceeded), treats 429 as retryable, honors `Retry-After`, and has 413-specific shrink-and-retry.
- **SDK currently:** `retry-queue.ts` implements real exponential backoff with jitter (base 3000ms × 2^retries, capped 30min, ±50% jitter) and a max-retry count (`DEFAULT_MAX_RETRIES=10`, `STATUS_CODE_ZERO_MAX_RETRIES=3`). However: (1) `_enqueue()` (lines 105-124) has no capacity cap — pushes unconditionally with no `maxRetryQueueSize`/drop-when-full logic. (2) Retry classification (line 82: `statusCode !== 200 && (statusCode < 400 || statusCode >= 500)`) puts 429 in the non-retryable 4xx bucket, so rate-limited requests are dropped on first failure rather than retried, contradicting the spec's expectation that 429 is retryable. (3) No `Retry-After` header parsing anywhere — backoff is purely retry-count-derived, never server-directed. (4) No 413-specific shrink-and-retry (413 falls into the same dropped 4xx bucket).
- **Backwards compatibility:** Needs deprecation path — adding a queue-size cap and 429/Retry-After handling changes drop/retry timing behavior for existing integrations; should be introduced as configurable with a permissive default to avoid altering current delivery characteristics.
- **Remediation:** Add a bounded queue size with drop-oldest/drop-newest policy; special-case 429 as retryable (optionally honoring `Retry-After`); add 413 shrink-and-retry.

### n23 — Session Replay Ingestion Controls (🟡 Partial)
- **Spec requires:** Evaluating a linked feature flag for replay gating should report it as a flag call (`$feature_flag_called`); URL-trigger activation (in addition to event-trigger activation) should release the "interaction hold."
- **SDK currently:** Enablement gating, linked-flag matching (all three shapes), deterministic hash-based sampling, event/URL trigger matching, AND/OR trigger combination, and the "interaction hold" mechanism for unconfirmed-activity recording epochs are all extensively and correctly implemented (`session-recording.ts`, `triggerMatching.ts`, `extensions/sampling.ts`, `lazy-loaded-session-recorder.ts`, `recording-strategies.ts`). However: (1) the linked flag is resolved via a passive `onFeatureFlags(...)` subscription callback (`triggerMatching.ts:391-431`) that only reads already-loaded flag values and never calls `capture('$feature_flag_called', ...)` — that capture only happens inside the imperative `getFeatureFlag()`/`getFeatureFlagPayload()` paths — so evaluating a replay `linkedFlag` does not report flag-called usage, missing that sub-clause of the requirement. (2) Only event triggers release the interaction hold (`lazy-loaded-session-recorder.ts`, explicit code comment: "URL and linked-flag activations never release — they fire without a human present"), narrower than the spec's release-condition list which also names URL triggers.
- **Backwards compatibility:** Backward-compatible — both fixes only add new cases where flag-usage is reported or the hold is released; no existing observable capability is removed. (Reporting `$feature_flag_called` on linked-flag evaluation does add feature-flag-called event volume, a minor product-metric side effect worth a staged rollout, but it is not breaking.)
- **Remediation:** Emit `$feature_flag_called` when the replay linked-flag is evaluated (mirroring the imperative getter path); have URL-trigger activation also release the interaction hold.

### n24 — Surveys (🟡 Partial)
- **Spec requires:** Opt-out state should prevent survey fetch/display (not just the resulting response-event emission); `reset()` should clear all seen/in-progress/abandoned survey state; `survey abandoned` should carry the same `$set` interaction marker as `sent`/`dismissed`.
- **SDK currently:** Init gating, fetch/cache/TTL-refresh with in-flight dedup, full eligibility pipeline (URL/device/CSS-selector matching), event-name compliance, and Preact+shadow-DOM rendering are all solidly implemented (`posthog-surveys.ts`, `surveys.tsx`). However: (1) opt-out is only enforced for survey fetch/display in `cookieless_mode` (`posthog-surveys.ts:125`) — in standard mode, a fully opted-out user still has surveys fetched and popovers rendered; only the resulting `capture()` event is suppressed (indirectly, via the generic `is_capturing()` gate). This contradicts a "no survey display" reading of the opt-out acceptance scenario. (2) `reset()`'s storage sweep (`posthog-surveys.ts:91-110`) only clears `seenSurvey_`/`inProgressSurvey_` prefixes, never `abandonedSurvey_`. (3) `survey abandoned` lacks the `$set` interaction marker that `sent`/`dismissed` both carry.
- **Backwards compatibility:** Needs deprecation path — actually gating survey fetch/display (not just event emission) on opt-out state changes visible behavior for currently-opted-out users who today still see surveys; should ship behind a flag or be documented as an explicit behavior change. The reset()-sweep and `abandoned` `$set`-marker fixes are Backward-compatible (additive/internal correctness fixes only).
- **Remediation:** Gate survey fetch/render (not just capture) on `is_capturing()`/opt-out outside cookieless mode; extend the `reset()` sweep to also clear `abandonedSurvey_` keys; add the `$set` marker to `survey abandoned`.

### n25 — Traces (❌ Fail)
- **Spec requires:** A generic APM tracing capability — `startSpan`/`withSpan` API, W3C traceparent interop, OTLP span data model, HTTP transport to `POST {host}/i/v1/traces`.
- **SDK currently:** Exhaustive search (`find -iname "*trace*"`, grep for `startSpan|withSpan|spanId|resourceSpans|scopeSpans|traceparent|tracestate|i/v1/traces`) found zero implementation anywhere in the repo, including `packages/browser`. The only tracing-adjacent code is `packages/ai/src/otel/exporter.ts` — the separate `@posthog/ai` LLM-analytics package's OTLP trace exporter for AI-generation spans (a distinct product feeding `$ai_trace_id`-based LLM analytics, not generic APM) — and `captureTraceFeedback`/`captureTraceMetric` (`posthog-core.ts:4476, 4494`), which only attach feedback to an *existing* `$ai_trace_id` rather than creating spans. No `traces` config object exists in `packages/types/src/posthog-config.ts`.
- **Backwards compatibility:** Backward-compatible — this is a wholly new, opt-in feature; adding a `traces` config object and `startSpan`/`withSpan` API would not touch any existing public surface.
- **Remediation:** Implement a generic tracing/span API and OTLP `/i/v1/traces` transport, analogous to the already-implemented `logs` capability (#56, PASS) which ships a comparable OTLP pipeline for `/i/v1/logs` and can serve as an architectural template.
