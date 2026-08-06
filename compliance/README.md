# SDK Compliance Matrix

Living record of how each in-scope PostHog SDK conforms to the cross-SDK contracts in
`openspec/specs/`. Maintained by a bounded weekly audit: **≤3 SDKs are deeply re-verified per
run** (spec-affected → code-changed → pending-initial-audit → staleness-backstop, in that
order), so every SDK gets re-checked roughly every 4 weeks rather than all at once. Per-SDK
detail — evidence, code references, and remediation for every non-Pass cell — lives in
`compliance/<sdk>.md`.

## Status legend

- ✅ **Pass** — SDK fully implements the contract.
- 🟡 **Partial** — implemented but deviates (missing option, different default, naming variance, incomplete semantics).
- ❌ **Fail** — not implemented, or behavior contradicts the spec.
- ➖ **N/A** — contract does not apply to this platform.
- ❓ **Unknown** — could not verify from available evidence; needs human review.

In-scope SDKs (referenced across `openspec/specs/`): posthog-js, posthog-python, posthog-node,
posthog-android, posthog-ios, posthog-flutter, posthog-react-native, posthog-php, posthog-ruby,
posthog-go, posthog-java, posthog-dotnet. 59 contracts are tracked per SDK (the 58 capabilities
listed in the root `README.md` table plus `bootstrap`, which has a canonical spec/acceptance file
but is missing from that table — a documentation gap worth fixing separately, out of scope for
this compliance-only PR).

**As of this run, all 12 in-scope SDKs have an initial audit on file** — the bootstrap backlog
(section below, "Pending initial audit") is now fully drained. Going forward, re-audits are
triggered by spec changes, code drift on the audited commit, or the ~4-week staleness backstop.

## Roll-up

| SDK | Overall | ✅ | 🟡 | ❌ | ➖ | ❓ | Last audited | Open gaps | File |
|---|---|---|---|---|---|---|---|---|---|
| posthog-js | 34/59 fully compliant (58%) | 34 | 15 | 7 | 3 | 0 | 2026-08-06 · `e1efa57` | 22 | [posthog-js.md](posthog-js.md) |
| posthog-python | 10/59 fully compliant (17%; 29 contracts N/A on a server SDK) | 10 | 13 | 7 | 29 | 0 | 2026-08-06 · `55370ee` | 20 | [posthog-python.md](posthog-python.md) |
| posthog-android | 33/59 fully compliant (56%) | 33 | 19 | 4 | 3 | 0 | 2026-08-06 · `0d2b16b` | 23 | [posthog-android.md](posthog-android.md) |
| posthog-ios | 33/59 fully compliant (56%) | 33 | 17 | 6 | 3 | 0 | 2026-08-06 · `057f4d6` | 23 | [posthog-ios.md](posthog-ios.md) |
| posthog-node | 11/59 fully compliant (19%; 27 contracts N/A on a server SDK) | 11 | 15 | 6 | 27 | 0 | 2026-08-06 · `e1efa57` (posthog-js monorepo) | 21 | [posthog-node.md](posthog-node.md) |
| posthog-flutter | 20/59 fully compliant (34%) | 20 | 22 | 6 | 5 | 6 | 2026-08-06 · `05b53dc` | 34 | [posthog-flutter.md](posthog-flutter.md) |
| posthog-react-native | 31/59 fully compliant (53%) | 31 | 23 | 2 | 2 | 1 | 2026-08-06 · `e1efa57` (posthog-js monorepo) | 26 | [posthog-react-native.md](posthog-react-native.md) |
| posthog-php | 12/59 fully compliant (20%; 31 contracts N/A on a server SDK) | 12 | 9 | 7 | 31 | 0 | 2026-08-06 · `ed93a67` | 16 | [posthog-php.md](posthog-php.md) |
| posthog-ruby | 13/59 fully compliant (22%; 30 contracts N/A on a server SDK) | 13 | 11 | 5 | 30 | 0 | 2026-08-06 · `31c187f` | 16 | [posthog-ruby.md](posthog-ruby.md) |
| posthog-go | 10/59 fully compliant (17%; 31 contracts N/A on a server SDK) | 10 | 11 | 7 | 31 | 0 | 2026-08-06 · `019af19` | 18 | [posthog-go.md](posthog-go.md) |
| posthog-java | 12/59 fully compliant (20%; 28 contracts N/A on a server SDK) | 12 | 13 | 6 | 28 | 0 | 2026-08-06 · `0d2b16b` (posthog-android monorepo) | 19 | [posthog-java.md](posthog-java.md) |
| posthog-dotnet | 7/59 fully compliant (12%; 28 contracts N/A on a server SDK) | 7 | 15 | 9 | 28 | 0 | 2026-08-06 · `e7f20e3` | 24 | [posthog-dotnet.md](posthog-dotnet.md) |

