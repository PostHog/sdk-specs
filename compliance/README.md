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
posthog-go, posthog-java, posthog-dotnet. **63 contracts** are now tracked per SDK: the 62
capabilities listed in the root `README.md` table, plus `bootstrap`, which has a canonical
spec/acceptance file but is missing from that table — a documentation gap worth fixing
separately, out of scope for this compliance-only PR.

Four contracts are newer than most per-SDK files. **Capture AI**, **Evaluate Flags**, and
**Exception Event Metadata** were merged between 2026-08-10 and 2026-08-13; **Session Replay
Debug Properties** was merged this cycle (PR [#72](https://github.com/PostHog/sdk-specs/pull/72)).
An SDK file is fully caught up only at 63 rows. Four files are there now (posthog-php and
posthog-ruby this run; posthog-python, posthog-node and posthog-ios reached 62 last run and need
only the Session Replay Debug Properties row); the remaining seven are still at 59 and need all
four added at their next audit. See "Queued for next run" below.

**No SDK is pending its first audit.** Every run since the backlog drained has been a re-audit
run, and selection is driven by the four-rule priority order at the top of this file.

## This run (2026-09-28)

sdk-specs `main` advanced from `0ea0aba` (last run's baseline) to `1d5fe42`, a **27-commit span
touching 23 capability specs** — by far the largest spec delta since this matrix started. One
brand-new capability landed (**Session Replay Debug Properties**, PR
[#72](https://github.com/PostHog/sdk-specs/pull/72), +544 lines, `client`-only), but the bulk of
the change is a deep expansion of the **server-side feature-flag contracts**:
`local-feature-flag-evaluator` +929 lines (property-matching semantics, PRs
[#51](https://github.com/PostHog/sdk-specs/pull/51)/[#54](https://github.com/PostHog/sdk-specs/pull/54),
`is_set` presence semantics [#49](https://github.com/PostHog/sdk-specs/pull/49), float
rollout percentages [#46](https://github.com/PostHog/sdk-specs/pull/46), versioned property
matching [#59](https://github.com/PostHog/sdk-specs/pull/59), and **experiment holdouts**
[#76](https://github.com/PostHog/sdk-specs/pull/76)); `evaluate-flags` +209 (bounded missing-key
probes [#44](https://github.com/PostHog/sdk-specs/pull/44)/[#47](https://github.com/PostHog/sdk-specs/pull/47)/[#48](https://github.com/PostHog/sdk-specs/pull/48),
snapshot evaluation runtime [#74](https://github.com/PostHog/sdk-specs/pull/74));
`flag-definition-loader` +73; and a coordinated malformed-payload rule across
`get-feature-flag-payload`, `get-feature-flag-result`, and `get-feature-flags-and-payloads`
(PR [#71](https://github.com/PostHog/sdk-specs/pull/71)). Outside flags: `capture` gained UTC
timestamp normalization ([#45](https://github.com/PostHog/sdk-specs/pull/45)) and null-valued
object-property dropping ([#60](https://github.com/PostHog/sdk-specs/pull/60)); `before-send-hook`
became **breaking** — a throwing hook must now drop the event
([#43](https://github.com/PostHog/sdk-specs/pull/43)); `retry-queue` separated durable retention
from flush retry scheduling ([#53](https://github.com/PostHog/sdk-specs/pull/53)); `traces` and
`logs` were realigned to the posthog-js reference
([#61](https://github.com/PostHog/sdk-specs/pull/61), [#56](https://github.com/PostHog/sdk-specs/pull/56),
[#58](https://github.com/PostHog/sdk-specs/pull/58), [#68](https://github.com/PostHog/sdk-specs/pull/68));
`remote-config` got an HTTP endpoint contract ([#70](https://github.com/PostHog/sdk-specs/pull/70));
and `flush`/`shutdown` were amended to document Ruby's optional timeout and Boolean return
([#35](https://github.com/PostHog/sdk-specs/pull/35)).

Selection: **posthog-php** and **posthog-ruby**, on **priority rule 1 (affected by spec
changes)**. Both are server SDKs with mature local-evaluation engines, so the flags-heavy delta
above lands on them more directly than on any client SDK, and both were also confirmed code-drifted
(php `ed93a67`→`5451f4e`, ruby `31c187f`→`185060a`) and past the ~4-week re-verification window
(both last audited 2026-08-06). This supersedes the previous run's queue, which had put
posthog-react-native first on staleness grounds before this spec delta existed; RN stays at the
top of the queue below.

**Two SDKs, not three.** The per-run cap is a ceiling, not a target, and this cycle's spec delta
was large enough that covering it properly for two server SDKs consumed the run's budget. The
matrix's stated preference is thoroughness over coverage, so the third slot was left unused rather
than spent on a shallow third pass.

- **posthog-php** (10 ✅ · 12 🟡 · 8 ❌ · 33 ➖ · 0 ❓, from 12/9/7/31/0 on 59 rows): all four
  missing contracts added. **Capture AI** ➖ and **Session Replay Debug Properties** ➖ (no AI
  surface; no replay subsystem — both N/A by the specs' own scope notes). **Evaluate Flags** 🟡 —
  the snapshot API is genuinely good (empty-vs-null key list handled, scoped requests, at most one
  remote call, local values never overwritten), but there is no negative-knowledge retention, so a
  requested-but-deleted key re-probes `/flags` on every call forever. **Exception Event Metadata**
  ❌ on first audit — no `exception_id`/`parent_id` linkage, `handled: true` hardcoded on every
  entry including causes, no `synthetic`, no `$exception_level`, and non-canonical
  `php_exception_handler`-style `$exception_source` values. Two ✅ rows were downgraded on new spec
  text rather than code changes: **Get Feature Flag Payload** ✅→🟡 (malformed payloads correctly
  return `null` but are not logged, which the new requirement mandates) and **Local Feature Flag
  Evaluator** ✅→🟡 (experiment holdouts are entirely unimplemented). Notably, PHP *passed* several
  of the new flag requirements outright: `property_matching_version` is threaded through the
  definition snapshot, `exact`/`is_not` use true Unicode lowercase while the string-search family
  correctly uses ASCII-only, `is_set`/`is_not_set` presence semantics are exact, and `before_send`
  already drops the event when a hook throws.
- **posthog-ruby** (9 ✅ · 14 🟡 · 8 ❌ · 32 ➖ · 0 ❓, from 13/11/5/30/0 on 59 rows): all four
  missing contracts added, same two ➖ verdicts as php (the Capture AI spec names Ruby by name in
  its scope note). **Evaluate Flags** 🟡 for the same missing-negative-knowledge reason. **Exception
  Event Metadata** ❌, but Ruby is the furthest along of the server SDKs audited so far — it already
  emits `exception_id`, `parent_id`, `type: "chained"`, `source: "cause"`, a 50-entry chain cap and
  cause-cycle detection; it fails on nested entries *inheriting* the outermost `handled`, missing
  `synthetic` and `$exception_level`, and `capture_exception` merging caller properties **over**
  the SDK-owned `$exception_list`. **One row improved on a real code change:** Before Send Hook now
  drops the event when a hook raises, matching the breaking spec amendment. Four rows were
  downgraded on new spec requirements, and three of them — **Get Feature Flag Payload** ✅→❌, **Get
  Feature Flag Result** ✅→🟡, **Get Feature Flags And Payloads** ✅→❌ — trace to one helper,
  `FeatureFlagResult.parse_payload`, whose `rescue JSON::ParserError` returns the **raw serialized
  string**, exactly what the new rule forbids (the deprecated bulk and single-flag poller paths
  don't decode at all). **Local Feature Flag Evaluator** ✅→🟡 for the same holdout gap as php,
  though Ruby otherwise nails the subtlest part of the new matching spec: full-Unicode `downcase`
  for `exact`/`is_not` versus `downcase(:ascii)` for the string-search family.

**Cross-cutting finding — experiment holdouts are unimplemented in both server SDKs checked.**
`grep -rn holdout` returns zero matches in either repository. In both cases the definition loader
already preserves `filters.holdout` untouched (definitions are stored as whole parsed structures),
so the gap is purely in the evaluator. This is a *silent correctness divergence*, not a missing
feature: a flag configured with a holdout is evaluated locally as though the holdout did not
exist, disagreeing with the backend for every identity inside it. Since the requirement is brand
new, neither is a regression — but two for two on the first two SDKs checked makes it worth
prioritizing explicitly for posthog-go, posthog-dotnet, posthog-python, and posthog-node at their
next audits rather than treating it as a routine new-requirement sweep.

**Second cross-cutting finding — the malformed-payload rule is a real gap, not a formality.**
PR [#71](https://github.com/PostHog/sdk-specs/pull/71) closed the "unparsed payload string" loophole
across three contracts at once. php returns the correct `null` but logs nothing; ruby returns the
raw string on three separate public paths. Every other server SDK should be checked against this
specific rule on its next pass — it is a one-helper fix in both SDKs seen so far, and it is the
kind of defect that is invisible until a payload breaks in production.

## Roll-up

| SDK | Overall | ✅ | 🟡 | ❌ | ➖ | ❓ | Last audited | Open gaps | File |
|---|---|---|---|---|---|---|---|---|---|
| posthog-js | 25/59 fully compliant (42%; **59 rows, needs +4 new contracts**) | 25 | 19 | 12 | 3 | 0 | 2026-08-10 · `34a34f3d` | 31 | [posthog-js.md](posthog-js.md) |
| posthog-python | 14/62 fully compliant (23%; 29 contracts N/A on a server SDK; **needs +1: Session Replay Debug Properties**) | 14 | 12 | 7 | 29 | 0 | 2026-08-17 · `95c7f6e0` | 19 | [posthog-python.md](posthog-python.md) |
| posthog-android | 31/59 fully compliant (53%; **59 rows, needs +4 new contracts**) | 31 | 16 | 9 | 3 | 0 | 2026-08-10 · `8659a7b4` | 25 | [posthog-android.md](posthog-android.md) |
| posthog-ios | 32/62 fully compliant (52%; **needs +1: Session Replay Debug Properties**) | 32 | 18 | 7 | 5 | 0 | 2026-08-17 · `c0218386` | 25 | [posthog-ios.md](posthog-ios.md) |
| posthog-node | 10/62 fully compliant (16%; 28 contracts N/A on a server SDK; **needs +1: Session Replay Debug Properties**) | 10 | 16 | 8 | 28 | 0 | 2026-08-17 · `fbdb6c7b` (posthog-js monorepo) | 24 | [posthog-node.md](posthog-node.md) |
| posthog-flutter | 20/59 fully compliant (34%; **59 rows, needs +4 new contracts**) | 20 | 22 | 6 | 5 | 6 | 2026-08-06 · `05b53dc` | 34 | [posthog-flutter.md](posthog-flutter.md) |
| posthog-react-native | 31/59 fully compliant (53%; **59 rows, needs +4 new contracts**) | 31 | 23 | 2 | 2 | 1 | 2026-08-06 · `e1efa57` (posthog-js monorepo — now stale, see below) | 26 | [posthog-react-native.md](posthog-react-native.md) |
| posthog-php | 10/63 fully compliant (16%; 33 contracts N/A on a server SDK) | 10 | 12 | 8 | 33 | 0 | 2026-09-28 · `5451f4e0` | 20 | [posthog-php.md](posthog-php.md) |
| posthog-ruby | 9/63 fully compliant (14%; 32 contracts N/A on a server SDK) | 9 | 14 | 8 | 32 | 0 | 2026-09-28 · `185060ab` | 22 | [posthog-ruby.md](posthog-ruby.md) |
| posthog-go | 10/59 fully compliant (17%; **59 rows, needs +4 new contracts**) | 10 | 11 | 7 | 31 | 0 | 2026-08-06 · `019af19` | 18 | [posthog-go.md](posthog-go.md) |
| posthog-java | 12/59 fully compliant (20%; **59 rows, needs +4 new contracts**) | 12 | 13 | 6 | 28 | 0 | 2026-08-10 · `8659a7b4` (posthog-android monorepo) | 19 | [posthog-java.md](posthog-java.md) |
| posthog-dotnet | 7/59 fully compliant (12%; **59 rows, needs +4 new contracts**) | 7 | 15 | 9 | 28 | 0 | 2026-08-06 · `e7f20e3` | 24 | [posthog-dotnet.md](posthog-dotnet.md) |

**Row-count note:** posthog-php and posthog-ruby were re-audited this run and now carry the full
63-row matrix. posthog-python, posthog-node, and posthog-ios sit at 62 — they need only the new
Session Replay Debug Properties row (➖ N/A for python and node, a real client-side audit for
ios). The remaining seven SDKs are still at 59 rows and need all four of Capture AI, Evaluate
Flags, Exception Event Metadata, and Session Replay Debug Properties added from scratch at their
next audit, not just a refresh of existing rows.

"Overall" for posthog-python, posthog-node, posthog-php, posthog-ruby, posthog-go, posthog-java,
and posthog-dotnet is computed against the contracts actually applicable to a server SDK
(posthog-python: 14 Pass / 33 applicable = 42%; posthog-node: 10 Pass / 34 applicable = 29%;
posthog-php: 10 Pass / 30 applicable = 33%; posthog-ruby: 9 Pass / 31 applicable = 29%;
posthog-go: 10 Pass / 28 applicable = 36%; posthog-java: 12 Pass / 31 applicable = 39%;
posthog-dotnet: 7 Pass / 31 applicable = 23%); shown above as raw Pass/(59 or 62) for
comparability with client SDKs, which see N/A far less often. **posthog-node note:** the standalone
`PostHog/posthog-node` repo has been archived/redirected — its code now lives at `packages/node` +
`packages/core` inside the `posthog-js` monorepo, so its audited commit is a `posthog-js` SHA. This
run re-audited node fresh at `fbdb6c7b` (2026-08-17), advancing well past posthog-js's own last
audited SHA (`34a34f3d`, 2026-08-10) and posthog-react-native's (`e1efa57`, 2026-08-06) — all three
share one monorepo but are independently tracked, and posthog-js/-react-native were **not**
re-audited this run, so they are now the most stale relative to actual monorepo HEAD; both are
flagged in "Queued for next run" below. **posthog-react-native note:** likewise archived
(`pushed_at` 2025-07-26) and folded into the same `posthog-js` monorepo at `packages/react-native`
+ `packages/react-native-plugin`, so it too is audited at a `posthog-js` SHA (`e1efa57`, now even
more stale) — but unlike posthog-node it extends the full client-side `PostHogCore` base, so it is
scored like a client SDK (raw Pass/59), not given the server-SDK applicable-only treatment.
**posthog-java note:** the standalone
`PostHog/posthog-java` repo is also archived; its README redirects to a new home at
`PostHog/posthog-android`'s `posthog-server/` subdirectory (package `com.posthog.server`,
Kotlin/JVM), which is what this audit evaluated — its audited commit (`8659a7b4`) is a
`posthog-android` SHA, the same commit posthog-android's own (separate) client-SDK audit used this
run, since both were re-verified together in the same monorepo clone.

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
| posthog-python | Traces | Backward-compatible | No `/i/v1/traces` OTLP pipeline (only an AI-events/OTel-bridge substitute the spec explicitly excludes) — [posthog-python.md#n2](posthog-python.md) |
| posthog-python | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | No persistent property-override cache, despite `@both`-tagged acceptance scenarios — [posthog-python.md#n10](posthog-python.md) |
| posthog-python | Exception Event Metadata | Mixed (see note) | `mechanism.handled` hardcoded `True` even when the SDK's own passing test proves the exception escaped the process; also missing `synthetic`, `$exception_source`, tree linkage, `$exception_level` — [posthog-python.md#n14](posthog-python.md) |
| posthog-android | Alias | Backward-compatible | No `distinct_id` alongside `alias` in the `$create_alias` payload — [posthog-android.md#n1](posthog-android.md) |
| posthog-android | Capture Exception | Backward-compatible | No top-level `$exception_type`/`$exception_message`, only nested `$exception_list` — [posthog-android.md#n2](posthog-android.md) |
| posthog-android | Get Feature Flags | Backward-compatible | No public flat bulk getter; internal cache-only version exists but isn't exposed — [posthog-android.md#n4](posthog-android.md) |
| posthog-android | Get Feature Flags And Payloads | Backward-compatible | No combined getter; returns `null` (not empty maps) on cold cache — [posthog-android.md#n5](posthog-android.md) |
| posthog-android | Screen | Needs deprecation path | Caller-supplied `$screen_name` silently overrides the explicit `screenTitle` argument — the SDK's own doc comment documents the wrong precedence — [posthog-android.md#n11](posthog-android.md) |
| posthog-android | Shutdown | Backward-compatible | `close()` never flushes; queued events stranded on disk — [posthog-android.md#n12](posthog-android.md) |
| posthog-android | Start Session Recording | Backward-compatible | `startSessionReplay()` has no `isOptedOut()` guard — [posthog-android.md#n13](posthog-android.md) |
| posthog-android | Autocapture | Backward-compatible | No generic UI-interaction autocapture (`$autocapture`) at all — [posthog-android.md#n16](posthog-android.md) |
| posthog-android | Traces | Backward-compatible | No OTLP traces/spans implementation — [posthog-android.md#n28](posthog-android.md) |
| posthog-ios | Get Feature Flags | Backward-compatible | No flat bulk flag getter, only internal machinery — [posthog-ios.md#n7](posthog-ios.md) |
| posthog-ios | Get Feature Flags And Payloads | Backward-compatible | No combined flags+payloads getter under any name — [posthog-ios.md#n8](posthog-ios.md) |
| posthog-ios | On Feature Flags | Backward-compatible | No public multi-subscriber listener API exposed — [posthog-ios.md#n11](posthog-ios.md) |
| posthog-ios | Shutdown | Backward-compatible | `close()` never calls `flush()` before stopping queues — [posthog-ios.md#n16](posthog-ios.md) |
| posthog-ios | Session Replay Privacy | Needs deprecation path | Password-field precedence bug in screenshot mode is now fixed, but default wireframe-capture mode still never checks `ph-no-capture` for plain `UIView`s — a silent privacy leak persists — [posthog-ios.md#n26](posthog-ios.md) |
| posthog-ios | Surveys | Backward-compatible | New intro-screen requirement (`displayIntroScreen` and friends) is entirely unimplemented; the parallel trailing `thankYouMessage*` fields already exist — [posthog-ios.md#n27](posthog-ios.md) |
| posthog-ios | Traces | Backward-compatible | No OTLP span/traces implementation anywhere — [posthog-ios.md#n2](posthog-ios.md) |
| posthog-node | Traces | Backward-compatible | No OTLP `/i/v1/traces` pipeline anywhere in the monorepo (industry-wide gap, matches posthog-python/-js) — [posthog-node.md#n2](posthog-node.md) |
| posthog-node | Capture Exception | Needs deprecation path | Deeper Exception Event Metadata verification surfaced overlapping hard failures (hardcoded `handled`/severity, missing flat properties, inverted precedence) — [posthog-node.md#n7](posthog-node.md) |
| posthog-node | Is Feature Enabled | Backward-compatible | Neither `isFeatureEnabled()` nor its successor accepts a caller `defaultValue` (hard SHALL, no server carve-out) — [posthog-node.md#n13](posthog-node.md) |
| posthog-node | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | Zero implementation; methods exist only on the client-only base class node doesn't extend — [posthog-node.md#n15](posthog-node.md) |
| posthog-node | Exception Event Metadata | Mixed (see note) | No `exception_id`/`parent_id` tree linkage, hardcoded `handled`/`$exception_level`, no `$exception_source`, caller properties override SDK-canonical fields — [posthog-node.md#n20](posthog-node.md) |
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
| posthog-js | Consent Gating | Backward-compatible | Opt-out drop has no logged reason; persistence writes are only opt-out-gated when explicitly configured — [posthog-js.md#n21](posthog-js.md) |
| posthog-js | Retry Queue | Needs deprecation path | Unbounded queue, 429 not retried, no `Retry-After` — [posthog-js.md#n28](posthog-js.md) |
| posthog-js | Session Manager | Needs deprecation path | Idle-rotation is skipped whenever the session id is read via the read-only `get_session_id()` path — [posthog-js.md#n29](posthog-js.md) |
| posthog-js | Session Replay Privacy | Backward-compatible | Custom network-mask hook bypasses keyword/content scrubbing that runs in the no-hook path — [posthog-js.md#n31](posthog-js.md) |
| posthog-js | Surveys | Needs deprecation path | Opt-out doesn't block survey display/fetch outside cookieless mode — [posthog-js.md#n32](posthog-js.md) |
| posthog-js | Logs | Needs deprecation path | Queue is in-memory-only and wiped on `reset()`; OTLP attribute-encoding and 408/`Retry-After` gaps — [posthog-js.md#n33](posthog-js.md) |
| posthog-python | Flush | Breaking | Failed batches are dropped, not retained — requeue-for-retry would change delivery/ordering semantics — [posthog-python.md#n6](posthog-python.md) |
| posthog-python | Retry Queue | Needs deprecation path | Same drop-on-failure behavior with observable `on_error`/blocking-timing implications — [posthog-python.md#n17](posthog-python.md) |
| posthog-python | Is Feature Enabled | Backward-compatible | Legacy `feature_enabled()` still lacks a caller default, but its designated successor `evaluate_flags(...).is_enabled(default_value=...)` fully satisfies the spec — upgraded from ❌ last run — [posthog-python.md#n9](posthog-python.md) |
| posthog-node | Capture AI | Backward-compatible | `privacyMode` is declared/documented but never wired to the client, so it silently fails to override `enableFullAiCapture` at config level as required — [posthog-node.md#n6](posthog-node.md) |
| posthog-node | Local Feature Flag Evaluator | Backward-compatible | New unrecognized-operator-degrades-to-inconclusive requirement is correctly implemented in code, but the acceptance `.feature` file hasn't been updated with the new scenarios yet (test-asset sync gap, not a runtime defect) — downgraded from ✅ this run — [posthog-node.md#n24](posthog-node.md) |
| posthog-ios | Exception Event Metadata | Mixed (see note) | No `exception_id`/`parent_id` tree linkage or `chained` mechanism type on nested exceptions, no `$exception_source`, no 50-entry truncation; manual `captureException` lets caller properties override SDK-owned fields (native-crash path gets this right) — [posthog-ios.md#n21](posthog-ios.md) |
| posthog-android | Consent Gating | Backward-compatible | Downgraded from ✅ this run — `optOut()` never stops an active replay session, and session-replay start/stop never check `isOptedOut()`, despite session replay being named in this spec's own scope — [posthog-android.md#n18](posthog-android.md) |
| posthog-android | HTTP Client | Backward-compatible | Downgraded from ✅ this run — the feature-flags retry classifier misses `UnknownHostException`/`SSLException`/`ConnectException` (DNS/TLS/connection-refused); core batch transport remains solid — [posthog-android.md#n22](posthog-android.md) |
| posthog-android | Feature Flag Called Tracker | Backward-compatible | Same allowlist gap as posthog-python, already fixed in posthog-js/-node per the audit notes — [posthog-android.md#n20](posthog-android.md) |
| posthog-android | Session Replay Privacy | Needs deprecation path | `ph-no-capture` ignored outside screenshot mode; default capture mode can leak tagged views — [posthog-android.md#n26](posthog-android.md) |
| posthog-android | Surveys | Needs deprecation path | Web-only `url`/`selector`-targeted surveys aren't excluded on Android as the spec requires — [posthog-android.md#n27](posthog-android.md) |
| posthog-ios | Screen | Needs deprecation path | Caller-supplied `$screen_name` silently overrides the explicit `screenTitle` argument, the inverse of spec precedence — [posthog-ios.md#n21](posthog-ios.md) |
| posthog-node | Flush / Retry Queue (v1 pipeline) | Needs deprecation path | `V1CaptureSender` never throws on exhausted retry, so failed batches are evicted from the queue as if delivered — [posthog-node.md#n8](posthog-node.md) |
| posthog-node | Feature Flag Called Tracker | Backward-compatible | Allowlist itself is fully compliant (inherited from posthog-js via shared `@posthog/core`), but capacity eviction is a full clear rather than incremental, violating the spec's anti-thundering-herd requirement — [posthog-node.md#n19](posthog-node.md) |
| posthog-flutter | Session Replay Privacy | Backward-compatible (mostly) | Independent Dart replay pipeline has no no-capture marker, no general unmask primitive, inconsistent password-field masking — [posthog-flutter.md#n31](posthog-flutter.md) |
| posthog-react-native | Bootstrap | Backward-compatible | Flag-merge spread order is inverted — previously-persisted flags win over a fresh bootstrap value, the opposite of the spec's required precedence — [posthog-react-native.md#n4](posthog-react-native.md) |
| posthog-react-native | Flush / Retry Queue | Backward-compatible | Shared-core catch handler evicts an exhausted-retry HTTP failure as if delivered instead of preserving it — same defect class as posthog-node — [posthog-react-native.md#n10](posthog-react-native.md) |
| posthog-react-native | Session Replay Privacy | ❓ Unknown | RN's own bridge does no masking itself; the underlying native SDKs it wraps have confirmed masking bugs (see posthog-ios#n22) that likely propagate but can't be independently re-verified — [posthog-react-native.md#n24](posthog-react-native.md) |
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
| posthog-go | Flush / Retry Queue | Breaking (core issue) | Once a batch's local retry budget is exhausted, both wire pipelines permanently drop it rather than requeuing — [posthog-go.md#n7](posthog-go.md) |
| posthog-go | Feature Flag Called Tracker | Backward-compatible | Allowlist missing the same 10 session-attribution properties as python/android/ios/php/ruby; `Close()` also never purges the dedup LRU — [posthog-go.md#n5](posthog-go.md) |
| posthog-go | Flag Definition Loader | Backward-compatible | No external/shared flag-definition cache-provider extension point at all, unlike posthog-ruby/php/node/python — [posthog-go.md#n6](posthog-go.md) |
| posthog-java | Before Send Hook | Backward-compatible | Chaining bug — passes the *original* event to every hook instead of the running mutated event, so a second hook never sees the first hook's changes — [posthog-java.md#n2](posthog-java.md) |
| posthog-java | Shutdown | Backward-compatible | `close()` never calls `queue.flush()`, only cancels the timer — sub-threshold events are silently lost — [posthog-java.md#n24](posthog-java.md) |
| posthog-java | Feature Flag Called Tracker | Backward-compatible | Same 10-property allowlist gap as posthog-ruby/-node/-php — [posthog-java.md#n8](posthog-java.md) |
| posthog-java | Local Feature Flag Evaluator | Mixed (see note) | Missing group context resolves to a hard `false` instead of falling back to remote evaluation (**Needs deprecation path**); **and**, newly confirmed this run, the `starts_with`/`not_starts_with`/`ends_with`/`not_ends_with` operator family added to the spec in `2036abd` is entirely unimplemented — every flag using them degrades safely to remote evaluation rather than returning a wrong answer (**Backward-compatible** to add) — [posthog-java.md#n18](posthog-java.md) |
| posthog-dotnet | Feature Flag Called Tracker | Backward-compatible | Same 10-property allowlist gap as every other server SDK audited; otherwise a well-built tracker (incremental eviction, group normalization) — [posthog-dotnet.md#n7](posthog-dotnet.md) |
| posthog-dotnet | Setup | Needs deprecation path | Re-`Init` silently swaps the default client's config today; adding a double-init guard changes behavior some callers may rely on — [posthog-dotnet.md#n20](posthog-dotnet.md) |
| posthog-dotnet | Identify | Breaking or Backward-compatible (implementation-dependent) | Missing/empty `distinctId` silently succeeds today; spec text calls for either a raise (breaking) or drop-with-log (backward-compatible) — [posthog-dotnet.md#n15](posthog-dotnet.md) |

Full contract-by-contract detail (31 posthog-js, 19 posthog-python, 25 posthog-android, 25
posthog-ios, 24 posthog-node, 34 posthog-flutter, 26 posthog-react-native, 20 posthog-php, 22
posthog-ruby, 18 posthog-go, 19 posthog-java, and 24 posthog-dotnet non-Pass/non-N/A cells) is in
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
re-confirmed the gap is still present in both, unaffected by the intervening code drift.

A second cross-cutting pattern: **Is Feature Enabled**'s caller-supplied default-value parameter
(a hard spec `SHALL`, no server carve-out) is missing in posthog-python, posthog-node,
posthog-php, posthog-ruby, posthog-go, and posthog-dotnet — 6 of the 7 server-style SDKs audited.
The lone exception is **posthog-java** (`posthog-server`'s `com.posthog.server` package), which
correctly implements a caller-supplied default on its canonical evaluation path (reconfirmed this
run) — worth using as the reference implementation when fixing the other 6.

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

**New this run — Exception Event Metadata's first three audits all found real gaps.** This
brand-new (2026-08-13) contract was checked for the first time against posthog-python, posthog-node,
and posthog-ios. All three hardcode at least one of `mechanism.handled`/`$exception_level` to a
fixed value regardless of true capture-boundary state (contradicting the spec's explicit "MUST NOT
default unknown to `false`"/fixed-value rule), omit the `exception_id`/`parent_id` tree-linkage
fields required by the canonical envelope, or let caller-supplied properties silently override
SDK-owned reserved keys. See [posthog-python.md#n14](posthog-python.md),
[posthog-node.md#n20](posthog-node.md), and [posthog-ios.md#n21](posthog-ios.md). Since this is a
new contract these aren't regressions, but the pattern repeating on the first three SDKs checked
means it's worth prioritizing when the remaining 9 SDKs get this contract added on their next
audit, rather than treating it as routine.

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
of their tracked contracts (63 for php/ruby after this run, 62 for python/ios/node, 59 for the rest
pending their next audit) to a concrete ✅/🟡/❌/➖ status with direct code evidence. **No new
Unknown cells were introduced this run**: every contract audited for posthog-php and posthog-ruby,
including the four added from scratch, resolved to a definite status against directly-cited code.

## Pending initial audit

None — all 12 in-scope SDKs have at least one full audit on file.

## Queued for next run

This run used 2 of its 3 available slots (**posthog-php**, **posthog-ruby**), selected on priority
rule 1 — this cycle's sdk-specs delta is overwhelmingly server-side feature-flag semantics. That
leaves **10 SDKs queued**. Every one of them is now past the ~4-week re-verification window, and
all of them need new contract rows.

| SDK | Last-audited SHA | Current HEAD | Last audited | Rows | New-contract rows needed |
|---|---|---|---|---|---|
| posthog-react-native | `e1efa57` (posthog-js monorepo) | `a5336382` | 2026-08-06 | 59 | Yes (+4) |
| posthog-go | `019af19` | `e16d124b` | 2026-08-06 | 59 | Yes (+4) |
| posthog-dotnet | `e7f20e3` | `b5440d78` | 2026-08-06 | 59 | Yes (+4) |
| posthog-flutter | `05b53dc` | `a60eba5c` | 2026-08-06 | 59 | Yes (+4) |
| posthog-js | `34a34f3d` | `a5336382` | 2026-08-10 | 59 | Yes (+4) |
| posthog-android | `8659a7b4` | `3bb72588` | 2026-08-10 | 59 | Yes (+4) |
| posthog-java | `8659a7b4` (posthog-android monorepo) | `3bb72588` | 2026-08-10 | 59 | Yes (+4) |
| posthog-python | `95c7f6e0` | `4a138e61` | 2026-08-17 | 62 | Yes (+1) |
| posthog-node | `fbdb6c7b` (posthog-js monorepo) | `a5336382` | 2026-08-17 | 62 | Yes (+1) |
| posthog-ios | `c0218386` | `3b6cd1f8` | 2026-08-17 | 62 | Yes (+1) |

All ten are confirmed code-drifted: every recorded SHA differs from its repository's current HEAD
(checked via `gh api repos/PostHog/<repo>/commits/HEAD` on 2026-09-28).

Prioritized for upcoming runs:

1. **posthog-go, posthog-dotnet** — highest priority. Both are server SDKs with local-evaluation
   engines, so they carry the same exposure to this cycle's flags delta that drove php and ruby
   here, and both are in the oldest (2026-08-06) staleness cohort. The two cross-cutting findings
   above give their audits a concrete starting point: check `holdout` support in the evaluator and
   the malformed-payload path in every payload accessor first.
2. **posthog-react-native** — was #1 on the previous run's queue and was displaced by rule 1, not
   by a reassessment. Its recorded SHA (`e1efa57`) remains the most stale pointer in the matrix
   relative to actual monorepo HEAD, and it is the natural first client-side audit for the new
   **Session Replay Debug Properties** contract, which names the mobile and hybrid SDKs as its
   primary conformance targets.
3. **posthog-python, posthog-node** — only one row behind (Session Replay Debug Properties, ➖ N/A
   for both), but both are directly implicated by the flags delta and both have drifted since
   2026-08-17, so a cheap row-add should be paired with a real re-verification of their
   Evaluate Flags and Local Feature Flag Evaluator rows.
4. **posthog-ios, posthog-android, posthog-js, posthog-java, posthog-flutter** — the client-side
   and mobile group. The new Session Replay Debug Properties contract is a genuine audit for
   ios/android/js/flutter/react-native (`$recording_status`, the `$sdk_debug_*` keys, and the
   `$snapshot` exclusion), and the `autocapture` mobile-touch-vs-browser-click distinction
   (PR [#69](https://github.com/PostHog/sdk-specs/pull/69)) and replay-setup crash containment
   (PR [#55](https://github.com/PostHog/sdk-specs/pull/55)) also land on them. posthog-java is
   server-side but shares posthog-android's monorepo commit, so the two are cheapest audited
   together.

At two SDKs per run the full rotation now takes about five weeks, which is slightly outside the
~4-week target. If the backlog does not shrink over the next two runs, the cap should be used in
full (3/run) or the per-SDK re-verification depth reduced for SDKs with no code drift — a tradeoff
worth a human decision rather than a silent change to this document.
