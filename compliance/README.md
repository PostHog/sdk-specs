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
posthog-go, posthog-java, posthog-dotnet. **69 contracts** are tracked per SDK: the 69 capabilities
listed in the root `README.md` table, unchanged this cycle.

**Row-count status.** Eight of the twelve files are at the full 69 rows: posthog-php, posthog-ruby,
posthog-go (2026-11-09), posthog-js and posthog-dotnet (this run), and posthog-android, posthog-ios
and posthog-flutter from the out-of-cycle 4.0/6.0 audits merged to `main`. posthog-python,
posthog-node and posthog-java sit at 68 and need only **Experiment Exposure**; **posthog-react-native
is the last file at 64** and needs five rows, all of them mechanical ➖ on a client SDK reading
`/flags?v=2`. **Every row where the backfill was a genuine scoring question has now been scored** —
posthog-dotnet's Emails row, the last of them, resolved ✅ this run.

**This branch and `main` carry different work, and both are reflected here.** The weekly rotation's
2026-11-02, 2026-11-09 and 2026-11-16 runs live in this PR and are not on `main`. Meanwhile `main`
merged four out-of-cycle audits this run did not perform — posthog-ios 4.0
([#187](https://github.com/PostHog/sdk-specs/pull/187)), posthog-flutter 6.0
([#200](https://github.com/PostHog/sdk-specs/pull/200)), posthog-android's capture rows for 4.0
([#186](https://github.com/PostHog/sdk-specs/pull/186)) and posthog-react-native's plugin 3.0 rows
([#201](https://github.com/PostHog/sdk-specs/pull/201)). This run merged `main` in and **kept those
four files as `main` has them**: each is newer and more thorough than the rotation pointer it
replaced. Their roll-up rows, gap entries and last-audited dates below come from those audits.

**Two scope questions for a human are still open from last cycle** — the `mcp-analytics`
applicability table listing posthog-ruby as "not yet" while the gem ships an `lib/posthog/mcp/`
package, and whether **posthog-rs** should enter the matrix as a 13th SDK. **A third is new this
run:** three files are now audited against unreleased release branches (posthog-ios 4.0,
posthog-android 4.0, posthog-flutter 6.0) while the rest are audited against shipped default
branches, so "last audited" no longer means the same thing in every row. See "Scope decisions
needed" below.

**No SDK is pending its first audit.**

## This run (2026-11-16)

**Two SDKs fully audited — posthog-js and posthog-dotnet — plus a spec-delta check on posthog-ios.**
posthog-ios was selected as the third slot on the branch's own pointer (2026-10-08), but merging
`main` revealed an out-of-cycle **posthog-ios 4.0 audit** merged six days ago
([#187](https://github.com/PostHog/sdk-specs/pull/187)), at the 4.0 release branch, covering all 69
rows against specs through `752f899`. Re-auditing the shipped 3.97.2 branch on top of that would have
replaced newer, better work with older work, so this run kept `main`'s file and instead checked only
what `openspec/specs/` changed *after* that audit's baseline — three applicable changes, one of which
moves a row. The same applies to posthog-android, posthog-flutter and posthog-react-native, whose
out-of-cycle audits `main` also carries. **The third slot was effectively spent on reconciliation
rather than a third audit; posthog-react-native inherits it next run.**

**sdk-specs advanced from `e08cbc0` to `6968122`: 16 commits touching `openspec/specs/`, no new
capability.** The changes that drove this run's selection and findings:

- **Feature flags, four related changes.** *Empty variant reads as disabled*
  ([#193](https://github.com/PostHog/sdk-specs/pull/193)) — a flag whose value is `""` reads
  `enabled: false, variant: ""`, `is-feature-enabled` returns `false`, a result list keeps the entry
  as disabled, a payload-carrying listener drops it, and `$active_feature_flags` leaves it out.
  *Failed remote flag handling* ([#211](https://github.com/PostHog/sdk-specs/pull/211)) — a per-flag
  `failed: true` record is not an evaluated result, is excluded from bulk reads and payloads,
  must not overwrite a successful local decision, and produces `evaluation_failed` rather than
  `flag_missing` on `$feature_flag_called`, independently of `errorsWhileComputingFlags`.
  *Local feature enrollment* ([#178](https://github.com/PostHog/sdk-specs/pull/178)) — a new
  pre-targeting check on `$feature_enrollment/<key>` with its own inconclusive rules.
  *`$feature_flag_variant_key`* ([#203](https://github.com/PostHog/sdk-specs/pull/203)) — the config
  version 2 attribution property is renamed.
- **MCP Analytics, five changes** ([#185](https://github.com/PostHog/sdk-specs/pull/185),
  [#212](https://github.com/PostHog/sdk-specs/pull/212),
  [#184](https://github.com/PostHog/sdk-specs/pull/184),
  [#192](https://github.com/PostHog/sdk-specs/pull/192)) — `$mcp_session_source`, the
  `$mcp_error_status` derivation, the error classifier and `$mcp_error_expected`, and the error
  message capture option.
- **Capture** ([#215](https://github.com/PostHog/sdk-specs/pull/215)) — set-like and listed sequence
  property values serialize as arrays, with a per-runtime table; an SDK must not send them as `{}`,
  `null`, or a stringified container, and must not drop the property.
- **Opt In** ([#199](https://github.com/PostHog/sdk-specs/pull/199)) — deferred crash reports honour
  consent at crash time: a crash recorded while opted out is never sent, and a consented report found
  by an opted-out launch waits for opt-in rather than being discarded.
- **Session replay** ([#197](https://github.com/PostHog/sdk-specs/pull/197),
  [#139](https://github.com/PostHog/sdk-specs/pull/139)) — wireframe recording and the
  `screenshotMode` / `screenshot` options are removed from the privacy and debug-property contracts
  on the basis that posthog-ios 4.0 and posthog-android 4.0 dropped them.
- Also: **Remote Config** ([#198](https://github.com/PostHog/sdk-specs/pull/198)) adds `quotaLimited`
  to the wire-field table, **Tracing Headers** ([#116](https://github.com/PostHog/sdk-specs/pull/116))
  adds an off-by-default posthog-js cookie fallback for server SDKs, and **Exception Event Metadata**
  ([#205](https://github.com/PostHog/sdk-specs/pull/205)) fixes the handled state for job retries.

**Selection.** Rules 1, 2 and 4 converge on the two SDKs audited in full:

- **Rule 4 (staleness backstop).** posthog-js and posthog-dotnet were the two oldest pointers at
  **6 weeks**, and after the out-of-cycle audits `main` carries they are the only two that were
  outside the ~4-week window at all.
- **Rule 1 (spec-affected).** posthog-js owns `@posthog/mcp`, which five of this cycle's commits land
  on; posthog-dotnet was the one SDK whose outstanding backfill contained a real ❌/✅ call.
- **Rule 3 is empty** — no SDK is pending an initial audit — and **rule 2** applies to both:
  posthog-js `6538babc`→`6b5843e0` (1.450.0, `@posthog/mcp` 1.2.2), posthog-dotnet
  `ae4d019c`→`362f459d`. posthog-ios was checked at the 4.0 branch tip `4c944806`.

**What this run deliberately did not do.** It did not re-derive all 69 rows from scratch for any of
the three. Each file's scope was: every row this cycle's spec delta touches, plus the five rows new
to that file. Rows outside that set carry forward from the previous audit and say so in their notes.

### posthog-dotnet ships Emails, and the last real backfill question in the matrix closes ✅

Emails was the one row left anywhere in the matrix where the 64→69 backfill was a genuine ❌/✅ call
rather than five mechanical ➖ rows. `src/PostHog/Emails/` did not exist at the October audit and is
now a complete implementation — the flattened `{"template_id", "to", "message_data", "distinct_id"}`
body, the five Cloud app hosts, the spec's full status-to-error-name table including the `409`/`422`
idempotency split, attachments, and one idempotency key held across retries. Four server SDKs have
now shipped this capability in two cycles (php, ruby, go, dotnet); posthog-java remains the one
server SDK scoring ❌ on it.

### posthog-ios: one row moves, on a rule that is four days old

The spec-delta check found three applicable changes since the 4.0 audit's `752f899` baseline. Two are
already met — failed remote flag handling
([#211](https://github.com/PostHog/sdk-specs/pull/211)) and the optional replay debug bundle's
custom-event rule ([#139](https://github.com/PostHog/sdk-specs/pull/139)). The third moves **Capture
✅→🟡**: [#215](https://github.com/PostHog/sdk-specs/pull/215) requires `Set`/`NSSet` property values
to serialize as arrays and says an SDK must not drop the property, and `sanitizeInvalidValue`
converts only `URL`, `Date`, dictionaries and arrays, so a set falls through to the drop path. The
4.0 `NSNull` work reworked the same two functions without adding a set branch. One `if let set = value as? NSSet`
fixes it. See [posthog-ios.md](posthog-ios.md)'s "Spec-delta check (2026-11-16)".

Worth recording while the file is open: the 4.0 audit on `main` found posthog-ios meeting
[#199](https://github.com/PostHog/sdk-specs/pull/199)'s deferred-crash consent rule in full, which
this run independently re-confirmed against the shipped 3.x branch — `optOut()` marks the crash
context rather than trying to tear down a handler it cannot remove, a launch that starts opted out
installs no integrations and so neither reads nor purges a consented report, and `optIn()` delivers
it. It is the one requirement this cycle that an SDK implements the hard way.

### The empty-variant rule splits the SDKs cleanly, and not where you would guess

[#193](https://github.com/PostHog/sdk-specs/pull/193) records a known gap in "posthog-js core and
react-native". The browser package is **not** affected: it builds its result with `enabled: !!flagValue`
and filters `$active_feature_flags` and listener payloads on truthiness, so `""` reads disabled
everywhere — all four of the rule's clauses pass on fresh evidence. posthog-dotnet and posthog-ios
posthog-dotnet fails it, for a one-line reason: `IsEnabled = value.IsString ? value.StringValue is not null : value.Value`,
so an empty variant reads enabled, and `is-feature-enabled` inherits it through the implicit `bool`
operator. Two rows, one shared fix. posthog-ios 3.97.2 had the same defect in the same shape; **4.0
already fixes it**, per the audit `main` carries — which is a useful datapoint for
posthog-react-native, the remaining SDK the spec names.

### @posthog/mcp closed last cycle's gap and opened three new ones

The previous audit's headline finding on posthog-js — unknown tool names being misreported as failed
`$mcp_tool_call`s, inflating the server's own error rate — is **fixed**: `$mcp_unknown_tool` is
emitted on both instrumentation paths. `$mcp_error_status` is implemented to the letter of
[#212](https://github.com/PostHog/sdk-specs/pull/212), cause-chain walk and all, and the
[#194](https://github.com/PostHog/sdk-specs/pull/194) redaction reversal needs no change. What is
missing is this cycle's new surface: client conversation ids from a tool call's `_meta` (rule 1 of
"Session identity", which outranks the SDK's own handle — ChatGPT, Codex and VS Code all fall
through today), `$mcp_session_source`, and the error classifier with `$mcp_error_expected`, plus the
error message capture option. All four are additive. The row stays 🟡.

### Two things a human should look at

1. **"Last audited" no longer means the same thing in every row.** Three files are now audited
   against unreleased release branches — posthog-ios 4.0, posthog-android 4.0, posthog-flutter 6.0 —
   because several contracts (notably the
   [#197](https://github.com/PostHog/sdk-specs/pull/197) wireframe removal) were written for those
   majors and no longer describe the shipped 3.x/5.x code. That is defensible, and this run kept
   those audits, but it means the matrix mixes "what ships today" with "what the next major will
   ship", and a reader cannot tell which from the roll-up alone. Raised as scope item 7 below.
2. **Nothing resolved to ❓, for the third run running.** Every cell this run touched resolved
   against directly cited code.

## Roll-up

| SDK | Overall | ✅ | 🟡 | ❌ | ➖ | ❓ | Last audited | Open gaps | File |
|---|---|---|---|---|---|---|---|---|---|
| posthog-js | 26/69 fully compliant (38%; 10 contracts N/A on a browser SDK) | 26 | 21 | 12 | 10 | 0 | 2026-11-16 · `6b5843e0` (targeted re-audit — see file header) | 33 | [posthog-js.md](posthog-js.md) |
| posthog-python | 17/68 fully compliant (25%; 30 contracts N/A on a server SDK) | 17 | 16 | 5 | 30 | 0 | 2026-11-02 · `dca22075` (targeted re-audit — see file header) | 21 | [posthog-python.md](posthog-python.md) |
| posthog-android | 43/69 fully compliant (62%; 43/64 = 67% on the shared basis) | 43 | 15 | 1 | 10 | 0 | 2026-11-10 · `aaa23d39` (4.0: 31 rows); other rows 2026-10-19 · `c5e788bd` — see file header | 16 | [posthog-android.md](posthog-android.md) |
| posthog-ios | 43/69 fully compliant (62%; 43/64 = 67% on the shared basis) | 43 | 15 | 1 | 10 | 0 | 2026-11-10 · `e27cbe4cb` (4.0 release branch, before 4.0.0 is published) + **spec-delta check 2026-11-16** at `4c944806` — see file header | 16 | [posthog-ios.md](posthog-ios.md) |
| posthog-node | 11/68 fully compliant (16%; 32 contracts N/A on a server SDK) | 11 | 21 | 4 | 32 | 0 | 2026-11-02 · `8c832754` (posthog-js monorepo; targeted re-audit — see file header) | 25 | [posthog-node.md](posthog-node.md) |
| posthog-flutter | 23/69 fully compliant (33%; 23/64 = 36% on the shared basis) | 23 | 30 | 4 | 12 | 0 | 2026-11-10 · `82123e6` (6.0 release PR, before 6.0.0 is published; capture v1 rows against #146 as merged; see below) | 34 | [posthog-flutter.md](posthog-flutter.md) |
| posthog-react-native | 29/64 fully compliant (45%) | 29 | 28 | 2 | 5 | 0 | 2026-11-10 · `210bf35d8` (react-native-plugin 3.0: six session replay rows, Opt In, Capture Exception, Exception Event Metadata only); other rows 2026-10-19 · `3ddaa654` — see file header | 30 | [posthog-react-native.md](posthog-react-native.md) |
| posthog-php | 11/69 fully compliant (16%; 38 contracts N/A on a server SDK) | 11 | 12 | 8 | 38 | 0 | 2026-11-09 · `9c059270` (targeted re-audit — see file header) | 20 | [posthog-php.md](posthog-php.md) |
| posthog-ruby | 10/69 fully compliant (14%; 37 contracts N/A on a server SDK) | 10 | 14 | 8 | 37 | 0 | 2026-11-09 · `c08fd1b9` (targeted re-audit — see file header) | 22 | [posthog-ruby.md](posthog-ruby.md) |
| posthog-go | 9/69 fully compliant (13%; 37 contracts N/A on a server SDK) | 9 | 14 | 9 | 37 | 0 | 2026-11-09 · `2f949f18` (targeted re-audit — see file header) | 23 | [posthog-go.md](posthog-go.md) |
| posthog-java | 12/68 fully compliant (18%; 33 contracts N/A on a server SDK) | 12 | 14 | 9 | 33 | 0 | 2026-11-02 · `8309f837` (posthog-android monorepo; row completion + targeted re-audit — see file header) | 23 | [posthog-java.md](posthog-java.md) |
| posthog-dotnet | 6/69 fully compliant (9%; 34 contracts N/A on a server SDK) | 6 | 19 | 10 | 34 | 0 | 2026-11-16 · `362f459d` (targeted re-audit — see file header) | 29 | [posthog-dotnet.md](posthog-dotnet.md) |

**2026-09-28 contract correction (retained):** posthog-js n31 is withdrawn: custom network callbacks
intentionally replace default body-content scrubbing after mandatory header/path/size cleaning. That
correction was re-verified this run against the merged
PR [#79](https://github.com/PostHog/sdk-specs/pull/79) text on fresh evidence, and the ✅ stands; see
[posthog-js.md#n31](posthog-js.md#n31).

**Out-of-cycle audits merged to `main` (2026-11-05 → 2026-11-10).** Four audits outside the weekly
rotation landed on `main` while this branch was open, and this run kept all four:
**posthog-ios 4.0** ([#187](https://github.com/PostHog/sdk-specs/pull/187)) — all 69 rows at the 4.0
release branch, 9 rows improved; **posthog-flutter 6.0**
([#200](https://github.com/PostHog/sdk-specs/pull/200)) — all 69 rows at the 6.0 release PR;
**posthog-android** ([#186](https://github.com/PostHog/sdk-specs/pull/186)) — 31 rows re-audited for
4.0 and capture v1; **posthog-react-native** ([#201](https://github.com/PostHog/sdk-specs/pull/201))
— nine rows re-audited for react-native-plugin 3.0. Their roll-up rows, gap entries and per-SDK files
below are those audits', not the rotation's. The rotation pointers they replaced (posthog-ios
`f5cbe87c` 2026-10-08, posthog-android `c5e788bd` and posthog-flutter `1032c102` 2026-10-19) are
superseded.

**Row-count note (2026-11-16):** nine files carry all 69 contracts. posthog-python, posthog-node and
posthog-java sit at 68 (missing Experiment Exposure only); posthog-android, posthog-flutter and
posthog-react-native sit at 64 and need five rows each, all of them mechanical ➖ on a client SDK that
reads `/flags?v=2`. The backfill no longer contains a scoring question anywhere in the matrix.

**Reading this run's numbers.** No SDK regressed on code this run; the one status change that is not
a brand-new row comes from new spec text. **posthog-dotnet** went 5 ✅ → 6 ✅ on Emails, a
capability it did not ship at the previous audit; its headline moves 8%→9% only because the
denominator grew by five at the same time (34 of its 69 rows are ➖ on a server SDK, so the
applicable-only reading is 6 / 35 = 17%). **posthog-js** keeps its ✅/🟡/❌ counts exactly — all five
new rows are ➖ — so its headline falls on denominator growth alone (41%→38%) without losing a
passing row; what moved there is inside the MCP Analytics note, which closed its largest gap and
gained three smaller ones. **posthog-ios** loses one ✅ (44→43) on the spec-delta check's
`Set`/`NSSet` finding — the only ✅→🟡 move in the matrix this run. Percentages that move because the
denominator grew are not regressions; the per-SDK files mark which direction each row moved and why. Earlier runs' notes on the other nine
SDKs still stand.

"Overall" for posthog-python, posthog-node, posthog-php, posthog-ruby, posthog-go, posthog-java,
and posthog-dotnet is computed against the contracts actually applicable to a server SDK
(posthog-python: 17 Pass / 38 applicable = 45%; posthog-node: 11 Pass / 36 applicable = 31%;
posthog-php: 11 Pass / 30 applicable = 37%; posthog-ruby: 9 Pass / 30 applicable = 30%;
posthog-go: 8 Pass / 31 applicable = 26%; posthog-java: 12 Pass / 35 applicable = 34%;
posthog-dotnet: 6 Pass / 35 applicable = 17%); shown above as raw Pass/(64, 68 or 69) for
comparability with client SDKs, which see N/A far less often. posthog-js's 26/69 is likewise 26 Pass
/ 59 applicable = 44%, since Capture AI, Evaluate Flags and the four server-scope add-on contracts
are ➖ on a browser SDK; posthog-ios's 43/69 is 43 Pass / 59 applicable = 73%. **posthog-node
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
| posthog-node | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | Zero implementation; methods exist only on the client-only base class node doesn't extend — [posthog-node.md#n15](posthog-node.md) |
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
| posthog-android | Traces | Backward-compatible | No OTLP traces/spans implementation — [posthog-android.md#n23](posthog-android.md#n23) |
| posthog-ios | Traces | Backward-compatible | No OTLP span/traces implementation anywhere — [posthog-ios.md#n2](posthog-ios.md) |
| posthog-flutter | Get Anonymous ID | Backward-compatible | Method still doesn't exist in the Dart API at all — [posthog-flutter.md#n12](posthog-flutter.md#n12) |
| posthog-flutter | Exception Event Metadata | Needs deprecation path | **New this run** — no `exception_id`/`parent_id` linkage at all, causes inherit the outermost `handled`, `$exception_level` hardcoded, caller property bag overrides SDK-owned keys, and the chain caps at 10 where the spec says 50 — [posthog-flutter.md#n9](posthog-flutter.md#n9) |
| posthog-flutter | Traces | Backward-compatible | No implementation; net-new, pre-GA — [posthog-flutter.md#n36](posthog-flutter.md#n36) |
| posthog-flutter | Tracing Headers | Backward-compatible | No implementation; Flutter has no Dart-side HTTP client of its own to intercept app traffic with — [posthog-flutter.md#n37](posthog-flutter.md#n37) |
| posthog-react-native | Is Opt Out | Backward-compatible | No callable `isOptOut()`; only the `optedOut` getter property, unlike every other audited client SDK. Re-confirmed 2026-10-19 — [posthog-react-native.md#n17](posthog-react-native.md#n17) |
| posthog-react-native | Session Replay Debug Properties | Backward-compatible | **Plugin 3.0 re-audit (2026-11-10), upgraded from ❌** — tiers, the 30 s window, `screenshot` capture mode and the minimal `$feature_flag_called` strip conform; the SDK-computed keys overwrite registered and caller values, against the client precedence rule — [posthog-react-native.md#n24](posthog-react-native.md#n24) |
| posthog-react-native | Traces | Backward-compatible | Still unwired — but `packages/core/src/traces/` and `_sendTracesBatch` now exist on the very base class RN extends, so this is wiring, not new subsystem work — [posthog-react-native.md#n31](posthog-react-native.md#n31) |

**Re-confirmed this run, unchanged at the new HEAD:** every posthog-php, posthog-ruby and posthog-go ❌ above was re-checked at `9c059270`, `c08fd1b9` and `2f949f18` respectively. None was found fixed, and no new ❌ was added — the three rows new to these files that could have been ❌ (Emails on each) all came in ✅.
| posthog-dotnet | Get Feature Flag Payload | Backward-compatible | No standalone `GetFeatureFlagPayloadAsync(key, distinctId)`; only reachable via a full flag/snapshot object — [posthog-dotnet.md#n15](posthog-dotnet.md) |
| posthog-dotnet | Is Feature Enabled | Backward-compatible | No `defaultValue` overload on `IsFeatureEnabledAsync`/`FeatureFlagEvaluations.IsEnabled`; every miss collapses to hardcoded `false` — [posthog-dotnet.md#n20](posthog-dotnet.md) |
| posthog-dotnet | Logs | Backward-compatible | Entirely unimplemented — [posthog-dotnet.md#n22](posthog-dotnet.md) |
| posthog-dotnet | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | Zero implementation despite `@both`-tagged, server-satisfiable acceptance scenarios — [posthog-dotnet.md#n23](posthog-dotnet.md) |
| posthog-dotnet | Retry Queue | Needs deprecation path | `AsyncBatchHandler` dequeues before send and never requeues on failure; any transient 5xx permanently drops the batch — [posthog-dotnet.md#n24](posthog-dotnet.md) |
| posthog-dotnet | Traces | Backward-compatible | Entirely unimplemented — [posthog-dotnet.md#n26](posthog-dotnet.md) |

### 🟡 Partial (highlights — see per-SDK files for the full list)

| SDK | Contract | Backwards-compat verdict | Note |
|---|---|---|---|
| posthog-dotnet | Get Feature Flag Result | Backward-compatible | **New 2026-11-16.** An empty variant `""` reads `enabled: true`; the spec requires `enabled: false, variant: ""` — [posthog-dotnet.md#n16](posthog-dotnet.md) |
| posthog-dotnet | Local Feature Flag Evaluator | Backward-compatible | **New 2026-11-16.** No `filters.feature_enrollment` support, so enrollment-gated flags run straight through targeting — [posthog-dotnet.md#n21](posthog-dotnet.md) |
| posthog-js | Capture | Backward-compatible | **New 2026-11-16.** `Set` property values serialize as `{}` — [posthog-js.md#n2](posthog-js.md) |
| posthog-js | MCP Analytics | Backward-compatible | **New 2026-11-16.** No client conversation ids from `_meta`, no `$mcp_session_source`, no error classifier / `$mcp_error_expected`, no error message capture option (the previous unknown-tool gap is fixed) — [posthog-js.md#n37](posthog-js.md) |
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
| posthog-node | Flush / Retry Queue (v1 pipeline) | Needs deprecation path | `V1CaptureSender` never throws on exhausted retry, so failed batches are evicted from the queue as if delivered — [posthog-node.md#n8](posthog-node.md) |
| posthog-node | Feature Flag Called Tracker | Backward-compatible | Allowlist itself is fully compliant (inherited from posthog-js via shared `@posthog/core`), but capacity eviction is a full clear rather than incremental, violating the spec's anti-thundering-herd requirement — [posthog-node.md#n19](posthog-node.md) |
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
| posthog-php | Retry Queue | Backward-compatible | **New this run, downgraded from ✅** — ingestion retries are a plain 100/200/400 ms doubling schedule with no jitter, while the SDK's own new `Emails` client jitters on `[0.8, 1.2]` — [posthog-php.md#n18](posthog-php.md) |
| posthog-ruby | MCP Analytics | Backward-compatible | **New this run** — a 3,798-line `lib/posthog/mcp/` package the spec's applicability table still records as "not yet"; the required `$mcp_interface` is never emitted, and the client-conversation-id rung added by #175/#176 is absent — [posthog-ruby.md#n21](posthog-ruby.md) |
| posthog-go | Retry Queue | Backward-compatible | **Added this run** — a third gap on an existing 🟡: `NewBackoff` supports jitter and every ingestion and flag call site passes `jitter: 0` (`backoff.go:36`, `flags.go:220`); only `Emails` jitters — [posthog-go.md#n19](posthog-go.md) |
| posthog-go | MCP Analytics | Backward-compatible | **Added this run** — the required `$mcp_interface` is never emitted and the client-conversation-id rung from #175/#176 is absent, on top of the three `$exception` side-car gaps already recorded — [posthog-go.md#n17](posthog-go.md) |
| posthog-go | Local Feature Flag Evaluator | Backward-compatible | **Downgraded from ✅ this run on new spec text** — experiment holdouts entirely unimplemented (`grep holdout`: zero matches); every other new matching requirement is met — [posthog-go.md#n15](posthog-go.md) |
| posthog-dotnet | Evaluate Flags | Backward-compatible | **New this run** — good control flow, but no negative-knowledge retention, and an unguarded `JsonDocument.Parse` makes a malformed payload throw during flag construction, discarding the whole remote response — [posthog-dotnet.md#n7](posthog-dotnet.md) |
| posthog-dotnet | Capture AI | Backward-compatible | **New this run** — `PostHog.AI` ships real `$ai_*` support but routes it through ordinary `Capture(...)` to `batch`; no `CaptureAi` surface and no isolated AI route with the larger payload allowance — [posthog-dotnet.md#n4](posthog-dotnet.md) |
| posthog-dotnet | Local Feature Flag Evaluator | Backward-compatible | **Downgraded from ✅ this run on new spec text** — experiment holdouts entirely unimplemented; every other new matching requirement is met — [posthog-dotnet.md#n21](posthog-dotnet.md) |
| posthog-dotnet | Get Feature Flags And Payloads | Backward-compatible | **Downgraded from ✅ this run on new spec text** — one malformed payload throws out of bulk-result construction and discards every healthy flag value and sibling payload with it — [posthog-dotnet.md#n17](posthog-dotnet.md) |
| posthog-js | MCP Analytics | Backward-compatible | **New this run** — the richest implementation in the matrix, but an unknown tool is misreported as a failed `$mcp_tool_call` on both instrumentation paths (a rule the spec applies to every SDK), and neither `$mcp_unknown_tool` nor `$mcp_input_required` is emitted — [posthog-js.md#n37](posthog-js.md) |
| posthog-js | Exception Event Metadata | Backward-compatible | **New this run** — the most complete producer envelope audited (full `exception_id`/`parent_id` linkage, canonical sources, correct nested-`handled` omission, spec-exact caps), missing only `$exception_source` and a capture category on the two global handlers, which fall back to `generic` — [posthog-js.md#n35](posthog-js.md) |
| posthog-js | Session Replay Debug Properties | Backward-compatible | **New this run** — re-scored against `d078270` after #96; tiering, the `$`-prefix gate, and the 30 s throttle conform, but after `stopSessionRecording()` on a loaded recorder events keep `active`/`buffering` instead of `$recording_status: disabled` — [posthog-js.md#n36](posthog-js.md) |
| posthog-ios | Capture | Backward-compatible | **New 2026-11-16 (spec-delta check), ✅→🟡** — `Set`/`NSSet` property values are dropped rather than serialized as arrays ([#215](https://github.com/PostHog/sdk-specs/pull/215)) — [posthog-ios.md](posthog-ios.md) |
| posthog-ios | Exception Event Metadata | Backward-compatible | Chain linkage, 50-entry cap, `$exception_source`, empty `value` and UUID-less image filtering landed in PostHog/posthog-ios#931 (merged in 4.0); caller properties can still override `$exception_level`/`$exception_source` on purpose (no typed level parameter yet, and Android/JS behave the same) — [posthog-ios.md#n19](posthog-ios.md) |
| posthog-android | Exception Event Metadata | Needs deprecation path | Nested entries copy the outermost `handled`, suppressed entries have no `mechanism.source`, a single-entry list has no `exception_id: 0`, no `$exception_source`, and `$exception_level` is a documented caller override (re-audited at 4.0 `aaa23d39`) — [posthog-android.md#n7](posthog-android.md#n7) |
| posthog-android | Identify | Backward-compatible | While opted out, `identify` updates the person-properties dedup hash for a `$set` it dropped, so the same properties are skipped after opt-in (4.0 `aaa23d39`) — [posthog-android.md#n28](posthog-android.md#n28) |
| posthog-android | Get Feature Flags / Get Feature Flags And Payloads | Backward-compatible | `getAllFeatureFlags()` is the spec's android 4.0 form but returns `null` after a restart until the disk cache is loaded (4.0 `aaa23d39`) — [posthog-android.md#n9](posthog-android.md#n9) |
| posthog-android | Surveys | Backward-compatible | Submit and dismiss move the last-seen survey date (#102), and a survey with an unknown question type blocks later surveys until reset (4.0 `aaa23d39`) — [posthog-android.md#n22](posthog-android.md#n22) |
| posthog-ios | Session Replay Privacy | Backward-compatible | **Upgraded from ❌** — 4.0's screenshot-only replay removes the leaking wireframe path; SwiftUI's `postHogMask()` still wins over an enclosing `postHogNoMask()`, the reverse of the spec's precedence (over-masks, no leak) — [posthog-ios.md#n24](posthog-ios.md) |
| posthog-ios | Get Feature Flags / Get Feature Flags And Payloads | Backward-compatible | **Upgraded from ❌** — the specs now record iOS 4.0's `getAllFeatureFlags()` result list (payloads decoded per entry) as its surface; still not the canonical map shape — [posthog-ios.md#n9](posthog-ios.md) |
| posthog-ios | Session Replay Debug Properties | Backward-compatible | **New row** — tiers, 30 s window and crash-context snapshot conform; gaps on caller-supplied `$session_id` and backdated events (the `active`-after-timeout gap is fixed in 4.0) — [posthog-ios.md#n26](posthog-ios.md) |
| posthog-ios | Exception Steps | Backward-compatible | **Downgraded from ✅** — steps are byte-counted, buffered and persisted with `NSNull` members that the analytics queue and capture v1 wire later strip, so the representations the spec requires to be identical differ — [posthog-ios.md#n30](posthog-ios.md#n30) |
| posthog-flutter | Session Replay Privacy | Backward-compatible | Independent Dart replay pipeline still has no no-capture marker (a nested `PostHogUnmaskWidget` can reveal anything inside `PostHogMaskWidget`); the unmask primitive, shared sensitive-input detection, and fail-closed mask walk have all landed since the previous audit — [posthog-flutter.md#n29](posthog-flutter.md#n29) |
| posthog-flutter | Remote Config | Backward-compatible | **Resolved from ❓** — mobile delegates to the native SDK (✅ there), but the new Dart desktop core never fetches remote config at all, so Windows/Linux clients get no server-side replay or survey gating — [posthog-flutter.md#n26](posthog-flutter.md#n26) |
| posthog-flutter | Get Feature Flag Payload / Result | Backward-compatible | **6.0** — payloads are read through `getFeatureFlagResult`, and posthog-ios 4.0 returns no payload for malformed JSON; on web posthog-js still returns the raw string — [posthog-flutter.md#n15](posthog-flutter.md#n15) |
| posthog-flutter | Get Feature Flags / Get Feature Flags And Payloads | Backward-compatible | **Upgraded from ❌ (6.0)** — the specs now record `getAllFeatureFlags()`'s result list as the flutter 6.0 surface; still not the canonical map shape, and on web an empty variant reads as enabled and a malformed payload is the raw string — [posthog-flutter.md#n16](posthog-flutter.md#n16) |
| posthog-flutter | Session Replay Debug Properties | Backward-compatible | **6.0** — mobile events are built by posthog-ios/posthog-android 4.x and carry their bundles (posthog-ios 🟡); desktop sends `$recording_status: disabled`, but the Dart core also puts `$sdk_debug_session_start` and `$sdk_debug_current_session_duration` on every event, custom events included, and no SDK may send the duration — [posthog-flutter.md#n28](posthog-flutter.md#n28) |
| posthog-flutter | Retry Queue | Needs deprecation path (inherited) | **Resolved from ❓** — desktop and mobile keep failed batches queued, but Flutter Web uses posthog-js's `RetryQueue`, which drops a 429; clears with posthog-js n28 — [posthog-flutter.md#n38](posthog-flutter.md#n38) |
| posthog-flutter | Capture / Capture AI | Backward-compatible | **6.0, against #146** — the Windows/Linux Dart core replaces an empty or non-string caller `$session_id` with its own session id, so it is never lifted or dropped with a warning; native paths keep the caller's value — [posthog-flutter.md#n41](posthog-flutter.md#n41) |
| posthog-flutter | Identify | Backward-compatible | **Downgraded on new spec text (6.0)** — the Windows/Linux Dart core returns early from `identify()` while opted out, so the distinct id and flags don't follow until opt-in; #167 says opt-out is not a guard — [posthog-flutter.md#n40](posthog-flutter.md#n40) |
| posthog-flutter | Surveys | Backward-compatible | **6.0** — posthog-android still moves the last-seen survey date on submit and dismiss (#102); posthog-ios now writes it on show — [posthog-flutter.md#n35](posthog-flutter.md#n35) |
| posthog-react-native | Bootstrap | Backward-compatible | Flag-merge spread order is inverted — previously-persisted flags win over a fresh bootstrap value, the opposite of the spec's required precedence — [posthog-react-native.md#n4](posthog-react-native.md) |
| posthog-react-native | Flush / Retry Queue | Backward-compatible | Shared-core catch handler evicts an exhausted-retry HTTP failure as if delivered instead of preserving it — same defect class as posthog-node, and precisely what posthog-flutter's new Dart core gets right — [posthog-react-native.md#n9](posthog-react-native.md#n9) |
| posthog-react-native | Setup | Backward-compatible | **Downgraded on new spec text** — `PostHogProvider` still takes only `apiKey`; PR [#108](https://github.com/PostHog/sdk-specs/pull/108) names it explicitly and prescribes the non-breaking fix (add `projectToken`, deprecate `apiKey` in the same release) — [posthog-react-native.md#n27](posthog-react-native.md#n27) |
| posthog-react-native | Get Feature Flag Payload / Result / Flags And Payloads | Needs deprecation path | **Downgraded on new spec text** — shared `parsePayload` returns the raw malformed string instead of the no-payload sentinel, and logs nothing; one fix in `@posthog/core` clears all three rows and also posthog-js and posthog-node — [posthog-react-native.md#n10](posthog-react-native.md#n10) |

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

**None. Every cell in the matrix has a definite status, for the third run running.**

No Unknown was introduced this run. The ten rows added across posthog-js and posthog-dotnet, and the
three delta rows checked on posthog-ios, all resolved on an explicit applicability sentence or a read
of the implementation, not on an absence of evidence:

- **Emails** on posthog-dotnet resolved ✅ against a read of `src/PostHog/Emails/`, field by field
  against the spec's HTTP mapping and error table — the last backfill row in the matrix that was a
  real ❌/✅ call.
- **Experiment Exposure** resolved ➖ on both, on the spec's own conditional applicability plus a
  direct check that each still requests `/flags?v=2`.
- **The three AI capabilities and Emails** on posthog-js resolved ➖ on server scope, with the
  browser packages' absence of any such surface confirmed by grep.
- **The posthog-ios delta rows** resolved against the 4.0 branch at `4c944806`: two met, one
  (`Set`/`NSSet` serialization) a definite 🟡 read off the two functions that would have to change.

Nothing is contested on the evidence this run. The open question is structural rather than
evidential, and it is scope item 7: three files are now audited against unreleased release branches,
so a ✅ in those rows describes code that is not published yet. That is a decision about what the
matrix measures, not a cell anyone is unsure how to score.

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

5. **The `mcp-analytics` applicability table is out of date in two places, and one of them changed a
   row's status.** It records posthog-ruby as "not yet" while `lib/posthog/mcp/` is a 3,798-line
   package that grew again this cycle; this run scored that package anyway and gave posthog-ruby a
   🟡 MCP Analytics row, which is a judgement call a maintainer may want to reverse to ➖ until the
   table is updated. Separately it lists `posthogmcp` and `posthogmcpsdk` for Go, where posthog-go
   now ships a third adapter, `posthogmcpgo` (1,137 lines, new this cycle). Neither is an SDK defect.
6. **Does a server SDK that stays on `/flags?v=2` keep scoring ➖ on Experiment Exposure
   indefinitely?** posthog-php, posthog-ruby and posthog-go all request `v=2`, and
   `openspec/specs/experiment-exposure/spec.md`'s applicability sentence says an SDK that does not
   read `v=4` records "sends no direct exposure" — so abstaining is conformant and all three score
   ➖. That is the conservative reading and this run took it. But it means three server SDKs cannot
   produce correct experiment analytics for a config version 2 flag and the matrix shows no gap for
   it. If `v=4` adoption is expected, the applicability sentence is the place to say so, and these
   rows become ❌ rather than ➖.

7. **The matrix now mixes shipped branches with unreleased release branches, and nothing marks
   which is which.** Three files are audited against unreleased majors — posthog-ios 4.0
   (`chore/v4-remove-deprecated`), posthog-android 4.0 and posthog-flutter 6.0 — while the other nine
   are audited against shipped default branches. The driver is real:
   [#197](https://github.com/PostHog/sdk-specs/pull/197) removed wireframe recording and the
   `screenshotMode` / `screenshot` options from `session-replay-privacy` and
   `session-replay-debug-properties` on the basis that 4.0 dropped them, so the shipped 3.x code
   cannot pass those contracts and the 4.0 branch can. But the consequence is that
   posthog-ios's ✅ rows describe code no user can install yet, next to posthog-js rows that describe
   code shipping today, with only the file header distinguishing them. Two things would fix it
   cheaply: a column or marker in the roll-up for "audited against an unreleased branch", and a
   decision on what happens to those rows if the major slips. A maintainer should also decide whether
   the rotation re-audits such an SDK at its default branch in the meantime, or waits for the release.

## Pending initial audit

None of the twelve current in-scope SDKs. **posthog-rs would be the first entry here** if the scope
decision above goes that way.

## Queued for next run

This run spent two slots on full audits (**posthog-js**, **posthog-dotnet**) and the third on
reconciling the branch with the four out-of-cycle audits `main` merged, which included a
spec-delta check on **posthog-ios**. That leaves **10 SDKs queued**, and after the out-of-cycle work
no SDK is more than two weeks past its last audit.

| SDK | Last-audited SHA | Last audited | Rows | Weeks since | Backfill needed |
|---|---|---|---|---|---|
| posthog-react-native | `210bf35d8` | 2026-11-10 (plugin 3.0 rows only; other rows 2026-10-19 · `3ddaa654`) | 64 | 4 on most rows | +5 (all ➖) |
| posthog-python | `dca22075` | 2026-11-02 | 68 | 2 | +1 (Experiment Exposure) |
| posthog-node | `8c832754` | 2026-11-02 | 68 | 2 | +1 (Experiment Exposure) |
| posthog-java | `8309f837` | 2026-11-02 | 68 | 2 | +1 (Experiment Exposure) |
| posthog-php | `9c059270` | 2026-11-09 | 69 | 1 | none |
| posthog-ruby | `c08fd1b9` | 2026-11-09 | 69 | 1 | none |
| posthog-go | `2f949f18` | 2026-11-09 | 69 | 1 | none |
| posthog-android | `aaa23d39` | 2026-11-10 (4.0: 31 rows; other rows 2026-10-19) | 69 | 1 on 4.0 rows | none |
| posthog-ios | `e27cbe4cb` + delta `4c944806` | 2026-11-10 / 2026-11-16 | 69 | 0 | none |
| posthog-flutter | `82123e6` | 2026-11-10 (6.0) | 69 | 1 | none |

Prioritized for upcoming runs:

1. **posthog-react-native** — the clearest first slot. It is the last file at 64 rows; only nine of
   its rows were refreshed by the plugin 3.0 audit, leaving the rest at 2026-10-19; and the spec
   names it directly twice this cycle, as a known gap for the empty-variant rules
   ([#193](https://github.com/PostHog/sdk-specs/pull/193), "posthog-js core and react-native").
   `@posthog/core`'s `getEnabledFromValue` was read directly this run and does return `true` for
   `""`, so those rows can be scored precisely and quickly.
2. **posthog-node** — shares that `@posthog/core` gap, and is the one SDK that actually implements
   Experiment Exposure (`packages/node/src/flag-events.ts`), so it is the only place the
   `$feature_flag_variant_key` rename ([#203](https://github.com/PostHog/sdk-specs/pull/203)) and the
   config version 2 attribution rules can be scored rather than marked ➖.
3. **posthog-python or posthog-java** for the third slot, both two weeks old and both needing the one
   Experiment Exposure row. posthog-java is the more interesting of the two: it is the last server
   SDK scoring ❌ on Emails, and four SDKs have now shipped that capability.
4. **posthog-android, posthog-ios, posthog-flutter, posthog-php, posthog-ruby, posthog-go** are all
   inside the window and need no backfill. Leave them until the ~4-week backstop or a spec change
   reaches them — but note that the three audited against unreleased branches will need a decision
   (scope item 7) before their next rotation slot, not just an audit.