"Overall" for posthog-python, posthog-node, posthog-php, posthog-ruby, posthog-go, posthog-java,
and posthog-dotnet is computed against the contracts actually applicable to a server SDK
(posthog-python: 10 Pass / 30 applicable = 33%; posthog-node: 11 Pass / 32 applicable = 34%;
posthog-php: 12 Pass / 28 applicable = 43%; posthog-ruby: 13 Pass / 29 applicable = 45%;
posthog-go: 10 Pass / 28 applicable = 36%; posthog-java: 12 Pass / 31 applicable = 39%;
posthog-dotnet: 7 Pass / 31 applicable = 23%); shown above as raw Pass/59 for comparability with
client SDKs, which see N/A far less often. **posthog-node note:** the standalone
`PostHog/posthog-node` repo has been archived/redirected — its code now lives at `packages/node` +
`packages/core` inside the `posthog-js` monorepo, so its audited commit is a `posthog-js` SHA
(`e1efa57`), not a `posthog-node` SHA. **posthog-react-native note:** likewise archived
(`pushed_at` 2025-07-26) and folded into the same `posthog-js` monorepo at `packages/react-native`
+ `packages/react-native-plugin`, so it too is audited at a `posthog-js` SHA (`e1efa57`) — but
unlike posthog-node it extends the full client-side `PostHogCore` base, so it is scored like a
client SDK (raw Pass/59), not given the server-SDK applicable-only treatment. **posthog-java
note:** the standalone `PostHog/posthog-java` repo is also archived; its README redirects to a new
home at `PostHog/posthog-android`'s `posthog-server/` subdirectory (package `com.posthog.server`,
Kotlin/JVM), which is what this audit evaluated — its audited commit (`0d2b16b`) is therefore a
`posthog-android` SHA, coincidentally the same commit posthog-android's own (separate) client-SDK
audit used, since both live in the same monorepo and neither has drifted since.

## Global open gaps (Fail before Partial, by SDK)

### ❌ Fail

