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
posthog-go, posthog-java, posthog-dotnet. **64 contracts** are now tracked per SDK: the 64
capabilities listed in the root `README.md` table, including **MCP Analytics**, added this cycle by
PR [#87](https://github.com/PostHog/sdk-specs/pull/87), and **Bootstrap**, added to the table by PR
[#97](https://github.com/PostHog/sdk-specs/pull/97).

Five contracts are newer than most per-SDK files. **Capture AI**, **Evaluate Flags**, and **Exception
Event Metadata** merged between 2026-08-10 and 2026-08-13; **Session Replay Debug Properties** on
2026-09-28 (PR [#72](https://github.com/PostHog/sdk-specs/pull/72)); and **MCP Analytics** on 2026-10-05
(PR [#87](https://github.com/PostHog/sdk-specs/pull/87)). After this run **ten SDKs carry all 64 rows**:
posthog-js, posthog-go, posthog-dotnet, posthog-ios, posthog-python, posthog-node, and — new this run —
posthog-react-native, posthog-flutter, and posthog-android. posthog-php and posthog-ruby sit at 63,
needing only the MCP Analytics row (➖ N/A for both on the spec's own applicability table).
**posthog-java is the last SDK still at 59 rows** and needs all five added at its next audit; see
"Queued for next run".

**No SDK is pending its first audit.** Every run since the backlog drained has been a re-audit
run, and selection is driven by the four-rule priority order at the top of this file.

## This run (2026-10-19)

**Three SDKs audited: posthog-react-native, posthog-flutter, posthog-android** — the first full
three-slot run since the rotation started slipping, and it clears the three oldest pointers in the
matrix at once (two from 2026-08-06, one from 2026-08-10).

**No spec change merged since the 2026-10-12 run.** The only commit on the base branch,
`541b9b0`, touches agent tooling and acceptance-authoring docs, not `openspec/specs/`. Selection
therefore fell to priority rules 2–4, and the queue the previous run left was followed exactly:
react-native #1, flutter #2, android #3 (java, android's co-located server SDK, deferred).

**Every ❓ Unknown cell in the matrix has been drained, and one new one opened deliberately.**
posthog-flutter's six Unknowns and posthog-react-native's one are all resolved to a definite status
with direct code evidence. The single remaining ❓ is a **correction**, not a new gap — see below.

### The headline: posthog-flutter is no longer only a wrapper

The entire reason posthog-flutter held six Unknowns was that its transport, queueing, storage, and
flag-tracking mechanics lived inside the embedded native SDKs. Since 2026-08-06 the repo has grown
**its own pure-Dart core** (`posthog_flutter/lib/src/core/`, ~2,700 lines across
`posthog_core.dart`, `posthog_core_stateless.dart`, `file_storage.dart`, `feature_flags.dart` and
friends) driving a new **Windows/Linux desktop platform** that runs entirely in Dart. The Dart
`lib/` tree is now 18,773 lines. Three execution paths now exist — native method channel on
iOS/Android/macOS, the new Dart core on Windows/Linux, `window.posthog` on web — and each row is
scored across all three.

Two things in that Dart core are **ahead of every other SDK in this matrix**:

- **Retry Queue ❓→✅.** `_doFlush` removes a batch from the queue **only when the error is not
  transient**, honours `Retry-After`, and re-arms the flush timer so an offline failure cannot
  strand the queue. A persistent 503 stays queued — exactly what the spec requires and precisely
  what posthog-js, posthog-node, and posthog-react-native all get wrong through the same shared
  catch handler.
- **Malformed feature-flag payloads.** `feature_flags.dart` documents and implements the rule
  verbatim: a payload that is not valid JSON (empty string included) is *no* payload — `null` is
  returned and the error is reported. That is **both halves** of the requirement, the correct
  sentinel and the mandated diagnostic, which no other SDK in the matrix currently has:
  posthog-ios, posthog-go, and now posthog-react-native return the raw malformed string, and
  posthog-php returns the right sentinel but never logs. **This holds on Windows/Linux only.** On
  iOS and macOS the payload comes from posthog-ios over the method channel, so Flutter inherits
  posthog-ios's raw-string fallback there, and its Get Feature Flag Payload and Get Feature Flag
  Result rows move ✅→🟡.

### posthog-android: the largest net improvement of any SDK so far

✅ rows **31→35** while the row count grew by five, and ❌ rows **9→5**. Four rows cleared outright:
**Screen ❌→✅** (the explicit `screenTitle` now wins over a caller-supplied `$screen_name`, with the
*cached* screen name correctly still overridable), **Shutdown ❌→✅** (`close()` now flushes before
tearing down — which also fixes the native half of posthog-flutter's Shutdown finding), **HTTP
Client 🟡→✅** (posthog-android#828 shipped; android is now the **only** SDK in the matrix with a
correct 300 ms→600 ms exponential flags backoff, and it passes the refused-connection rule), and
**Capture Exception ❌→✅** on the PR [#103](https://github.com/PostHog/sdk-specs/pull/103)
withdrawal the previous run predicted. **Autocapture ❌→🟡** — `$autocapture` for View and Compose
taps now genuinely exists (plus `$rageclick`), but ships off by default.

Android also turns out to have **by far the most complete Session Replay Debug Properties
implementation outside the browser** — all four required keys, a real tri-state `$recording_status`,
a correct `$snapshot` exclusion, and a `disabled` fallback when no replay handler is installed. It
is 🟡 on two deviations: no required/optional tiering and no 30-second throttle (so the whole bundle
rides every event, including custom ones), and a crash-time `$exception` from a previous launch is
stamped with an **empty** map where the spec requires a persisted crash-context snapshot.

### posthog-react-native: 802 commits of drift, two improvements, four spec-driven downgrades

**Capture Exception 🟡→✅** on the PR #103 withdrawal, and **Session Replay Privacy ❓→🟡** resolved.
Four rows moved ✅→🟡 on new spec text with no code regression: **Setup** (PR
[#108](https://github.com/PostHog/sdk-specs/pull/108) names React Native's `apiKey` prop by name —
`PostHogProvider` still has no `projectToken`), and **Get Feature Flag Payload / Result / Flags And
Payloads** on the payload-decoding rule, where shared `parsePayload` returns the raw malformed
string. RN now **passes** PR [#114](https://github.com/PostHog/sdk-specs/pull/114)'s caller-property
precedence (client `enrichProperties` spreads the caller last; the stateless server base keeps the
opposite order, which is the documented split) and PR
[#110](https://github.com/PostHog/sdk-specs/pull/110)'s refused-connection rule. **Session Replay
Debug Properties ❌** on first audit: zero implementation despite RN owning a real replay
integration.

### A correction a human should see: posthog-node's Traces row was wrong

The 2026-10-12 posthog-node audit recorded Traces as ❌ on "no OTLP `/i/v1/traces` pipeline
**anywhere in the monorepo**". That was a false negative. While auditing react-native in the same
monorepo this run, the pipeline turned up immediately: `packages/core/src/traces/` (span, OTLP,
`traceparent`, ids, config, context, sanitize, live-spans), exported as `PostHogTraces`, with
`_sendTracesBatch` on `PostHogCoreStateless` — and **posthog-node is the one package that wires it**
(`packages/node/src/client.ts:698-703`). It merged in posthog-js#4579 on **2026-09-10**, four weeks
before the audit that called it absent.

The row is corrected to **❓ Unknown**, not to a Pass: the implementation demonstrably exists, so ❌
is indefensible, but it has not been read against the traces spec's configuration knobs, defaults,
W3C interop, payload bounds, or retry classification, and guessing ✅/🟡 would be exactly the error
being corrected. **posthog-node should be prioritized at the next audit to score it.** Nothing else
on posthog-node's page was re-audited this run. The related react-native finding — it has the shared
engine and transport but never constructs `PostHogTraces` — stands independently.

**One thing worth a maintainer's attention:** three of this run's 🟡 verdicts are **"Needs
deprecation path" on the same spec clause** — `exception-event-metadata` line 300, which forbids an
application property bag from overriding SDK-owned `$exception_list`/`$exception_level`/
`$exception_source`. posthog-react-native, posthog-flutter, and posthog-android all let the caller's
generic property map win, and posthog-android's `PostHogStateless.kt` *documents* it as intended
behaviour. Compliance needs a typed-override channel to ship first in all three. That is now
confirmed in six SDKs (adding these three to posthog-python, posthog-node, and posthog-ruby) and is
the single most widely-shared non-compliance in the matrix.

## Roll-up

| SDK | Overall | ✅ | 🟡 | ❌ | ➖ | ❓ | Last audited | Open gaps | File |
|---|---|---|---|---|---|---|---|---|---|
| posthog-js | 26/64 fully compliant (41%) | 26 | 21 | 12 | 5 | 0 | 2026-10-05 · `6538babc` (targeted re-audit; most of the 59 pre-existing rows carried from 2026-08-10, see file header) | 33 | [posthog-js.md](posthog-js.md) |
| posthog-python | 13/64 fully compliant (20%; 30 contracts N/A on a server SDK) | 13 | 16 | 5 | 30 | 0 | 2026-10-12 · `509c8525` | 21 | [posthog-python.md](posthog-python.md) |
| posthog-android | 35/64 fully compliant (55%) | 35 | 18 | 5 | 6 | 0 | 2026-10-19 · `c5e788bd` (targeted re-audit — see file header) | 23 | [posthog-android.md](posthog-android.md) |
| posthog-ios | 38/64 fully compliant (59%) | 38 | 16 | 4 | 6 | 0 | 2026-10-08 · `f5cbe87c` + PostHog/posthog-ios#924–#934 (out-of-cycle refresh, see below) | 20 | [posthog-ios.md](posthog-ios.md) |
| posthog-node | 9/64 fully compliant (14%; 29 contracts N/A on a server SDK) | 9 | 21 | 4 | 29 | 1 | 2026-10-12 · `4f590b36` (posthog-js monorepo; Traces row corrected 2026-10-19) | 25 (+1 ❓) | [posthog-node.md](posthog-node.md) |
| posthog-flutter | 22/64 fully compliant (34%) | 22 | 28 | 6 | 8 | 0 | 2026-10-19 · `1032c102` | 34 | [posthog-flutter.md](posthog-flutter.md) |
| posthog-react-native | 28/64 fully compliant (44%) | 28 | 28 | 3 | 5 | 0 | 2026-10-19 · `3ddaa654` (posthog-js monorepo) | 31 | [posthog-react-native.md](posthog-react-native.md) |
| posthog-php | 11/63 fully compliant (17%; 33 contracts N/A on a server SDK; **needs +1: MCP Analytics**) | 11 | 11 | 8 | 33 | 0 | 2026-09-28 · `5451f4e0` | 19 | [posthog-php.md](posthog-php.md) |
| posthog-ruby | 9/63 fully compliant (14%; 33 contracts N/A on a server SDK; **needs +1: MCP Analytics**) | 9 | 13 | 8 | 33 | 0 | 2026-09-28 · `185060ab` | 21 | [posthog-ruby.md](posthog-ruby.md) |
| posthog-go | 8/64 fully compliant (13%; 33 contracts N/A on a server SDK) | 8 | 14 | 9 | 33 | 0 | 2026-10-05 · `08549f42` | 23 | [posthog-go.md](posthog-go.md) |
| posthog-java | 12/59 fully compliant (20%; **59 rows, needs +5 new contracts**) | 12 | 13 | 6 | 28 | 0 | 2026-08-10 · `8659a7b4` (posthog-android monorepo) | 19 | [posthog-java.md](posthog-java.md) |
| posthog-dotnet | 5/64 fully compliant (8%; 30 contracts N/A on a server SDK) | 5 | 19 | 10 | 30 | 0 | 2026-10-05 · `ae4d019c` | 29 | [posthog-dotnet.md](posthog-dotnet.md) |

**2026-09-28 contract correction (retained):** posthog-js n31 is withdrawn: custom network callbacks
intentionally replace default body-content scrubbing after mandatory header/path/size cleaning. That
correction was re-verified this run against the merged
PR [#79](https://github.com/PostHog/sdk-specs/pull/79) text on fresh evidence, and the ✅ stands; see
[posthog-js.md#n31](posthog-js.md#n31).

**2026-10-08 out-of-cycle refresh — posthog-ios:** re-audited all 64 rows at `f5cbe87c` against
sdk-specs `f238b16`, outside the weekly 3-slot rotation. 7 rows improved (On Feature Flags and
Surveys ❌→✅; Screen, Set Person Properties, Before Send Hook, Event Batcher, Consent Gating 🟡→✅),
3 rows moved ✅→🟡 on new spec requirements (Capture null-dropping; malformed-payload decoding in
Get Feature Flag Result and Feature Flag Cache), and 4 rows moved ✅→🟡 on findings the previous
audit missed with unchanged code (Flush, HTTP Client, Get Session ID, Is Feature Enabled). New rows:
MCP Analytics ➖, Session Replay Debug Properties 🟡. Details in [posthog-ios.md](posthog-ios.md).
The roll-up counts include the fixes from PostHog/posthog-ios#924–#934: Shutdown ❌→✅ and five 🟡→✅
(Group, Group Identify, Stop Session Recording, Feature Flag Called Tracker, HTTP Client); see the "posthog-ios PRs included" table in the per-SDK file.

**Row-count note:** **seven of twelve SDKs now carry the full 64-row matrix** — posthog-js,
posthog-go, posthog-dotnet, posthog-ios, and, after this run, posthog-react-native, posthog-flutter,
and posthog-android. posthog-python and posthog-node were brought to 64 on 2026-10-12. posthog-php
and posthog-ruby sit at 63 and need only the MCP Analytics row (➖ N/A for both, since the spec's
own applicability table lists Ruby as "not yet" and does not mention PHP). **posthog-java is now the
only SDK still at 59 rows** and needs all five of Capture AI, Evaluate Flags, Exception Event
Metadata, Session Replay Debug Properties, and MCP Analytics added from scratch at its next audit.

**Reading this run's numbers.** posthog-android gained four ✅ rows outright while its denominator
grew by five, so its headline moved 53%→55% on genuine repository progress. posthog-react-native's
✅ count fell 31→28 and its percentage 53%→44%, but **not one of those moves is a code regression**:
one row improved, five new rows landed (three ➖, one 🟡, one ❌), and four ✅ rows were downgraded
purely by spec text that merged after its last audit. posthog-flutter's ✅ count rose
(20→22) and its 🟡 count went 22→28. Most of the 🟡 growth is the six Unknowns resolving to 🟡, which is
a gain in knowledge, not a loss of compliance; three rows (Capture Exception, Screen, Set Person
Properties) were re-scored ✅ because their recorded gaps were fixed or retired. The rest is two
spec-driven downgrades: Get Feature Flag
Payload and Get Feature Flag Result are correct in the Dart core, but iOS/macOS inherit posthog-ios's
raw-string payload fallback. Percentages that move because the
denominator grew, or because an Unknown became a known Partial, are not regressions; the per-SDK
files mark which direction each row moved and why. Earlier runs' notes on posthog-js, posthog-go,
and posthog-dotnet (✅ counts falling purely on new spec text, and posthog-dotnet's 19 🟡 being
largely one shared payload-parse fix) still stand.

"Overall" for posthog-python, posthog-node, posthog-php, posthog-ruby, posthog-go, posthog-java,
and posthog-dotnet is computed against the contracts actually applicable to a server SDK
(posthog-python: 13 Pass / 34 applicable = 38%; posthog-node: 9 Pass / 35 applicable = 26%;
posthog-php: 11 Pass / 30 applicable = 37%; posthog-ruby: 9 Pass / 30 applicable = 30%;
posthog-go: 8 Pass / 31 applicable = 26%; posthog-java: 12 Pass / 31 applicable = 39%;
posthog-dotnet: 5 Pass / 34 applicable = 15%); shown above as raw Pass/(59, 63 or 64) for
comparability with client SDKs, which see N/A far less often. posthog-js's 26/64 is likewise 26 Pass
/ 59 applicable = 44%, since Capture AI and Evaluate Flags are ➖ on a browser SDK. **posthog-node
note:** the standalone `PostHog/posthog-node` repo has been archived/redirected — its code now lives
at `packages/node` + `packages/core` inside the `posthog-js` monorepo, so its audited commit is a
`posthog-js` SHA. **posthog-react-native note:** likewise archived and folded into the same
`posthog-js` monorepo at `packages/react-native` + `packages/react-native-plugin`, so it too is
audited at a `posthog-js` SHA — now `3ddaa654`, 802 commits on from its previous `e1efa57` pointer.
Unlike posthog-node it extends the full client-side `PostHogCore` base, so it is scored like a
client SDK (raw Pass/64), not given the server-SDK applicable-only treatment. **posthog-flutter
note:** no longer a pure wrapper — it now ships its own Dart core driving a Windows/Linux desktop
platform, alongside the native method-channel path on iOS/Android/macOS and `window.posthog` on web.
Rows are scored across all three paths; see the file header. **posthog-java note:**
the standalone `PostHog/posthog-java` repo is also archived; its README redirects to a new home at
`PostHog/posthog-android`'s `posthog-server/` subdirectory (package `com.posthog.server`,
Kotlin/JVM), which is what that audit evaluated — its audited commit (`8659a7b4`) is a
`posthog-android` SHA. It was the same commit posthog-android's own client-SDK audit used until this
run, which moved android to `c5e788bd` and left java behind at `8659a7b4`; java is now the matrix's
stalest pointer and its only 59-row file.

## Global open gaps (Fail before Partial, by SDK)

### ❌ Fail

| SDK | Contract | Backwards-compat verdict | Note |
|---|---|---|---|
| posthog-js | Exception Steps | Backward-compatible | Buffer is incorrectly cleared on every capture, contradicting the spec's explicit persist-across-captures scenario — [posthog-js.md#n3](posthog-js.md) |
| posthog-js | Flush | Backward-compatible | No public `flush()` on the browser client at all — [posthog-js.md#n4](posthog-js.md) |
| posthog-js | Get Anonymous ID | Backward-compatible | No `getAnonymousId()`; anon id is fused into `distinct_id` — [posthog-js.md#n5](posthog-js.md) |
| posthog-js | Get Feature Flags | Backward-compatible | No flat `Record<string, value>` getter, only array-shaped `getAllFeatureFlags()` — [posthog-js.md#n7](posthog-js.md) |
| posthog-js | Get Feature Flags And Payloads | Backward-compatible | No such method under any name — [posthog-js.md#n8](posthog-js.md) |
| posthog-js | Group | Backward-compatible | No `_requirePersonProcessing`/opt-out guard at all, unlike every structurally similar method — [posthog-js.md#n10](posthog-js.md) |
| posthog-js | Group Identify | Backward-compatible | No standalone `groupIdentify()`; only reachable via unguarded `group()` — [posthog-js.md#n11](posthog-js.md) |
| posthog-js | Screen | Backward-compatible | No `screen()` API/`$screen` event; `$pageview` is a weaker analogue — [posthog-js.md#n15](posthog-js.md) |
| posthog-js | Before Send Hook | Backward-compatible | No try/catch around the hook call at all; a throwing hook crashes `capture()` — [posthog-js.md#n20](posthog-js.md) |
| posthog-js | Event Batcher | Needs deprecation path | No count-based `flushAt`/`maxBatchSize`/413 handling in the browser queue — [posthog-js.md#n22](posthog-js.md) |
| posthog-js | HTTP Client | Backward-compatible | Zero retry mechanism for the flags-endpoint request (no partial retry logic exists either) — [posthog-js.md#n24](posthog-js.md) |
| posthog-js | Traces | Backward-compatible | No OTLP span/traces implementation anywhere — [posthog-js.md#n34](posthog-js.md) |
| posthog-python | Logs | Backward-compatible | No `/i/v1/logs` OTLP pipeline — [posthog-python.md#n1](posthog-python.md) |
| posthog-python | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | No persistent property-override cache, despite `@both`-tagged acceptance scenarios — [posthog-python.md#n10](posthog-python.md) |
| posthog-android | Alias | Backward-compatible | No `distinct_id` alongside `alias` in the `$create_alias` payload; re-confirmed 2026-10-19 at `PostHogStateless.kt:373-385` — [posthog-android.md#n1](posthog-android.md#n1) |
| posthog-android | Get Feature Flags | Backward-compatible | No public flat bulk getter; internal cache-only version exists but isn't exposed — [posthog-android.md#n9](posthog-android.md#n9) |
| posthog-android | Get Feature Flags And Payloads | Backward-compatible | No combined getter; returns `null` (not empty maps) on cold cache — [posthog-android.md#n10](posthog-android.md#n10) |
| posthog-android | Start Session Recording | Backward-compatible | `startSessionReplay()` still has no `isOptedOut()` guard — it checks `isEnabled()` and the replay flag only, and `group()` nine screens away documents why those are not the same check — [posthog-android.md#n20](posthog-android.md#n20) |
| posthog-android | Traces | Backward-compatible | No OTLP traces/spans implementation — [posthog-android.md#n23](posthog-android.md#n23) |
| posthog-ios | Get Feature Flags | Backward-compatible | No public flat key→value bulk flag getter — [posthog-ios.md#n9](posthog-ios.md) |
| posthog-ios | Get Feature Flags And Payloads | Backward-compatible | No combined flags+payloads getter under any name — [posthog-ios.md#n10](posthog-ios.md) |
| posthog-ios | Session Replay Privacy | Needs deprecation path | Default wireframe mode still records the children of a plain `ph-no-capture` container unmasked — [posthog-ios.md#n24](posthog-ios.md) |
| posthog-ios | Traces | Backward-compatible | No OTLP span/traces implementation anywhere — [posthog-ios.md#n2](posthog-ios.md) |
| posthog-node | Traces | ~~Backward-compatible~~ **corrected to ❓** | The ❌ was a **false negative**: `packages/core/src/traces/` merged 2026-09-10 and posthog-node wires it (`client.ts:698-703`). Moved to ❓ pending a real scoring pass — [posthog-node.md#n2](posthog-node.md#n2) |
| posthog-node | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | Zero implementation; methods exist only on the client-only base class node doesn't extend — [posthog-node.md#n15](posthog-node.md) |
| posthog-flutter | Get Anonymous ID | Backward-compatible | Method still doesn't exist in the Dart API at all — [posthog-flutter.md#n12](posthog-flutter.md#n12) |
| posthog-flutter | Get Feature Flags | Backward-compatible | No bulk flag getter anywhere in Dart, though the Dart core holds the full flag map internally — [posthog-flutter.md#n16](posthog-flutter.md#n16) |
| posthog-flutter | Get Feature Flags And Payloads | Backward-compatible | No combined getter; notably the decode half this depends on is already correct in the Dart core, so only the surface is missing — [posthog-flutter.md#n17](posthog-flutter.md#n17) |
| posthog-flutter | Exception Event Metadata | Needs deprecation path | **New this run** — no `exception_id`/`parent_id` linkage at all, causes inherit the outermost `handled`, `$exception_level` hardcoded, caller property bag overrides SDK-owned keys, and the chain caps at 10 where the spec says 50 — [posthog-flutter.md#n9](posthog-flutter.md#n9) |
| posthog-flutter | Traces | Backward-compatible | No implementation; net-new, pre-GA — [posthog-flutter.md#n36](posthog-flutter.md#n36) |
| posthog-flutter | Tracing Headers | Backward-compatible | No implementation; Flutter has no Dart-side HTTP client of its own to intercept app traffic with — [posthog-flutter.md#n37](posthog-flutter.md#n37) |
| posthog-react-native | Is Opt Out | Backward-compatible | No callable `isOptOut()`; only the `optedOut` getter property, unlike every other audited client SDK. Re-confirmed 2026-10-19 — [posthog-react-native.md#n17](posthog-react-native.md#n17) |
| posthog-react-native | Session Replay Debug Properties | Backward-compatible | **New this run** — zero implementation (no `$recording_status`, no `$sdk_debug_*`) despite RN owning a real replay integration and already computing most of the state these keys report — [posthog-react-native.md#n24](posthog-react-native.md#n24) |
| posthog-react-native | Traces | Backward-compatible | Still unwired — but `packages/core/src/traces/` and `_sendTracesBatch` now exist on the very base class RN extends, so this is wiring, not new subsystem work — [posthog-react-native.md#n31](posthog-react-native.md#n31) |
| posthog-php | Exception Event Metadata | Needs deprecation path | No `exception_id`/`parent_id` linkage, `handled: true` hardcoded on every entry including causes, no `synthetic`, no `$exception_level`, non-canonical `php_exception_handler`-style `$exception_source` — [posthog-php.md#n5](posthog-php.md) |
| posthog-php | Is Feature Enabled | Backward-compatible | `isFeatureEnabled()` has no `defaultValue` param (hard SHALL, no server carve-out) — [posthog-php.md#n11](posthog-php.md) |
| posthog-php | Logs | Backward-compatible | No `/i/v1/logs` OTLP pipeline — [posthog-php.md#n13](posthog-php.md) |
| posthog-php | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | No persistent property-override store at all; only per-call kwargs — [posthog-php.md#n14](posthog-php.md) |
| posthog-php | Traces | Backward-compatible | No OTLP `/i/v1/traces` pipeline — [posthog-php.md#n16](posthog-php.md) |
| posthog-ruby | Get Feature Flag Payload | Needs deprecation path | Malformed payloads are returned as their **raw serialized string**; the deprecated poller path never decodes at all — [posthog-ruby.md#n10](posthog-ruby.md) |
| posthog-ruby | Get Feature Flags And Payloads | Needs deprecation path | Bulk map is filled with undecoded, unvalidated raw payload strings, disagreeing with the snapshot accessor — [posthog-ruby.md#n12](posthog-ruby.md) |
| posthog-ruby | Exception Event Metadata | Mixed (see note) | Linkage/chaining/50-cap are correct, but nested entries inherit the outermost `handled`, `synthetic` and `$exception_level` are absent, and caller properties override SDK-owned `$exception_list` — [posthog-ruby.md#n6](posthog-ruby.md) |
| posthog-ruby | Is Feature Enabled | Backward-compatible | Neither `is_feature_enabled` nor `FeatureFlagEvaluations#enabled?` accepts a caller `default_value` (hard SHALL, no server carve-out) — [posthog-ruby.md#n14](posthog-ruby.md) |
| posthog-ruby | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | No persistent property-override store; only per-call kwargs — [posthog-ruby.md#n17](posthog-ruby.md) |
| posthog-go | Is Feature Enabled | Backward-compatible | Neither `IsFeatureEnabled`/`GetFeatureFlag` nor `FeatureFlagEvaluations.IsEnabled` accepts a caller default; every miss collapses to hardcoded `false` — [posthog-go.md#n14](posthog-go.md) |
| posthog-go | Logs | Backward-compatible | No `/i/v1/logs` OTLP pipeline anywhere — [posthog-go.md#n16](posthog-go.md) |
| posthog-go | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | No persistent property-override store; only per-call struct fields — [posthog-go.md#n18](posthog-go.md) |
| posthog-go | Traces | Backward-compatible | No OTLP `/i/v1/traces` pipeline anywhere — [posthog-go.md#n20](posthog-go.md) |
| posthog-go | Exception Event Metadata | Backward-compatible | **New this run** — `ExceptionMechanism` carries only `handled`/`synthetic`; no `exception_id`/`parent_id` linkage, no `$exception_source`, no `$exception_level` on the core capture path — [posthog-go.md#n6](posthog-go.md) |
| posthog-go | Get Feature Flag Payload | Backward-compatible | **Downgraded from ✅ this run on new spec text** — returns the raw malformed payload string with nothing logged; the only `json.Unmarshal` is an opt-in typed helper — [posthog-go.md#n10](posthog-go.md) |
| posthog-dotnet | Exception Event Metadata | Backward-compatible | **New this run** — the whole `mechanism` object is a fixed literal (`source: ""`, `synthetic: false`, `handled: true`) emitted identically for every entry: two forbidden unknown-placeholders, `handled` copied onto every nested entry, and no linkage fields — [posthog-dotnet.md#n8](posthog-dotnet.md) |
| posthog-java | Alias | Backward-compatible | `aliasStateless()` has no blank-check on `distinctId`/`alias`, unlike `identify()` seven lines away — [posthog-java.md#n1](posthog-java.md) |
| posthog-java | Logs | Backward-compatible | No `/i/v1/logs` OTLP pipeline in `posthog-server` — [posthog-java.md#n19](posthog-java.md) |
| posthog-java | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | No persistent property-override store despite `@both`-tagged acceptance scenarios — [posthog-java.md#n20](posthog-java.md) |
| posthog-dotnet | Get Feature Flag Payload | Backward-compatible | No standalone `GetFeatureFlagPayloadAsync(key, distinctId)`; only reachable via a full flag/snapshot object — [posthog-dotnet.md#n15](posthog-dotnet.md) |
| posthog-dotnet | Is Feature Enabled | Backward-compatible | No `defaultValue` overload on `IsFeatureEnabledAsync`/`FeatureFlagEvaluations.IsEnabled`; every miss collapses to hardcoded `false` — [posthog-dotnet.md#n20](posthog-dotnet.md) |
| posthog-dotnet | Logs | Backward-compatible | Entirely unimplemented — [posthog-dotnet.md#n22](posthog-dotnet.md) |
| posthog-dotnet | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | Zero implementation despite `@both`-tagged, server-satisfiable acceptance scenarios — [posthog-dotnet.md#n23](posthog-dotnet.md) |
| posthog-dotnet | Retry Queue | Needs deprecation path | `AsyncBatchHandler` dequeues before send and never requeues on failure; any transient 5xx permanently drops the batch — [posthog-dotnet.md#n24](posthog-dotnet.md) |
| posthog-dotnet | Traces | Backward-compatible | Entirely unimplemented — [posthog-dotnet.md#n26](posthog-dotnet.md) |

### 🟡 Partial (highlights — see per-SDK files for the full list)

| SDK | Contract | Backwards-compat verdict | Note |
|---|---|---|---|
| posthog-js | Consent Gating | Backward-compatible | Opt-out drop has no logged reason; persistence writes are only opt-out-gated when explicitly configured — [posthog-js.md#n21](posthog-js.md) |
| posthog-js | Retry Queue | Needs deprecation path | Unbounded queue, 429 not retried, no `Retry-After` — [posthog-js.md#n28](posthog-js.md) |
| posthog-js | Session Manager | Needs deprecation path | Idle-rotation is skipped whenever the session id is read via the read-only `get_session_id()` path — [posthog-js.md#n29](posthog-js.md) |
| posthog-js | Surveys | Needs deprecation path | Opt-out doesn't block survey display/fetch outside cookieless mode — [posthog-js.md#n32](posthog-js.md) |
| posthog-js | Logs | Needs deprecation path | Queue is in-memory-only and wiped on `reset()`; OTLP attribute-encoding and 408/`Retry-After` gaps — [posthog-js.md#n33](posthog-js.md) |
| posthog-python | Flush | Breaking | Failed batches are dropped, not retained — requeue-for-retry would change delivery/ordering semantics — [posthog-python.md#n6](posthog-python.md) |
| posthog-python | Retry Queue | Needs deprecation path | Same drop-on-failure behavior with observable `on_error`/blocking-timing implications — [posthog-python.md#n17](posthog-python.md) |
| posthog-python | Is Feature Enabled | Backward-compatible | Legacy `feature_enabled()` still lacks a caller default, but its designated successor `evaluate_flags(...).is_enabled(default_value=...)` fully satisfies the spec — upgraded from ❌ last run — [posthog-python.md#n9](posthog-python.md) |
| posthog-node | Capture AI | Backward-compatible | `privacyMode` is declared/documented but never wired to the client, so it silently fails to override `enableFullAiCapture` at config level as required — [posthog-node.md#n6](posthog-node.md) |
| posthog-python | Capture | Backward-compatible | **New this run** — `$release_id` is stamped correctly on the shared path but is absent from the minimized `$feature_flag_called` allowlist, which the capture spec now says SHALL retain it — [posthog-python.md#n4](posthog-python.md) |
| posthog-python | Exception Event Metadata | Needs deprecation path | **Upgraded from ❌** — linkage, nested-`handled` omission, the 50-entry cap, real `handled: False` from the uncaught hooks and `$exception_level` all landed; only the caller-property-bag override remains, and it already ships a `DeprecationWarning` naming the next major — [posthog-python.md#n14](posthog-python.md) |
| posthog-python | HTTP Client | Backward-compatible | **Downgraded from ✅ on new spec text** — a blanket `except requests.exceptions.ConnectionError` retries a *refused* flags connection, which the spec now says SHALL NOT be retried — [posthog-python.md#n18](posthog-python.md) |
| posthog-python | Local Feature Flag Evaluator | Backward-compatible | **Downgraded from ✅ on new spec text** — holdouts *are* implemented (first SDK in this matrix), but a boolean group key buckets on Python's `"True"` spelling instead of going inconclusive — [posthog-python.md#n19](posthog-python.md) |
| posthog-python | Evaluate Flags | Backward-compatible | **Downgraded from ✅ on new spec text** — no negative-knowledge retention; a deleted key re-probes `/flags` forever — [posthog-python.md#n17](posthog-python.md) |
| posthog-python | MCP Analytics | Backward-compatible | **New this run** — `posthog/mcp` is a strong first implementation with the exact 102,400-byte bound, but neither `$mcp_unknown_tool` nor `$mcp_input_required` ships, and the `$exception` side-car omits `$exception_source: "mcp.tool_call"` and never sets `synthetic` — [posthog-python.md#n20](posthog-python.md) |
| posthog-node | Capture | Backward-compatible | **New this run** — `$release_id` is resolved and trimmed correctly but applied only on the exception paths, so ordinary captures, `alias`, `groupIdentify` and `identify` carry none — [posthog-node.md#n5](posthog-node.md) |
| posthog-node | Exception Event Metadata / Capture Exception | Mixed (see notes) | **Both upgraded from ❌** — `@posthog/core` now emits `exception_id`/`parent_id` linkage with no inherited `handled`, and the uncaught listeners pass real metadata; three gaps remain (no `$exception_source`, hardcoded `$exception_level: 'error'`, caller bag overrides reserved keys), all in shared code that posthog-js and posthog-react-native inherit — [posthog-node.md#n20](posthog-node.md) |
| posthog-node | Is Feature Enabled | Backward-compatible | **Upgraded from ❌** — `FeatureFlagEvaluations.isEnabled(key, { defaultValue })` now satisfies the hard caller-default `SHALL`; only the legacy getter lacks it — [posthog-node.md#n13](posthog-node.md) |
| posthog-node | Evaluate Flags | Backward-compatible | **Downgraded from ✅ on new spec text** — no negative-knowledge retention, the sixth server SDK in a row to lack it — [posthog-node.md#n10](posthog-node.md) |
| posthog-node | MCP Analytics | Backward-compatible | **New this run** — `@posthog/mcp` emits neither optional event and misreports an unknown tool as a failed `$mcp_tool_call`; see the ownership question above about whether this row belongs to node or js — [posthog-node.md#n26](posthog-node.md) |
| posthog-node | Local Feature Flag Evaluator | Backward-compatible | Holdouts **are** implemented in `@posthog/core`, and the acceptance-asset sync gap is unchanged; new this run, a non-scalar group key buckets on `"true"` / `"[object Object]"` instead of going inconclusive — [posthog-node.md#n24](posthog-node.md) |
| posthog-ios | Exception Event Metadata | Backward-compatible | Chain linkage, 50-entry cap, `$exception_source`, empty `value` and UUID-less image filtering land in PostHog/posthog-ios#931; caller properties can still override `$exception_level`/`$exception_source` on purpose (no typed level parameter yet, and Android/JS behave the same) — [posthog-ios.md#n19](posthog-ios.md) |
| posthog-android | Consent Gating | Backward-compatible | `optOut()` never stops an active replay session, and session-replay start/stop never check `isOptedOut()`, despite session replay being named in this spec's own scope — [posthog-android.md#n5](posthog-android.md#n5) |
| posthog-android | Session Replay Debug Properties | Backward-compatible | **New this run** — the most complete implementation outside the browser, but no required/optional tiering and no 30s throttle (the whole bundle rides every event), and a crash-time `$exception` from a previous launch is stamped with an **empty** map where the spec requires a persisted crash-context snapshot — [posthog-android.md#n17](posthog-android.md#n17) |
| posthog-android | Exception Event Metadata | Needs deprecation path | **New this run** — linkage, 50-cap and cycle detection are all correct, but `synthetic` is a hardcoded `false` (the spec's explicit "MUST NOT represent unknown with false"), causes inherit `handled`, no `mechanism.source`/`$exception_source`, and `$exception_level` is a *documented* caller override — [posthog-android.md#n7](posthog-android.md#n7) |
| posthog-android | Session Replay Privacy | Needs deprecation path | `ph-no-capture` ignored outside screenshot mode; default capture mode can leak tagged views — [posthog-android.md#n19](posthog-android.md#n19) |
| posthog-android | Surveys | Needs deprecation path | Web-only `url`/`selector`-targeted surveys aren't excluded on Android as the spec requires — [posthog-android.md#n22](posthog-android.md#n22) |
| posthog-android | Autocapture | Backward-compatible (except the default) | **Upgraded from ❌** — `$autocapture` for View and Compose taps now exists, with `$rageclick` and a no-capture tag, but `captureElementInteractions` defaults to `false` — [posthog-android.md#n2](posthog-android.md#n2) |
| posthog-ios | Capture | Backward-compatible | **Downgraded from ✅ on new spec text** — `NSNull`-valued properties are serialized as JSON `null` instead of dropped; empty event names are not dropped — [posthog-ios.md#n4](posthog-ios.md) |
| posthog-ios | Session Replay Debug Properties | Backward-compatible | **New row** — tiers, 30 s window and crash-context snapshot conform; gaps on caller-supplied `$session_id`, backdated events, and `active` status after a background session timeout — [posthog-ios.md#n26](posthog-ios.md) |
| posthog-node | Flush / Retry Queue (v1 pipeline) | Needs deprecation path | `V1CaptureSender` never throws on exhausted retry, so failed batches are evicted from the queue as if delivered — [posthog-node.md#n8](posthog-node.md) |
| posthog-node | Feature Flag Called Tracker | Backward-compatible | Allowlist itself is fully compliant (inherited from posthog-js via shared `@posthog/core`), but capacity eviction is a full clear rather than incremental, violating the spec's anti-thundering-herd requirement — [posthog-node.md#n19](posthog-node.md) |
| posthog-flutter | Session Replay Privacy | Backward-compatible | Independent Dart replay pipeline still has no no-capture marker (a nested `PostHogUnmaskWidget` can reveal anything inside `PostHogMaskWidget`); the unmask primitive, shared sensitive-input detection, and fail-closed mask walk have all landed since the previous audit — [posthog-flutter.md#n29](posthog-flutter.md#n29) |
| posthog-flutter | Remote Config | Backward-compatible | **Resolved from ❓** — mobile delegates to the native SDK (✅ there), but the new Dart desktop core never fetches remote config at all, so Windows/Linux clients get no server-side replay or survey gating — [posthog-flutter.md#n26](posthog-flutter.md#n26) |
| posthog-flutter | HTTP Client | Backward-compatible | **Resolved from ❓** — the Dart core retries a refused `/flags` connection (every transport exception is wrapped into one retryable type), and `retriable` has no backoff multiplier — [posthog-flutter.md#n19](posthog-flutter.md#n19) |
| posthog-flutter | Session Replay Debug Properties | Backward-compatible | **New this run** — none of the three `$sdk_debug_replay_*` required keys exist on any platform, and `$recording_status` is emitted only on desktop, where replay does not run — [posthog-flutter.md#n28](posthog-flutter.md#n28) |
| posthog-flutter | Get Feature Flag Payload / Result | Backward-compatible | **Downgraded on new spec text** — the Dart core returns no payload for malformed JSON, but on iOS/macOS the value comes from posthog-ios, which returns the raw string; the fix is in posthog-ios — [posthog-flutter.md#n14](posthog-flutter.md#n14) |
| posthog-react-native | Bootstrap | Backward-compatible | Flag-merge spread order is inverted — previously-persisted flags win over a fresh bootstrap value, the opposite of the spec's required precedence — [posthog-react-native.md#n4](posthog-react-native.md) |
| posthog-react-native | Flush / Retry Queue | Backward-compatible | Shared-core catch handler evicts an exhausted-retry HTTP failure as if delivered instead of preserving it — same defect class as posthog-node, and precisely what posthog-flutter's new Dart core gets right — [posthog-react-native.md#n9](posthog-react-native.md#n9) |
| posthog-react-native | Session Replay Privacy | Backward-compatible | **Resolved from ❓** — RN's own layer is correct and privacy-safe-by-default; the residual non-compliance is posthog-ios n24's confirmed container-children defect inherited through the pass-through — [posthog-react-native.md#n26](posthog-react-native.md#n26) |
| posthog-react-native | Setup | Backward-compatible | **Downgraded on new spec text** — `PostHogProvider` still takes only `apiKey`; PR [#108](https://github.com/PostHog/sdk-specs/pull/108) names it explicitly and prescribes the non-breaking fix (add `projectToken`, deprecate `apiKey` in the same release) — [posthog-react-native.md#n27](posthog-react-native.md#n27) |
| posthog-react-native | Get Feature Flag Payload / Result / Flags And Payloads | Needs deprecation path | **Downgraded on new spec text** — shared `parsePayload` returns the raw malformed string instead of the no-payload sentinel, and logs nothing; one fix in `@posthog/core` clears all three rows and also posthog-js and posthog-node — [posthog-react-native.md#n10](posthog-react-native.md#n10) |
| posthog-php | Feature Flag Called Tracker | Backward-compatible | Minimal-event allowlist missing the same 10 session-attribution properties as python/android — [posthog-php.md#n6](posthog-php.md) |
| posthog-php | HTTP Client | Backward-compatible | `/flags` retry backoff starts at 100ms instead of the spec-mandated 300ms/600ms schedule — [posthog-php.md#n10](posthog-php.md) |
| posthog-php | Local Feature Flag Evaluator | Backward-compatible | Experiment holdouts entirely unimplemented — a flag with a holdout evaluates locally as if it had none, silently disagreeing with the backend — [posthog-php.md#n12](posthog-php.md) |
| posthog-php | Evaluate Flags | Backward-compatible | No negative-knowledge retention or probe coordination, so a requested-but-deleted key re-probes `/flags` on every call forever — [posthog-php.md#n3](posthog-php.md) |
| posthog-php | Get Feature Flag Payload | Backward-compatible | Malformed payloads correctly return `null` but are never logged, which the new requirement mandates — [posthog-php.md#n8](posthog-php.md) |
| posthog-php | Capture | Backward-compatible | Null-valued object properties are serialized as JSON `null` rather than dropped (new requirement); no opt-out mechanism exists at all — [posthog-php.md#n1](posthog-php.md) |
| posthog-ruby | Local Feature Flag Evaluator | Backward-compatible | Same holdout gap as php; the rest of the expanded matching spec (versioned matching, Unicode-vs-ASCII lowercase split, presence semantics) is correct — [posthog-ruby.md#n15](posthog-ruby.md) |
| posthog-ruby | Evaluate Flags | Backward-compatible | Same missing negative-knowledge retention as php, plus raw-string payloads inherited from `parse_payload` — [posthog-ruby.md#n5](posthog-ruby.md) |
| posthog-ruby | Get Feature Flag Result | Needs deprecation path | Result fields are correctly preserved, but the payload field carries the raw malformed string — [posthog-ruby.md#n11](posthog-ruby.md) |
| posthog-ruby | Capture | Backward-compatible | Null-valued object properties serialized as JSON `null`; sub-second precision truncated to 3 digits (UTC normalization itself is correct) — [posthog-ruby.md#n3](posthog-ruby.md) |
| posthog-ruby | Alias / Capture / Group Identify | Breaking | Raises `ArgumentError` on missing required fields (asserted by the SDK's own test suite) instead of the spec's silent-drop-with-warning — [posthog-ruby.md#n1](posthog-ruby.md) |
| posthog-ruby | Feature Flag Called Tracker | Backward-compatible | Same allowlist gap as python/android/php, plus a full-`clear` on capacity instead of incremental LRU eviction — [posthog-ruby.md#n7](posthog-ruby.md) |
| posthog-ruby | Retry Queue | Needs deprecation path | Failed batches dropped rather than requeued, with observable `on_error`/timing implications — [posthog-ruby.md#n18](posthog-ruby.md) |
| posthog-go | Flush / Retry Queue | Breaking (core issue) | Once a batch's local retry budget is exhausted, both wire pipelines permanently drop it rather than requeuing — [posthog-go.md#n9](posthog-go.md) |
| posthog-go | Feature Flag Called Tracker | Backward-compatible | Allowlist missing the same 10 session-attribution properties as python/android/ios/php/ruby; `Close()` also never purges the dedup LRU — [posthog-go.md#n7](posthog-go.md) |
| posthog-go | Flag Definition Loader | Backward-compatible | The cache-provider gap is closed (`FlagDefinitionCacheProvider`, `flag_definition_cache.go:15-31`, fail-safe in both directions); still 🟡 because a 401/403 from the definitions endpoint falls into the generic non-200 branch, with only 402 handled explicitly (`featureflags.go:777`) — [posthog-go.md#n8](posthog-go.md) |
| posthog-java | Before Send Hook | Backward-compatible | Chaining bug — passes the *original* event to every hook instead of the running mutated event, so a second hook never sees the first hook's changes — [posthog-java.md#n2](posthog-java.md) |
| posthog-java | Shutdown | Backward-compatible | `close()` never calls `queue.flush()`, only cancels the timer — sub-threshold events are silently lost — [posthog-java.md#n24](posthog-java.md) |
| posthog-java | Feature Flag Called Tracker | Backward-compatible | Same 10-property allowlist gap as posthog-ruby/-node/-php — [posthog-java.md#n8](posthog-java.md) |
| posthog-java | Local Feature Flag Evaluator | Mixed (see note) | Missing group context resolves to a hard `false` instead of falling back to remote evaluation (**Needs deprecation path**); **and**, newly confirmed this run, the `starts_with`/`not_starts_with`/`ends_with`/`not_ends_with` operator family added to the spec in `2036abd` is entirely unimplemented — every flag using them degrades safely to remote evaluation rather than returning a wrong answer (**Backward-compatible** to add) — [posthog-java.md#n18](posthog-java.md) |
| posthog-dotnet | Feature Flag Called Tracker | Backward-compatible | Same 10-property allowlist gap as every other server SDK audited; otherwise a well-built tracker (incremental eviction, group normalization) — [posthog-dotnet.md#n10](posthog-dotnet.md) |
| posthog-dotnet | Setup | Needs deprecation path | Re-`Init` silently swaps the default client's config today; adding a double-init guard changes behavior some callers may rely on — [posthog-dotnet.md#n25](posthog-dotnet.md) |
| posthog-dotnet | Identify | Breaking or Backward-compatible (implementation-dependent) | Missing/empty `distinctId` silently succeeds today; spec text calls for either a raise (breaking) or drop-with-log (backward-compatible) — [posthog-dotnet.md#n19](posthog-dotnet.md) |
| posthog-go | MCP Analytics | Backward-compatible | **New this run** — strong first implementation, but the `$exception` side-car omits `$exception_source: "mcp.tool_call"` and hardcodes `mechanism.synthetic: true` on a path only reached for a thrown error, inverting the spec's rule; no `client_metadata` intent source (the manual API rejects the value) — [posthog-go.md#n17](posthog-go.md) |
| posthog-go | Evaluate Flags | Backward-compatible | **New this run** — no negative-knowledge retention (a deleted key re-probes `/flags` forever) and no JSON validation on `GetFlagPayload` — [posthog-go.md#n5](posthog-go.md) |
| posthog-go | Local Feature Flag Evaluator | Backward-compatible | **Downgraded from ✅ this run on new spec text** — experiment holdouts entirely unimplemented (`grep holdout`: zero matches); every other new matching requirement is met — [posthog-go.md#n15](posthog-go.md) |
| posthog-dotnet | Evaluate Flags | Backward-compatible | **New this run** — good control flow, but no negative-knowledge retention, and an unguarded `JsonDocument.Parse` makes a malformed payload throw during flag construction, discarding the whole remote response — [posthog-dotnet.md#n7](posthog-dotnet.md) |
| posthog-dotnet | Capture AI | Backward-compatible | **New this run** — `PostHog.AI` ships real `$ai_*` support but routes it through ordinary `Capture(...)` to `batch`; no `CaptureAi` surface and no isolated AI route with the larger payload allowance — [posthog-dotnet.md#n4](posthog-dotnet.md) |
| posthog-dotnet | Local Feature Flag Evaluator | Backward-compatible | **Downgraded from ✅ this run on new spec text** — experiment holdouts entirely unimplemented; every other new matching requirement is met — [posthog-dotnet.md#n21](posthog-dotnet.md) |
| posthog-dotnet | Get Feature Flags And Payloads | Backward-compatible | **Downgraded from ✅ this run on new spec text** — one malformed payload throws out of bulk-result construction and discards every healthy flag value and sibling payload with it — [posthog-dotnet.md#n17](posthog-dotnet.md) |
| posthog-js | MCP Analytics | Backward-compatible | **New this run** — the richest implementation in the matrix, but an unknown tool is misreported as a failed `$mcp_tool_call` on both instrumentation paths (a rule the spec applies to every SDK), and neither `$mcp_unknown_tool` nor `$mcp_input_required` is emitted — [posthog-js.md#n37](posthog-js.md) |
| posthog-js | Exception Event Metadata | Backward-compatible | **New this run** — the most complete producer envelope audited (full `exception_id`/`parent_id` linkage, canonical sources, correct nested-`handled` omission, spec-exact caps), missing only `$exception_source` and a capture category on the two global handlers, which fall back to `generic` — [posthog-js.md#n35](posthog-js.md) |
| posthog-js | Session Replay Debug Properties | Backward-compatible | **New this run** — re-scored against `d078270` after #96; tiering, the `$`-prefix gate, and the 30 s throttle conform, but after `stopSessionRecording()` on a loaded recorder events keep `active`/`buffering` instead of `$recording_status: disabled` — [posthog-js.md#n36](posthog-js.md) |

Full contract-by-contract detail (33 posthog-js, 21 posthog-python, 23 posthog-android, 20
posthog-ios, 26 posthog-node, 34 posthog-flutter, 31 posthog-react-native, 19 posthog-php, 21
posthog-ruby, 23 posthog-go, 19 posthog-java, and 29 posthog-dotnet non-Pass/non-N/A cells) is in
the respective per-SDK files.

## Cross-cutting pattern worth flagging

> **Reading note.** Paragraphs in this section are appended by the run that discovered the pattern
> and are not rewritten afterwards, so an unqualified "this run" inside a paragraph means the run
> that wrote it. Paragraphs below this note that are not explicitly dated were written on or before
> 2026-10-12. The 2026-10-19 additions are at the end of the section.


The **Feature Flag Called Tracker** minimal-event allowlist gap (missing session-attribution
properties from the most recently merged fix prior to this run, sdk-specs commit `b59e8b4`) is
confirmed in **8 of the 12 audited SDKs**: posthog-python, posthog-android, posthog-ios,
posthog-php, posthog-ruby, posthog-go, posthog-java, and posthog-dotnet. It was already fixed in
posthog-js, posthog-node, and posthog-react-native (all three share `@posthog/core`, so it's the
same fix inherited three times, not three independent fixes). **Updated 2026-10-19:**
posthog-flutter's status is no longer ❓ — its new Dart core implements the tracker directly for
desktop (a value-keyed dedup map, cleared on reset) but has **no minimal-envelope allowlist
handling at all**, which follows from its other new finding that the Dart core never fetches remote
config and so never learns the gate. posthog-react-native's own row also remains 🟡 on a related
point: it inherits the correct shared allowlist code but never persists the server's
`minimalFlagCalledEvents` gate, so `isMinimalFlagCalledEventsEnabled()` fails safe to `false` and
the minimal envelope is never produced. The 2026-08-10 re-audits of posthog-android and posthog-java independently
re-confirmed the gap is still present in both, unaffected by the intervening code drift. The
2026-10-05 re-audits of posthog-go and posthog-dotnet did the same: `grep -niE
'referring_domain|utm_source|gclid|fbclid'` returns zero matches in either SDK's non-test source
after 75 and 64 commits of drift respectively, so the gap has now survived two consecutive audits in
both.

**Experiment holdouts: the four-for-four streak is broken — two of six server SDKs now implement them.**
The requirement (sdk-specs PR [#76](https://github.com/PostHog/sdk-specs/pull/76), merged 2026-09-28) says
a flag configured with a holdout must evaluate the holdout before its release conditions so the local
answer matches the backend. posthog-php, posthog-ruby, posthog-go and posthog-dotnet all returned **zero**
`grep -rni holdout` matches at their audits. This run found the opposite in both SDKs checked:
posthog-python hashes `holdout-<value>` with the service's `-` separator and resolves the holdout before
the condition loop (`feature_flags.py:124-156`, `:405-408`), and posthog-node does the same in shared
`@posthog/core` code (`featureFlagLocalEvaluation.ts:546-580`), with `filters.holdout` carried through the
definition type. Both implementations call out the separator explicitly in comments, which suggests they
were written against the service's behavior rather than independently guessed. **These two are the
reference implementations to point the other four at** — the remaining gap is php, ruby, go, dotnet, and
java (unchecked), and it stays the highest-value single fix in the matrix because it is a silent
correctness divergence: a held-out identity gets a local answer that disagrees with the backend, with no
error and no fallback. The client SDKs have no local evaluator and are unaffected.

**Negative-knowledge retention for missing flag keys is unimplemented in every server SDK checked —
now six for six.** The Evaluate Flags requirement obliges an SDK with a successful
local-definition refresh lifecycle to remember that a requested key was absent from both the loaded
definitions and a clean remote fallback, in a finite-capacity in-memory store cleared on each
successful refresh, and to coordinate concurrent probes for the same key. posthog-php, posthog-ruby,
posthog-go, posthog-dotnet and — added this run — posthog-python and posthog-node all have none of this
machinery (no missing-key store, no definitions generation counter, no in-flight probe map). The
user-visible effect is identical in all six: a
requested-but-deleted key re-probes `/flags` on every single `evaluateFlags` call for that scope,
forever, and N concurrent evaluations missing the same key make N requests. Six for six, including both
SDKs the spec names as its reference server implementations, is the signal here: either the requirement
is harder to implement than its authors judged, or it is not where SDK authors would spend the effort.
Unlike the holdout gap
this is a cost-and-latency problem rather than a correctness one, and it is the harder of the two to
implement correctly (the spec's generation-and-probe rules are intricate), so it is worth deciding
deliberately whether to implement it uniformly or to narrow the requirement upstream.

A second cross-cutting pattern: **Is Feature Enabled**'s caller-supplied default-value parameter
(a hard spec `SHALL`, no server carve-out) is missing from the *legacy* getter in posthog-python,
posthog-node, posthog-php, posthog-ruby, posthog-go, and posthog-dotnet. **Two of those six now satisfy
it through the successor API instead**: python's `evaluate_flags(...).is_enabled(default_value=...)` and,
new this run, node's `FeatureFlagEvaluations.isEnabled(key, { defaultValue })`. The other four satisfy it
nowhere. **posthog-java** (`posthog-server`'s `com.posthog.server` package), which
correctly implements a caller-supplied default on its canonical evaluation path — worth using as the
reference implementation when fixing the other 6. Reconfirmed in posthog-go and posthog-dotnet this
run: Go's `FeatureFlagPayload` struct still has no `DefaultValue` field and
`FeatureFlagEvaluations.IsEnabled(key string) bool` still hardcodes `return false` for an unknown
flag; .NET is unchanged in the same way. The python/node successor-API shape is the migration the
remaining four should follow rather than retrofitting the legacy getters.

A third pattern: **Set/Reset Person/Group Properties For Flags** (all four contracts) have zero
persistent-override-store implementation in every server-style SDK audited — posthog-python,
posthog-node, posthog-php, posthog-ruby, posthog-go, posthog-java, and posthog-dotnet (7 of 7) —
despite `@both`-tagged, mechanically server-satisfiable acceptance scenarios in all four specs.
This is the most consistent gap in the entire matrix and the specs' own `Applicability: client`
prose vs. the acceptance files' `@both` tags should be reconciled upstream regardless of which way
remediation goes.

**Shutdown never flushes before stopping queues** recurred across posthog-android, posthog-ios,
posthog-flutter, and posthog-java's `posthog-server` (`close()` cancels the flush timer but never
calls `queue.flush()`) — all Backward-compatible fixes, all the same defect shape. The run that
wrote this paragraph reconfirmed the posthog-android and posthog-java instances. **Updated
2026-10-19:** the pattern is now down to one ❌. posthog-android's Shutdown is ✅ (`PostHog.close()`
calls `flush()` first, `PostHog.kt:536-545`), and posthog-ios's is ✅ with
PostHog/posthog-ios#924. posthog-flutter moved ❌→🟡: both native SDKs now flush and the desktop
path makes a bounded send attempt, so only Flutter Web's no-op `close` remains
([posthog-flutter.md#n32](posthog-flutter.md#n32)). posthog-java's `posthog-server` is the one
instance still failing, pending its next audit.
posthog-js's Shutdown gap is a related-but-distinct failure mode (the shutdown flag never gates
subsequent captures, rather than the queue never draining) — tracked separately under its own
note, not folded into this pattern.

**Local Feature Flag Evaluator string-operator gap (prior run).** The spec change that selected
posthog-java for the 2026-08-10 run's audit (`starts_with`/`ends_with` support, sdk-specs
`2036abd`) named six SDKs as already shipping the feature (posthog-js/node core, posthog-python,
posthog-php, posthog-ruby, posthog-go, posthog-dotnet) and flagged posthog-android, posthog-ios,
posthog-java, and posthog-flutter as unchecked. That run confirmed the operators are **N/A** for
posthog-android/posthog-ios/posthog-flutter (none have a local evaluator to extend) but are
**missing** in posthog-java's `posthog-server` despite it being the one SDK in that follow-up
list with a genuine local evaluator. Degrades safely to remote evaluation, so no incorrect answers
are being returned today.

**Exception Event Metadata is the fastest-moving contract in the matrix, and the SDKs are converging on
the same two residual gaps.** When this contract was first checked (posthog-python, posthog-node,
posthog-ios) all three hardcoded `mechanism.handled` or `$exception_level`, omitted the
`exception_id`/`parent_id` linkage, or let caller properties override SDK-owned keys — three ❌ in a row.
Two months later both SDKs re-audited this run have rebuilt their envelopes and moved ❌→🟡:
posthog-python now has full linkage, a 50-entry cap with cycle detection, nested entries that correctly
omit `handled`, and real `handled: False` from the uncaught hooks; posthog-node's shared `@posthog/core`
builder does the same with `type: 'chained'` nested entries. **What is left is the same two items in
both, plus a third in node:** `$exception_source` is never set from the capture boundary even though the
boundary is known at the call site, and an application property bag can still overwrite SDK-owned
`$exception_list`/`$exception_level`/`$exception_source` — the one thing the spec states as a flat MUST
NOT. posthog-python is ahead here: it already ships a `DeprecationWarning` naming the exact reserved keys
and the release that will stop honoring them, which is the pattern the others should copy rather than
breaking callers silently. node additionally hardcodes `$exception_level: 'error'` on a boundary that
terminates the process, where the spec says `fatal`. Because node's builder is shared, one fix in
`@posthog/core` closes the matching posthog-js and posthog-react-native gaps too. See
[posthog-python.md#n14](posthog-python.md), [posthog-node.md#n20](posthog-node.md), and
[posthog-ios.md#n19](posthog-ios.md).

**A requirement was withdrawn this run, and one SDK was right all along.** sdk-specs PR
[#103](https://github.com/PostHog/sdk-specs/pull/103) made `$exception_list[0].type`/`.value` the
canonical exception type and message and declared the flat top-level `$exception_type`/`$exception_message`
properties "not required for standard capture paths", deleting their assertions from the acceptance
scenario. posthog-python's only Capture Exception finding was that it had deliberately removed those
properties in 7.3.1 and never re-added them — so that row is now ✅ with no code change, and the audit's
previous remediation advice ("re-add them") would have been wrong to follow. **Other files still carry
this withdrawn finding and should drop it at their next audit:** posthog-android's n2 ("no top-level
`$exception_type`/`$exception_message`, only nested `$exception_list`") was listed as an ❌ Fail on
exactly this basis, and any other row whose evidence rests on the flat pair needs re-reading against
the current spec text. **Updated 2026-10-19:** posthog-android's Capture Exception row is now ✅ on
this withdrawal. It is a useful reminder that a matrix cell can go stale
because the contract moved, not because the SDK did.

**New this run — Local Feature Flag Evaluator's unrecognized-operator requirement is
correctly implemented in code but not yet test-covered.** posthog-node's evaluator correctly
returns an inconclusive/per-flag-scoped result for any operator it doesn't recognize (verified in
`packages/core`), but the acceptance `.feature` file for this capability hasn't been updated with
the new scenarios from the spec yet — a test-asset sync gap worth fixing in `sdk-specs` itself,
not an SDK defect. See [posthog-node.md#n24](posthog-node.md).

**2026-10-19 — the exception property-bag override is the matrix's most widely-shared
non-compliance.** `exception-event-metadata` line 300 is explicit: an application property bag MUST
NOT override SDK-owned `$exception_list`, `$exception_level`, `$exception_source`, or
`$debug_images`; only documented *typed* overrides participate in precedence. **Six of twelve SDKs
violate it**, and this run added three of them:

| SDK | How it violates the clause |
|---|---|
| posthog-react-native | `{ ...buildExceptionProperties(error, hint), ...finalAdditional }` — caller spread last |
| posthog-flutter | `{ '$exception_level': …, '$exception_list': …, if (properties != null) ...properties }` — caller spread last |
| posthog-android | `PostHogStateless.kt:701` **documents** it: "callers can override reserved keys such as `$exception_level`" |
| posthog-node, posthog-js | same shared `@posthog/core` path as react-native |
| posthog-ruby | caller properties override SDK-owned `$exception_list` |

All six carry a **"Needs deprecation path"** verdict for the same reason: callers may rely on the
current behaviour today, and the spec's own remedy is to ship a typed override channel (level,
source, mechanism, debug images) *first*, then stop honouring the generic key. That sequencing is a
cross-SDK decision, not six independent ones, and it is the single highest-leverage item a
maintainer could pick up from this matrix.

**2026-10-19 — the retry-queue split is now three-against-one in the right direction.** The "evict a
retryable-but-exhausted failure as if delivered" defect is confirmed in posthog-js, posthog-node,
and posthog-react-native (one shared `@posthog/core` catch handler, so one fix) and in
posthog-python/posthog-flutter's older notes. posthog-flutter's **new Dart core gets it right** —
`_doFlush` removes the batch only when the error is not transient — and posthog-android and
posthog-go already did. The correct implementation now exists in three separate codebases to copy
from, so the `@posthog/core` fix has a worked reference rather than needing a design.

**2026-10-19 — Session Replay Debug Properties is the newest contract and already splits three
ways.** Of the four client SDKs that own replay: posthog-js is the reference; **posthog-android has
all four required keys** plus a real tri-state `$recording_status`, a correct `$snapshot` exclusion
and a `disabled` fallback, deviating only on tiering/throttling and the crash-context snapshot;
**posthog-flutter has none of the three `$sdk_debug_replay_*` keys** and emits `$recording_status`
only on the one platform where replay does not run; and **posthog-react-native has nothing at all**
despite owning a real replay integration and already computing most of the state. Since both
flutter and react-native embed native SDKs for replay, the cheapest path for both is to surface what
android already computes across the bridge rather than reimplement it.

## Unknown (❓) cells needing human review

**One cell, and it is a correction rather than a gap.**

**posthog-node — Traces** — [posthog-node.md#n2](posthog-node.md#n2). The 2026-10-12 audit scored
this ❌ on "no OTLP `/i/v1/traces` pipeline anywhere in the monorepo". While auditing
posthog-react-native in the same monorepo this run, the pipeline turned up immediately:
`packages/core/src/traces/` (span, OTLP, `traceparent`, ids, config, context, sanitize, live-spans),
exported as `PostHogTraces`, with `_sendTracesBatch` on `PostHogCoreStateless` — and posthog-node is
the one package that wires it (`packages/node/src/client.ts:155`, `:698-703`). It merged in
[posthog-js#4579](https://github.com/PostHog/posthog-js/pull/4579) on **2026-09-10**, four weeks
before the audit that called it absent.

The row is corrected to ❓ rather than to a Pass on purpose: the implementation demonstrably exists,
so ❌ is indefensible, but it has not been read against the traces spec's configuration knobs,
defaults, W3C interop, payload bounds, or retry classification. Guessing ✅ or 🟡 would repeat the
error being corrected. **Action for a human: prioritize posthog-node at the next run to score this
row.** The posthog-python Traces audit (2026-10-12, the matrix's first ✅ on this contract) is the
reference for what a full evaluation covers.

**The seven Unknowns the previous run carried are all drained.** posthog-flutter's six resolved
because the premise behind them — "a thin Dart wrapper that cannot verify its own transport" — is no
longer true: the new Dart core implements Event Batcher, Feature Flag Called Tracker, HTTP Client,
Persistent Storage, and Retry Queue directly for the desktop platform, and Remote Config resolved by
reading the mobile path against `compliance/posthog-android.md`. Five became 🟡 and **Retry Queue
became ✅**. posthog-react-native's single Unknown (Session Replay Privacy) resolved to 🟡 once this
run had `posthog-android` cloned and could pair it with posthog-ios's existing confirmed finding.

**No Unknown cells in the other eleven SDKs.** Every one of the fifteen contracts audited from
scratch this run — five each on react-native, flutter, and android — resolved to a definite status
against directly-cited code, and no new Unknown was introduced by an audit.

## Pending initial audit

None — all 12 in-scope SDKs have at least one full audit on file.

## Queued for next run

This run used **all three slots** (posthog-react-native, posthog-flutter, posthog-android), the
first full run since the rotation began slipping. It clears the three oldest pointers in the matrix
and all seven ❓ Unknown cells the previous run carried; the one ❓ left is posthog-node's Traces
correction. **Six SDKs are queued.**

| SDK | Last-audited SHA | Last audited | Rows | New-contract rows needed |
|---|---|---|---|---|
| posthog-java | `8659a7b4` (posthog-android monorepo) | 2026-08-10 | 59 | Yes (+5) |
| posthog-php | `5451f4e0` | 2026-09-28 | 63 | Yes (+1) |
| posthog-ruby | `185060ab` | 2026-09-28 | 63 | Yes (+1) |
| posthog-go | `08549f42` | 2026-10-05 | 64 | No |
| posthog-dotnet | `ae4d019c` | 2026-10-05 | 64 | No |
| posthog-node | `4f590b36` (posthog-js monorepo) | 2026-10-12 | 64 | No — but carries the matrix's only ❓ |

Prioritized for the next run:

1. **posthog-java** — the clear #1 on every rule at once. It now holds the **stalest pointer in the
   matrix** (2026-08-10) and is the **only SDK still at 59 rows**, needing all five new contracts
   added from scratch. Its co-located sibling posthog-android moved from `8659a7b4` to `c5e788bd`
   this run, so the monorepo drift is already measured, and several of this run's android findings
   (the `close()`-flushes fix, the shipped `isRetryableFlagsError` widening, the `ThrowableCoercer`
   exception envelope) live in `posthog/src/main/java/com/posthog/` — **shared core that
   `posthog-server/` also uses**, so much of the evidence is already written and java's audit should
   be unusually cheap for the value. It is also the one server SDK whose local evaluator has never
   been checked against the holdout or negative-knowledge requirements, and the only SDK that
   already implements the caller-supplied `default_value` correctly, making it the reference for
   that fix.
2. **posthog-node** — not stale (2026-10-12), but it carries the matrix's only ❓, and that cell
   exists because an audit got a factual question wrong. Scoring
   `packages/core/src/traces/` against `openspec/specs/traces/spec.md` is a **bounded, well-defined
   task** — one capability, one directory, with posthog-python's 2026-10-12 Traces ✅ as a worked
   reference. Worth half a slot rather than a whole one. Note the posthog-js monorepo has moved
   from `4f590b36` to `3ddaa654` since node's audit (this run read the latter for react-native), so
   a full node re-audit would not be wasted either.
3. **posthog-php, posthog-ruby** — both fully re-audited 2026-09-28 and needing only the MCP
   Analytics row, which is ➖ N/A for both. Fold the one-row addition into whichever run has spare
   capacity rather than spending a slot. **Both would also benefit from this run's exception work:**
   posthog-php's Exception Event Metadata ❌ and posthog-ruby's mixed verdict are the same defect
   family now characterized in detail from three more angles (flutter ❌, android 🟡,
   react-native 🟡), so a re-score is cheaper than it was.
4. **posthog-go, posthog-dotnet** — audited 2026-10-05, at the edge of the ~4-week window by the
   next run. Both would be straight re-verifications with no new rows.

**Rotation health: recovered.** The target is every SDK re-verified roughly every 4 weeks. After
this run the pointer ages are java 10 weeks, php/ruby 3 weeks, go/dotnet 2 weeks, node 1 week, and
js/python/ios/android/flutter/react-native all within 2 weeks. **java is the only SDK outside the
window**, and the previous run's contingency plan — spend a slot on a shallow row-completion pass
over the four 59-row files — is no longer needed: three of those four were completed properly this
run, and java is the last one. A single normal slot clears the backlog entirely.

**One structural note for whoever picks up java.** This run re-sorted `posthog-android.md`
alphabetically and **reassigned its note numbers**. A reference to "posthog-android nX" in a
document written before 2026-10-19 points at the old numbering; the file's Notes section says so at
the top.
