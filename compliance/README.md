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
posthog-go, posthog-java, posthog-dotnet. **68 contracts** are now tracked per SDK: the 68
capabilities listed in the root `README.md` table.

**The contract surface grew by four this cycle, all server-scope.** **Emails**
([#159](https://github.com/PostHog/sdk-specs/pull/159)) and the three AI-evaluation capabilities
**AI Datasets**, **AI Scorers** and **Offline Evaluations**
([#137](https://github.com/PostHog/sdk-specs/pull/137), with per-item models added by
[#149](https://github.com/PostHog/sdk-specs/pull/149)) merged between 2026-10-20 and 2026-10-30. Their
applicability differs in a way that matters for scoring: **Emails says "Server SDKs only"
unconditionally**, so an unimplemented Emails row on a server SDK is ❌, while the three AI capabilities
scope themselves to "server SDKs **that implement**" them, so an unimplemented row is ➖. Client SDKs
take ➖ on all four.

**Row-count status.** The three SDKs audited this run (posthog-python, posthog-node, posthog-java) are
at the full 68 rows, and posthog-java's long-standing 59-row shortfall is closed. **The other nine
SDKs are at 64 or 63 and need the four new rows backfilled** — a mechanical addition for the six client
SDKs (four ➖ each) and a real scoring question only for posthog-php, posthog-ruby, posthog-go and
posthog-dotnet, where the Emails row is a genuine ❌/✅ call. posthog-php and posthog-ruby additionally
still need the MCP Analytics row (➖ for both).

**Two scope questions for a human, raised by this cycle's specs.** (1) **posthog-rs** is now named in
the `mcp-analytics` applicability table with a concrete surface (`posthog_rs::mcp`, feature `mcp`,
rmcp adapter), added by [#150](https://github.com/PostHog/sdk-specs/pull/150). By the rule "include
only SDKs the specs actually reference" it has become in-scope and should enter the matrix pending
initial audit; this run did not add it unilaterally. (2) **posthog-kmp** and **posthog-unity** are
mentioned in `session-replay-privacy` ([#160](https://github.com/PostHog/sdk-specs/pull/160)) — kmp as
delegating to posthog-android, unity as "a named follow-up" that does not implement the requirement
yet. These are single-spec remarks rather than enumerated surfaces, so they are weaker candidates than
posthog-rs. See "Scope decisions needed" below.

**No SDK is pending its first audit.** Every run since the backlog drained has been a re-audit
run, and selection is driven by the four-rule priority order at the top of this file.
## This run (2026-11-02)

**Three SDKs audited: posthog-java, posthog-node, posthog-python** — the full three-slot cap, and the
whole server cohort that the cycle's spec delta lands on.

**sdk-specs advanced from `898b669` to `be25182`: 20 commits touching `openspec/specs/`, including
four new capabilities.** The changes that drove this run's selection and findings:

- **Four new server-scope capabilities** — Emails
  ([#159](https://github.com/PostHog/sdk-specs/pull/159)), AI Datasets, AI Scorers and Offline
  Evaluations ([#137](https://github.com/PostHog/sdk-specs/pull/137),
  [#149](https://github.com/PostHog/sdk-specs/pull/149)). Every one of them names posthog-python
  and/or posthog-node as its reference surface, which is rule 1 pointing squarely at this cohort.
- **Retry Queue** ([#132](https://github.com/PostHog/sdk-specs/pull/132)) — ingestion retry backoff
  SHOULD be jittered, scaling the computed delay rather than replacing the schedule, with
  `Retry-After` still a floor applied after jitter.
- **Shutdown** ([#135](https://github.com/PostHog/sdk-specs/pull/135)) — a shutdown timeout bounds the
  *whole* teardown drain, not each delivery within it; once the budget is gone the SDK stops, starts no
  further flush, returns normally, and reports once.
- **Evaluate Flags / Get Feature Flag Result**
  ([#111](https://github.com/PostHog/sdk-specs/pull/111), building on
  [#109](https://github.com/PostHog/sdk-specs/pull/109)) — snapshot enablement and value accessors
  SHALL take a per-read `sendFeatureFlagEvents`; payload accessors, key enumeration and in-memory
  filters SHALL NOT. An omitted option uses the client-level default where the SDK has one.
- **HTTP Client** ([#81](https://github.com/PostHog/sdk-specs/pull/81)) — request body compression and
  its opt-out. Server SDKs may default to no compression and may express the control as a boolean or
  an enum, so this is a light requirement on this cohort; the hard rule is that a server rejection
  must never silently downgrade to an uncompressed resend.
- **MCP Analytics** ([#150](https://github.com/PostHog/sdk-specs/pull/150),
  [#157](https://github.com/PostHog/sdk-specs/pull/157)) — #150 reconciles three redaction rules and
  **explicitly records that the SDKs, not the spec, must change on one of them**: object keys get the
  same passes as string values. #157 adds the common-prefix margin rule for long keys.
- Also: **Flag Definition Loader** ([#88](https://github.com/PostHog/sdk-specs/pull/88)) optional
  polling opt-out (a MAY, so it creates no gap); **Capture Exception**
  ([#124](https://github.com/PostHog/sdk-specs/pull/124)) fatal-path serializer parity (applies only
  where an SDK has a separate fatal serializer); and several client-scoped changes
  ([#143](https://github.com/PostHog/sdk-specs/pull/143) capture precedence,
  [#127](https://github.com/PostHog/sdk-specs/pull/127) rate-limiter clock bound,
  [#121](https://github.com/PostHog/sdk-specs/pull/121) survey popup delay,
  [#155](https://github.com/PostHog/sdk-specs/pull/155) replay debug precedence,
  [#160](https://github.com/PostHog/sdk-specs/pull/160) Android FLAG_SECURE) that this run's cohort is
  not exposed to.

**Selection.** Rules 1, 2 and 4 all point the same way:

- **Rule 1 (spec-affected).** All four new capabilities are server-scope and none of the client SDKs
  can score anything but ➖ on them. Of the six server SDKs, posthog-python and posthog-node are the
  named reference surfaces and posthog-java is the only one whose Emails row could plausibly have
  changed without anyone noticing.
- **Rule 2 (changed since last audit).** All three drifted: posthog-java `8659a7b4`→`8309f837`
  (+2,099/−345 lines in `posthog-server/src/main` alone), posthog-node `4f590b36`→`8c832754`,
  posthog-python `509c8525`→`dca22075` (+19,800 lines in `posthog/`, excluding tests).
- **Rule 4 (staleness backstop).** posthog-java's pointer was **12 weeks** old, the only one outside
  the ~4-week window by more than a few days, and it was the last SDK short of the full contract list.
  posthog-node and posthog-python were both three weeks old — inside the window, but chosen on rules 1
  and 2 rather than staleness.

**What this run deliberately did not do.** It did not re-derive all 68 rows for any of the three SDKs.
Each per-SDK file states its own scope in the header and marks which rows carry forward unverified
from the previous audit. posthog-java's forward-carried set is the largest and is the first thing to
spend its next slot on.

### The matrix has no Unknown cells for the first time

posthog-node's **Traces ❓→✅** was the last one, and it was queued specifically for this run.
`packages/core/src/traces/` (8,190 lines) was read against all of `openspec/specs/traces/spec.md`:
the `startSpan`/`withSpan`/`getActiveSpan` surface, the thirteen configuration knobs with their
positive-integer fallbacks, the off-until-configured gate, the OTLP transport with bearer auth and
gzip, and the error-handling policy. It passes each of them, and in places implements the spec's
reasoning rather than just its outcome — the retry budget is charged per *backoff window* rather than
per attempt, a caller-driven flush is explicitly exempted from charging, and the batch size ramps back
up by one per healthy send after a 413 shrink. See [posthog-node.md#n2](posthog-node.md).

This closes a two-run correction: the row was ❌ on 2026-10-12 (a false negative — the grep missed a
pipeline that had merged four weeks earlier), ❓ on 2026-10-19, and is now scored.

### posthog-java: the first SDK with feature-flag negative knowledge

Seven server SDKs have now been checked against the `evaluate-flags` requirement that an SDK remember
a key was absent from both its local definitions and a clean remote fallback. Six — php, ruby, go,
dotnet, python, node — lack it entirely. **posthog-java has it, and has it properly.**
`PostHogFeatureFlags.kt` carries a capacity-bounded `knownMissingFlagKeys` store, a
`missingFlagKeysGeneration` counter invalidated on every successful definitions refresh, and an
`inFlightMissingFlagProbes` map so concurrent callers for the same key wait on one probe instead of
each issuing a `/flags` request. A response is matched against the generation it was issued under, so
a refresh landing mid-probe cannot install stale negative knowledge.

That matters beyond one row: **the remediation written on six other SDK pages now has a first-party
reference implementation** instead of a description. See [posthog-java.md#n27](posthog-java.md).

posthog-java's Evaluate Flags row is still 🟡, on a narrower and newer gap: its snapshot accessors
`isEnabled(key)` and `getFlag(key)` take no per-read `sendFeatureFlagEvents`, which #111 now requires.
posthog-node already satisfies that requirement; posthog-python does not.

### posthog-python passes all four new contracts

It is the only SDK that does, and that is close to tautological — it is the named reference surface
for all four — but each was checked against the spec rather than assumed, and the checks found the
implementation genuinely faithful on the details that are easiest to get wrong: the complete
response → error-name table for Emails including both 409, both 422 and both 429 branches; the
per-operation page limits and caps across datasets, revisions, items and item versions; the
offset-versus-cursor split in scorers; and #149's per-item `model_version`, validated locally,
carried in the item's immutable encoded JSON, and rejected before any I/O when two results declare
conflicting models for one item UUID. See [n21]–[n24] in
[posthog-python.md](posthog-python.md).

Its other movement this run is a quiet improvement that closes half of an existing note: tracing-header
extraction is no longer Django-only. `posthog/integrations/` now carries `flask.py`, `asgi.py` and
`drf.py` sharing a new `_tracing_headers.py`.

### posthog-java's exception envelope is the worst row added this run

**Exception Event Metadata ❌ on first scoring**, and it fails four `exception-event-metadata` rules at
once: `mechanism.synthetic` is the literal `false` on every entry (the spec says "A producer MUST NOT
default unknown synthetic state to `false`"); `mechanism.source` is never emitted, with the parent edge
smuggled into `type` as `"suppressed"`; `exception_id` is omitted entirely on single-entry lists where
the spec unconditionally requires `0`; and `handled` is resolved once and copied onto every cause.

This is **shared-core code** (`ThrowableCoercer.kt` in the `posthog` module), so it is the same defect
posthog-android carries and one fix closes both rows. posthog-java does do one thing posthog-android
does not: it sets `$exception_source` from the concrete runtime hook. See
[posthog-java.md#n29](posthog-java.md).

### The jitter requirement is unmet across the whole cohort

[#132](https://github.com/PostHog/sdk-specs/pull/132) is SHOULD-tier, and **all three SDKs audited this
run fail it**, each for a slightly different reason worth recording separately:

- **posthog-python** has a correct exponential progression with `Retry-After` as a floor and a shared
  ceiling — and no randomness anywhere on the path.
- **posthog-node** *ships* a correct jitter helper (`packages/core/src/utils/backoff.ts`, with the
  `Retry-After` floor applied after jitter), but uses it **only** in the logs and traces OTLP queues.
  The analytics-events ingestion queue still waits a **fixed 3,000 ms** per attempt through
  `retriable()` — no exponential progression, no jitter, no `Retry-After` handling at all. This is
  shared `@posthog/core` code, so posthog-react-native and posthog-browser inherit it.
- **posthog-java** uses a linear 5 s → 60 s progression with no randomness and no visible `Retry-After`
  handling.

posthog-node is the cheapest fix of the three and the highest-leverage: the helper it needs is already
in the same package.

## Roll-up

| SDK | Overall | ✅ | 🟡 | ❌ | ➖ | ❓ | Last audited | Open gaps | File |
|---|---|---|---|---|---|---|---|---|---|
| posthog-js | 26/64 fully compliant (41%; **64 rows, needs +4 new contracts**) | 26 | 21 | 12 | 5 | 0 | 2026-10-05 · `6538babc` (targeted re-audit; most of the 59 pre-existing rows carried from 2026-08-10, see file header) | 33 | [posthog-js.md](posthog-js.md) |
| posthog-python | 17/68 fully compliant (25%; 30 contracts N/A on a server SDK) | 17 | 16 | 5 | 30 | 0 | 2026-11-02 · `dca22075` (targeted re-audit — see file header) | 21 | [posthog-python.md](posthog-python.md) |
| posthog-android | 37/64 fully compliant (58%; **64 rows, needs +4 new contracts**) | 37 | 16 | 5 | 6 | 0 | 2026-10-19 · `c5e788bd` (targeted re-audit — see file header) | 21 | [posthog-android.md](posthog-android.md) |
| posthog-ios | 38/64 fully compliant (59%; **64 rows, needs +4 new contracts**) | 38 | 16 | 4 | 6 | 0 | 2026-10-08 · `f5cbe87c` + PostHog/posthog-ios#924–#934 (out-of-cycle refresh, see below) | 20 | [posthog-ios.md](posthog-ios.md) |
| posthog-node | 11/68 fully compliant (16%; 32 contracts N/A on a server SDK) | 11 | 21 | 4 | 32 | 0 | 2026-11-02 · `8c832754` (posthog-js monorepo; targeted re-audit — see file header) | 25 | [posthog-node.md](posthog-node.md) |
| posthog-flutter | 21/64 fully compliant (33%; **64 rows, needs +4 new contracts**) | 21 | 29 | 6 | 8 | 0 | 2026-10-19 · `1032c102` | 35 | [posthog-flutter.md](posthog-flutter.md) |
| posthog-react-native | 29/64 fully compliant (45%; **64 rows, needs +4 new contracts**) | 29 | 27 | 3 | 5 | 0 | 2026-10-19 · `3ddaa654` (posthog-js monorepo) | 30 | [posthog-react-native.md](posthog-react-native.md) |
| posthog-php | 11/63 fully compliant (17%; 33 contracts N/A on a server SDK; **needs +5: MCP Analytics and the four new contracts**) | 11 | 11 | 8 | 33 | 0 | 2026-09-28 · `5451f4e0` | 19 | [posthog-php.md](posthog-php.md) |
| posthog-ruby | 9/63 fully compliant (14%; 33 contracts N/A on a server SDK; **needs +5: MCP Analytics and the four new contracts**) | 9 | 13 | 8 | 33 | 0 | 2026-09-28 · `185060ab` | 21 | [posthog-ruby.md](posthog-ruby.md) |
| posthog-go | 8/64 fully compliant (13%; 33 contracts N/A on a server SDK; **64 rows, needs +4 new contracts**) | 8 | 14 | 9 | 33 | 0 | 2026-10-05 · `08549f42` | 23 | [posthog-go.md](posthog-go.md) |
| posthog-java | 12/68 fully compliant (18%; 33 contracts N/A on a server SDK) | 12 | 14 | 9 | 33 | 0 | 2026-11-02 · `8309f837` (posthog-android monorepo; row completion + targeted re-audit — see file header) | 23 | [posthog-java.md](posthog-java.md) |
| posthog-dotnet | 5/64 fully compliant (8%; 30 contracts N/A on a server SDK; **64 rows, needs +4 new contracts**) | 5 | 19 | 10 | 30 | 0 | 2026-10-05 · `ae4d019c` | 29 | [posthog-dotnet.md](posthog-dotnet.md) |

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
**Row-count note (2026-11-02):** the contract list is now **68**. The three SDKs audited this run —
posthog-python, posthog-node and posthog-java — carry all 68, and posthog-java's 59-row shortfall,
open since the matrix's 64-row expansion, is closed. The other nine sit at 64 (posthog-js,
posthog-android, posthog-ios, posthog-flutter, posthog-react-native, posthog-go, posthog-dotnet) or
63 (posthog-php, posthog-ruby). For the six **client** SDKs the backfill is mechanical: all four new
contracts are server-scope and score ➖. For **posthog-go and posthog-dotnet** it is a real scoring
question on one row — Emails is unconditional for server SDKs, so it is a ❌/✅ call, while the three
AI capabilities are ➖ unless the SDK implements them. **posthog-php and posthog-ruby** need those
four plus the still-outstanding MCP Analytics row (➖ for both; the spec's applicability table lists
Ruby as "not yet" and does not mention PHP).

**Reading this run's numbers.** None of the three audited SDKs regressed on code. posthog-python's ✅
count rose 13→17 entirely on the four new contracts it already implemented, taking it 20%→25% on a
denominator four rows larger. posthog-node went 9→11: Traces resolving ❓→✅ plus Emails ✅, with the
other three new rows ➖ — and its ❓ column reaching zero is what empties the whole matrix's Unknown
count. posthog-java's ✅ count is unchanged at 12 while its denominator grew by nine, so its headline
fell 20%→18%; that is entirely denominator growth plus two genuine new ❌ rows (Emails, Exception
Event Metadata) and one row whose N/A basis was withdrawn (Traces ➖→❌, because the "no SDK implements
this yet" reasoning stopped being true once posthog-python and posthog-node shipped it). Its real
movement this run is a row that stayed 🟡 — Evaluate Flags — while containing the matrix's first
working negative-knowledge implementation. Percentages that move because the denominator grew are not
regressions; the per-SDK files mark which direction each row moved and why. Earlier runs' notes on
posthog-js, posthog-go, posthog-dotnet, posthog-android, posthog-react-native and posthog-flutter
still stand.

"Overall" for posthog-python, posthog-node, posthog-php, posthog-ruby, posthog-go, posthog-java,
and posthog-dotnet is computed against the contracts actually applicable to a server SDK
(posthog-python: 17 Pass / 38 applicable = 45%; posthog-node: 11 Pass / 36 applicable = 31%;
posthog-php: 11 Pass / 30 applicable = 37%; posthog-ruby: 9 Pass / 30 applicable = 30%;
posthog-go: 8 Pass / 31 applicable = 26%; posthog-java: 12 Pass / 35 applicable = 34%;
posthog-dotnet: 5 Pass / 34 applicable = 15%); shown above as raw Pass/(63, 64 or 68) for
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
`posthog-android` SHA — `8309f837` as of this run. The two SDKs no longer share an audited commit:
posthog-android sits at `c5e788bd` (2026-10-19) and posthog-java at `8309f837` (2026-11-02). Several
of java's findings are in the shared `posthog/` core module and therefore apply to both — the
Exception Event Metadata envelope and the `aliasStateless()` validation gap in particular — so fixes
there close rows on two pages at once.

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
| posthog-java | Exception Event Metadata | **Needs deprecation path** (partly backward-compatible) | Four rules broken at once in shared core: `synthetic` hardcoded `false`, no `mechanism.source`, `exception_id` omitted on single-entry lists, `handled` copied onto every cause. Fixing it also closes the matching posthog-android row — [posthog-java.md#n29](posthog-java.md) |
| posthog-java | Emails | Backward-compatible | Not implemented; the Emails spec applies to server SDKs unconditionally — [posthog-java.md#n28](posthog-java.md) |
| posthog-java | Traces | Backward-compatible | No `/i/v1/traces` pipeline. Its `otel/` package enriches the application's own OpenTelemetry spans and is a different capability; the previous ➖ rested on "no SDK implements this yet", which python and node have since made false — [posthog-java.md#n26](posthog-java.md) |
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
| posthog-python | Retry Queue | Backward-compatible | **New this run** — correct exponential backoff with `Retry-After` as a floor, but no jitter anywhere, so a refused fleet returns in lockstep (#132) — [posthog-python.md#n16](posthog-python.md) |
| posthog-python | MCP Analytics | Backward-compatible | **New this run** — object keys are copied verbatim instead of getting the same redaction passes as string values, which [#150](https://github.com/PostHog/sdk-specs/pull/150) records as an SDK-side change; plus the two pre-existing optional-event gaps — [posthog-python.md#n20](posthog-python.md) |
| posthog-node | Retry Queue | Backward-compatible | **New this run** — the package ships a correct jitter helper but uses it only for logs and traces; the analytics-events queue still waits a fixed 3,000 ms with no backoff and no `Retry-After` (shared `@posthog/core`, so react-native and browser inherit it) — [posthog-node.md#n25](posthog-node.md) |
| posthog-java | Evaluate Flags | Backward-compatible | **New row** — the matrix's only working negative-knowledge implementation, but its snapshot accessors take no per-read `sendFeatureFlagEvents` (#111) and `isEnabled` takes no caller default — [posthog-java.md#n27](posthog-java.md) |
| posthog-java | Local Feature Flag Evaluator | Backward-compatible | **Re-assessed** — the `starts_with`/`ends_with` operator family is now implemented, but experiment holdouts are still absent, so a holdout flag's local answer diverges from the backend — [posthog-java.md#n18](posthog-java.md) |
| posthog-java | Retry Queue | Backward-compatible | **New this run** — linear 5 s→60 s backoff with no jitter and no visible `Retry-After` handling (#132) — [posthog-java.md#n21](posthog-java.md) |
| posthog-python | HTTP Client | Backward-compatible | **Downgraded from ✅ on new spec text** — a blanket `except requests.exceptions.ConnectionError` retries a *refused* flags connection, which the spec now says SHALL NOT be retried — [posthog-python.md#n18](posthog-python.md) |
| posthog-python | Local Feature Flag Evaluator | Backward-compatible | **Downgraded from ✅ on new spec text** — holdouts *are* implemented (first SDK in this matrix), but a boolean group key buckets on Python's `"True"` spelling instead of going inconclusive — [posthog-python.md#n19](posthog-python.md) |
| posthog-python | Evaluate Flags | Backward-compatible | No negative-knowledge retention (a deleted key re-probes `/flags` forever), and **new this run** its snapshot accessors take no per-read `sendFeatureFlagEvents`, which #111 now requires — [posthog-python.md#n17](posthog-python.md) |
| posthog-python | MCP Analytics | Backward-compatible | **New this run** — `posthog/mcp` is a strong first implementation with the exact 102,400-byte bound, but neither `$mcp_unknown_tool` nor `$mcp_input_required` ships, and the `$exception` side-car omits `$exception_source: "mcp.tool_call"` and never sets `synthetic` — [posthog-python.md#n20](posthog-python.md) |
| posthog-node | Capture | Backward-compatible | **New this run** — `$release_id` is resolved and trimmed correctly but applied only on the exception paths, so ordinary captures, `alias`, `groupIdentify` and `identify` carry none — [posthog-node.md#n5](posthog-node.md) |
| posthog-node | Exception Event Metadata / Capture Exception | Mixed (see notes) | **Both upgraded from ❌** — `@posthog/core` now emits `exception_id`/`parent_id` linkage with no inherited `handled`, and the uncaught listeners pass real metadata; three gaps remain (no `$exception_source`, hardcoded `$exception_level: 'error'`, caller bag overrides reserved keys), all in shared code that posthog-js and posthog-react-native inherit — [posthog-node.md#n20](posthog-node.md) |
| posthog-node | Is Feature Enabled | Backward-compatible | **Upgraded from ❌** — `FeatureFlagEvaluations.isEnabled(key, { defaultValue })` now satisfies the hard caller-default `SHALL`; only the legacy getter lacks it — [posthog-node.md#n13](posthog-node.md) |
| posthog-node | Evaluate Flags | Backward-compatible | No negative-knowledge retention. #111's per-read `sendFeatureFlagEvents` **is** satisfied, unlike python and java — [posthog-node.md#n10](posthog-node.md) |
| posthog-node | MCP Analytics | Backward-compatible | **New this run** — `@posthog/mcp` emits neither optional event and misreports an unknown tool as a failed `$mcp_tool_call`; see the ownership question above about whether this row belongs to node or js — [posthog-node.md#n26](posthog-node.md) |
| posthog-node | Local Feature Flag Evaluator | Backward-compatible | Holdouts **are** implemented in `@posthog/core`, and the acceptance-asset sync gap is unchanged; new this run, a non-scalar group key buckets on `"true"` / `"[object Object]"` instead of going inconclusive — [posthog-node.md#n24](posthog-node.md) |
| posthog-ios | Exception Event Metadata | Backward-compatible | Chain linkage, 50-entry cap, `$exception_source`, empty `value` and UUID-less image filtering land in PostHog/posthog-ios#931; caller properties can still override `$exception_level`/`$exception_source` on purpose (no typed level parameter yet, and Android/JS behave the same) — [posthog-ios.md#n19](posthog-ios.md) |
| posthog-android | Consent Gating | Backward-compatible | `optOut()` never stops an active replay session, and session-replay start/stop never check `isOptedOut()`, despite session replay being named in this spec's own scope — [posthog-android.md#n5](posthog-android.md#n5) |
| posthog-android | Session Replay Debug Properties | Backward-compatible | **New this run** — the most complete implementation outside the browser, but no required/optional tiering and no 30s throttle (the whole bundle rides every event) — [posthog-android.md#n17](posthog-android.md#n17) |
| posthog-android | Exception Event Metadata | Needs deprecation path | **New this run** — linkage, 50-cap and cycle detection are all correct, but `synthetic` is a hardcoded `false` (the spec's explicit "MUST NOT represent unknown with false"), causes inherit `handled`, no `mechanism.source`/`$exception_source`, and `$exception_level` is a *documented* caller override — [posthog-android.md#n7](posthog-android.md#n7) |
| posthog-android | Session Replay Privacy | Needs deprecation path | `ph-no-capture` ignored outside screenshot mode; default capture mode can leak tagged views — [posthog-android.md#n19](posthog-android.md#n19) |
| posthog-android | Surveys | Needs deprecation path | Web-only `url`/`selector`-targeted surveys aren't excluded on Android as the spec requires — [posthog-android.md#n22](posthog-android.md#n22) |
| posthog-ios | Capture | Backward-compatible | **Downgraded from ✅ on new spec text** — `NSNull`-valued properties are serialized as JSON `null` instead of dropped; empty event names are not dropped — [posthog-ios.md#n4](posthog-ios.md) |
| posthog-ios | Session Replay Debug Properties | Backward-compatible | **New row** — tiers, 30 s window and crash-context snapshot conform; gaps on caller-supplied `$session_id`, backdated events, and `active` status after a background session timeout — [posthog-ios.md#n26](posthog-ios.md) |
| posthog-node | Flush / Retry Queue (v1 pipeline) | Needs deprecation path | `V1CaptureSender` never throws on exhausted retry, so failed batches are evicted from the queue as if delivered — [posthog-node.md#n8](posthog-node.md) |
| posthog-node | Feature Flag Called Tracker | Backward-compatible | Allowlist itself is fully compliant (inherited from posthog-js via shared `@posthog/core`), but capacity eviction is a full clear rather than incremental, violating the spec's anti-thundering-herd requirement — [posthog-node.md#n19](posthog-node.md) |
| posthog-flutter | Session Replay Privacy | Backward-compatible | Independent Dart replay pipeline still has no no-capture marker (a nested `PostHogUnmaskWidget` can reveal anything inside `PostHogMaskWidget`); the unmask primitive, shared sensitive-input detection, and fail-closed mask walk have all landed since the previous audit — [posthog-flutter.md#n29](posthog-flutter.md#n29) |
| posthog-flutter | Remote Config | Backward-compatible | **Resolved from ❓** — mobile delegates to the native SDK (✅ there), but the new Dart desktop core never fetches remote config at all, so Windows/Linux clients get no server-side replay or survey gating — [posthog-flutter.md#n26](posthog-flutter.md#n26) |
| posthog-flutter | HTTP Client | Backward-compatible | **Resolved from ❓** — the Dart core retries a refused `/flags` connection (every transport exception is wrapped into one retryable type), and `retriable` has no backoff multiplier — [posthog-flutter.md#n19](posthog-flutter.md#n19) |
| posthog-flutter | Session Replay Debug Properties | Backward-compatible | **New this run** — none of the three `$sdk_debug_replay_*` required keys exist on any platform, and `$recording_status` is emitted only on desktop, where replay does not run — [posthog-flutter.md#n28](posthog-flutter.md#n28) |
| posthog-flutter | Get Feature Flag Payload / Result | Backward-compatible | **Downgraded on new spec text** — the Dart core returns no payload for malformed JSON, but on iOS/macOS the value comes from posthog-ios, which returns the raw string; the fix is in posthog-ios — [posthog-flutter.md#n14](posthog-flutter.md#n14) |
| posthog-flutter | Retry Queue | Needs deprecation path (inherited) | **Resolved from ❓** — desktop and mobile keep failed batches queued, but Flutter Web uses posthog-js's `RetryQueue`, which drops a 429; clears with posthog-js n28 — [posthog-flutter.md#n38](posthog-flutter.md#n38) |
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
desktop (a value-keyed dedup map, cleared on reset), and also the minimal envelope: it persists the
`minimalFlagCalledEvents` gate from `/flags` and applies the allowlist to non-experiment
`$feature_flag_called` events. Its row stays 🟡 only on the embedded Android tracker.
posthog-react-native persists the same gate in `PostHogCore` and reads it back, so its row is ✅. The 2026-08-10 re-audits of posthog-android and posthog-java independently
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

**2026-11-02 — negative knowledge: six for six becomes six for seven, and the seventh is the
reference.** posthog-java implements the requirement in full, and the paragraph above should be read
with that correction. `PostHogFeatureFlags.kt` carries a capacity-bounded `knownMissingFlagKeys`
store, a `missingFlagKeysGeneration` counter invalidated on every successful definitions refresh, and
an `inFlightMissingFlagProbes` map that makes concurrent callers for one key wait on a single probe;
a probe response is matched against the generation it was issued under, so a refresh landing mid-probe
cannot install stale knowledge. That answers the question the paragraph above left open — the
requirement is implementable as written, and the gap on php, ruby, go, dotnet, python and node is a
prioritization fact rather than a spec-difficulty one. **The remediation on those six pages should now
point at `posthog-java`'s implementation** instead of describing one. See
[posthog-java.md#n27](posthog-java.md).

**2026-11-02 — holdouts: still two of seven.** posthog-java, the previously unchecked server SDK named
in the holdout paragraph above, returns zero `grep -rn holdout` matches in `posthog-server/src/main`.
The gap is therefore php, ruby, go, dotnet and java, with python and node as the references. Unchanged
in substance; the "unchecked" qualifier on java is now resolved.

**2026-11-02 — ingestion retry jitter is unmet across the whole server cohort.** sdk-specs
[#132](https://github.com/PostHog/sdk-specs/pull/132) (SHOULD-tier) asks that each ingestion retry wait
be scaled by random jitter so clients refused together do not return together, with `Retry-After`
remaining a floor applied after jitter. All three SDKs audited this run fail it, and the shapes differ
enough to be worth recording: **posthog-python** has a correct exponential progression and
`Retry-After` floor with no randomness; **posthog-java** uses a linear 5 s→60 s progression with no
randomness and no visible `Retry-After` handling; and **posthog-node** is the odd one — it *ships* a
spec-shaped jitter helper (`packages/core/src/utils/backoff.ts`, jitter applied to the SDK's own delay
with the header as a floor) but wires it only into the logs and traces OTLP queues, leaving the
analytics-events queue on a **fixed 3,000 ms** retry with no backoff curve at all. Because that queue
is shared `@posthog/core` code, posthog-react-native and posthog-browser inherit it, which makes
posthog-node both the cheapest fix and the one with the widest blast radius. The four server SDKs not
yet checked against #132 (php, ruby, go, dotnet) should be scored for it at their next audits.

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
and a `disabled` fallback, deviating only on tiering/throttling;
**posthog-flutter has none of the three `$sdk_debug_replay_*` keys** and emits `$recording_status`
only on the one platform where replay does not run; and **posthog-react-native has nothing at all**
despite owning a real replay integration and already computing most of the state. Since both
flutter and react-native embed native SDKs for replay, the cheapest path for both is to surface what
android already computes across the bridge rather than reimplement it.
## Unknown (❓) cells needing human review

**None. For the first time since the matrix was created, every cell has a definite status.**

posthog-node's Traces row was the last one and it resolved to ✅ this run after a full read of
`packages/core/src/traces/` against `openspec/specs/traces/spec.md` — see
[posthog-node.md#n2](posthog-node.md) and "The matrix has no Unknown cells for the first time" above.
That closes a two-run correction: ❌ (false negative) on 2026-10-12, ❓ on 2026-10-19, ✅ now.

**No new Unknown was introduced this run.** Every one of the thirteen rows scored from scratch —
four each on posthog-python and posthog-node, nine on posthog-java — resolved against directly cited
code. Where this run could not establish something cheaply, it said so inside the relevant note
rather than opening a cell: posthog-java's group-key rendering under
[#89](https://github.com/PostHog/sdk-specs/pull/89) is recorded as unconfirmed inside
[posthog-java.md#n18](posthog-java.md) rather than as a separate ❓.

## Scope decisions needed (human)

These are not compliance findings; they are questions about what the matrix should cover. This run
did not act on any of them unilaterally.

1. **posthog-rs should probably enter the matrix.**
   [#150](https://github.com/PostHog/sdk-specs/pull/150) added it to the `mcp-analytics` applicability
   table with a concrete surface — `posthog_rs::mcp`, feature `mcp`, rmcp adapter — and the spec's
   library-identity section names `posthog-rs-mcp` as its `$lib`. It is also cited in
   `openspec/specs/capture/spec.md` as one of two SDKs defaulting enrichment on. By the "include only
   SDKs the specs actually reference" rule that is enough. Adding it means a 13th per-SDK file and one
   more slot in the ~4-week rotation.
2. **posthog-kmp and posthog-unity are weaker candidates.** Both appear only in
   `session-replay-privacy` ([#160](https://github.com/PostHog/sdk-specs/pull/160)) — kmp as
   conforming once its pinned posthog-android version does, unity as an explicit named follow-up that
   does not implement the requirement yet. A single-spec remark about delegation is thinner evidence
   of in-scope status than an enumerated package surface, so these are left out pending a decision.
3. **posthog-java's Traces row needs a direction, not just a fix.** It is scored ❌ because the
   capability applies and is unimplemented, but the JVM may reasonably take the position that
   applications bring their own OpenTelemetry SDK and PostHog only enriches it — which is what
   `PostHogContextSpanProcessor` does today. If that is the intent, it belongs in
   `openspec/specs/traces/spec.md` as an applicability carve-out rather than sitting as a permanent ❌.
4. **posthog-python's Shutdown row sits on an ambiguity.**
   [#135](https://github.com/PostHog/sdk-specs/pull/135)'s rules are conditioned on "Where `shutdown`
   takes or defaults to a timeout", and posthog-python's `shutdown()` takes none — but the
   requirement's acceptance scenarios are tagged `@both` and call shutdown *with* a timeout. Either
   the conditional makes them inapplicable to a no-timeout surface, or server SDKs must grow a timeout
   parameter. See [posthog-python.md#n11](posthog-python.md).

## Pending initial audit

None of the twelve current in-scope SDKs. **posthog-rs would be the first entry here** if the scope
decision above goes that way.

## Queued for next run

This run used all 3 slots (**posthog-java**, **posthog-node**, **posthog-python**). That leaves
**9 SDKs queued**, and for the first time the queue is dominated by a **row backfill** rather than by
staleness: nine of the twelve files need the four new server-scope contracts added.

| SDK | Last-audited SHA | Last audited | Rows | Weeks since | Backfill needed |
|---|---|---|---|---|---|
| posthog-php | `5451f4e0` | 2026-09-28 | 63 | 5 | +5 (MCP Analytics + the four new) |
| posthog-ruby | `185060ab` | 2026-09-28 | 63 | 5 | +5 (MCP Analytics + the four new) |
| posthog-go | `08549f42` | 2026-10-05 | 64 | 4 | +4 |
| posthog-dotnet | `ae4d019c` | 2026-10-05 | 64 | 4 | +4 |
| posthog-js | `6538babc` | 2026-10-05 | 64 | 4 | +4 (all ➖) |
| posthog-ios | `f5cbe87c` | 2026-10-08 | 64 | 3.5 | +4 (all ➖) |
| posthog-android | `c5e788bd` | 2026-10-19 | 64 | 2 | +4 (all ➖) |
| posthog-flutter | `1032c102` | 2026-10-19 | 64 | 2 | +4 (all ➖) |
| posthog-react-native | `3ddaa654` | 2026-10-19 | 64 | 2 | +4 (all ➖) |

Prioritized for upcoming runs:

1. **posthog-php and posthog-ruby** — now the two stalest pointers (5 weeks, just past the ~4-week
   window) and the two with the largest backfill. Both are also the SDKs whose Emails row is a real
   scoring question rather than a mechanical ➖, and both carry the Exception Event Metadata defect
   family that this run characterized from a third angle on posthog-java. Two slots.
2. **posthog-go and posthog-dotnet** — 4 weeks, at the edge of the window, each needing the same
   four-row backfill with one genuine Emails call. Either makes a sensible third slot. posthog-go has
   the additional pull of being named in the `mcp-analytics` table alongside the SDKs that #150 says
   must change their object-key redaction, which this run confirmed is still unfixed on posthog-python
   and is likely unfixed there too.
3. **A half-slot backfill sweep over the five client SDKs** (posthog-js, posthog-ios,
   posthog-android, posthog-flutter, posthog-react-native). All four new contracts are server-scope,
   so these twenty rows are ➖ with a one-line justification each. This is cheap and gets the whole
   matrix onto one denominator; fold it into whichever run has spare capacity rather than spending a
   slot. **Do not** let it displace a real audit.
4. **posthog-java's forward-carried rows.** This run completed its row count and re-derived the rows
   the drift and spec delta land on, but a large share of its 68 rows still rest on 2026-08-10
   evidence against a module that has moved +2,099 lines since. Its next slot should be a full
   re-derivation rather than another targeted pass.
5. **posthog-rs**, if the scope decision adds it — it would enter as pending initial audit and should
   take a full slot, not a corner of one.

**Rotation health.** Pointer ages after this run: php/ruby 5 weeks, go/dotnet/js 4, ios 3.5,
android/flutter/react-native 2, and java/node/python 0. **php and ruby are the only two outside the
~4-week window**, both by about a week, and both are first in the queue. The rotation is healthy; the
backlog that replaced the old staleness problem is row completion, which is cheaper per row and does
not require re-reading an SDK.
