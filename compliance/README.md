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
posthog-go, posthog-java, posthog-dotnet. **62 contracts** are now tracked per SDK (the 61
capabilities listed in the root `README.md` table, up from 58 as of the last run, plus
`bootstrap`, which has a canonical spec/acceptance file but is missing from that table — a
documentation gap worth fixing separately, out of scope for this compliance-only PR). The three
new contracts — **Capture AI**, **Evaluate Flags**, and **Exception Event Metadata** — were
merged into sdk-specs between 2026-08-10 and 2026-08-13, i.e. after every SDK's most recent audit
at the time, so **every one of the 12 per-SDK files needs at least one more pass to grow from 59
rows to 62** before the matrix is fully caught up; see "Queued for next run" below.

**Bootstrap backlog fully drained** since the run that first reached 12/12 SDKs audited. This run
(2026-08-17) is a **re-audit** run: no SDK is pending its first audit. Selection this run was
driven by (1) three new spec-defined contracts merged since the last run, and (2) confirmed code
drift on the three oldest-audited SDKs still in the "run-1" staleness cohort — see "This run"
below.

## This run (2026-08-17)

sdk-specs `main` advanced from `2036abd` (the baseline the previous run — posthog-js,
posthog-android, posthog-java — was audited against) to `0ea0aba`, a 9-commit span that added
three brand-new capability specs (**Capture AI** PR [#37](https://github.com/PostHog/sdk-specs/pull/37),
**Evaluate Flags** PR [#34](https://github.com/PostHog/sdk-specs/pull/34), **Exception Event
Metadata** PR [#39](https://github.com/PostHog/sdk-specs/pull/39)) plus five prose/requirement
fixes to existing contracts: `local-feature-flag-evaluator` gained a general "unrecognized
operator degrades to inconclusive" requirement (PR [#36](https://github.com/PostHog/sdk-specs/pull/36));
`shutdown`'s error-handling section was corrected to say Promise-based SDKs should *resolve* (not
reject) on timeout (PR [#40](https://github.com/PostHog/sdk-specs/pull/40), driven by a
posthog-node/`@posthog/core` fix); `identify` gained an explicit anonymous-still-anonymous→identified
transition scenario (PR [#18](https://github.com/PostHog/sdk-specs/pull/18)); `surveys` gained an
intro-screen requirement (PR [#32](https://github.com/PostHog/sdk-specs/pull/32), browser +
posthog-react-native shipped it first); and `reset` gained an optional bootstrap-options extension
(PR [#41](https://github.com/PostHog/sdk-specs/pull/41), confirmed browser-only so far).

Selection: **posthog-python**, **posthog-node**, and **posthog-ios** — the three oldest-audited
SDKs (all last verified 2026-08-06, the "run-1"/"run-2" staleness cohort per the prior run's
queue), all independently confirmed to have drifted code since their last audit (python
`55370ee`→`95c7f6e0`; the posthog-js monorepo backing node `e1efa57`→`fbdb6c7b`; ios
`057f4d6`→`c0218386`), and all directly affected by the new/changed contracts above: Capture AI
and Evaluate Flags are server-only (python, node); Exception Event Metadata applies to all three
(`both` applicability); the corrected Shutdown requirement was specifically about Node; Identify's
new transition scenario is client-only (ios); Surveys' intro screen is client-only (ios).

- **posthog-python** (14 ✅ · 12 🟡 · 7 ❌ · 29 ➖ · 0 ❓, up from 10/13/7/29/0 on 59 rows): **Capture
  AI** and **Evaluate Flags** both score ✅ — a mature `FeatureFlagEvaluations` snapshot API and a
  fully-spec-compliant AI capture lane already exist. **Exception Event Metadata** scores ❌ on its
  first audit: `mechanism.handled` is hardcoded `true` even when the SDK's own passing test proves
  the exception escaped the process — exactly the anti-pattern the spec forbids — plus missing
  `synthetic`, `$exception_source`, chained-exception tree linkage, and `$exception_level`.
  Re-verification also upgraded three older cells on fresh evidence (not code changes): **Group
  Identify** 🟡→✅ (validation now exists), **Is Feature Enabled** ❌→🟡 (the legacy method still
  lacks a default, but its designated successor `evaluate_flags(...).is_enabled(default_value=...)`
  fully satisfies the spec), and **Feature Flag Called Tracker** 🟡→✅ (last run's finding was a
  false positive against `@client`-only acceptance scenarios; Python's allowlist is the spec's own
  cited reference implementation).
- **posthog-node** (10 ✅ · 16 🟡 · 8 ❌ · 28 ➖ · 0 ❓, up from 11/15/6/27/0 on 59 rows, audited via
  the `posthog-js` monorepo's `packages/node`+`packages/core`): **Evaluate Flags** scores ✅.
  **Capture AI** scores 🟡 — implemented and well-tested, but `privacyMode` is declared and
  documented yet never wired to the client, so it silently fails to override
  `enableFullAiCapture` at the config level as the spec requires. **Exception Event Metadata**
  scores ❌ (missing tree linkage entirely, hardcoded `handled: true` on nested causes, hardcoded
  `$exception_level`, no `$exception_source`, and caller properties override SDK-canonical
  fields). The corrected **Shutdown** requirement is confirmed already-compliant — `@posthog/core`
  does resolve (not reject) on timeout. **Capture Exception** was downgraded 🟡→❌ as the deeper
  Exception Event Metadata pass surfaced overlapping hard failures. **Local Feature Flag
  Evaluator** was downgraded ✅→🟡: the new unrecognized-operator requirement is correctly
  implemented in code, but the acceptance `.feature` file hasn't been updated with the new
  scenarios yet (a test-asset sync gap, not a runtime defect).
- **posthog-ios** (32 ✅ · 18 🟡 · 7 ❌ · 5 ➖ · 0 ❓, up from 33/17/6/3/0 on 59 rows): **Capture AI**
  and **Evaluate Flags** both score ➖ N/A (server-only contracts, confirmed against the spec's own
  applicability text). **Exception Event Metadata** scores 🟡 — no `exception_id`/`parent_id` tree
  linkage, nested exceptions never get `mechanism.type = "chained"`, `$exception_source` is never
  emitted, no 50-entry truncation, and manual `captureException` lets caller properties override
  SDK-owned fields (the native-crash path gets this right). **Identify**'s new anonymous-transition
  scenario is confirmed ✅ already correct. **Surveys** was downgraded ✅→❌: the new intro-screen
  requirement (`displayIntroScreen` and friends) is entirely unimplemented, while the parallel
  trailing `thankYouMessage*` fields already exist. **Session Replay Privacy**'s previously-flagged
  password-field precedence bug in screenshot mode is fixed, but the contract stays ❌ overall
  because the wireframe-mode no-capture leak persists. All other previously-tracked rows were
  independently re-verified against fresh code and confirmed unchanged.

**Cross-cutting finding — Exception Event Metadata's first audit pass found real gaps in all
three SDKs checked against it.** Every one of posthog-python, posthog-node, and posthog-ios
either hardcodes `mechanism.handled`/`$exception_level` to a fixed value regardless of true
capture-boundary state, omits the `exception_id`/`parent_id` tree-linkage fields the spec's
canonical envelope requires, or lets caller-supplied properties override SDK-owned reserved keys
(or some combination of all three). Since this is a brand-new contract, none of these are
regressions — but the pattern repeating on the very first three SDKs checked suggests it's worth
prioritizing Exception Event Metadata specifically when the remaining 9 SDKs get their next audit,
rather than treating it as a routine new-row fill-in.

## Roll-up

| SDK | Overall | ✅ | 🟡 | ❌ | ➖ | ❓ | Last audited | Open gaps | File |
|---|---|---|---|---|---|---|---|---|---|
| posthog-js | 25/59 fully compliant (42%; **59 rows, needs +3 new contracts**) | 25 | 19 | 12 | 3 | 0 | 2026-08-10 · `34a34f3d` | 31 | [posthog-js.md](posthog-js.md) |
| posthog-python | 14/62 fully compliant (23%; 29 contracts N/A on a server SDK) | 14 | 12 | 7 | 29 | 0 | 2026-08-17 · `95c7f6e0` | 19 | [posthog-python.md](posthog-python.md) |
| posthog-android | 31/59 fully compliant (53%; **59 rows, needs +3 new contracts**) | 31 | 16 | 9 | 3 | 0 | 2026-08-10 · `8659a7b4` | 25 | [posthog-android.md](posthog-android.md) |
| posthog-ios | 32/62 fully compliant (52%) | 32 | 18 | 7 | 5 | 0 | 2026-08-17 · `c0218386` | 25 | [posthog-ios.md](posthog-ios.md) |
| posthog-node | 10/62 fully compliant (16%; 28 contracts N/A on a server SDK) | 10 | 16 | 8 | 28 | 0 | 2026-08-17 · `fbdb6c7b` (posthog-js monorepo) | 24 | [posthog-node.md](posthog-node.md) |
| posthog-flutter | 20/59 fully compliant (34%; **59 rows, needs +3 new contracts**) | 20 | 22 | 6 | 5 | 6 | 2026-08-06 · `05b53dc` | 34 | [posthog-flutter.md](posthog-flutter.md) |
| posthog-react-native | 31/59 fully compliant (53%; **59 rows, needs +3 new contracts**) | 31 | 23 | 2 | 2 | 1 | 2026-08-06 · `e1efa57` (posthog-js monorepo — now stale, see below) | 26 | [posthog-react-native.md](posthog-react-native.md) |
| posthog-php | 12/59 fully compliant (20%; **59 rows, needs +3 new contracts**) | 12 | 9 | 7 | 31 | 0 | 2026-08-06 · `ed93a67` | 16 | [posthog-php.md](posthog-php.md) |
| posthog-ruby | 13/59 fully compliant (22%; **59 rows, needs +3 new contracts**) | 13 | 11 | 5 | 30 | 0 | 2026-08-06 · `31c187f` | 16 | [posthog-ruby.md](posthog-ruby.md) |
| posthog-go | 10/59 fully compliant (17%; **59 rows, needs +3 new contracts**) | 10 | 11 | 7 | 31 | 0 | 2026-08-06 · `019af19` | 18 | [posthog-go.md](posthog-go.md) |
| posthog-java | 12/59 fully compliant (20%; **59 rows, needs +3 new contracts**) | 12 | 13 | 6 | 28 | 0 | 2026-08-10 · `8659a7b4` (posthog-android monorepo) | 19 | [posthog-java.md](posthog-java.md) |
| posthog-dotnet | 7/59 fully compliant (12%; **59 rows, needs +3 new contracts**) | 7 | 15 | 9 | 28 | 0 | 2026-08-06 · `e7f20e3` | 24 | [posthog-dotnet.md](posthog-dotnet.md) |

**Row-count note:** posthog-python, posthog-node, and posthog-ios were re-audited this run and now
carry the full 62-row matrix (including the 3 new contracts below). The other 9 SDKs' files still
have only 59 rows — their next audit needs to add Capture AI, Evaluate Flags, and Exception Event
Metadata from scratch, not just refresh existing rows.

"Overall" for posthog-python, posthog-node, posthog-php, posthog-ruby, posthog-go, posthog-java,
and posthog-dotnet is computed against the contracts actually applicable to a server SDK
(posthog-python: 14 Pass / 33 applicable = 42%; posthog-node: 10 Pass / 34 applicable = 29%;
posthog-php: 12 Pass / 28 applicable = 43%; posthog-ruby: 13 Pass / 29 applicable = 45%;
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
| posthog-java | Local Feature Flag Evaluator | Mixed (see note) | Missing group context resolves to a hard `false` instead of falling back to remote evaluation (**Needs deprecation path**); **and**, newly confirmed this run, the `starts_with`/`not_starts_with`/`ends_with`/`not_ends_with` operator family added to the spec in `2036abd` is entirely unimplemented — every flag using them degrades safely to remote evaluation rather than returning a wrong answer (**Backward-compatible** to add) — [posthog-java.md#n18](posthog-java.md) |
| posthog-dotnet | Feature Flag Called Tracker | Backward-compatible | Same 10-property allowlist gap as every other server SDK audited; otherwise a well-built tracker (incremental eviction, group normalization) — [posthog-dotnet.md#n7](posthog-dotnet.md) |
| posthog-dotnet | Setup | Needs deprecation path | Re-`Init` silently swaps the default client's config today; adding a double-init guard changes behavior some callers may rely on — [posthog-dotnet.md#n20](posthog-dotnet.md) |
| posthog-dotnet | Identify | Breaking or Backward-compatible (implementation-dependent) | Missing/empty `distinctId` silently succeeds today; spec text calls for either a raise (breaking) or drop-with-log (backward-compatible) — [posthog-dotnet.md#n15](posthog-dotnet.md) |

Full contract-by-contract detail (31 posthog-js, 19 posthog-python, 25 posthog-android, 25
posthog-ios, 24 posthog-node, 34 posthog-flutter, 26 posthog-react-native, 16 posthog-php, 16
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
of their tracked contracts (62 for python/ios/node, 59 for the rest pending their next audit) to a
concrete ✅/🟡/❌/➖ status with direct code evidence.

## Pending initial audit

None — all 12 in-scope SDKs have at least one full audit on file.

## Queued for next run

This run's cap (3 SDKs/run) went to **posthog-python, posthog-node, and posthog-ios** — the three
oldest-audited SDKs (2026-08-06), all confirmed code-drifted, and all directly affected by the
three new contracts (Capture AI, Evaluate Flags, Exception Event Metadata) and five prose fixes
merged into sdk-specs since the last run. That leaves **9 SDKs queued**, all of which now also need
the 3 new contract rows added (none of the 9 have them yet — see the row-count note in the roll-up
table above):

| SDK | Last-audited SHA | Last audited | Rows | New-contract rows needed |
|---|---|---|---|---|
| posthog-js | `34a34f3d` | 2026-08-10 | 59 | Yes (+3) |
| posthog-android | `8659a7b4` | 2026-08-10 | 59 | Yes (+3) |
| posthog-java | `8659a7b4` (posthog-android monorepo) | 2026-08-10 | 59 | Yes (+3) |
| posthog-flutter | `05b53dc` | 2026-08-06 | 59 | Yes (+3) |
| posthog-react-native | `e1efa57` (posthog-js monorepo, now well behind current HEAD) | 2026-08-06 | 59 | Yes (+3) |
| posthog-php | `ed93a67` | 2026-08-06 | 59 | Yes (+3) |
| posthog-ruby | `31c187f` | 2026-08-06 | 59 | Yes (+3) |
| posthog-go | `019af19` | 2026-08-06 | 59 | Yes (+3) |
| posthog-dotnet | `e7f20e3` | 2026-08-06 | 59 | Yes (+3) |

Prioritized as follows for upcoming runs, continuing the staleness-backstop rotation now that the
"run-1"/"run-2" cohort (posthog-js, posthog-python, posthog-android, posthog-ios, posthog-node) has
been fully refreshed at least once except js/android themselves (last touched 2026-08-10, so they
still have ~3 weeks of runway before the ~4-week re-verification window closes):
1. **posthog-react-native** — highest priority: it shares the posthog-js monorepo with node (just
   re-audited fresh at `fbdb6c7b`) and js (last touched 2026-08-10), but RN's own recorded SHA
   (`e1efa57`) is now the single most-stale pointer in the whole matrix relative to actual monorepo
   HEAD, and it's also directly affected by the new Surveys intro-screen requirement (RN shipped
   that feature alongside browser, so it should already comply — worth confirming).
2. **posthog-php, posthog-ruby** — "run-3 cohort," confirmed drifted last run, still not
   re-audited; both are server SDKs directly affected by Capture AI/Evaluate Flags (net-new
   contracts to add) plus Exception Event Metadata.
3. **posthog-go, posthog-dotnet** — remainder of the "run-4 cohort"; same new-contract exposure as
   php/ruby.
4. **posthog-flutter** — also confirmed drifted last run (`05b53dc`→newer); lower priority only
   because Capture AI/Evaluate Flags are both N/A for it (client-only), leaving just Exception
   Event Metadata and Surveys-intro-screen as new/changed surface to check.
5. **posthog-js, posthog-android, posthog-java** — least stale (2026-08-10), but still missing all
   3 new contract rows; natural picks once the ~4-week window approaches in early September or if
   a future spec change specifically implicates them.

Every in-scope SDK should still land inside the ~4-week re-verification window this rotation
targets, assuming no further spec changes reprioritize the queue in the meantime.
