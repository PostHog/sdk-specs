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
(PR [#87](https://github.com/PostHog/sdk-specs/pull/87)). After this run **six SDKs carry all 64 rows**:
posthog-js, posthog-go, posthog-dotnet, posthog-ios, and — new this run — posthog-python and posthog-node.
posthog-php and posthog-ruby sit at 63, needing only the MCP Analytics row (➖ N/A for both on the spec's
own applicability table). The four client/hybrid SDKs still at 59 rows (react-native, flutter, android,
java) need five rows each added at their next audit; see "Queued for next run".

**No SDK is pending its first audit.** Every run since the backlog drained has been a re-audit
run, and selection is driven by the four-rule priority order at the top of this file.

## This run (2026-10-12)

sdk-specs `main` advanced from `75c8f5d` (last run's baseline) to `513d94c`, **20 commits**, the largest
spec delta since the matrix began — but no new capability, so the contract count stays at **64**. The
changes that move rows: **caller-supplied properties take precedence** over super properties and SDK
context on client SDKs, with the server order described separately (PR
[#114](https://github.com/PostHog/sdk-specs/pull/114)); an **environment-sourced release identifier**
(`POSTHOG_RELEASE_ID` → `$release_id`) that a server SDK stamps on its shared event path, keeps out of
`$set`/`$group_set`, and **retains on a minimized `$feature_flag_called`** (PR
[#80](https://github.com/PostHog/sdk-specs/pull/80)); **`projectToken` as the canonical project-credential
option name**, which names React Native's `apiKey` prop and Unity's `ApiKey` as the two client SDKs that
still need it (PR [#108](https://github.com/PostHog/sdk-specs/pull/108)); **a refused connection is not a
transient transport condition** and a flags request SHALL NOT retry it (PR
[#110](https://github.com/PostHog/sdk-specs/pull/110)); **group keys are rendered for bucketing like the
flags service**, with any non-string/non-number key treated as unresolved context rather than rendered
with a host spelling (PR [#89](https://github.com/PostHog/sdk-specs/pull/89)); **the exception list is
canonical**, retiring the flat `$exception_type`/`$exception_message` requirement (PR
[#103](https://github.com/PostHog/sdk-specs/pull/103)); **ignored exception types** as an optional
drop-by-type option (PR [#95](https://github.com/PostHog/sdk-specs/pull/95)); and **observable remote
snapshot reads** on `evaluate-flags` (PR [#107](https://github.com/PostHog/sdk-specs/pull/107)).

Selection: **posthog-python** and **posthog-node**, the previous queue's joint #1, on priority rule 1 and
rule 2 together. Both are named by the specs this delta touches most (the release-id, evaluate-flags and
group-key requirements are all server-side), both are the `capture-ai` spec's two named reference
implementations, and both had drifted from their recorded 2026-08-17 pointers — posthog-python
`95c7f6e0`→`509c8525`, posthog-node `fbdb6c7b`→`4f590b36`. Both were also still short the two newest
contract rows, which this run adds.

**This run used two of its three slots, not three.** The two audits were unusually large — python shipped
a whole tracing subsystem and a ~40-module MCP package between audits, and both SDKs' exception envelopes
were rebuilt — and the run chose to finish those two properly rather than start a third shallowly, per
this matrix's "3 carefully beats 12 superficially" rule. **This is worth a human's attention:** at two
SDKs per run the 8-SDK backlog takes four weeks to clear *without* the ~4-week re-verification of the
SDKs audited since, so the rotation is now slipping. posthog-react-native — the stalest pointer in the
matrix (2026-08-06, `e1efa57`) and the one SDK the new `projectToken` requirement names by name — was the
intended third pick and moves to the top of the queue below.

- **posthog-python** (13 ✅ · 16 🟡 · 5 ❌ · 30 ➖ · 0 ❓ on 64 rows, from 14/12/7/29/0 on 62): the largest
  single-run improvement in this matrix so far, and most of it is real new code rather than re-scoring.
  **Traces ❌→✅** — python now ships a dependency-free OTLP span pipeline to `/i/v1/traces`
  (`posthog/tracing/`, zero `opentelemetry` imports) with W3C `traceparent`/`tracestate` interop, the
  spec's configuration knobs at the spec's defaults, gzip, a local 10 MiB bound, and retry
  classification that matches the spec line for line. It is the first ✅ on Traces anywhere in this
  matrix. **Exception Event Metadata ❌→🟡** — `exception_id`/`parent_id` linkage on the ordinary
  chained path, `handled` omitted on nested entries, a 50-entry cap with cycle detection, real
  `handled: False` from the uncaught hooks, `$exception_level` normalization and a typed
  `$exception_source` channel; the one remaining gap, caller property bags overriding SDK-owned keys,
  already ships a `DeprecationWarning` naming the next major. **Capture Exception 🟡→✅ on new spec
  text** — the flat-property gap that was its only finding is exactly what PR
  [#103](https://github.com/PostHog/sdk-specs/pull/103) withdrew, so the SDK's deliberate 7.3.1 removal
  turned out to be right. **Holdouts are implemented** (`feature_flags.py:124-156`), breaking the
  four-for-four pattern below. Three rows move the other way, all on new spec text: **HTTP Client ✅→🟡**
  (a blanket `except requests.exceptions.ConnectionError` retries a refused flags connection), **Local
  Feature Flag Evaluator ✅→🟡** (a boolean group key buckets on Python's `"True"` spelling instead of
  going inconclusive), and **Evaluate Flags ✅→🟡** (no negative-knowledge retention). **MCP Analytics 🟡
  on first audit** — `posthog/mcp` is a ~40-module implementation with the required properties, the exact
  102,400-byte bound and the 30-minute session window, missing only the two SHOULD-tier optional events
  and the `$exception` side-car's `$exception_source`/`synthetic`. One narrow new gap: `$release_id` is
  stamped correctly everywhere **except** the minimized `$feature_flag_called` allowlist, which strips it
  — a one-line fix to a frozenset the spec itself now cites as the reference allowlist.
- **posthog-node** (9 ✅ · 21 🟡 · 5 ❌ · 29 ➖ · 0 ❓ on 64 rows, from 10/16/8/28/0 on 62): three rows move
  ❌→🟡 and one ✅→🟡. **Exception Event Metadata ❌→🟡** and **Capture Exception ❌→🟡** are the same
  rebuild seen from two angles: `@posthog/core`'s builder now emits `exception_id`/`parent_id` linkage
  with `type: 'chained'` on nested entries and, correctly, no inherited `handled`, and the uncaught and
  unhandled-rejection listeners pass real `{ type, handled: false }` metadata. What is left is three
  gaps shared with posthog-js through the same shared package — no `$exception_source` anywhere, a
  hardcoded `$exception_level: 'error'` even on the terminating boundary, and a caller property bag that
  still overrides SDK-owned keys — so one fix in `@posthog/core` closes them in posthog-js and
  posthog-react-native too. **Is Feature Enabled ❌→🟡** — `FeatureFlagEvaluations.isEnabled(key, {
  defaultValue })` now satisfies the hard caller-default `SHALL`; only the legacy getter lacks it, the
  same shape as python's upgrade last cycle. **Evaluate Flags ✅→🟡** on the missing negative knowledge.
  **Holdouts are implemented** in `@posthog/core`, and the refused-connection rule was *already* correct
  (`posthog-core-stateless.ts:221` excludes `ECONNREFUSED` from the retryable set) — node is the only SDK
  so far that passed a new requirement on the day it merged. Two gaps are node-specific: `$release_id` is
  resolved correctly but applied **only on the exception paths**, so ordinary captures, `alias`,
  `groupIdentify` and `identify` carry none; and a non-scalar group key buckets on `"true"` /
  `"[object Object]"` instead of going inconclusive.
- **An ownership question for a human.** MCP Analytics' applicability table lists `@posthog/mcp` under
  **posthog-js**, but `packages/mcp/package.json` declares `posthog-node` as its workspace and peer
  dependency — the host SDK whose `capture` carries the `$mcp_*` events is posthog-node. The row is now
  scored on both files, cross-referenced, so no evidence is lost, but exactly one of them should own it.
  The spec's table or the row needs a maintainer decision.

## Roll-up

| SDK | Overall | ✅ | 🟡 | ❌ | ➖ | ❓ | Last audited | Open gaps | File |
|---|---|---|---|---|---|---|---|---|---|
| posthog-js | 26/64 fully compliant (41%) | 26 | 21 | 12 | 5 | 0 | 2026-10-05 · `6538babc` (targeted re-audit; most of the 59 pre-existing rows carried from 2026-08-10, see file header) | 33 | [posthog-js.md](posthog-js.md) |
| posthog-python | 13/64 fully compliant (20%; 30 contracts N/A on a server SDK) | 13 | 16 | 5 | 30 | 0 | 2026-10-12 · `509c8525` | 21 | [posthog-python.md](posthog-python.md) |
| posthog-android | 31/59 fully compliant (53%; **59 rows, needs +5 new contracts**) | 31 | 16 | 9 | 3 | 0 | 2026-08-10 · `8659a7b4` | 25 | [posthog-android.md](posthog-android.md) |
| posthog-ios | 38/64 fully compliant (59%) | 38 | 16 | 4 | 6 | 0 | 2026-10-08 · `f5cbe87c` + PostHog/posthog-ios#924–#934 (out-of-cycle refresh, see below) | 20 | [posthog-ios.md](posthog-ios.md) |
| posthog-node | 9/64 fully compliant (14%; 29 contracts N/A on a server SDK) | 9 | 21 | 5 | 29 | 0 | 2026-10-12 · `4f590b36` (posthog-js monorepo) | 26 | [posthog-node.md](posthog-node.md) |
| posthog-flutter | 20/59 fully compliant (34%; **59 rows, needs +5 new contracts**) | 20 | 22 | 6 | 5 | 6 | 2026-08-06 · `05b53dc` | 34 | [posthog-flutter.md](posthog-flutter.md) |
| posthog-react-native | 31/59 fully compliant (53%; **59 rows, needs +5 new contracts**) | 31 | 23 | 2 | 2 | 1 | 2026-08-06 · `e1efa57` (posthog-js monorepo — now very stale, see below) | 26 | [posthog-react-native.md](posthog-react-native.md) |
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

**Row-count note:** four SDKs now carry the full 64-row matrix — posthog-js, posthog-go, and
posthog-dotnet, re-audited this run, plus posthog-ios after its 2026-10-08 out-of-cycle refresh.
posthog-php and posthog-ruby sit at 63 and need only the new MCP Analytics row (➖ N/A for both,
since the spec's own applicability table lists Ruby as "not yet" and does not mention PHP).
posthog-python and posthog-node sit at 62 and need two rows each. The remaining four —
posthog-android, posthog-flutter, posthog-react-native, and posthog-java — are still at 59 and need
all five of Capture AI, Evaluate Flags, Exception Event Metadata, Session Replay Debug Properties,
and MCP Analytics added from scratch at their next audit, not just a refresh of existing rows.

**Three movements worth noting in the raw numbers.** posthog-js's ✅ count is unchanged at 26 while
its row count grew by five, so its headline percentage *fell* (44%→41%) without a single row being
downgraded — the three new client-applicable contracts all scored 🟡. posthog-go lost two ✅ rows
purely to new spec text while *gaining* two improvements that were already 🟡, so its ✅ count moved
8←10 despite genuine progress in the repository. posthog-dotnet's ✅ count fell to 5 for the same
reason, and its 19 🟡 is now the largest Partial count of any server SDK; a single shared
payload-parse fix would move four of those rows at once. Percentages that move because the
denominator grew are not regressions, and the per-SDK files mark which direction each row moved and
why.

"Overall" for posthog-python, posthog-node, posthog-php, posthog-ruby, posthog-go, posthog-java,
and posthog-dotnet is computed against the contracts actually applicable to a server SDK
(posthog-python: 14 Pass / 33 applicable = 42%; posthog-node: 10 Pass / 34 applicable = 29%;
posthog-php: 11 Pass / 30 applicable = 37%; posthog-ruby: 9 Pass / 30 applicable = 30%;
posthog-go: 8 Pass / 31 applicable = 26%; posthog-java: 12 Pass / 31 applicable = 39%;
posthog-dotnet: 5 Pass / 34 applicable = 15%); shown above as raw Pass/(59, 62, 63 or 64) for
comparability with client SDKs, which see N/A far less often. posthog-js's 26/64 is likewise 26 Pass
/ 59 applicable = 44%, since Capture AI and Evaluate Flags are ➖ on a browser SDK. **posthog-node
note:** the standalone `PostHog/posthog-node` repo has been archived/redirected — its code now lives
at `packages/node` + `packages/core` inside the `posthog-js` monorepo, so its audited commit is a
`posthog-js` SHA. **posthog-react-native note:** likewise archived and folded into the same
`posthog-js` monorepo at `packages/react-native` + `packages/react-native-plugin`, so it too is
audited at a `posthog-js` SHA (`e1efa57`) — which this run's posthog-js re-audit (`6538babc`,
+676 commits) leaves further behind than ever, making RN the most stale pointer in the matrix.
Unlike posthog-node it extends the full client-side `PostHogCore` base, so it is scored like a
client SDK (raw Pass/59), not given the server-SDK applicable-only treatment. **posthog-java note:**
the standalone `PostHog/posthog-java` repo is also archived; its README redirects to a new home at
`PostHog/posthog-android`'s `posthog-server/` subdirectory (package `com.posthog.server`,
Kotlin/JVM), which is what that audit evaluated — its audited commit (`8659a7b4`) is a
`posthog-android` SHA, the same commit posthog-android's own client-SDK audit used.

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
| posthog-android | Alias | Backward-compatible | No `distinct_id` alongside `alias` in the `$create_alias` payload — [posthog-android.md#n1](posthog-android.md) |
| posthog-android | Capture Exception | ~~Backward-compatible~~ **likely withdrawn** | The finding is "no top-level `$exception_type`/`$exception_message`, only nested `$exception_list`" — exactly the requirement sdk-specs PR [#103](https://github.com/PostHog/sdk-specs/pull/103) retired. Not re-scored here because android was not audited this run; to be confirmed and most likely cleared at its next audit — [posthog-android.md#n2](posthog-android.md) |
| posthog-android | Get Feature Flags | Backward-compatible | No public flat bulk getter; internal cache-only version exists but isn't exposed — [posthog-android.md#n4](posthog-android.md) |
| posthog-android | Get Feature Flags And Payloads | Backward-compatible | No combined getter; returns `null` (not empty maps) on cold cache — [posthog-android.md#n5](posthog-android.md) |
| posthog-android | Screen | Needs deprecation path | Caller-supplied `$screen_name` silently overrides the explicit `screenTitle` argument — the SDK's own doc comment documents the wrong precedence — [posthog-android.md#n11](posthog-android.md) |
| posthog-android | Shutdown | Backward-compatible | `close()` never flushes; queued events stranded on disk — [posthog-android.md#n12](posthog-android.md) |
| posthog-android | Start Session Recording | Backward-compatible | `startSessionReplay()` has no `isOptedOut()` guard — [posthog-android.md#n13](posthog-android.md) |
| posthog-android | Autocapture | Backward-compatible | No generic UI-interaction autocapture (`$autocapture`) at all — [posthog-android.md#n16](posthog-android.md) |
| posthog-android | Traces | Backward-compatible | No OTLP traces/spans implementation — [posthog-android.md#n28](posthog-android.md) |
| posthog-ios | Get Feature Flags | Backward-compatible | No public flat key→value bulk flag getter — [posthog-ios.md#n9](posthog-ios.md) |
| posthog-ios | Get Feature Flags And Payloads | Backward-compatible | No combined flags+payloads getter under any name — [posthog-ios.md#n10](posthog-ios.md) |
| posthog-ios | Session Replay Privacy | Needs deprecation path | Default wireframe mode still records the children of a plain `ph-no-capture` container unmasked — [posthog-ios.md#n24](posthog-ios.md) |
| posthog-ios | Traces | Backward-compatible | No OTLP span/traces implementation anywhere — [posthog-ios.md#n2](posthog-ios.md) |
| posthog-node | Traces | Backward-compatible | No OTLP `/i/v1/traces` pipeline anywhere in the monorepo (industry-wide gap, matches posthog-python/-js) — [posthog-node.md#n2](posthog-node.md) |
| posthog-node | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | Zero implementation; methods exist only on the client-only base class node doesn't extend — [posthog-node.md#n15](posthog-node.md) |
| posthog-flutter | Get Anonymous ID | Backward-compatible | Method doesn't exist in the Dart API at all (standing `// TODO`) — [posthog-flutter.md#n14](posthog-flutter.md) |
| posthog-flutter | Get Feature Flags | Backward-compatible | No bulk flag getter anywhere in Dart — [posthog-flutter.md#n16](posthog-flutter.md) |
| posthog-flutter | Get Feature Flags And Payloads | Backward-compatible | No combined flags+payloads getter anywhere in Dart — [posthog-flutter.md#n17](posthog-flutter.md) |
| posthog-flutter | Shutdown | Backward-compatible | `close()` never flushes; complete no-op on Web — [posthog-flutter.md#n34](posthog-flutter.md) |
| posthog-flutter | Traces | Backward-compatible | No implementation; net-new, pre-GA — [posthog-flutter.md#n38](posthog-flutter.md) |
| posthog-flutter | Tracing Headers | Backward-compatible | No implementation; Flutter has no Dart-side HTTP client of its own to intercept app traffic with — [posthog-flutter.md#n39](posthog-flutter.md) |
| posthog-react-native | Is Opt Out | Backward-compatible | No callable `isOptOut()`; only an internal `optedOut` getter property, unlike every other audited client SDK — [posthog-react-native.md#n15](posthog-react-native.md) |
| posthog-react-native | Traces | Backward-compatible | No OTLP span/traces implementation anywhere in the monorepo — [posthog-react-native.md#n28](posthog-react-native.md) |
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
| posthog-android | Consent Gating | Backward-compatible | Downgraded from ✅ this run — `optOut()` never stops an active replay session, and session-replay start/stop never check `isOptedOut()`, despite session replay being named in this spec's own scope — [posthog-android.md#n18](posthog-android.md) |
| posthog-android | HTTP Client | Backward-compatible | Downgraded from ✅ this run — the feature-flags retry classifier misses `UnknownHostException`/`SSLException`/`ConnectException` (DNS/TLS/connection-refused); core batch transport remains solid — [posthog-android.md#n22](posthog-android.md) |
| posthog-android | Feature Flag Called Tracker | Backward-compatible | Same allowlist gap as posthog-python, already fixed in posthog-js/-node per the audit notes — [posthog-android.md#n20](posthog-android.md) |
| posthog-android | Session Replay Privacy | Needs deprecation path | `ph-no-capture` ignored outside screenshot mode; default capture mode can leak tagged views — [posthog-android.md#n26](posthog-android.md) |
| posthog-android | Surveys | Needs deprecation path | Web-only `url`/`selector`-targeted surveys aren't excluded on Android as the spec requires — [posthog-android.md#n27](posthog-android.md) |
| posthog-ios | Capture | Backward-compatible | **Downgraded from ✅ on new spec text** — `NSNull`-valued properties are serialized as JSON `null` instead of dropped; empty event names are not dropped — [posthog-ios.md#n4](posthog-ios.md) |
| posthog-ios | Session Replay Debug Properties | Backward-compatible | **New row** — tiers, 30 s window and crash-context snapshot conform; gaps on caller-supplied `$session_id`, backdated events, and `active` status after a background session timeout — [posthog-ios.md#n26](posthog-ios.md) |
| posthog-node | Flush / Retry Queue (v1 pipeline) | Needs deprecation path | `V1CaptureSender` never throws on exhausted retry, so failed batches are evicted from the queue as if delivered — [posthog-node.md#n8](posthog-node.md) |
| posthog-node | Feature Flag Called Tracker | Backward-compatible | Allowlist itself is fully compliant (inherited from posthog-js via shared `@posthog/core`), but capacity eviction is a full clear rather than incremental, violating the spec's anti-thundering-herd requirement — [posthog-node.md#n19](posthog-node.md) |
| posthog-flutter | Session Replay Privacy | Backward-compatible (mostly) | Independent Dart replay pipeline has no no-capture marker, no general unmask primitive, inconsistent password-field masking — [posthog-flutter.md#n31](posthog-flutter.md) |
| posthog-react-native | Bootstrap | Backward-compatible | Flag-merge spread order is inverted — previously-persisted flags win over a fresh bootstrap value, the opposite of the spec's required precedence — [posthog-react-native.md#n4](posthog-react-native.md) |
| posthog-react-native | Flush / Retry Queue | Backward-compatible | Shared-core catch handler evicts an exhausted-retry HTTP failure as if delivered instead of preserving it — same defect class as posthog-node — [posthog-react-native.md#n10](posthog-react-native.md) |
| posthog-react-native | Session Replay Privacy | ❓ Unknown | RN's own bridge does no masking itself; the underlying native SDKs it wraps have confirmed masking bugs (see posthog-ios#n24) that likely propagate but can't be independently re-verified — [posthog-react-native.md#n24](posthog-react-native.md) |
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

Full contract-by-contract detail (33 posthog-js, 19 posthog-python, 25 posthog-android, 20
posthog-ios, 24 posthog-node, 34 posthog-flutter, 26 posthog-react-native, 20 posthog-php, 22
posthog-ruby, 23 posthog-go, 19 posthog-java, and 29 posthog-dotnet non-Pass/non-N/A cells) is in
the respective per-SDK files.

## Cross-cutting pattern worth flagging

The **Feature Flag Called Tracker** minimal-event allowlist gap (missing session-attribution
properties from the most recently merged fix prior to this run, sdk-specs commit `b59e8b4`) is
confirmed in **8 of the 12 audited SDKs**: posthog-python, posthog-android, posthog-ios,
posthog-php, posthog-ruby, posthog-go, posthog-java, and posthog-dotnet. It was already fixed in
posthog-js, posthog-node, and posthog-react-native (all three share `@posthog/core`, so it's the
same fix inherited three times, not three independent fixes). posthog-flutter's own Dart code has
zero allowlist logic (100% delegated to embedded native SDKs), so its status stays ❓ Unknown
rather than assumed. This run's re-audits of posthog-android and posthog-java independently
re-confirmed the gap is still present in both, unaffected by the intervening code drift. This run's
re-audits of posthog-go and posthog-dotnet did the same: `grep -niE
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

**Shutdown never flushes before stopping queues** recurs across posthog-android, posthog-ios,
posthog-flutter, and posthog-java's `posthog-server` (`close()` cancels the flush timer but never
calls `queue.flush()`) — all Backward-compatible fixes, all the same defect shape. This run
reconfirmed the posthog-android and posthog-java instances of this pattern are unchanged.
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
`$exception_type`/`$exception_message`, only nested `$exception_list`") is listed as an ❌ Fail in the
table above on exactly this basis, and any other row whose evidence rests on the flat pair needs
re-reading against the current spec text. It is a useful reminder that a matrix cell can go stale
because the contract moved, not because the SDK did.

**New this run — Local Feature Flag Evaluator's unrecognized-operator requirement is
correctly implemented in code but not yet test-covered.** posthog-node's evaluator correctly
returns an inconclusive/per-flag-scoped result for any operator it doesn't recognize (verified in
`packages/core`), but the acceptance `.feature` file for this capability hasn't been updated with
the new scenarios from the spec yet — a test-asset sync gap worth fixing in `sdk-specs` itself,
not an SDK defect. See [posthog-node.md#n24](posthog-node.md).

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

No Unknown cells in posthog-js, posthog-android, posthog-python, posthog-ios, posthog-node,
posthog-php, posthog-ruby, posthog-go, posthog-java, or posthog-dotnet — all ten resolved every one
of their tracked contracts (64 for js/go/dotnet after this run, 63 for php/ruby, 62 for
python/ios/node, 59 for the rest pending their next audit) to a concrete ✅/🟡/❌/➖ status with
direct code evidence. **No new Unknown cells were introduced this run**: all fifteen contracts
audited from scratch across posthog-go, posthog-dotnet, and posthog-js — including the new MCP
Analytics capability on two of them — resolved to a definite status against directly-cited code.
posthog-flutter's 6 cells remain the matrix's entire Unknown backlog and are unchanged since
2026-08-06; draining them is a stated reason to prioritize Flutter in the next rotation.

## Pending initial audit

None — all 12 in-scope SDKs have at least one full audit on file.

## Queued for next run

This run used **two of its three slots** (posthog-python, posthog-node) and deliberately did not start a
third — see "This run" above for why, and for the rotation-slippage warning that comes with it. **Eight
SDKs are queued**, every one of them past the ~4-week re-verification window.

| SDK | Last-audited SHA | Last audited | Rows | New-contract rows needed |
|---|---|---|---|---|
| posthog-react-native | `e1efa57` (posthog-js monorepo) | 2026-08-06 | 59 | Yes (+5) |
| posthog-flutter | `05b53dc` | 2026-08-06 | 59 | Yes (+5) |
| posthog-android | `8659a7b4` | 2026-08-10 | 59 | Yes (+5) |
| posthog-java | `8659a7b4` (posthog-android monorepo) | 2026-08-10 | 59 | Yes (+5) |
| posthog-php | `5451f4e0` | 2026-09-28 | 63 | Yes (+1) |
| posthog-ruby | `185060ab` | 2026-09-28 | 63 | Yes (+1) |
| posthog-go | `08549f42` | 2026-10-05 | 64 | No |
| posthog-dotnet | `ae4d019c` | 2026-10-05 | 64 | No |

Prioritized for upcoming runs:

1. **posthog-react-native** — the clear #1, and this run's intended third pick. It holds the stalest
   pointer in the matrix (2026-08-06, now many hundreds of commits behind the monorepo HEAD this run
   read), it is one of only two SDKs the new `projectToken` requirement names by name (its
   `PostHogProvider` still takes an `apiKey` prop and must add `projectToken` with a deprecated alias),
   and it inherits `@posthog/core`'s exception-envelope and group-key behavior, which this run has just
   characterized in detail from the node side — so much of the shared-code evidence is already written
   and only the RN-specific layer needs fresh reading. It also needs all five missing contract rows, and
   is the natural client-side audit for Session Replay Debug Properties.
2. **posthog-flutter** — equally stale (2026-08-06) and the holder of **all 6 remaining ❓ Unknown cells
   in the matrix**; draining those is worth a slot on its own.
3. **posthog-android, posthog-java** — cheapest audited together (java's `posthog-server/` lives in the
   android monorepo and both are pinned to `8659a7b4`). android carries the mobile Session Replay Debug
   Properties audit and should confirm the withdrawn flat-exception-property finding above; java is the
   one server SDK with a local evaluator never checked against the holdout or negative-knowledge
   requirements, and it is the only SDK that already implements the caller-supplied `default_value`
   correctly, so it is also the reference for that fix.
4. **posthog-php, posthog-ruby** — lowest priority. Both were fully re-audited on 2026-09-28 and need
   only the MCP Analytics row, which is ➖ N/A for both. Fold the one-row addition into whichever run has
   spare capacity rather than spending a slot.

**Rotation health.** The target is every SDK re-verified roughly every 4 weeks. Three per run meets it;
this run's two does not, and the four oldest pointers (react-native, flutter, android, java) are now
9–10 weeks old. If the next run can only manage two deep audits again, the right trade is to spend one
slot on a *shallow* row-completion pass over the four 59-row files — adding the five missing contract
rows with conservative ❓/➖ scoring where the evidence is not read — so the matrix is at least
structurally complete while the deep rotation catches up.
