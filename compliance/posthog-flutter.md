# posthog-flutter — SDK Compliance

**Repo:** [PostHog/posthog-flutter](https://github.com/PostHog/posthog-flutter)
**Audited commit:** `1032c102934c4b0338282a0fd3dcff94f7c2db00` ([commit](https://github.com/PostHog/posthog-flutter/commit/1032c102934c4b0338282a0fd3dcff94f7c2db00)) — audited on 2026-10-19
**Audited against sdk-specs commit:** `c72e367`
**Summary:** 21 ✅ · 29 🟡 · 6 ❌ · 8 ➖ · 0 ❓ (64 rows; previous audit 2026-08-06 at `05b53dc` scored 20/22/6/5/6 on 59 rows)

**Why this run:** rotation priority 2 — equally stale with react-native (2026-08-06) and the holder of
**all six remaining ❓ Unknown cells in the whole matrix**. Draining those was the stated reason to
spend a slot here. **All six are now resolved to a definite status** ([n8](#n8), [n10](#n10),
[n17](#n17), [n22](#n22), [n24](#n24), and Retry Queue to ✅). The matrix now has **zero Unknown
cells across all twelve SDKs.**

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

- **Retry Queue (❓→✅).** `_doFlush` (`posthog_core_stateless.dart:491-552`) removes a batch from
  the queue **only when the error is not transient** (`if (!_isTransientFetchError(e)) queue.remove(...)`),
  honours `Retry-After` by pausing the flush timer, and re-arms the periodic flush so an offline
  failure does not strand the queue until the next capture. A persistent 503 stays queued — exactly
  what the spec requires, and exactly what posthog-js, posthog-node, and posthog-react-native all
  get wrong (see posthog-react-native [n9](posthog-react-native.md#n9)).
- **Malformed feature-flag payloads.** `feature_flags.dart:9-12` documents and implements the rule
  verbatim: "A payload that is not valid JSON (an empty string included) is no payload: null is
  returned and the error goes to `onMalformed`." That is **both halves** of the requirement — the
  correct sentinel *and* the mandated diagnostic — which no other SDK in the matrix currently has:
  posthog-ios, posthog-go, and posthog-react-native return the raw malformed string, and
  posthog-php returns the right sentinel but logs nothing. Get Feature Flag Payload and Get Feature
  Flag Result keep their ✅.

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
Persistent Storage ❓→🟡, Remote Config ❓→🟡, **Retry Queue ❓→✅**.

**Improvement (1):** **Shutdown ❌→🟡** ([n30](#n30)). The Dart layer still does not flush before
delegating, but two of the three paths now flush anyway: desktop `close()` makes a bounded send
attempt, and the embedded `posthog-android` `PostHog.close()` **now calls `flush()`**
(`posthog/src/main/java/com/posthog/PostHog.kt:536-545`), fixing the native half of the previous
finding. Flutter Web remains a bare no-op, which is what keeps the row off ✅.

**New rows (5):** Capture AI ➖, Evaluate Flags ➖, MCP Analytics ➖ (all `server`-scoped; Flutter is
in none of their applicability tables), **Exception Event Metadata ❌** ([n9](#n9)), **Session Replay
Debug Properties 🟡** ([n26](#n26)).

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
| 8 | Capture Exception | 🟡 | [n5] |
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
| 24 | Get Feature Flag Payload | ✅ | |
| 25 | Get Feature Flag Result | ✅ | |
| 26 | Get Feature Flags | ❌ | [n14] |
| 27 | Get Feature Flags And Payloads | ❌ | [n15] |
| 28 | Get Session ID | ✅ | |
| 29 | Group | 🟡 | [n16] |
| 30 | Group Identify | ➖ | |
| 31 | HTTP Client | 🟡 | [n17] |
| 32 | Identify | ✅ | |
| 33 | Is Feature Enabled | 🟡 | [n18] |
| 34 | Is Opt Out | ✅ | |
| 35 | Is Session Replay Active | ✅ | |
| 36 | Local Feature Flag Evaluator | ➖ | |
| 37 | Logs | 🟡 | [n19] |
| 38 | MCP Analytics | ➖ | |
| 39 | On Feature Flags | 🟡 | [n20] |
| 40 | Opt In | 🟡 | [n21] |
| 41 | Persistent Storage | 🟡 | [n22] |
| 42 | Register | 🟡 | [n23] |
| 43 | Reload Feature Flags | ✅ | |
| 44 | Remote Config | 🟡 | [n24] |
| 45 | Reset | ✅ | |
| 46 | Reset Group Properties For Flags | ✅ | |
| 47 | Reset Person Properties For Flags | ✅ | |
| 48 | Retry Queue | ✅ | |
| 49 | Screen | 🟡 | [n25] |
| 50 | Session Manager | ✅ | |
| 51 | Session Replay Debug Properties | 🟡 | [n26] |
| 52 | Session Replay Ingestion Controls | ✅ | |
| 53 | Session Replay Privacy | 🟡 | [n27] |
| 54 | Set Group Properties For Flags | ✅ | |
| 55 | Set Person Properties | 🟡 | [n28] |
| 56 | Set Person Properties For Flags | ✅ | |
| 57 | Setup | 🟡 | [n29] |
| 58 | Shutdown | 🟡 | [n30] |
| 59 | Start Session Recording | 🟡 | [n31] |
| 60 | Stop Session Recording | 🟡 | [n32] |
| 61 | Surveys | 🟡 | [n33] |
| 62 | Traces | ❌ | [n34] |
| 63 | Tracing Headers | ❌ | [n35] |
| 64 | Unregister | ✅ | |

## Notes

Notes [n1](#n1)–[n7](#n7), [n11](#n11)–[n16](#n16), [n18](#n18)–[n21](#n21), [n23](#n23),
[n25](#n25), [n27](#n27)–[n29](#n29), [n31](#n31)–[n35](#n35) carry forward the findings of the
2026-08-06 audit, re-checked for existence at this commit; their analysis is unchanged except where
stated. Notes [n8](#n8), [n9](#n9), [n10](#n10), [n17](#n17), [n22](#n22), [n24](#n24),
[n26](#n26), and [n30](#n30) are new or substantially rewritten this run.

### n1 — Alias (🟡 Partial)
- **Spec requires:** `both`. Drop the call when the current distinct id or the alias target is missing/empty, logging a validation warning.
- **SDK currently:** `Posthog().alias({required String alias})` (`lib/src/posthog.dart:375`) is a pass-through to the platform instance with no emptiness validation on either side of the pair, on any of the three platform paths.
- **Backwards compatibility:** Backward-compatible — an early return with a warning only affects calls that today produce a malformed event.
- **Remediation:** Validate in `Posthog().alias()` before dispatch, so all three platform paths are covered by one check.

### n2 — Autocapture (🟡 Partial)
- **Spec requires:** Interaction autocapture with sanitized element context and no-capture markers honoured.
- **SDK currently:** Carried forward from the previous audit; the Dart autocapture surface is unchanged at this commit. Flutter has screen/route autocapture via `PosthogObserver` but no generic widget-interaction `$autocapture`.
- **Backwards compatibility:** Backward-compatible — new capture behaviour behind a config flag is additive.
- **Remediation:** As previously recorded.

### n3 — Before Send Hook (🟡 Partial)
- **Spec requires:** A hook chain whose exceptions are caught and logged, with the event dropped rather than the host application crashing.
- **SDK currently:** `lib/src/utils/before_send.dart:39` catches a throwing callback, logs a warning, and drops the event — the throw-safety half is correct and was re-read at this commit. The previously-recorded gap (coverage: the hook does not run on every event-producing path) is unchanged.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** As previously recorded.

### n4 — Bootstrap (🟡 Partial)
- **Spec requires:** Apply bootstrap identity/flags only when nothing is persisted; bootstrap flags win on collision.
- **SDK currently:** Carried forward; unchanged at this commit.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** As previously recorded.

### n5 — Capture Exception (🟡 Partial)
- **Spec requires:** The public exception-capture API's surface and ordering (the flat `$exception_type`/`$exception_message` requirement was retired by PR [#103](https://github.com/PostHog/sdk-specs/pull/103)).
- **SDK currently:** `Posthog().captureException(...)` (`lib/src/posthog.dart:816`) and `captureRunZonedGuardedError(...)` (`:839`) exist with correct outermost-first ordering through `DartExceptionProcessor`. The remaining gap is the one previously recorded about the public surface, not the envelope — the envelope's own defects are now scored separately under [n9](#n9).
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** As previously recorded.

### n6 — Consent Gating (🟡 Partial)
- **Spec requires:** A persisted opt-out that silently drops captures with no network call, defaulting per configuration.
- **SDK currently:** The Dart core implements this correctly for desktop: `optedOut` (`posthog_core_stateless.dart:178-183`) resolves a runtime decision, then the persisted value, then the configured default, and `optIn()`/`optOut()` persist the decision (`:185-201`). The previously-recorded gap is on the mobile path and is unchanged.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** As previously recorded.

### n7 — Debug (🟡 Partial)
- **Spec requires:** A runtime debug toggle affecting SDK diagnostics.
- **SDK currently:** `Posthog().debug(bool)` (`lib/src/posthog.dart:459`) exists on all paths; the previously-recorded gap is unchanged.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** As previously recorded.

### n8 — Event Batcher (🟡 Partial)
- **Spec requires:** Count- and time-based batching with configurable `flushAt`/batch size, a bounded queue with oldest-first eviction, and 413 handling that reduces the batch size rather than dropping the batch.
- **SDK currently:** **Resolved from ❓ Unknown.** The previous audit could not inspect this because it lived inside the native SDKs. The Dart core now implements it directly for desktop, and the implementation is good: `_flushAt`, `_maxBatchSize`, and `_maxQueueSize` are all config-driven and clamped to a minimum of 1 (`posthog_core_stateless.dart:112-114`); `_enqueue` flushes when `queue.length >= _flushAt` (`:423`) and evicts the overflow oldest-first (`:414`); `_scheduleFlush`/`_clearFlushTimer` (`:442-460`) provide the time-based path; and a 413 halves `_maxBatchSize` and retries the same batch rather than dropping it (`:522-526`). **Why 🟡 rather than ✅:** this covers Windows and Linux only. On iOS/Android the batcher is still the embedded native SDK's, and `compliance/posthog-android.md` n19 records a 🟡 there; on Web it is posthog-js's. The contract is therefore met on one of three platforms and partially met on the others.
- **Backwards compatibility:** Backward-compatible — the fix is in the sibling SDKs, not in this repo.
- **Remediation:** No action in posthog-flutter. Track the mobile half under posthog-android n19 and the web half under posthog-js; re-score to ✅ once the embedded SDKs' batcher rows clear.

### n9 — Exception Event Metadata (❌ Fail)
- **Spec requires:** Every entry in `$exception_list` SHALL carry a `mechanism` with a unique non-negative integer `exception_id` (`0` for the outermost), and every nested entry SHALL carry `parent_id`, `mechanism.type` equal to `chained`, and a `mechanism.source` describing the parent edge. `handled` describes capture disposition **at the relevant boundary** and MUST NOT be invented for a nested entry. Producers SHALL serialize at most **50** entries, retaining the outermost plus the first 49 nested in canonical depth-first order. Application property bags **MUST NOT** override SDK-owned `$exception_list`, `$exception_level`, or `$exception_source` (spec line 300).
- **SDK currently:** Audited from scratch against `lib/src/error_tracking/dart_exception_processor.dart`. What is right: a real `mechanism` object with `handled`, `synthetic`, and `type` (`:82-86`); genuine synthetic detection (`:73-78`); correct outermost-first cause ordering (`:107-118`); `thread_id` where available; and a cycle guard via a `seen` set (`:170`). **Four defects, any one of which blocks ✅, and together a Fail:** (1) **no `exception_id` and no `parent_id` anywhere** — grep returns zero hits for both across the whole repo, so the canonical tree linkage the spec makes mandatory on every entry is entirely absent and nested entries cannot be attributed to their parents; (2) **nested causes inherit the outermost `handled`** — `_appendCauses` passes the parent's value straight down (`:178`, `'handled': handled`), which is the invented capture-boundary metadata the spec forbids, and they also lack `type: 'chained'` and any `source`; (3) **`$exception_level` is a hardcoded literal** — `'$exception_level': 'error'` with the comment "Never crashes, so always error" (`:123`) — and **no `$exception_source` is emitted at all**; (4) **the caller's property bag overrides SDK-owned keys** — the result map is built as `{ '$exception_level': …, '$exception_list': …, if (properties != null) ...properties }` (`:120-125`), spreading caller properties **last**, so a caller passing `$exception_list` replaces the SDK's own. Separately, `maxExceptionChainLength = 10` (`:20`) truncates more aggressively than the spec's 50, discarding entries the spec says to retain.
- **Backwards compatibility:** **Needs deprecation path.** Defects (1), (2), and (3) are additive wire-format changes and are backward-compatible on their own. Defect (4) is not: a caller may today pass `$exception_level` through the generic property bag, and the spec asks for documented *typed* overrides instead, so the typed channel has to ship before the generic one stops winning.
- **Remediation:** Assign `exception_id` by depth-first index with `0` outermost and set `parent_id` plus `mechanism.type: 'chained'` and `mechanism.source: 'cause'` on every appended cause; stop propagating the parent's `handled` to causes (omit it rather than guessing); derive `$exception_level` from the capture boundary and emit `$exception_source`; raise `maxExceptionChainLength` to 50; and add typed level/source/mechanism parameters to `captureException`, then stop spreading the generic property bag over the reserved keys. The same work clears the mirror finding in `compliance/posthog-php.md` n5.

### n10 — Feature Flag Called Tracker (🟡 Partial)
- **Spec requires:** Dedupe `$feature_flag_called` per (flag, value), re-fire on value change, clear on `reset()`, and honour the minimal-envelope allowlist.
- **SDK currently:** **Resolved from ❓ Unknown.** The Dart core implements the tracker directly: `_flagCallReported` is a `Map<String, Set<PostHogFeatureFlagValue?>>` (`posthog_core.dart:25-26`), the dedup check is `!(_flagCallReported[key]?.contains(flagValue) ?? false)` (`:780`) — keyed on the value, so a changed value correctly re-fires — the set is populated after reporting (`:815`), `$feature_flag_called` is captured at `:838`, and the whole map is cleared on reset (`:82`). Failure cases are recorded for the event (`:888`). **Why 🟡:** desktop only; the mobile path is the embedded native tracker, which `compliance/posthog-android.md` n20 records as 🟡, and no minimal-envelope allowlist handling is visible on the Dart path.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** Add minimal-envelope allowlist handling to the Dart core's capture path; track the mobile half under posthog-android n20.

### n11 — Flush (🟡 Partial)
- **Spec requires:** `both`. No-op on an empty queue; drain immediately; a failed batch stays queued.
- **SDK currently:** `Posthog().flush()` (`lib/src/posthog.dart:804`) dispatches to the platform instance. Desktop's `flush()` (`posthog_flutter_desktop.dart:479`) routes into the Dart core's correct implementation (see Retry Queue above). On mobile it is `invokeMethod('flush')` (`posthog_flutter_io.dart:743-752`). **The previously-recorded gap is unchanged and is on Web:** `posthog_flutter_web_handler.dart:400-402` has `case 'flush':` with the delegating call **commented out**, so `flush()` on Flutter Web is a silent no-op that resolves successfully while delivering nothing.
- **Backwards compatibility:** Backward-compatible — making a no-op actually call through only delivers events that the caller already asked to deliver.
- **Remediation:** Uncomment/implement the `window.posthog` flush delegation in the web handler, or make the no-op log a warning so it is not silent.

### n12 — Get Anonymous ID (❌ Fail)
- **Spec requires:** `client`. A getter returning the SDK's anonymous identifier.
- **SDK currently:** Re-confirmed at this commit: the public API list in `lib/src/posthog.dart` has `getDistinctId()` (`:380`) and `getSessionId()` (`:948`) but **no `getAnonymousId()`** on any platform path. The standing `// TODO` recorded by the previous audit is still the only trace of it.
- **Backwards compatibility:** Backward-compatible — a new getter is additive.
- **Remediation:** Add `Future<String> getAnonymousId()` to the platform interface, implemented over the method channel on mobile, from `PostHogPersistedProperty.anonymousId` in the Dart core on desktop, and over `window.posthog` on web.

### n13 — Get Feature Flag (🟡 Partial)
- **Spec requires:** A single-flag value getter with correct missing-flag semantics.
- **SDK currently:** `getFeatureFlag(String key)` (`lib/src/posthog.dart:764`) exists on all paths; the previously-recorded gap is unchanged at this commit.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** As previously recorded.

### n14 — Get Feature Flags (❌ Fail)
- **Spec requires:** A bulk getter returning all known flags as a key→value map.
- **SDK currently:** Re-confirmed at this commit — no bulk flag getter exists anywhere in the Dart API (`lib/src/posthog.dart` has only the single-key `getFeatureFlag`, `getFeatureFlagPayload`, and `getFeatureFlagResult`). The Dart core *does* hold the full flag map internally (`core/feature_flags.dart`), so the data is available; it is simply not exposed.
- **Backwards compatibility:** Backward-compatible — a new getter is additive.
- **Remediation:** Expose the Dart core's flag map through the platform interface and bridge it on mobile and web.

### n15 — Get Feature Flags And Payloads (❌ Fail)
- **Spec requires:** A combined getter returning flags and their decoded payloads.
- **SDK currently:** Re-confirmed at this commit — no combined getter under any name. Notably, the decoding half this contract depends on is already correct in the Dart core (see the payload note in the header), so only the surface is missing.
- **Backwards compatibility:** Backward-compatible — additive.
- **Remediation:** Add the combined getter alongside [n14](#n14)'s bulk getter, reusing the existing correct decode path.

### n16 — Group (🟡 Partial)
- **Spec requires:** Persist the group association and emit `$groupidentify`; drop a missing/empty type or key.
- **SDK currently:** `Posthog().group(...)` (`lib/src/posthog.dart:628`) with no emptiness validation; carried forward, unchanged at this commit.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** As previously recorded — validate in the Dart layer so all three paths are covered.

### n17 — HTTP Client (🟡 Partial)
- **Spec requires:** Platform transport with gzip where supported; a `/flags` retry policy that retries transient transport conditions but **not a refused connection** (PR [#110](https://github.com/PostHog/sdk-specs/pull/110)); and a retry schedule whose first retry is not sent before 300 ms.
- **SDK currently:** **Resolved from ❓ Unknown.** The Dart core implements the transport directly for desktop and much of it is right: gzip is applied with a correct `Content-Encoding` header when configured (`posthog_core_stateless.dart:635-637`), a request timeout cancels the attempt (`:565-574`), `Retry-After` is parsed and honoured (`:650`), and the `/flags` retry budget and base delay are `1` retry at **300 ms** (`:79-80`) — matching the spec's first-retry floor, where posthog-js/node use a fixed 3,000 ms and fail it. **Gap:** `_isRetryableFlagsError` (`:56-58`) returns `true` for **any** `PostHogFetchNetworkError`, and `_fetchWithRetry` wraps every transport exception — a connection-refused `SocketException` included — into exactly that type (`:572-574`). A refused `/flags` connection is therefore retried, which PR [#110](https://github.com/PostHog/sdk-specs/pull/110) forbids. Separately, `retriable` (`core/utils/utils.dart:15-39`) waits a **fixed** `retryDelay` on each attempt with no backoff multiplier, so the `/batch/` path's three retries are all 3 s apart rather than escalating. On mobile the transport is the native SDK's, recorded 🟡 under `compliance/posthog-android.md` n22.
- **Backwards compatibility:** Backward-compatible — narrowing a retry predicate and adding a backoff multiplier are internal changes with no public surface.
- **Remediation:** In `_isRetryableFlagsError`, exclude a refused connection — inspect the wrapped `SocketException`'s `osError` and treat `ECONNREFUSED` as terminal (posthog-js's `isRetryableFlagsFetchError` is the reference); make `retriable` multiply `retryDelay` by `2 ** (i - 1)`.

### n18 — Is Feature Enabled (🟡 Partial)
- **Spec requires:** A boolean getter accepting a caller-supplied default.
- **SDK currently:** `Future<bool> isFeatureEnabled(String key)` (`lib/src/posthog.dart:485`) — re-confirmed at this commit, still **no `defaultValue` parameter**, so every miss collapses to a hardcoded `false`. Same shape as the confirmed findings on posthog-php, posthog-ruby, posthog-go, and posthog-dotnet.
- **Backwards compatibility:** Backward-compatible — an optional named parameter with the current value as its default changes nothing for existing callers.
- **Remediation:** Add `{bool defaultValue = false}` to `isFeatureEnabled` and thread it through the platform interface.

### n19 — Logs (🟡 Partial)
- **Spec requires:** An OTLP logs pipeline with canonical `AnyValue` encoding, severity mapping, and rate capping.
- **SDK currently:** `Posthog().captureLog(...)` (`lib/src/posthog.dart:301`) with a `PostHogLogRecord`/`PostHogLogSeverity`/`PostHogLogger` surface (`lib/src/logs/`), including a `beforeSend` hook for log records. Carried forward; the previously-recorded encoding deviations are unchanged.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** As previously recorded.

### n20 — On Feature Flags (🟡 Partial)
- **Spec requires:** A listener invoked when flags load, including for a listener registered after flags are already available.
- **SDK currently:** `PostHogConfig.onFeatureFlags` (`OnFeatureFlagsCallback`, declared in `posthog_flutter_platform_interface.dart:12`) is a **single config-time callback**, not a registration API — so there is no way to add a listener later at all, and the late-registration scenario cannot be satisfied by construction. Carried forward, unchanged.
- **Backwards compatibility:** Backward-compatible — adding a registration method alongside the config callback is additive.
- **Remediation:** Add `onFeatureFlags(callback)` returning an unsubscribe handle, backed by the Dart core's `EventEmitter` (`core/event_emitter.dart`), firing immediately when flags are already loaded.

### n21 — Opt In (🟡 Partial)
- **Spec requires:** Opt-in/opt-out naming and semantics per the capability.
- **SDK currently:** Flutter exposes both `optIn()`/`optOut()` (`lib/src/posthog.dart:423`, `:399`) **and** `enable()`/`disable()` aliases (`:449`, `:443`). The previously-recorded naming/semantics gap is unchanged at this commit.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** As previously recorded.

### n22 — Persistent Storage (🟡 Partial)
- **Spec requires:** Durable key/value persistence that never throws into the host app, with failures surfaced through SDK diagnostics.
- **SDK currently:** **Resolved from ❓ Unknown.** `core/file_storage.dart` (444 lines) is a real, carefully-specified implementation for desktop and its header comment reads like a spec of its own: persisted properties in a single `posthog_data.json` snapshot; each queued event its own UUIDv7-named file in `posthog_queue/` so queueing one event does not rewrite the others; an OS file lock (`posthog.lock`) so a second app instance reads the snapshot but cannot overwrite the first's identity and consent; **"Storage never throws into the host app"** with an explicit `isDegraded` memory-only mode on read failure that refuses to overwrite good persisted data; and atomic replace via temp-file-plus-rename (`_writeAtomically`, `:436`) so a crash never leaves a half-written file. The documented limitations are honest (no `fsync`, so the newest writes can be lost on a crash; the lock may not hold on network filesystems). **Why 🟡:** desktop only — mobile persistence is the native SDK's, recorded 🟡 under `compliance/posthog-android.md` n24, and web is `posthog-js`'s.
- **Backwards compatibility:** Backward-compatible — nothing in this repo needs to change.
- **Remediation:** No action in posthog-flutter for the desktop path. Track the mobile half under posthog-android n24.

### n23 — Register (🟡 Partial)
- **Spec requires:** Register a super property that is merged into every subsequent event.
- **SDK currently:** `Posthog().register(String key, Object value)` (`lib/src/posthog.dart:467`); carried forward, unchanged.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** As previously recorded.

### n24 — Remote Config (🟡 Partial)
- **Spec requires:** Fetch and apply the project's remote configuration, gating replay and surveys from it.
- **SDK currently:** **Resolved from ❓ Unknown.** On mobile the native SDK handles it and `compliance/posthog-android.md` records Remote Config ✅, so that path is satisfied. **On desktop it is absent:** grep for `remote_config`, `remoteConfig`, and `/array/` across `posthog_flutter/lib/src/` returns **zero** hits, so the Dart core never fetches remote config and desktop clients run on local configuration only — no server-side replay or survey gating, and no `minimalFlagCalledEvents` signal (which is also why [n10](#n10) has no allowlist handling).
- **Backwards compatibility:** Backward-compatible — adding a config fetch at startup is additive; clients that currently see no remote gating would start honouring it, which is the intended behaviour.
- **Remediation:** Add a remote-config fetch to the Dart core's startup path and apply it to the same switches the native SDKs gate on.

### n25 — Screen (🟡 Partial)
- **Spec requires:** Emit `$screen` with `$screen_name`, with the explicit name argument winning over a caller-supplied property.
- **SDK currently:** `Posthog().screen(...)` (`lib/src/posthog.dart:253`); carried forward, unchanged at this commit. Note the embedded Android SDK has its own confirmed precedence failure on this contract (`compliance/posthog-android.md` n11, ❌), which the Flutter wrapper does not compensate for.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** As previously recorded; the mobile half is fixed by posthog-android n11.

### n26 — Session Replay Debug Properties (🟡 Partial)
- **Spec requires:** `client`. Four required keys on **every** captured event except `$snapshot` on all platforms — `$recording_status`, `$sdk_debug_replay_event_trigger_status`, `$sdk_debug_replay_linked_flag_trigger_status`, `$sdk_debug_replay_internal_buffer_length` — plus a throttled optional `$sdk_debug_*` bundle on SDK events, with all of them stripped from the minimal `$feature_flag_called` envelope. An SDK with no replay integration produces only `$recording_status: disabled`.
- **SDK currently:** Audited from scratch. **Partially present, and the part that exists is on the wrong axis.** The Dart core emits three debug keys on its own schedule — `$sdk_debug_session_start`, `$sdk_debug_current_session_duration`, and `$sdk_debug_pending_queue_size` (`core/posthog_core.dart:170-173`) — and the desktop client stamps `$recording_status: 'disabled'` (`posthog_desktop_client.dart:41`), which is the correct value for a platform with no replay integration. **None of the three cross-platform required replay keys exists**: grep for `sdk_debug_replay` across the repo returns zero hits, so `$sdk_debug_replay_event_trigger_status`, `$sdk_debug_replay_linked_flag_trigger_status`, and `$sdk_debug_replay_internal_buffer_length` are absent on every platform — including iOS and Android, where Flutter runs a substantial Dart-side replay pipeline (`lib/src/replay/`) and therefore has real values to report. `$recording_status` itself is emitted only on desktop, where replay does not exist; the mobile paths that *do* record emit no `$recording_status` from the Dart layer at all.
- **Backwards compatibility:** Backward-compatible — these are additive diagnostic properties on events the SDK already sends.
- **Remediation:** Attach `$recording_status` on the mobile paths from the state `PostHogInternalEvents.sessionRecordingActive` already tracks, and add the three `$sdk_debug_replay_*` keys sourced from the Dart replay pipeline's trigger state and `SnapshotManager`'s buffer depth; exclude `$snapshot` events; keep the desktop `disabled` value as-is.

### n27 — Session Replay Privacy (🟡 Partial)
- **Spec requires:** Mask text, images, and sensitive inputs by default; honour unmask markers.
- **SDK currently:** Flutter owns a substantial independent masking implementation in Dart (`lib/src/replay/mask/` — `posthog_mask_controller.dart`, `posthog_text_mask.dart`, `sensitive_text_input.dart`, `posthog_unmask_widget.dart`, `unmask_rects.dart`, plus a text-mask-policy parser and web canvas mask geometry), which is why this row was never Unknown. Carried forward; the previously-recorded gap is unchanged at this commit.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** As previously recorded.

### n28 — Set Person Properties (🟡 Partial)
- **Spec requires:** Set person properties without requiring an identify call, emitting the `$set`/`$set_once` shape.
- **SDK currently:** `Posthog().setPersonProperties(...)` (`lib/src/posthog.dart:187`); carried forward, unchanged.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** As previously recorded.

### n29 — Setup (🟡 Partial)
- **Spec requires:** `openspec/specs/setup/spec.md:163`, `:179` — name the project credential `projectToken`, with any legacy `apiKey` retained as a deprecated alias; plus lifecycle hygiene on re-initialization.
- **SDK currently:** **The `projectToken` half now passes outright** — `posthog_config.dart:102-109` declares `final String projectToken` and keeps `String get apiKey => projectToken` behind a `@Deprecated` annotation naming `projectToken` as the replacement, which is exactly the non-breaking shape the spec prescribes. `setup()` also now rejects a blank token with a logged warning (`lib/src/posthog.dart:70-76`), and `_installFlutterIntegrations` calls `_uninstallFlutterIntegrations()` first (`:101-103`), so repeated setup no longer **stacks** error-tracking integrations — the specific harm the previous audit named. **Remaining gap:** there is still no explicit double-init guard or warning. A second `Posthog().setup()` silently re-runs the whole path, refreshes the mask-parser map, and re-invokes native `setup` over the method channel, and `PosthogFlutterPlugin.kt` has no already-initialized check of its own.
- **Backwards compatibility:** Backward-compatible — adding an idempotency guard or a debug warning is additive.
- **Remediation:** Track whether `setup()` has already run and warn (or no-op) on a second call without an intervening `close()`.

### n30 — Shutdown (🟡 Partial)
- **Spec requires:** Flush pending events before tearing down so queued data is not lost.
- **SDK currently:** **Improved from ❌.** The previous audit's finding had two halves and one of them is now fixed. **Still true:** `Posthog().close()` (`lib/src/posthog.dart:927-942`) clears Dart-side state and calls `_posthog.close()` with **no preceding flush**, and `PosthogFlutterIO.close()` (`posthog_flutter_io.dart:836-846`) sends only `invokeMethod('close')`. **Now fixed downstream:** the embedded `posthog-android` `PostHog.close()` calls `flush()` before tearing down (`posthog/src/main/java/com/posthog/PostHog.kt:536-545`, with the comment "flush pending events before tearing down so queued data isn't lost"), and `PostHogStateless.close()` calls `queue?.flushForShutdown()` (`PostHogStateless.kt:115-126`) — so on Android the flush does happen, inside the native SDK. posthog-ios's Shutdown row is ✅ after its 2026-10-08 refresh. **Newly covered:** desktop `close()` (`posthog_flutter_desktop.dart:535`) makes one bounded send attempt of up to two seconds, documented at `lib/src/posthog.dart:920-923`. **What keeps this off ✅:** Flutter Web's `close` is still a bare no-op — `posthog_flutter_web_handler.dart:404-406` has `case 'close':` with the delegating call commented out — so `close()` on Flutter Web does nothing at all, and the Dart layer itself still has no flush of its own as a safety net if a native SDK's behaviour regresses.
- **Backwards compatibility:** Backward-compatible — adding a bounded flush before `close()` only delivers events the caller already queued.
- **Remediation:** Implement Flutter Web's `close` (at minimum a best-effort delegation to `window.posthog`), and add a bounded `await flush()` in the Dart layer's `close()` so the guarantee does not depend on each embedded SDK.

### n31 — Start Session Recording (🟡 Partial)
- **Spec requires:** Recording stays inactive while opted out, and the SDK's local state reflects actual replay state.
- **SDK currently:** `startSessionRecording({bool resumeCurrent = true})` (`lib/src/posthog.dart:964`); carried forward — the local `PostHogInternalEvents.sessionRecordingActive` flip is still not conditioned on a success signal from native.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** As previously recorded.

### n32 — Stop Session Recording (🟡 Partial)
- **Spec requires:** Finalize/flush pending replay data on stop rather than discarding it.
- **SDK currently:** `stopSessionRecording()` (`lib/src/posthog.dart:981`); carried forward — `ScreenshotCapturer.cancel()` still discards an in-flight frame.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** As previously recorded.

### n33 — Surveys (🟡 Partial)
- **Spec requires:** Exclude web-only-conditioned surveys on non-web SDKs; enforce eligibility and the wait period; emit the survey event family.
- **SDK currently:** Flutter has a full Dart survey display implementation (`lib/src/surveys/` — models, `survey_service.dart`, and a complete widget set). Carried forward; the previously-recorded gap is unchanged at this commit.
- **Backwards compatibility:** Backward-compatible.
- **Remediation:** As previously recorded, plus note sdk-specs PR [#102](https://github.com/PostHog/sdk-specs/pull/102): the wait period starts when a survey is **shown**.

### n34 — Traces (❌ Fail)
- **Spec requires:** An OTLP span pipeline to `/i/v1/traces` with W3C `traceparent`/`tracestate` interop.
- **SDK currently:** Re-confirmed at this commit — no implementation. Grep for `startSpan`, `traceparent`, and `i/v1/traces` across `posthog_flutter/lib/` returns only unrelated matches in the stack-trace parser. The Dart core now has its own HTTP transport and batching, so the substrate a traces pipeline would sit on does exist, but nothing is built on it.
- **Backwards compatibility:** Backward-compatible — net-new, pre-GA capability.
- **Remediation:** Build the span pipeline over the Dart core's existing `_fetchWithRetry` transport, following `packages/core/src/traces/` in the posthog-js monorepo as the reference implementation.

### n35 — Tracing Headers (❌ Fail)
- **Spec requires:** Inject `traceparent`/`tracestate` into outbound application HTTP requests.
- **SDK currently:** Re-confirmed at this commit — zero hits for `traceparent` or `tracestate` anywhere in `posthog_flutter/lib/`. The previous audit's reasoning still holds: Flutter has no Dart-side HTTP client of its own through which app traffic flows, so there is nothing to intercept without the app opting in.
- **Backwards compatibility:** Backward-compatible — any solution is opt-in.
- **Remediation:** Ship an opt-in `package:http` interceptor (and a Dio interceptor) that stamps the headers, rather than attempting transparent interception.
