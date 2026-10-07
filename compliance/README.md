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

Five contracts are newer than most per-SDK files. **Capture AI**, **Evaluate Flags**, and
**Exception Event Metadata** were merged between 2026-08-10 and 2026-08-13; **Session Replay Debug
Properties** was merged on 2026-09-28 (PR [#72](https://github.com/PostHog/sdk-specs/pull/72)); and
**MCP Analytics** landed this cycle. Only the three SDKs re-audited this run (posthog-js,
posthog-go, posthog-dotnet) plus posthog-php and posthog-ruby (re-audited 2026-09-28, at 63 rows)
carry them; the other seven SDKs are short one or more rows and need them added at their next
audit. See "Queued for next run" below.

**No SDK is pending its first audit.** Every run since the backlog drained has been a re-audit
run, and selection is driven by the four-rule priority order at the top of this file.

## This run (2026-10-05)

sdk-specs `main` advanced from `1d5fe42` (last run's baseline) to `75c8f5d`, a **four-commit span**
— far smaller than last cycle's 27, but one of the four is a brand-new capability. **MCP Analytics**
(PR [#87](https://github.com/PostHog/sdk-specs/pull/87), +582 spec lines, +451 acceptance lines)
specifies a whole product surface: `$mcp_tool_call` and its required properties, a
cross-SDK-deterministic `$session_id` derivation, conversation anchoring, injected
`context`/`llm_model`/`conversation_id` arguments, payload privacy, a 102,400-byte event bound, and
an optional-event family. Its applicability table names three in-scope SDKs by package —
posthog-js (`@posthog/mcp`), posthog-python (`posthog.mcp`), and posthog-go
(`posthogmcp`/`posthogmcpsdk`) — which makes it the single most targeted spec change this matrix
has seen. The other three: **Evaluate Flags** (PR [#77](https://github.com/PostHog/sdk-specs/pull/77))
reshaped the flag evaluation runtime from a per-key accessor into a criterion on the snapshot
filter, and made the filter the only runtime surface; **Session Replay Privacy**
(PR [#79](https://github.com/PostHog/sdk-specs/pull/79)) added a 10-scenario
`Browser replay network body scrubber replacement` requirement — custom network masking callbacks
*replace* default body scrubbing rather than composing with it, with explicit rules for a nullish
return on an initial performance entry and for a throwing callback; and **Logs**
(PR [#91](https://github.com/PostHog/sdk-specs/pull/91)) replaced the vague "monotonic +1ns bump"
with a concrete `max(clockNanos, previous + 1_000)` floor, because PostHog stores log timestamps at
microsecond precision.

Selection: **posthog-go**, **posthog-dotnet**, and **posthog-js**, using the full three-SDK cap for
the first time in three runs.

- **posthog-go** — priority rule 1 and rule 4 together. The new MCP Analytics spec names its two
  packages explicitly, and Go had just shipped them (six MCP PRs since the last audit); it also
  carries the Evaluate Flags delta as a server SDK with a local evaluator, and it sat in the oldest
  (2026-08-06) staleness cohort as the previous queue's joint #1.
- **posthog-dotnet** — rule 1 (Evaluate Flags, as the other server SDK with a local evaluator in
  the oldest cohort) and the previous queue's other joint #1.
- **posthog-js** — rule 1, and the only SDK the Session Replay Privacy change can land on at all,
  since that requirement is browser-only. It is also named for `@posthog/mcp` in the MCP spec and is
  the declared reference implementation for `logs`, so three of this cycle's four spec changes point
  at it. This displaced posthog-react-native, which the previous queue had at #2 on staleness
  grounds; RN stays at the top of the queue below.

All three were confirmed code-drifted, and heavily: posthog-go **+75 commits**
(`019af196`→`08549f42`), posthog-dotnet **+64** (`e7f20e3`→`ae4d019c`), posthog-js **+676**
(`34a34f3d`→`6538babc`).

- **posthog-go** (8 ✅ · 14 🟡 · 9 ❌ · 33 ➖ · 0 ❓ on 64 rows, from 10/11/7/31/0 on 59): the most
  eventful file this run. **MCP Analytics** 🟡 on first audit, and it is a strong first
  implementation — the cross-SDK FNV-1a session derivation is byte-exact, per-session state is
  LRU-bounded at 1,024 with a 30-minute rotation, the required properties and the 102,400-byte
  bound are all there, and both `SHOULD`-tier optional events ship. Its gaps are narrow and
  specific: the `$exception` side-car omits the required `$exception_source: "mcp.tool_call"`, and
  `mechanism.synthetic` is hardcoded `true` on a path only ever reached for a *thrown* error —
  exactly the case the spec says is not synthetic — so every MCP exception Go emits is mislabelled.
  **Evaluate Flags** 🟡: a genuinely good snapshot API (empty-vs-nil key list, one request,
  local-wins merge, partial snapshot on remote failure) with no negative-knowledge retention and no
  JSON validation on `GetFlagPayload`. **Exception Event Metadata** ❌ on first audit — no
  `exception_id`/`parent_id` linkage, no `$exception_source`, no `$exception_level` on the core
  path. **Capture AI** ➖ (the `otel/` module is an OTLP span pipeline to `/i/v0/ai/otel`, not a
  capture surface). **Two rows improved on real code changes:** Flag Definition Loader's missing
  shared-cache extension point is now a full `FlagDefinitionCacheProvider` with fail-safe fallback
  in both directions, and Flush gained a real blocking `Flush()`/`FlushWithContext()`. **Two were
  downgraded by new spec text, not new code:** Get Feature Flag Payload ✅→❌ (returns the raw
  malformed string, unlogged) and Local Feature Flag Evaluator ✅→🟡 (holdouts unimplemented).
- **posthog-dotnet** (5 ✅ · 19 🟡 · 10 ❌ · 30 ➖ · 0 ❓ on 64 rows, from 7/15/9/28/0 on 59): no new
  capability landed, so nearly all movement comes from new spec text. **Capture AI** 🟡 — .NET is
  the one unnamed server SDK that genuinely ships AI support (`PostHog.AI`, with an OpenAI handler
  and a full `$ai_*` vocabulary), but those events go through ordinary `Capture(...)` to `batch`
  with no isolated AI route, so the spec's interim arrangement is literally what .NET does while the
  condition it attaches to adoption is already met. **Evaluate Flags** 🟡 — the control flow is one
  of the better ones in this matrix (all four safe-empty cases, a deliberate cache bypass for scoped
  requests, an explicitly commented local-wins merge), spoiled by the same missing negative
  knowledge and by the payload defect below. **Exception Event Metadata** ❌ — the entire
  `mechanism` object is a fixed literal (`type: "generic"`, `handled: true`, `source: ""`,
  `synthetic: false`) emitted identically for every entry in the tree, so it violates the
  omit-unknown rule twice over (`""` and `false` are both named as forbidden placeholders), copies
  the outermost `handled` onto every cause and aggregate member, and has no linkage fields at all.
  **One defect explains four rows:** an unguarded `JsonDocument.Parse` in both `FeatureFlag`
  factories means a malformed payload throws during flag *construction* — discarding the flag's
  correctly evaluated local value on one path and the **entire** remote response on the other.
  .NET never leaks the raw malformed string (its `JsonDocument?` type makes that impossible, unlike
  ruby and go), but it fails the same requirement from the opposite direction, and fixing that one
  call pair resolves Evaluate Flags, Get Feature Flag Payload, Get Feature Flag Result, and Get
  Feature Flags And Payloads together.
- **posthog-js** (26 ✅ · 21 🟡 · 12 ❌ · 5 ➖ · 0 ❓ on 64 rows, from 26/18/12/3/0 on 59): a targeted
  re-audit rather than a full 59-row re-verification — the rows this cycle's delta lands on, plus
  the five missing contracts. **Session Replay Privacy ✅ reconfirmed on fresh evidence,** which is
  the most useful result here: the browser SDK satisfies every scenario PR
  [#79](https://github.com/PostHog/sdk-specs/pull/79) added, including the two subtle ones — the
  initial-entry fallback is built from metadata captured *before* the callback runs (with a comment
  explaining that callbacks may mutate their argument), and a throwing callback is caught per record
  one level up in the network plugin, dropping that record and its derived server timings while the
  rest of the batch keeps flowing. Last run's n31 withdrawal was correct, and this run verified it
  against the merged text rather than inheriting it. **Exception Event Metadata** 🟡 — and this is
  **the most complete producer envelope of any SDK in this matrix**: full `exception_id`/`parent_id`
  depth-first linkage with canonical `cause`/`member` sources, `type: "chained"` on nested entries,
  nested entries correctly carrying *no* inherited `handled`, and the spec's 50-entry and
  1,000-member budgets implemented to the letter with cycle detection. Its two gaps are both
  capture-boundary provenance: `$exception_source` is never set (and a Playwright test asserts it is
  `undefined`), and the `window.onerror` / `unhandledrejection` handlers pass a mechanism without a
  `type`, so both land on `generic` instead of their own categories — while the console integration
  gets it right, showing only the two handlers were missed. **MCP Analytics** 🟡 — `@posthog/mcp` is
  clearly the reference implementation (~8,800 lines; input keys and aliases, server build, the
  feedback tool with host-declared report arguments, tools-list, initialize, resources, the replayed
  session-token path Go omits), but it emits neither `$mcp_unknown_tool` nor `$mcp_input_required`,
  and an unknown tool is not merely unreported but **misreported** as a failed `$mcp_tool_call` on
  both instrumentation paths — inflating the server's own tool error rate with names it never
  registered, which is the one rule in "Optional events" that applies to every SDK regardless of
  capability tags. **Session Replay Debug Properties** 🟡, re-scored on 2026-10-07 against sdk-specs
  `d078270` after PR [#96](https://github.com/PostHog/sdk-specs/pull/96) rewrote the contract. The
  required-key tier, the `$`-prefix gate on the optional bundle, its 30-second throttle, and the
  absence of any replay key without the session-recording extension all match the merged spec.
  The one gap is narrower: after `stopSessionRecording()` on a loaded recorder, events keep
  reporting `active` or `buffering` instead of `$recording_status: disabled`, confirmed by a runtime
  check at `6538babc`. **Capture AI** and
  **Evaluate Flags** are ➖ on a client SDK, both by explicit spec scope text.

## Roll-up

| SDK | Overall | ✅ | 🟡 | ❌ | ➖ | ❓ | Last audited | Open gaps | File |
|---|---|---|---|---|---|---|---|---|---|
| posthog-js | 26/64 fully compliant (41%) | 26 | 21 | 12 | 5 | 0 | 2026-10-05 · `6538babc` | 33 | [posthog-js.md](posthog-js.md) |
| posthog-python | 14/62 fully compliant (23%; 29 contracts N/A on a server SDK; **needs +2: Session Replay Debug Properties, MCP Analytics**) | 14 | 12 | 7 | 29 | 0 | 2026-08-17 · `95c7f6e0` | 19 | [posthog-python.md](posthog-python.md) |
| posthog-android | 31/59 fully compliant (53%; **59 rows, needs +5 new contracts**) | 31 | 16 | 9 | 3 | 0 | 2026-08-10 · `8659a7b4` | 25 | [posthog-android.md](posthog-android.md) |
| posthog-ios | 32/62 fully compliant (52%; **needs +2: Session Replay Debug Properties, MCP Analytics**) | 32 | 18 | 7 | 5 | 0 | 2026-08-17 · `c0218386` | 25 | [posthog-ios.md](posthog-ios.md) |
| posthog-node | 10/62 fully compliant (16%; 28 contracts N/A on a server SDK; **needs +2: Session Replay Debug Properties, MCP Analytics**) | 10 | 16 | 8 | 28 | 0 | 2026-08-17 · `fbdb6c7b` (posthog-js monorepo) | 24 | [posthog-node.md](posthog-node.md) |
| posthog-flutter | 20/59 fully compliant (34%; **59 rows, needs +5 new contracts**) | 20 | 22 | 6 | 5 | 6 | 2026-08-06 · `05b53dc` | 34 | [posthog-flutter.md](posthog-flutter.md) |
| posthog-react-native | 31/59 fully compliant (53%; **59 rows, needs +5 new contracts**) | 31 | 23 | 2 | 2 | 1 | 2026-08-06 · `e1efa57` (posthog-js monorepo — now very stale, see below) | 26 | [posthog-react-native.md](posthog-react-native.md) |
| posthog-php | 10/63 fully compliant (16%; 33 contracts N/A on a server SDK; **needs +1: MCP Analytics**) | 10 | 12 | 8 | 33 | 0 | 2026-09-28 · `5451f4e0` | 20 | [posthog-php.md](posthog-php.md) |
| posthog-ruby | 9/63 fully compliant (14%; 32 contracts N/A on a server SDK; **needs +1: MCP Analytics**) | 9 | 14 | 8 | 32 | 0 | 2026-09-28 · `185060ab` | 22 | [posthog-ruby.md](posthog-ruby.md) |
| posthog-go | 8/64 fully compliant (13%; 33 contracts N/A on a server SDK) | 8 | 14 | 9 | 33 | 0 | 2026-10-05 · `08549f42` | 23 | [posthog-go.md](posthog-go.md) |
| posthog-java | 12/59 fully compliant (20%; **59 rows, needs +5 new contracts**) | 12 | 13 | 6 | 28 | 0 | 2026-08-10 · `8659a7b4` (posthog-android monorepo) | 19 | [posthog-java.md](posthog-java.md) |
| posthog-dotnet | 5/64 fully compliant (8%; 30 contracts N/A on a server SDK) | 5 | 19 | 10 | 30 | 0 | 2026-10-05 · `ae4d019c` | 29 | [posthog-dotnet.md](posthog-dotnet.md) |

**2026-09-28 contract correction (retained):** posthog-js n31 is withdrawn: custom network callbacks
intentionally replace default body-content scrubbing after mandatory header/path/size cleaning. That
correction was re-verified this run against the merged
PR [#79](https://github.com/PostHog/sdk-specs/pull/79) text on fresh evidence, and the ✅ stands; see
[posthog-js.md#n31](posthog-js.md#n31).

**Row-count note:** three SDKs now carry the full 64-row matrix — posthog-js, posthog-go, and
posthog-dotnet, re-audited this run. posthog-php and posthog-ruby sit at 63 and need only the new
MCP Analytics row (➖ N/A for both, since the spec's own applicability table lists Ruby as "not yet"
and does not mention PHP). posthog-python, posthog-node, and posthog-ios sit at 62 and need two
rows each. The remaining four — posthog-android, posthog-flutter, posthog-react-native, and
posthog-java — are still at 59 and need all five of Capture AI, Evaluate Flags, Exception Event
Metadata, Session Replay Debug Properties, and MCP Analytics added from scratch at their next audit,
not just a refresh of existing rows.

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
posthog-php: 10 Pass / 30 applicable = 33%; posthog-ruby: 9 Pass / 31 applicable = 29%;
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

Full contract-by-contract detail (33 posthog-js, 19 posthog-python, 25 posthog-android, 25
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

**Experiment holdouts are unimplemented in every server SDK checked since the requirement landed —
four for four.** The requirement (sdk-specs PR [#76](https://github.com/PostHog/sdk-specs/pull/76),
merged 2026-09-28) says a flag configured with a holdout must evaluate the holdout before its
release conditions so the local answer matches the backend's. `grep -rni holdout` returns **zero**
matches in posthog-php, posthog-ruby, posthog-go, and posthog-dotnet alike — source and tests. In
every case the definition loader already preserves `filters.holdout` untouched (definitions are
decoded as whole structures), so the data is present and simply unread: the gap is entirely in the
evaluator. This is a *silent correctness divergence*, not a missing feature — a flag with a holdout
is evaluated locally as though the holdout did not exist, so every identity inside the holdout gets
an answer that disagrees with the backend, with no error and no fallback. Because the requirement is
new, none of the four is a regression. But four for four on the first four SDKs checked makes this
the highest-value single fix in the matrix right now, and it should be audited first — not swept
in with routine new-requirement checks — for posthog-python, posthog-node, and posthog-java at
their next audits. The client SDKs have no local evaluator and are unaffected.

**Negative-knowledge retention for missing flag keys is unimplemented in every server SDK checked —
also four for four.** The Evaluate Flags requirement obliges an SDK with a successful
local-definition refresh lifecycle to remember that a requested key was absent from both the loaded
definitions and a clean remote fallback, in a finite-capacity in-memory store cleared on each
successful refresh, and to coordinate concurrent probes for the same key. posthog-php, posthog-ruby,
posthog-go, and posthog-dotnet all have none of this machinery (no missing-key store, no definitions
generation counter, no in-flight probe map). The user-visible effect is identical in all four: a
requested-but-deleted key re-probes `/flags` on every single `evaluateFlags` call for that scope,
forever, and N concurrent evaluations missing the same key make N requests. Unlike the holdout gap
this is a cost-and-latency problem rather than a correctness one, and it is the harder of the two to
implement correctly (the spec's generation-and-probe rules are intricate), so it is worth deciding
deliberately whether to implement it uniformly or to narrow the requirement upstream.

A second cross-cutting pattern: **Is Feature Enabled**'s caller-supplied default-value parameter
(a hard spec `SHALL`, no server carve-out) is missing in posthog-python, posthog-node,
posthog-php, posthog-ruby, posthog-go, and posthog-dotnet — 6 of the 7 server-style SDKs audited.
The lone exception is **posthog-java** (`posthog-server`'s `com.posthog.server` package), which
correctly implements a caller-supplied default on its canonical evaluation path — worth using as the
reference implementation when fixing the other 6. Reconfirmed in posthog-go and posthog-dotnet this
run: Go's `FeatureFlagPayload` struct still has no `DefaultValue` field and
`FeatureFlagEvaluations.IsEnabled(key string) bool` still hardcodes `return false` for an unknown
flag; .NET is unchanged in the same way. Note that posthog-python has since satisfied this through
its successor API (`evaluate_flags(...).is_enabled(default_value=...)`), which is the migration
shape the other five should follow rather than retrofitting the legacy getters.

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

This run used all 3 available slots (**posthog-go**, **posthog-dotnet**, **posthog-js**), the first
time the cap has been used in full. That leaves **9 SDKs queued**. Every one of them is past the
~4-week re-verification window, and all of them need new contract rows.

| SDK | Last-audited SHA | Last audited | Rows | New-contract rows needed |
|---|---|---|---|---|
| posthog-react-native | `e1efa57` (posthog-js monorepo) | 2026-08-06 | 59 | Yes (+5) |
| posthog-flutter | `05b53dc` | 2026-08-06 | 59 | Yes (+5) |
| posthog-android | `8659a7b4` | 2026-08-10 | 59 | Yes (+5) |
| posthog-java | `8659a7b4` (posthog-android monorepo) | 2026-08-10 | 59 | Yes (+5) |
| posthog-python | `95c7f6e0` | 2026-08-17 | 62 | Yes (+2) |
| posthog-node | `fbdb6c7b` (posthog-js monorepo) | 2026-08-17 | 62 | Yes (+2) |
| posthog-ios | `c0218386` | 2026-08-17 | 62 | Yes (+2) |
| posthog-php | `5451f4e0` | 2026-09-28 | 63 | Yes (+1) |
| posthog-ruby | `185060ab` | 2026-09-28 | 63 | Yes (+1) |

Prioritized for upcoming runs:

1. **posthog-python, posthog-node** — promoted to the top this run on priority rule 1. The new MCP
   Analytics spec names both of their packages (`posthog.mcp` and, for node, the monorepo
   add-on surface alongside `@posthog/mcp`), and MCP Analytics is the only capability whose
   applicability table names specific SDKs by package — so these are rule-1 selections in the
   strictest sense, not staleness picks. Both are also the SDKs the `capture-ai` spec names as its
   two reference implementations, which makes them the right place to check whether posthog-dotnet's
   Capture AI 🟡 ([n4]) reflects a real adoption gap or a spec-applicability gap. Both have drifted
   since 2026-08-17 and both should be checked against the four-for-four holdout and
   negative-knowledge patterns above.
2. **posthog-react-native, posthog-flutter** — the two stalest pointers in the matrix (2026-08-06),
   and RN's recorded SHA is now **+676 commits** behind the monorepo HEAD this run audited, by far
   the largest drift of any recorded pointer. Both are the natural client-side audits for Session
   Replay Debug Properties, which names the mobile and hybrid SDKs as its primary conformance
   targets. posthog-flutter also still holds **all 6 remaining ❓ Unknown cells** in the matrix, and
   draining those is worth a run on its own: the posthog-js re-audit this run gives a current
   reference for the browser side of its delegation chain.
3. **posthog-android, posthog-java** — cheapest audited together, since posthog-java's
   `posthog-server/` lives in the posthog-android monorepo and both are pinned to the same
   `8659a7b4`. android carries the mobile Session Replay Debug Properties audit; java carries the
   holdout and negative-knowledge checks as the one server SDK with a local evaluator not yet
   checked against either.
4. **posthog-ios** — needs only two rows added, but Session Replay Debug Properties is a genuine
   client-side audit for it (`$recording_status`, the `$sdk_debug_*` keys, the `$snapshot`
   exclusion), and posthog-js's result this run gives a concrete browser baseline to compare the
   mobile value subset against.
5. **posthog-php, posthog-ruby** — lowest priority. Both were fully re-audited on 2026-09-28 at 63
   rows and need only the MCP Analytics row, which is ➖ N/A for both on the spec's own applicability
   table. A one-row addition does not justify a slot; fold it into whichever run has spare capacity.

At three SDKs per run the full rotation takes four weeks, which meets the ~4-week target. The
previous run's warning about a five-week rotation at two per run is resolved by using the cap in
full, and this run demonstrates that three thorough audits fit in one run when the spec delta is
smaller than last cycle's.
