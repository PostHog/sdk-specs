# posthog-dotnet — SDK Compliance

**Repo:** [PostHog/posthog-dotnet](https://github.com/PostHog/posthog-dotnet)
**Audited commit:** `e7f20e3d359a9481c8b9a7b8f22d6acf3788850e` ([commit](https://github.com/PostHog/posthog-dotnet/commit/e7f20e3d359a9481c8b9a7b8f22d6acf3788850e)) — audited on 2026-08-06
**Audited against sdk-specs commit:** `b59e8b430c83c5549fc396c8b092615b79d08dd4`
**Summary:** 7 ✅ · 15 🟡 · 9 ❌ · 28 ➖ · 0 ❓

Note on repo layout: `posthog-dotnet` is a multi-package repo with three shipped NuGet packages —
`PostHog` (core, `src/PostHog/`), `PostHog.AspNetCore` (`src/PostHog.AspNetCore/`), and `PostHog.AI`
(LLM observability for OpenAI/etc., `src/PostHog.AI/`) — plus a `sdk_compliance_adapter/` project
that wraps the SDK for the cross-SDK test harness. Core public API surface lives in
`src/PostHog/PostHogClient.cs` (`IPostHogClient`: `Capture`, `IdentifyAsync`, `GroupIdentifyAsync`,
`AliasAsync`, `CaptureException`, the deprecated single-flag `GetFeatureFlagAsync`/
`IsFeatureEnabledAsync`, the canonical snapshot-based `EvaluateFlagsAsync` → `FeatureFlagEvaluations`
(`enabled?`/`GetFlag`/`GetFlagPayload`), `GetAllFeatureFlagsAsync`, `LoadFeatureFlagsAsync`,
`FlushAsync`); `Features/LocalFeatureFlagsLoader.cs`/`LocalEvaluator.cs` implement ETag-polled local
flag-definition evaluation gated by a `SecretKey`/personal-API-key; `Features/*FeatureFlagCache.cs`
cache flag responses per-`distinctId`; `Library/AsyncBatchHandler.cs` is the batching/queue engine;
`Api/PostHogApiClient.cs` is the HTTP transport (retry, gzip); `ErrorTracking/` builds
`$exception`/`$exception_list` payloads; `PostHogContext.cs` is an `AsyncLocal`-scoped
request-context used to resolve ambient `distinct_id`/`session_id`. `PostHog.AspNetCore/Tracing/`
adds ASP.NET Core middleware that extracts `X-POSTHOG-*` headers into `PostHogContext` (the
Tracing Headers contract) and `FeatureManagement/` wires flags into `Microsoft.FeatureManagement`.
This is a **server-side SDK** — a console-app/ASP.NET-Core library with no UI, no session replay,
no autocapture, no surveys, and no persistent local storage across process restarts; identity is
either passed explicitly per call or resolved from a request-scoped `AsyncLocal` context, matching
the shape of posthog-ruby/posthog-python/posthog-node rather than posthog-ios/posthog-android. All
file paths below are relative to `/tmp/audit-posthog-dotnet/` unless noted.

| # | Contract | Status | Note |
|---|----------|--------|------|
| 1 | Alias | 🟡 | [n1] |
| 2 | Application Lifecycle | ➖ | mobile/native app install/foreground/background lifecycle; spec explicitly excludes server SDKs; acceptance is `@client`-only |
| 3 | Autocapture | ➖ | browser/mobile UI-event auto-capture; spec excludes server SDKs (no UI event stream); acceptance is `@client`-only |
| 4 | Before Send Hook | 🟡 | [n2] |
| 5 | Bootstrap | ➖ | client-side cold-start identity/flag hydration from persisted/server-rendered values; acceptance is `@client`-only; no cold-start/local-storage problem exists in a stateless server SDK |
| 6 | Capture | 🟡 | [n3] |
| 7 | Capture Exception | 🟡 | [n4] |
| 8 | Consent Gating | ➖ | client-side persistent per-user consent gate (`Applicability: client`); acceptance is `@client`-only; the constructor-time `Disabled` option is a static kill-switch, not a runtime consent layer |
| 9 | Create Person Profile | ➖ | client-side identity/profile-control API scoped by spec to the posthog-js family; acceptance is `@client`-only; no equivalent concept exists server-side |
| 10 | Debug | 🟡 | [n5] |
| 11 | Device ID Generator | ➖ | client-side persisted device-id bootstrap (`Applicability: client`); acceptance is `@client`-only; SDK is stateless per call with no persisted device concept |
| 12 | Event Batcher | ✅ | |
| 13 | Exception Steps | ➖ | spec explicitly scopes single-user breadcrumb buffer to client SDKs, server/multi-tenant explicitly out of scope pending a follow-up spec; acceptance is `@client`-only |
| 14 | Feature Flag Cache | 🟡 | [n6] |
| 15 | Feature Flag Called Tracker | 🟡 | [n7] |
| 16 | Flag Definition Loader | 🟡 | [n8] |
| 17 | Flush | 🟡 | [n9] |
| 18 | Get Anonymous ID | ➖ | client-side ambient-identity getter (`Applicability: client`); acceptance is `@client`-only |
| 19 | Get Distinct ID | 🟡 | [n10] |
| 20 | Get Feature Flag | 🟡 | [n11] |
| 21 | Get Feature Flag Payload | ❌ | [n12] |
| 22 | Get Feature Flag Result | 🟡 | [n13] |
| 23 | Get Feature Flags | ✅ | |
| 24 | Get Feature Flags And Payloads | ✅ | |
| 25 | Get Session ID | ➖ | client-side ambient session-id getter; acceptance is `@client`-only; SDK relays a caller/header-supplied session id but owns no session lifecycle |
| 26 | Group | ➖ | client-side ambient-context setter distinct from `group_identify`; spec explicitly notes server SDKs expose `group_identify` directly instead; acceptance is `@client`-only |
| 27 | Group Identify | 🟡 | [n14] |
| 28 | HTTP Client | ✅ | |
| 29 | Identify | 🟡 | [n15] |
| 30 | Is Feature Enabled | ❌ | [n16] |
| 31 | Is Opt Out | ➖ | client-side persisted consent-state getter (`Applicability: client`); acceptance is `@client`-only |
| 32 | Is Session Replay Active | ➖ | client-side session-replay status getter; acceptance is `@client`-only |
| 33 | Local Feature Flag Evaluator | ✅ | |
| 34 | Logs | ❌ | [n17] |
| 35 | On Feature Flags | ➖ | client-side callback/event surface tied to ambient flag state; acceptance file has no `@both`/`@server` scenario (unlike the "...For Flags" contracts); SDK's flag APIs are pull-only |
| 36 | Opt In | ➖ | client-side persistent consent toggle (`Applicability: client`); acceptance is `@client`-only |
| 37 | Persistent Storage | ➖ | client-side persistent state layer (ambient identity/cached SDK state); acceptance is `@client`-only; SDK has no local disk/keychain persistence |
| 38 | Register | ➖ | client-side persistent super-properties registry; acceptance is `@client`-only with no server/both scenario; SDK's `SuperProperties` is a static, init-only config value, not a runtime mutation API |
| 39 | Reload Feature Flags | ➖ | client-side ambient-flag-cache refresh keyed to a single "current user"; acceptance is `@client`-only; SDK has no ambient identity or single per-identity flag cache to refresh (cache is keyed per explicit call args) |
| 40 | Remote Config | ➖ | client-side project-config bootstrap bundling replay/surveys/error-tracking settings with flag preload; acceptance is `@client`-only; SDK's `GetRemoteConfigPayloadAsync` is an unrelated per-flag encrypted-payload fetch that happens to share the name |
| 41 | Reset | ➖ | client-side ambient-identity/session/super-properties clear (`Applicability: client`); acceptance is `@client`-only; no `Reset()` exists on `IPostHogClient` (the API-client `ResetAsync` sends an unrelated `$reset` analytics event) |
| 42 | Reset Group Properties For Flags | ❌ | [n18] |
| 43 | Reset Person Properties For Flags | ❌ | [n18] |
| 44 | Retry Queue | ❌ | [n19] |
| 45 | Screen | ➖ | client-side screen-view capture primitive (`Applicability: client`); acceptance is `@client`-only; no `Screen()` symbol exists |
| 46 | Session Manager | ➖ | client-side ambient session id/rotation/persistence; acceptance (private) is `@client`-only; SDK relays a caller-supplied session id with no rotation/timeout logic |
| 47 | Session Replay Ingestion Controls | ➖ | browser/mobile session-replay sampling/trigger controls; acceptance is `@client`-only |
| 48 | Session Replay Privacy | ➖ | browser/mobile DOM/screenshot masking; acceptance is `@client`-only |
| 49 | Set Group Properties For Flags | ❌ | [n18] |
| 50 | Set Person Properties | ➖ | client-side ambient-identity property setter; spec's own scope note says server SDKs express this via identify-style event APIs instead — which the SDK provides (`IdentifyAsync`, `Capture(..., personPropertiesToSet, ...)`); acceptance is `@client`-only |
| 51 | Set Person Properties For Flags | ❌ | [n18] |
| 52 | Setup | 🟡 | [n20] |
| 53 | Shutdown | ✅ | |
| 54 | Start Session Recording | ➖ | client-side session-replay control; acceptance is `@client`-only |
| 55 | Stop Session Recording | ➖ | client-side session-replay control; acceptance is `@client`-only |
| 56 | Surveys | ➖ | browser/mobile survey display lifecycle; acceptance is `@client`-only; SDK does provide manual `CaptureSurveyResponse`/`CaptureSurveyShown`/`CaptureSurveyDismissed` event helpers matching the spec's own server-SDK carve-out, but implements no eligibility/display lifecycle |
| 57 | Traces | ❌ | [n21] |
| 58 | Tracing Headers | ✅ | |
| 59 | Unregister | ➖ | client-side persistent super-properties registry; acceptance is `@client`-only; no register/super-property mutation API exists to unregister from |

## Notes

### n1 — Alias (🟡 Partial)
- **Spec requires:** `both` applicability. The `@both`-tagged acceptance scenario "Alias is dropped when required identities are missing" (`acceptance/public/alias.feature:34-42`) requires that calling alias without a previous distinct id enqueues no event and records a validation warning.
- **SDK currently:** `AliasAsync(previousId, newId, cancellationToken)` (`src/PostHog/PostHogClient.cs:189-208`) delegates to `PostHogApiClientExtensions.AliasAsync` (`src/PostHog/Api/PostHogApiClientExtensions.cs:70-95`), which sends `$create_alias` with `distinct_id`/`alias` correctly shaped for the `@server` happy-path scenario. However there is no presence validation anywhere on `previousId`/`newId` — `src/PostHog/Library/Ensure.cs` only implements `NotNull<T>` (reference-null check), and no call site applies even that check to these string arguments. An empty/whitespace id is silently POSTed to the server rather than dropped with a warning. No test in `tests/UnitTests/PostHogClientTests.cs` covers this.
- **Backwards compatibility:** Backward-compatible — adding a drop-with-warning presence check changes behavior only for already-malformed calls (previously silently sent, now silently no-op); no signature change.
- **Remediation:** Add an empty/whitespace guard on `previousId`/`newId` in `AliasAsync` that logs a warning and returns a no-op `ApiResult` without calling the API.

### n2 — Before Send Hook (🟡 Partial)
- **Spec requires:** `both` applicability. A `beforeSend` hook that may mutate or drop (return `null`) an event before enqueue; on hook exception, must not crash the caller; spec permits (does not mandate) hook chaining via an array of hooks run in order, stopping on a drop.
- **SDK currently:** `PostHogOptions.BeforeSend` (`src/PostHog/Config/PostHogOptions.cs:147`) is a single `Func<CapturedEvent, CapturedEvent?>?`. `PostHogClient.ApplyBeforeSend`/`CaptureBatchAsync` (`PostHogClient.cs:423-471`) run it after full event enrichment (super properties, `$lib`, flags), correctly drop the event on a `null` return, and catch any exception from the hook (`catch (Exception ex)`, `PostHogClient.cs:465`), logging and dropping just that event rather than crashing. This satisfies the "never crash the caller" requirement, though the .NET SDK's failure-mode choice (drop the event) differs from peers that fall back to the last-good/original event on hook exception — a valid but stricter SDK-specific policy per the spec's "handled according to SDK policy" language. Gap: there is no first-class support for an array of chained hooks — only a single delegate can be assigned to `BeforeSend`.
- **Backwards compatibility:** Needs deprecation path if pursued via retyping — changing `BeforeSend`'s property type outright (e.g. to `List<Func<...>>`) would break any existing `options.BeforeSend = someLambda` assignment. Adding a *new*, additive chaining mechanism alongside the existing single-hook property is backward-compatible.
- **Remediation:** Add an additive mechanism for registering multiple hooks (composed internally, stopping on the first `null`) rather than changing `BeforeSend`'s existing type; add a unit test asserting a warning/error log call on hook exception (currently only inferable from code, not asserted).

### n3 — Capture (🟡 Partial)
- **Spec requires:** `both` applicability. Event name must be non-empty; on server SDKs `distinct_id` must also be present and non-empty — the spec's own prose claims "Go and .NET enforce this with explicit validation errors." Error handling section separately states the general rule: "Drop silently on... empty/invalid event name, invalid distinct id (server)... Never throw to the caller under normal operation."
- **SDK currently:** `CaptureCore` (`src/PostHog/PostHogClient.cs:298-394`) has no guard on `eventName` at all — an empty/null-at-runtime event name flows straight into `new CapturedEvent(...)` and is enqueued, not dropped and not throwing. For a missing `distinctId`, `PostHogContextHelper.ResolveIdentity` (`src/PostHog/PostHogContext.cs:126-142`) silently substitutes a fresh `Guid.NewGuid()` and marks the event personless — again, neither the "explicit validation error" the spec's prose attributes to .NET, nor a clean drop; confirmed by test `tests/UnitTests/PostHogContextTests.cs:69-77` (`FreshScopeWhitespaceDistinctIdIsIgnored`), which asserts silent substitution, not an exception. The spec's specific claim that .NET "enforces this with explicit validation errors" does not match this codebase.
- **Backwards compatibility:** Backward-compatible if fixed via drop-silently (matches the general spec rule and is the lower-risk option); Breaking if fixed via throw (matching the spec's literal — likely stale — claim about .NET), since existing callers passing empty strings today get silent success and would newly get an exception.
- **Remediation:** Add a guard in `CaptureCore`: if `string.IsNullOrEmpty(eventName)`, log a warning and return `false` without enqueueing. Flag to spec maintainers that the capture spec's claim about .NET's validation behavior does not match current SDK behavior, so either the prose or the SDK needs to change.

### n4 — Capture Exception (🟡 Partial)
- **Spec requires:** flat top-level `$exception_type`/`$exception_message` alongside the structured `$exception_list`; stack frames ordered outermost/entry-point first, crash site last (SDKs on crash-first runtimes like .NET must reverse).
- **SDK currently:** `ExceptionPropertiesBuilder.Build` (`src/PostHog/ErrorTracking/ExceptionPropertiesBuilder.cs:23-24,32`) correctly sets flat `$exception_type`/`$exception_message` alongside `$exception_list`, and cause-chain ordering (outer exception first, root cause last) is correct via a depth-tracking `Stack<(Exception, depth)>` (lines 37-90). However `BuildStackFrameList` (lines 92-138) iterates `System.Diagnostics.StackTrace(exception, true).GetFrames()` directly with no reversal — .NET's native frame order is crash-site-first, so `frames[0]` is the throw site rather than the outermost caller the spec requires. No test asserts frame order. Null-exception and general-exception handling correctly avoid throwing (`CaptureExceptionCore`, `PostHogClient.cs:494-537`).
- **Backwards compatibility:** Backward-compatible — reversing the frame array only changes wire-payload internal ordering, not any public type/signature.
- **Remediation:** Reverse the frame list in `BuildStackFrameList` before returning so index 0 is outermost and the last entry is the crash site; add a regression test asserting frame order for a multi-frame call chain.

### n5 — Debug (🟡 Partial)
- **Spec requires:** `client` applicability, with its own carve-out: "some SDKs expose only configuration-time logging options instead of a public runtime method."
- **SDK currently:** No runtime `Debug(bool)` toggle exists — the only relevant hits are the standard `LogLevel.Debug` severity and `PostHogSdk.LoggerFactory` (`src/PostHog/PostHogSdk.cs:47-50`), configured once at setup via `Microsoft.Extensions.Logging`, not toggled at runtime. This satisfies the spec's own config-time carve-out in spirit but cannot execute the acceptance file's literal runtime enable/disable/default-true scenarios — landing as Partial rather than a clean N/A, consistent with how the equivalent Ruby audit treated `logging.rb`'s plain log-line emitter.
- **Backwards compatibility:** Backward-compatible — a new `PostHogClient.SetDebug(bool)`/`PostHogSdk.Debug(bool)` runtime toggle would be a pure addition.
- **Remediation:** Either add a lightweight runtime verbosity toggle gating an internal flag (no network/analytics side effects), or explicitly document that debug verbosity is controlled exclusively via `Microsoft.Extensions.Logging` configuration as the server-SDK equivalent.

### n6 — Feature Flag Cache (🟡 Partial)
- **Spec requires:** `client` applicability prose, but describes generic caching-with-TTL semantics; audited server SDKs (e.g. per prior posthog-ruby precedent) are held to a substance-based reading when a real cache subsystem exists.
- **SDK currently:** `Features/{IFeatureFlagCache.cs,FeatureFlagCacheBase.cs,MemoryFeatureFlagCache.cs,FallbackFeatureFlagCache.cs,FeatureFlagCacheKey.cs}` plus `PostHog.AspNetCore/Cache/HttpContextFeatureFlagCache.cs` implement a real per-`(distinctId, personProperties, groups)` cache with a 10-second TTL and a per-HTTP-request-scoped variant. Gaps: cache writes replace the cached `FlagsResult` wholesale rather than merging on a partial/error response (so a transient `ErrorsWhileComputingFlags` response can overwrite a previously-good cache entry with a degraded one), and there is no listener/change-notification hook on cache update. There is also no single ambient "current identity" cache-clear-on-reset concept, since the SDK has no `Reset()` (see contract 41) — an architectural mismatch rather than a bug.
- **Backwards compatibility:** Backward-compatible — merge-on-partial-response semantics can be layered onto `FeatureFlagCacheBase`'s existing write path without changing the public cache interface.
- **Remediation:** Add partial-response merge logic so a degraded fetch doesn't wholesale-replace a good cache entry; document that identity-reset invalidation is architecturally N/A for this stateless-per-call SDK.

### n7 — Feature Flag Called Tracker (🟡 Partial)
- **Spec requires:** dedupe `$feature_flag_called` by `(flag, value, distinct_id, normalized groups)`; bounded eviction that SHOULD evict incrementally rather than full-clearing; clear on identity reset / SDK shutdown; minimal-event mode (gated by server `minimalFlagCalledEvents` + flag `has_experiment == false`) whose allowlist must include, per the most recent sdk-specs fix (commit `b59e8b4`), 10 session-attribution properties (`$referring_domain`, `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `utm_term`, `gad_source`, `mc_cid`, `gclid`, `fbclid`) while still excluding `$referrer`.
- **SDK currently:** `_featureFlagCalledEventCache` (`PostHogClient.cs:24,112-117`) is a `MemoryCache` keyed on `(distinctId, featureKey, cacheKeyValue, groupsCacheKey)` (`PostHogClient.cs:931-932`); `CanonicalGroupsCacheKey` (`PostHogClient.cs:968-978`) correctly sorts group pairs so insertion order doesn't create spurious cache misses — satisfying the group-normalization requirement and the `@server` group-context scenarios. Capacity handling uses `MemoryCache.Compact(0.2)` (`PostHogClient.cs:954-960`, `PostHogOptions.cs:169`) — a genuine incremental (20%) LRU-style eviction, not a full clear, correctly matching the spec's SHOULD guidance (better than some peer SDKs' full-clear-on-capacity behavior). The cache is disposed on `DisposeAsync`/shutdown (`PostHogClient.cs:1411`), satisfying the shutdown-clear MUST. Gap: `MinimalFeatureFlagCalledEventProperties` (`PostHogClient.cs:31-50`) contains the 16 posthog-python-reference-style core properties (including `$geoip_disable`/`$is_server`) but is **missing all 10 of the session-attribution properties** added by sdk-specs commit `b59e8b4` — none of `$referring_domain`, `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `utm_term`, `gad_source`, `mc_cid`, `gclid`, `fbclid` are present (it does correctly have no `$referrer` entry, but that's moot without the offsetting allowlist additions). Since `SuperProperties` (`PostHogOptions.cs:137-141`) is exactly the mechanism a caller would use to register UTM/attribution values as ambient properties on a server, this SDK is just as exposed to the "minimized event silently nulls session attribution" failure mode the spec's rationale describes. There is also no separate `Reset()`-triggered clear, but this is a direct consequence of the SDK having no `Reset()` API at all (contract 41), not a tracker-specific defect.
- **Backwards compatibility:** Backward-compatible — adding entries to an allowlist array only retains more data in minimized events; strictly additive.
- **Remediation:** Add the 10 session-attribution property names from sdk-specs commit `b59e8b4` to `MinimalFeatureFlagCalledEventProperties` in `PostHogClient.cs`.

### n8 — Flag Definition Loader (🟡 Partial)
- **Spec requires:** `both` applicability (`@server`-tagged acceptance). ETag-conditional polling of local flag/cohort definitions gated by a personal/secret key; quota-limited backoff; stale-on-failure preservation; and an external/shared `flag_definition_cache`-style provider seam that other SDKs (e.g. Ruby's `FlagDefinitionCacheProvider`) use for distributed caching (e.g. Redis) across processes.
- **SDK currently:** `Features/LocalFeatureFlagsLoader.cs` implements secret-key gating, a dedicated `/flags/definitions` endpoint with full ETag/304 handling (preserving prior definitions on `NotModified`), a `PeriodicTimer`-based poll loop (default 30s), quota-limited backoff that clears the ETag and stops polling, stale-on-failure preservation, `IsLoaded`/`FlagDefinitionsLoadedAt` readiness signals, explicit `Clear()`, and graceful async disposal — this is a solid, well-tested implementation of the polling/ETag core. Gap: there is no external/shared flag-definition cache-provider abstraction anywhere in the codebase (no `IFlagDefinitionCacheProvider`-equivalent seam) — every process fetches/polls independently, with no hook for a Redis-backed or otherwise distributed provider.
- **Backwards compatibility:** Backward-compatible — a provider seam can be added as an optional constructor/DI parameter defaulting to "no provider, fetch directly," matching the spec's fail-safe-to-direct-fetch requirement.
- **Remediation:** Introduce an optional cache-provider seam (fetch-decision, read, store, shutdown hooks; sync + async) in `LocalFeatureFlagsLoader`, mirroring posthog-ruby's `FlagDefinitionCacheProvider` pattern.

### n9 — Flush (🟡 Partial)
- **Spec requires:** `@both`. No-op on empty queue with no network call (matches); bypass batching intervals and attempt delivery now (matches); on a retryable failure, the call must not throw and the failed event must remain queued for a later retry.
- **SDK currently:** `PostHogClient.FlushAsync()` (`PostHogClient.cs:1336-1351`) genuinely awaits through `AsyncBatchHandler.FlushAsync()` → `DrainBatchesAsync()` to the real HTTP POST, and empty-queue flush is a safe no-op. However `TryReadBatch` (`Library/CollectionExtensions.cs:100-113`) dequeues the batch from the channel *before* invoking the send handler (`Library/AsyncBatchHandler.cs:228-251`), and there is no requeue path on failure — confirmed by `tests/UnitTests/Library/AsyncBatchHandlerTests.cs:114-148` (`FlushBatchAsyncContinuesAfterException`), where a failed batch's events are permanently lost rather than remaining queued. `FlushAsync` itself correctly swallows and logs the exception without throwing to the caller, satisfying half the scenario.
- **Backwards compatibility:** Needs deprecation path — requeue-on-failure changes today's drop-on-failure semantics (and introduces a duplicate-send-on-retry risk), which some integrations may implicitly depend on; should ship as an explicit, documented behavior change.
- **Remediation:** In `DrainBatchesAsync`, on retryable/transient failure, re-enqueue the just-dequeued batch instead of discarding it; only drop on terminal/non-retryable failures.

### n10 — Get Distinct ID (🟡 Partial)
- **Spec requires:** spec's own `## Applicability` line says `client`, but the acceptance feature `get-distinct-id.feature` is tagged `@both` and contains an explicit `@server` scenario: "Server SDKs do not expose ambient distinct id state" — the SDK is expected to expose *some* callable answering this question, even if the answer is "no ambient id available."
- **SDK currently:** No public `GetDistinctId()`-equivalent method or property exists anywhere. `PostHogContext.DistinctId` (`src/PostHog/PostHogContext.cs`) — populated only via ASP.NET Core middleware reading the `X-POSTHOG-DISTINCT-ID` header — is `internal`, unreachable from the public API surface. There is therefore no way for a caller to invoke a documented API and observe the "not available" answer the `@server` scenario expects; the capability is absent rather than merely returning null.
- **Backwards compatibility:** Backward-compatible — a new public `GetDistinctId()`/`TryGetDistinctId()` surfacing `PostHogContext.Current?.DistinctId` (or explicitly `null` outside a request scope) would be a pure addition.
- **Remediation:** Add a public method on `IPostHogClient` or a public `PostHogContext` accessor that returns the ambient distinct id if a tracing-header scope is active, or `null`/a documented "not available" sentinel otherwise.

### n11 — Get Feature Flag (🟡 Partial)
- **Spec requires:** `both`. A per-flag getter accepting evaluation options (person/group properties, groups, local-only, tracking suppression).
- **SDK currently:** The deprecated `GetFeatureFlagAsync(featureKey, distinctId, FeatureFlagOptions?, CancellationToken)` (`IPostHogClient.cs:203-207`, impl `PostHogClient.cs:644-810`) supports `OnlyEvaluateLocally`, `PersonProperties`, `Groups`, `FlagKeysToEvaluate`, `DisableGeoIp`, and `SendFeatureFlagEvents` (tracking suppression) — near-complete option parity, missing only a `deviceId` parameter (unused anywhere in the codebase). The canonical, non-deprecated replacement path, `EvaluateFlagsAsync(...).GetFlag(key)`, has **no per-call tracking-suppression option** at all — `EvaluateFlagsAsync`'s `AllFeatureFlagsOptions` exposes no `SendFeatureFlagEvents`-equivalent, so achieving spec parity (suppressing the `$feature_flag_called` side effect) currently requires using the deprecated method.
- **Backwards compatibility:** Backward-compatible — adding a tracking-suppression option to the canonical `EvaluateFlagsAsync`/`FeatureFlagEvaluations` surface is additive (C# overloading, consistent with the existing default-interface-member pattern).
- **Remediation:** Add tracking-suppression capability to the canonical `EvaluateFlagsAsync`/`FeatureFlagEvaluations` surface so callers don't need the deprecated method for that use case.

### n12 — Get Feature Flag Payload (❌ Fail)
- **Spec requires:** a dedicated payload getter callable with just a key and distinct id (optionally with a `matchValue` override), cache-only, no `$feature_flag_called` emission by default.
- **SDK currently:** No method named `GetFeatureFlagPayloadAsync` (or equivalent) exists anywhere — confirmed by exhaustive grep. The only paths to a payload are `FeatureFlag.Payload` (a field on an already-evaluated flag object returned by the deprecated per-flag getter) or `FeatureFlagEvaluations.GetFlagPayload(key)`, both of which require the caller to already hold a full flag/snapshot result from a separate call — there is no standalone API taking just `(key, distinctId)` the way every other audited server SDK exposes, and no `matchValue` override exists at all.
- **Backwards compatibility:** Backward-compatible — a new method is a pure addition; C# default interface members (already used for `EvaluateFlagsAsync`) allow this without breaking `IPostHogClient` implementers.
- **Remediation:** Add `Task<JsonDocument?> GetFeatureFlagPayloadAsync(string featureKey, string distinctId, JsonDocument? matchValue = null, FeatureFlagOptions? options = null, CancellationToken cancellationToken = default)` as a new, non-deprecated API surface.

### n13 — Get Feature Flag Result (🟡 Partial)
- **Spec requires:** a canonical result object `{ key, enabled, variant?, payload? }`; unknown flags return no structured result (not a partial/default object).
- **SDK currently:** No method literally named `GetFeatureFlagResultAsync` exists, but `Features/FeatureFlag.cs` is a de facto canonical result record with `Key`/`IsEnabled`/`VariantKey`/`Payload`/`HasExperiment` fields, matching the spec's shape closely. The canonical `EvaluateFlagsAsync(distinctId).GetFlag(key)` path correctly returns `null` for an unknown flag. However the still-shipped, still-usable deprecated `GetFeatureFlagAsync`, on a remote-evaluation miss, constructs a **synthetic disabled flag** object instead of returning nothing (`PostHogClient.cs:747-756`: `response = new FeatureFlag { Key = featureKey, IsEnabled = false }`) — exactly the "partial/default object" anti-pattern the spec's own "unknown flag" scenario forbids.
- **Backwards compatibility:** Backward-compatible — the correct behavior already lives on the recommended (`EvaluateFlagsAsync`) path; a literally-named `GetFeatureFlagResultAsync` naming-parity wrapper would be a pure addition, and the deprecated method's differing behavior is inherited legacy behavior, not something the fix needs to touch.
- **Remediation:** Optionally add a thin `GetFeatureFlagResultAsync` naming-parity wrapper over `EvaluateFlagsAsync(...).GetFlag(...)` for spec-name discoverability; document that the deprecated `GetFeatureFlagAsync`'s "flag missing" case intentionally differs from the new snapshot API.

### n14 — Group Identify (🟡 Partial)
- **Spec requires:** `@both`. `$groupidentify` event with `$group_type`/`$group_key`/`$group_set`; a missing group key must enqueue no event and record a validation warning.
- **SDK currently:** `GroupIdentifyAsync`/`GroupIdentifyCoreAsync` (`PostHogClient.cs:238-275`) correctly builds `$groupidentify` with `$group_type`/`$group_key`/`$group_set` (`Api/PostHogApiClientExtensions.cs:47-68`) and synthesizes a `distinct_id` (`$"${type}_{key}"`) when none is supplied, matching spec prose and corroborated by `tests/UnitTests/PostHogClientTests.cs:213-249`. No presence validation exists on `type`/`key` anywhere in the chain — an empty/missing key flows through into a malformed synthesized distinct id and is still sent to the server, the opposite of the required drop-and-warn behavior. No test covers this missing-key case.
- **Backwards compatibility:** Backward-compatible — adding a drop-with-warning presence check changes behavior only for already-malformed calls.
- **Remediation:** Add presence validation for `type`/`key` in `GroupIdentifyCoreAsync` that logs a warning and short-circuits to a no-op result before calling the API client.

### n15 — Identify (🟡 Partial)
- **Spec requires:** `@both`. The `@both`-tagged "Identify validates distinct id" scenario requires that calling identify without a distinct id leaves state unchanged and enqueues no identity event. Spec prose explicitly names .NET as one of the SDKs that "raises" on an empty distinct id.
- **SDK currently:** `IdentifyAsync` (`PostHogClient.cs:210-235`) and the extension overloads in `Extensions/IdentifyPersonAsyncExtensions.cs` never validate `distinctId` — `Ensure.cs` only implements reference-null checks, never applied to this parameter, so an empty string passes through unchanged and flows into a real HTTP request. This directly contradicts both possible readings of the spec: it neither raises (as the spec's own prose attributes to .NET) nor drops silently.
- **Backwards compatibility:** Breaking if implemented as "raise" (matching spec prose) — would newly throw for calls that previously silently succeeded. Backward-compatible if implemented as "drop with log," which also satisfies the Gherkin scenario's literal requirement without introducing a new exception type.
- **Remediation:** Add a presence check that logs a warning and no-ops on empty/whitespace `distinctId`, favoring the backward-compatible drop-based fix; separately flag to spec maintainers that the current SDK matches neither documented .NET behavior described in the spec prose.

### n16 — Is Feature Enabled (❌ Fail)
- **Spec requires:** hard `SHALL`, `@both`, no server-SDK carve-out: the SDK SHALL accept a caller-supplied default value and SHALL return it whenever the flag has no value (not loaded, failed request, unknown key); a flag with a real value — including `false` — always wins over the default.
- **SDK currently:** `IsFeatureEnabledAsync(featureKey, distinctId, FeatureFlagOptions?, CancellationToken)` (`IPostHogClient.cs:188-192`, impl `PostHogClient.cs:615-619`) has **no `defaultValue` parameter anywhere** (confirmed via exhaustive grep of all flag-related code). It collapses every miss to hardcoded `false`: `return result is { IsEnabled: true };`. The canonical replacement, `FeatureFlagEvaluations.IsEnabled(key)` (`FeatureFlagEvaluations.cs:84-88`), has the identical shape (`return record is { Enabled: true };`) — a genuinely-disabled flag and a flag with no value at all are indistinguishable, and there is no way for a caller to override a miss to `true`. This is the identical known gap pattern independently found in posthog-ruby/-python/-node.
- **Backwards compatibility:** Backward-compatible — adding a `defaultValue`-aware overload on the canonical `FeatureFlagEvaluations` surface (returning the default only when no record exists) is purely additive via C# overloading.
- **Remediation:** Add `FeatureFlagEvaluations.IsEnabled(string key, bool defaultValue)` (and/or an equivalent parameter on `IsFeatureEnabledAsync`) that returns `defaultValue` only on a genuine miss, distinguishing it from a real `false` result. Also fix `FeatureFlagExtensions.cs`'s `bool?`-returning overload, whose XML doc claims `null`-on-miss semantics it doesn't actually implement (it delegates to the same `bool`-collapsing core method).

### n17 — Logs (❌ Fail)
- **Spec requires:** a `captureLog`/logger API producing OTLP-shaped log records, shipped via `POST {host}/i/v1/logs`, with severity mapping, batching, and feature-flag/session-id context enrichment.
- **SDK currently:** Exhaustive repo-wide grep for `captureLog`, `i/v1/logs`, `OTLP`/`OpenTelemetry`, `severityNumber`, `resourceLogs`/`scopeLogs` returns zero matches across all `.cs` files; no OpenTelemetry package dependency exists. `ILogger` usage throughout the SDK is exclusively the SDK's own internal `Microsoft.Extensions.Logging` diagnostics, unrelated to the product Logs capability. No acceptance `.feature` file exists for `logs` in either `acceptance/public/` or `acceptance/private/`, so there is no acceptance-test obligation currently being missed mechanically — but the spec itself states no server-SDK exemption.
- **Backwards compatibility:** Backward-compatible if implemented — a wholly new, opt-in API and pipeline cannot break any existing integration.
- **Remediation:** Track as a known net-new feature gap. If prioritized, implement a `captureLog`/logger facade, an OTLP/HTTP-JSON batcher targeting `/i/v1/logs`, severity mapping, and context enrichment (feature flags array, session/distinct id).

### n18 — Set/Reset Person/Group Properties For Flags (❌ Fail, all four contracts)
- **Spec requires:** each of these four specs' own `## Applicability` line says `client` ("Server SDKs usually take person/group properties directly on each flag-evaluation call instead of maintaining a persistent local override store"). However all four acceptance feature files (`set-person-properties-for-flags.feature`, `set-group-properties-for-flags.feature`, `reset-person-properties-for-flags.feature`, `reset-group-properties-for-flags.feature`) are tagged `@both` at the file level and on every scenario, with concrete, generically-written, server-satisfiable scenarios (setting/resetting properties stores/clears a local override that must flow into a subsequent flag-reload request). Per this audit's precedent (matching prior posthog-ruby/posthog-python treatment of these same four contracts), these are treated as in-scope-but-unimplemented rather than N/A.
- **SDK currently:** Exhaustive grep for `PersonPropertiesForFlags`/`GroupPropertiesForFlags` across `src/`, `tests/`, `samples/` returns zero matches for all four. `PersonProperties`/`Groups` exist only as per-call arguments on `GetAllFeatureFlagsAsync`/`EvaluateFlagsAsync`/the deprecated single-flag getters — the spec's own documented server-side *alternative*, but architecturally distinct from a *persistent* override store that automatically applies to all subsequent evaluation/reload calls without the caller re-passing it each time, which is what the acceptance scenarios test. No override cache and no `SetPersonPropertiesForFlags`/`SetGroupPropertiesForFlags`/`ResetPersonPropertiesForFlags`/`ResetGroupPropertiesForFlags` method exists anywhere.
- **Backwards compatibility:** Backward-compatible — a new opt-in stateful override store (naturally extending the existing `PostHogContext` ambient-scope pattern) would be purely additive; no existing call signature needs to change.
- **Remediation:** Add `SetPersonPropertiesForFlags()`/`SetGroupPropertiesForFlags()`/`ResetPersonPropertiesForFlags()`/`ResetGroupPropertiesForFlags()`, backed by a context-scoped override store merged into flag-evaluation/reload calls as a default (overridable by explicit per-call properties). Flag upstream to sdk-specs maintainers that the spec-prose `Applicability: client` and the acceptance files' `@both` tags are inconsistent.

### n19 — Retry Queue (❌ Fail)
- **Spec requires:** `both`. In-memory queue with backpressure/drop-when-full; classify retryable (network errors, 5xx, 408, 429) vs. non-retryable failures; retryable failures keep the same events queued for a later, separate flush attempt; success removal by stable identity so concurrently-captured events aren't mistaken for the in-flight batch.
- **SDK currently:** Bounded queue with `DropOldest` overflow policy exists and is tested (`Library/AsyncBatchHandler.cs:63-66`, `tests/UnitTests/Library/AsyncBatchHandlerTests.cs:233-264`), and concurrent-capture-during-flush safety is naturally satisfied by the channel-based dequeue model. But there is no durable/persistent retry-queue concept — the only retry mechanism is `PostJsonWithRetryAsync`'s in-memory retry loop scoped to a single HTTP call (`Library/HttpClientExtensions.cs:193-262`); once `MaxRetries` (default 3) is exhausted, the exception propagates and the already-dequeued batch (removed from the channel before the send attempt, per `AsyncBatchHandler.cs:228-251`) is permanently dropped — the same root cause as the Flush gap (n9). The scenario "keeps events after transient failure, delivers after later success" fails: there is no separate requeue/later-redelivery path.
- **Backwards compatibility:** Needs deprecation path — requeue-on-failure changes today's drop-on-exhaustion semantics and introduces duplicate-send risk on subsequent retry, which should ship as an explicit, documented behavior change rather than a silent default change.
- **Remediation:** Same fix as Flush (n9): add a real requeue-on-failure layer in `DrainBatchesAsync`, classifying retryable vs. terminal failures (mirroring `HttpClientExtensions`' own classification) and re-enqueueing retryable batches instead of dropping them.

### n20 — Setup (🟡 Partial)
- **Spec requires:** spec's own `## Applicability` line says `client` ("Server SDKs generally use constructors or per-call clients instead"), acceptance is `@client`-only — but the spec's behavior list includes "prevent accidental double initialization... treat repeated setup of the same singleton/instance as a no-op with logging/warnings," a behavior a server SDK's static facade can genuinely implement or fail to implement.
- **SDK currently:** The `PostHogClient` constructor (`PostHogClient.cs:69-121`) performs real subsystem initialization (API client, batch handler, feature-flags loader, project-token validation) — not a stub — and `PostHogConfigurationBuilder.Build()` uses `TryAddSingleton` for DI registration, idempotent under ASP.NET Core DI (tested `RegistrationTests.cs:14-36`). However the static convenience facade `PostHogSdk.Init()` (`PostHogSdk.cs:58-61`) has **no double-init guard**: each call unconditionally constructs a new `PostHogClient` and overwrites `DefaultClient` via plain assignment, silently discarding (without disposing or flushing) the previous client and leaking its background workers/HTTP connections, with no warning logged — diverging from the spec's "no-op with logging/warnings" guidance for the one code path (the static singleton facade) where that guidance is actually applicable.
- **Backwards compatibility:** Needs deprecation path — adding a guard changes today's re-`Init`-to-swap-config behavior, which some callers may currently rely on to reconfigure the default client at runtime.
- **Remediation:** Add a no-op-with-warning guard (or an explicit dispose-then-replace path) in `PostHogSdk.Init()` when `DefaultClient` is already set.

### n21 — Traces (❌ Fail)
- **Spec requires:** a manual `startSpan`/`withSpan` API, no-op span handles when unconfigured, W3C traceparent propagation, and an OTLP-traces buffered queue shipped to `POST {host}/i/v1/traces`. The spec explicitly distinguishes this from LLM-analytics traces, which are "captured as analytics events, not OTLP."
- **SDK currently:** Exhaustive grep for `startSpan`/`withSpan`, `traceparent`/`tracestate`, `resourceSpans`/`scopeSpans`, `i/v1/traces` returns zero matches anywhere in the repo; no `PostHog.OpenTelemetry`/tracing project exists alongside the three shipped packages. The only span/trace-adjacent code is `src/PostHog.AI/PostHogOpenAIHandler.cs`, which sends `$ai_generation`/`$ai_embedding` analytics events via the ordinary `Capture` API using `$ai_trace_id`/`$ai_span_id`/`$ai_span_name` as plain event properties for LLM Observability UI grouping — exactly the "captured as analytics events, not OTLP" carve-out the spec explicitly excludes from this contract's scope. No acceptance `.feature` file exists for `traces` in either directory.
- **Backwards compatibility:** Backward-compatible if implemented — a wholly new, opt-in API/pipeline.
- **Remediation:** Track as a known net-new feature gap. If implemented, build a manual span API, in-memory span queue, W3C trace-context interop, and OTLP export to `/i/v1/traces` — the spec notes server SDKs may source `posthogDistinctId`/`sessionId` span attributes from the same tracing-headers request context already implemented for contract 58.