| SDK | Contract | Backwards-compat verdict | Note |
|---|---|---|---|
| posthog-js | Flush | Backward-compatible | No public `flush()` on the browser client at all — [posthog-js.md#n2](posthog-js.md) |
| posthog-js | Get Anonymous ID | Backward-compatible | No `getAnonymousId()`; anon id is fused into `distinct_id` — [posthog-js.md#n3](posthog-js.md) |
| posthog-js | Get Feature Flags | Backward-compatible | No flat `Record<string, value>` getter, only array-shaped `getAllFeatureFlags()` — [posthog-js.md#n5](posthog-js.md) |
| posthog-js | Get Feature Flags And Payloads | Backward-compatible | No such method under any name — [posthog-js.md#n6](posthog-js.md) |
| posthog-js | Screen | Backward-compatible | No `screen()` API/`$screen` event; `$pageview` is a weaker analogue — [posthog-js.md#n10](posthog-js.md) |
| posthog-js | Event Batcher | Needs deprecation path | No count-based `flushAt`/`maxBatchSize`/413 handling in the browser queue — [posthog-js.md#n16](posthog-js.md) |
| posthog-js | Traces | Backward-compatible | No OTLP span/traces implementation anywhere — [posthog-js.md#n25](posthog-js.md) |
| posthog-python | Logs | Backward-compatible | No `/i/v1/logs` OTLP pipeline — [posthog-python.md#n1](posthog-python.md) |
| posthog-python | Traces | Backward-compatible | No `/i/v1/traces` OTLP pipeline — [posthog-python.md#n2](posthog-python.md) |
| posthog-python | Is Feature Enabled | Backward-compatible | `feature_enabled()` has no `default_value` param (hard SHALL, no server carve-out) — [posthog-python.md#n10](posthog-python.md) |
| posthog-python | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | No persistent property-override cache, despite `@both`-tagged acceptance scenarios — [posthog-python.md#n11](posthog-python.md) |
| posthog-android | Shutdown | Backward-compatible | `close()` never flushes; queued events stranded on disk — [posthog-android.md#n12](posthog-android.md) |
| posthog-android | Start Session Recording | Backward-compatible | `startSessionReplay()` has no `isOptedOut()` guard — [posthog-android.md#n13](posthog-android.md) |
| posthog-android | Autocapture | Backward-compatible | No generic UI-interaction autocapture (`$autocapture`) at all — [posthog-android.md#n16](posthog-android.md) |
| posthog-android | Traces | Backward-compatible | No OTLP traces/spans implementation — [posthog-android.md#n26](posthog-android.md) |
| posthog-ios | Get Feature Flags | Backward-compatible | No flat bulk flag getter, only internal machinery — [posthog-ios.md#n11](posthog-ios.md) |
| posthog-ios | Get Feature Flags And Payloads | Backward-compatible | No combined flags+payloads getter under any name — [posthog-ios.md#n12](posthog-ios.md) |
| posthog-ios | On Feature Flags | Backward-compatible | No public multi-subscriber listener API exposed — [posthog-ios.md#n17](posthog-ios.md) |
| posthog-ios | Session Replay Privacy | Needs deprecation path | Default wireframe-capture mode never checks `ph-no-capture` for plain `UIView`s — a silent privacy leak in the default mode — [posthog-ios.md#n22](posthog-ios.md) |
| posthog-ios | Shutdown | Backward-compatible | `close()` never calls `flush()` before stopping queues — [posthog-ios.md#n24](posthog-ios.md) |
| posthog-ios | Traces | Backward-compatible | No OTLP span/traces implementation anywhere — [posthog-ios.md#n26](posthog-ios.md) |
| posthog-node | Traces | Backward-compatible | No OTLP `/i/v1/traces` pipeline anywhere in the monorepo (industry-wide gap, matches posthog-python/-js) — [posthog-node.md#n2](posthog-node.md) |
| posthog-node | Is Feature Enabled | Backward-compatible | Neither `isFeatureEnabled()` nor its successor accepts a caller `defaultValue` (hard SHALL, no server carve-out) — [posthog-node.md#n11](posthog-node.md) |
| posthog-node | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | Zero implementation; methods exist only on the client-only base class node doesn't extend — [posthog-node.md#n13](posthog-node.md) |
| posthog-flutter | Get Anonymous ID | Backward-compatible | Method doesn't exist in the Dart API at all (standing `// TODO`) — [posthog-flutter.md#n14](posthog-flutter.md) |
| posthog-flutter | Get Feature Flags | Backward-compatible | No bulk flag getter anywhere in Dart — [posthog-flutter.md#n16](posthog-flutter.md) |
| posthog-flutter | Get Feature Flags And Payloads | Backward-compatible | No combined flags+payloads getter anywhere in Dart — [posthog-flutter.md#n17](posthog-flutter.md) |
| posthog-flutter | Shutdown | Backward-compatible | `close()` never flushes; complete no-op on Web — [posthog-flutter.md#n34](posthog-flutter.md) |
| posthog-flutter | Traces | Backward-compatible | No implementation; net-new, pre-GA — [posthog-flutter.md#n38](posthog-flutter.md) |
| posthog-flutter | Tracing Headers | Backward-compatible | No implementation; Flutter has no Dart-side HTTP client of its own to intercept app traffic with — [posthog-flutter.md#n39](posthog-flutter.md) |
| posthog-react-native | Is Opt Out | Backward-compatible | No callable `isOptOut()`; only an internal `optedOut` getter property, unlike every other audited client SDK — [posthog-react-native.md#n15](posthog-react-native.md) |
| posthog-react-native | Traces | Backward-compatible | No OTLP span/traces implementation anywhere in the monorepo — [posthog-react-native.md#n28](posthog-react-native.md) |
| posthog-php | Is Feature Enabled | Backward-compatible | `isFeatureEnabled()` has no `defaultValue` param (hard SHALL, no server carve-out) — [posthog-php.md#n8](posthog-php.md) |
| posthog-php | Logs | Backward-compatible | No `/i/v1/logs` OTLP pipeline — [posthog-php.md#n9](posthog-php.md) |
| posthog-php | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | No persistent property-override store at all; only per-call kwargs — [posthog-php.md#n10](posthog-php.md) |
| posthog-php | Traces | Backward-compatible | No OTLP `/i/v1/traces` pipeline — [posthog-php.md#n12](posthog-php.md) |
| posthog-ruby | Is Feature Enabled | Backward-compatible | Neither `is_feature_enabled` nor `FeatureFlagEvaluations#enabled?` accepts a caller `default_value` (hard SHALL, no server carve-out) — [posthog-ruby.md#n9](posthog-ruby.md) |
| posthog-ruby | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | No persistent property-override store; only per-call kwargs — [posthog-ruby.md#n11](posthog-ruby.md) |
| posthog-go | Is Feature Enabled | Backward-compatible | Neither `IsFeatureEnabled`/`GetFeatureFlag` nor `FeatureFlagEvaluations.IsEnabled` accepts a caller default; every miss collapses to hardcoded `false` — [posthog-go.md#n12](posthog-go.md) |
| posthog-go | Logs | Backward-compatible | No `/i/v1/logs` OTLP pipeline anywhere — [posthog-go.md#n13](posthog-go.md) |
| posthog-go | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | No persistent property-override store; only per-call struct fields — [posthog-go.md#n14](posthog-go.md) |
| posthog-go | Traces | Backward-compatible | No OTLP `/i/v1/traces` pipeline anywhere — [posthog-go.md#n16](posthog-go.md) |
| posthog-java | Alias | Backward-compatible | `aliasStateless()` has no blank-check on `distinctId`/`alias`, unlike `identify()` seven lines away — [posthog-java.md#n1](posthog-java.md) |
| posthog-java | Logs | Backward-compatible | No `/i/v1/logs` OTLP pipeline in `posthog-server` — [posthog-java.md#n19](posthog-java.md) |
| posthog-java | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | No persistent property-override store despite `@both`-tagged acceptance scenarios — [posthog-java.md#n20](posthog-java.md) |
| posthog-dotnet | Get Feature Flag Payload | Backward-compatible | No standalone `GetFeatureFlagPayloadAsync(key, distinctId)`; only reachable via a full flag/snapshot object — [posthog-dotnet.md#n12](posthog-dotnet.md) |
| posthog-dotnet | Is Feature Enabled | Backward-compatible | No `defaultValue` overload on `IsFeatureEnabledAsync`/`FeatureFlagEvaluations.IsEnabled`; every miss collapses to hardcoded `false` — [posthog-dotnet.md#n16](posthog-dotnet.md) |
| posthog-dotnet | Logs | Backward-compatible | Entirely unimplemented — [posthog-dotnet.md#n17](posthog-dotnet.md) |
| posthog-dotnet | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | Zero implementation despite `@both`-tagged, server-satisfiable acceptance scenarios — [posthog-dotnet.md#n18](posthog-dotnet.md) |
| posthog-dotnet | Retry Queue | Needs deprecation path | `AsyncBatchHandler` dequeues before send and never requeues on failure; any transient 5xx permanently drops the batch — [posthog-dotnet.md#n19](posthog-dotnet.md) |
| posthog-dotnet | Traces | Backward-compatible | Entirely unimplemented — [posthog-dotnet.md#n21](posthog-dotnet.md) |

### 🟡 Partial (highlights — see per-SDK files for the full list)

| SDK | Contract | Backwards-compat verdict | Note |
|---|---|---|---|
| posthog-js | Retry Queue | Needs deprecation path | Unbounded queue, 429 not retried, no `Retry-After` — [posthog-js.md#n22](posthog-js.md) |
| posthog-js | Surveys | Needs deprecation path | Opt-out doesn't block survey display/fetch outside cookieless mode — [posthog-js.md#n24](posthog-js.md) |
| posthog-python | Flush | Breaking | Failed batches are dropped, not retained — requeue-for-retry would change delivery/ordering semantics — [posthog-python.md#n6](posthog-python.md) |
| posthog-python | Retry Queue | Needs deprecation path | Same drop-on-failure behavior with observable `on_error`/blocking-timing implications — [posthog-python.md#n17](posthog-python.md) |
| posthog-python | Feature Flag Called Tracker | Backward-compatible | Minimal-event allowlist missing the 10 session-attribution properties added by sdk-specs' own most recent merged fix (`b59e8b4`) — [posthog-python.md#n16](posthog-python.md) |
| posthog-android | Feature Flag Called Tracker | Backward-compatible | Same allowlist gap as posthog-python, already fixed in posthog-js/-node per the audit notes — [posthog-android.md#n19](posthog-android.md) |
| posthog-android | Session Replay Privacy | Needs deprecation path | `ph-no-capture` ignored outside screenshot mode; default capture mode can leak tagged views — [posthog-android.md#n24](posthog-android.md) |
| posthog-android | Surveys | Needs deprecation path | Web-only `url`/`selector`-targeted surveys aren't excluded on Android as the spec requires — [posthog-android.md#n25](posthog-android.md) |
| posthog-ios | Screen | Needs deprecation path | Caller-supplied `$screen_name` silently overrides the explicit `screenTitle` argument, the inverse of spec precedence — [posthog-ios.md#n21](posthog-ios.md) |
| posthog-node | Flush / Retry Queue (v1 pipeline) | Needs deprecation path | `V1CaptureSender` never throws on exhausted retry, so failed batches are evicted from the queue as if delivered — [posthog-node.md#n8](posthog-node.md) |
| posthog-node | Feature Flag Called Tracker | Backward-compatible | Allowlist itself is fully compliant (inherited from posthog-js via shared `@posthog/core`), but capacity eviction is a full clear rather than incremental, violating the spec's anti-thundering-herd requirement — [posthog-node.md#n19](posthog-node.md) |
| posthog-flutter | Session Replay Privacy | Backward-compatible (mostly) | Independent Dart replay pipeline has no no-capture marker, no general unmask primitive, inconsistent password-field masking — [posthog-flutter.md#n31](posthog-flutter.md) |
| posthog-react-native | Bootstrap | Backward-compatible | Flag-merge spread order is inverted — previously-persisted flags win over a fresh bootstrap value, the opposite of the spec's required precedence — [posthog-react-native.md#n4](posthog-react-native.md) |
| posthog-react-native | Flush / Retry Queue | Backward-compatible | Shared-core catch handler evicts an exhausted-retry HTTP failure as if delivered instead of preserving it — same defect class as posthog-node — [posthog-react-native.md#n10](posthog-react-native.md) |
| posthog-react-native | Session Replay Privacy | ❓ Unknown | RN's own bridge does no masking itself; the underlying native SDKs it wraps have confirmed masking bugs (see posthog-ios#n22) that likely propagate but can't be independently re-verified — [posthog-react-native.md#n24](posthog-react-native.md) |
| posthog-php | Feature Flag Called Tracker | Backward-compatible | Minimal-event allowlist missing the same 10 session-attribution properties as python/android — [posthog-php.md#n4](posthog-php.md) |
| posthog-php | HTTP Client | Backward-compatible | `/flags` retry backoff starts at 100ms instead of the spec-mandated 300ms/600ms schedule — [posthog-php.md#n7](posthog-php.md) |
| posthog-ruby | Alias / Capture / Group Identify | Breaking | Raises `ArgumentError` on missing required fields (asserted by the SDK's own test suite) instead of the spec's silent-drop-with-warning — [posthog-ruby.md#n1](posthog-ruby.md) |
| posthog-ruby | Feature Flag Called Tracker | Backward-compatible | Same allowlist gap as python/android/php, plus a full-`clear` on capacity instead of incremental LRU eviction — [posthog-ruby.md#n5](posthog-ruby.md) |
| posthog-ruby | Retry Queue | Needs deprecation path | Failed batches dropped rather than requeued, with observable `on_error`/timing implications — [posthog-ruby.md#n12](posthog-ruby.md) |
| posthog-go | Flush / Retry Queue | Breaking (core issue) | Once a batch's local retry budget is exhausted, both wire pipelines permanently drop it rather than requeuing — [posthog-go.md#n7](posthog-go.md) |
| posthog-go | Feature Flag Called Tracker | Backward-compatible | Allowlist missing the same 10 session-attribution properties as python/android/ios/php/ruby; `Close()` also never purges the dedup LRU — [posthog-go.md#n5](posthog-go.md) |
| posthog-go | Flag Definition Loader | Backward-compatible | No external/shared flag-definition cache-provider extension point at all, unlike posthog-ruby/php/node/python — [posthog-go.md#n6](posthog-go.md) |
| posthog-java | Before Send Hook | Backward-compatible | Chaining bug — passes the *original* event to every hook instead of the running mutated event, so a second hook never sees the first hook's changes — [posthog-java.md#n2](posthog-java.md) |
| posthog-java | Shutdown | Backward-compatible | `close()` never calls `queue.flush()`, only cancels the timer — sub-threshold events are silently lost — [posthog-java.md#n24](posthog-java.md) |
| posthog-java | Feature Flag Called Tracker | Backward-compatible | Same 10-property allowlist gap as posthog-ruby/-node/-php — [posthog-java.md#n8](posthog-java.md) |
| posthog-java | Local Feature Flag Evaluator | Needs deprecation path | Missing group context resolves to a hard `false` instead of falling back to a remote evaluation — [posthog-java.md#n18](posthog-java.md) |
| posthog-dotnet | Feature Flag Called Tracker | Backward-compatible | Same 10-property allowlist gap as every other server SDK audited; otherwise a well-built tracker (incremental eviction, group normalization) — [posthog-dotnet.md#n7](posthog-dotnet.md) |
| posthog-dotnet | Setup | Needs deprecation path | Re-`Init` silently swaps the default client's config today; adding a double-init guard changes behavior some callers may rely on — [posthog-dotnet.md#n20](posthog-dotnet.md) |
| posthog-dotnet | Identify | Breaking or Backward-compatible (implementation-dependent) | Missing/empty `distinctId` silently succeeds today; spec text calls for either a raise (breaking) or drop-with-log (backward-compatible) — [posthog-dotnet.md#n15](posthog-dotnet.md) |

Full contract-by-contract detail (all 47 posthog-js, 38 posthog-python, 47 posthog-android, 26
posthog-ios, 21 posthog-node, 39 posthog-flutter, 28 posthog-react-native, 13 posthog-php, 14
posthog-ruby, 18 posthog-go, 19 posthog-java, and 24 posthog-dotnet non-Pass cells) is in the
respective per-SDK files.

## Cross-cutting pattern worth flagging

The **Feature Flag Called Tracker** minimal-event allowlist gap (missing session-attribution
properties from the most recently merged spec change, sdk-specs commit `b59e8b4`) is now confirmed
in **8 of the 12 audited SDKs**: posthog-python, posthog-android, posthog-ios, posthog-php,
posthog-ruby, posthog-go, posthog-java, and posthog-dotnet. It was already fixed in posthog-js,
posthog-node, and posthog-react-native (all three share `@posthog/core`, so it's the same fix
inherited three times, not three independent fixes). posthog-flutter's own Dart code has zero
allowlist logic (100% delegated to embedded native SDKs), so its status stays ❓ Unknown rather
than assumed. With all 12 in-scope SDKs now audited, this is a confirmed, complete picture: a fix
that shipped to the shared JS core but was independently ported to only 3 of the 9
independent-implementation SDKs.

A second cross-cutting pattern, also now visible across the full 12-SDK set: **Is Feature
Enabled**'s caller-supplied default-value parameter (a hard spec `SHALL`, no server carve-out) is
missing in posthog-python, posthog-node, posthog-php, posthog-ruby, posthog-go, and posthog-dotnet
— 6 of the 7 server-style SDKs audited. The lone exception is **posthog-java**
(`posthog-server`'s `com.posthog.server` package), which correctly implements a caller-supplied
default on its canonical evaluation path — worth using as the reference implementation when fixing
the other 6.

A third pattern, also newly complete: **Set/Reset Person/Group Properties For Flags** (all four
contracts) have zero persistent-override-store implementation in every server-style SDK audited —
posthog-python, posthog-node, posthog-php, posthog-ruby, posthog-go, posthog-java, and
posthog-dotnet (7 of 7) — despite `@both`-tagged, mechanically server-satisfiable acceptance
scenarios in all four specs. This is the most consistent gap in the entire matrix and the specs'
own `Applicability: client` prose vs. the acceptance files' `@both` tags should be reconciled
upstream regardless of which way remediation goes.

**Shutdown never flushes before stopping queues** continues to recur: posthog-android,
posthog-ios, posthog-flutter (mobile/client SDKs, previously noted) and now also **posthog-java**
(`posthog-server`'s `close()` cancels the flush timer but never calls `queue.flush()`) — all
Backward-compatible fixes, all the same defect shape.

## Unknown (❓) cells needing human review

**posthog-flutter — 6 cells**, all stemming from its architecture as a thin Dart wrapper that
delegates most transport/queueing mechanics to embedded native SDKs (posthog-android/posthog-ios)
or, on web, to an existing `window.posthog` (posthog-js) — behavior the Flutter repo alone cannot
verify:
- **Event Batcher** — [posthog-flutter.md#n10](posthog-flutter.md)
- **Feature Flag Called Tracker** — allowlist logic is 100% delegated to native SDKs; plausibly
  inherits the same gap found in embedded posthog-android, but not independently verifiable —
  [posthog-flutter.md#n11](posthog-flutter.md)
- **HTTP Client** — [posthog-flutter.md#n20](posthog-flutter.md)
- **Persistent Storage** — [posthog-flutter.md#n26](posthog-flutter.md)
- **Remote Config** — [posthog-flutter.md#n28](posthog-flutter.md)
- **Retry Queue** — [posthog-flutter.md#n29](posthog-flutter.md)

**posthog-react-native — 1 cell**: **Session Replay Privacy** —
[posthog-react-native.md#n24](posthog-react-native.md). RN's own bridge code performs no masking
itself (it only forwards config booleans to the underlying native SDK), and the native SDKs it
wraps (posthog-ios/posthog-android) have confirmed masking bugs from prior audits that would
likely propagate — but this can't be independently re-verified without checking the exact pinned
native-SDK versions `@posthog/react-native-plugin` depends on, so it's recorded as Unknown rather
than assumed.

No Unknown cells in posthog-ios, posthog-node, posthog-php, posthog-ruby, posthog-go,
posthog-java, or posthog-dotnet — all seven resolved every one of their 59 contracts to a concrete
✅/🟡/❌/➖ status with direct code evidence.

## Pending initial audit

None — all 12 in-scope SDKs now have at least one full audit on file. (posthog-go, posthog-java,
and posthog-dotnet were the last 3 to be drained from the bootstrap backlog, in this run.)

## Queued for next run

This run checked for spec changes since the last run (none — sdk-specs `main` HEAD is still
`b59e8b4`, the same commit every prior audit in this matrix was run against) and for code drift on
the 9 already-audited SDKs (none — every recorded audited SHA still matches each repo's current
default-branch HEAD as of this run). With nothing changed and nothing stale, this run's cap (3
SDKs/run) drained the final 3 of the pending-initial-audit backlog: **posthog-go**,
**posthog-java** (confirmed redirected from the archived standalone repo into
`posthog-android`'s `posthog-server/` subdirectory — a Kotlin/JVM server SDK, distinct from the
Android client SDK audited separately in the same monorepo), and **posthog-dotnet**.

With the bootstrap backlog now fully drained, **the staleness backstop takes over starting next
run**: re-audit whichever SDKs have gone longest since their last full audit. Every SDK in this
matrix currently carries the same audit date (2026-08-06, reflecting this compressed run
schedule), so recency is tie-broken by audit-run order — the run-1 cohort (**posthog-js**,
**posthog-python**, **posthog-android**) was audited first and should be re-verified first next
time, followed by the run-2 cohort (posthog-ios, posthog-node, posthog-flutter), and so on, keeping
every SDK inside the ~4-week re-verification window.
