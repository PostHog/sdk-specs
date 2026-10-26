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
posthog-go, posthog-java, posthog-dotnet. **64 contracts** are tracked per SDK: the 64
capabilities listed in the root `README.md` table.

**Eleven of the twelve SDKs now carry all 64 rows.** The five contracts that were newer than most
per-SDK files — **Capture AI**, **Evaluate Flags**, **Exception Event Metadata**, **Session Replay
Debug Properties** and **MCP Analytics** — were backfilled onto posthog-react-native,
posthog-flutter and posthog-android this run. Only **posthog-java** is still short (59 rows), and it
leads the queue below.

**No SDK is pending its first audit.** Every run since the backlog drained has been a re-audit
run, and selection is driven by the four-rule priority order at the top of this file.

## This run (2026-10-26)

sdk-specs advanced from `75c8f5d` (last run's baseline) to `b865140`, an **18-commit span** touching
`openspec/specs/` or `acceptance/` (23 commits in total) — unusually broad rather than deep: no new
capability, but fourteen separate contracts changed, most of them client-applicable.

The changes that drove this run's findings:

- **Capture / Register** ([#114](https://github.com/PostHog/sdk-specs/pull/114), `a86f68e`) — a new
  hard requirement, "Caller-supplied event properties take precedence". On a client SDK a property
  the caller passes on an event now wins over a registered (super) property **and over an SDK context
  property of the same key** (`$lib`, `$os`, `$app_version`, `$screen_name`, `$feature/<key>`, …),
  with an explicit allowlist of the SDK-owned keys that may still be applied afterwards. This is the
  one change this cycle that can *downgrade* a previously-passing row, and it did.
- **Capture Exception / Exception Event Metadata**
  ([#103](https://github.com/PostHog/sdk-specs/pull/103), `8ee7d7a`) — `$exception_list[0].type` /
  `.value` are now canonical and the legacy top-level `$exception_type` / `$exception_message`
  properties are explicitly "not required for standard capture paths". This **withdraws** the basis of
  an existing ❌.
- **Capture Exception** ([#95](https://github.com/PostHog/sdk-specs/pull/95), `73a3954`) — a new
  "Ignored exception types" requirement that names `errorTrackingConfig.ignoredExceptionTypes` on
  posthog-ios and posthog-android by name, and requires the drop to apply on *every* path including
  `$exception` events handed to the generic capture API by the Flutter and React Native bridges.
- **Surveys** ([#93](https://github.com/PostHog/sdk-specs/pull/93), `f238b16`) — a survey containing a
  question type the SDK cannot display must be skipped **whole**, logged, not marked seen, and must not
  block another eligible survey; wrappers must apply the check on the shared path that feeds their
  renderers rather than in each renderer.
- **Setup** ([#108](https://github.com/PostHog/sdk-specs/pull/108), `c2f09c1`) — the project credential
  config option is named `projectToken`, with any surviving `apiKey` spelling kept as a deprecated
  alias in the same release so the rename does not need a major version.
- **HTTP Client** ([#110](https://github.com/PostHog/sdk-specs/pull/110), `f62a029`) — a connection
  actively refused by the destination is *not* a transient transport condition: flag requests must not
  retry it. DNS, TLS, timeout and connection-reset failures still retry.
- **Event Batcher** ([#92](https://github.com/PostHog/sdk-specs/pull/92), `09acafd`) — replay upload
  requests must not mix sessions or identities, using the identifiers stored **on each snapshot
  event**, including for snapshots restored from storage and requests rebuilt for retry.
- **Session Replay Debug Properties** ([#96](https://github.com/PostHog/sdk-specs/pull/96), `c414d50`)
  — the contract was rewritten into a required-key tier plus a gated, 30-second-throttled optional
  bundle, with a mobile-specific four-key required list.
- Also: **Session Replay Ingestion Controls**
  ([#83](https://github.com/PostHog/sdk-specs/pull/83)) held-epoch size cap; **Application Lifecycle**
  ([#101](https://github.com/PostHog/sdk-specs/pull/101)) `$app_version`/`$app_build`; **Reload
  Feature Flags** ([#99](https://github.com/PostHog/sdk-specs/pull/99)) optional completion failure
  reporting; **Flag Definition Loader** ([#78](https://github.com/PostHog/sdk-specs/pull/78))
  snake_case shared-cache field names (server-only); and **MCP Analytics**
  ([#98](https://github.com/PostHog/sdk-specs/pull/98)) fresh server argument ownership (server-only).

Selection: **posthog-react-native**, **posthog-flutter**, and **posthog-android** — the full
three-SDK cap, and the top three of the previous run's queue in order. Rules 1, 2 and 4 all point the
same way for these three, which is why the queue did not need re-ranking:

- **Rule 1 (spec-affected).** Nine of this cycle's fourteen changed contracts are client-applicable,
  and three of them (Application Lifecycle `$app_version`/`$app_build`, the rewritten replay debug
  property tiers, and the `ignoredExceptionTypes` option that explicitly names the Flutter and RN
  bridges) are *mobile*-specific. No other cohort was this exposed.
- **Rule 2 (changed since last audit).** All three were confirmed heavily code-drifted:
  posthog-react-native `e1efa57`→`2e98ca8d`, posthog-flutter `05b53dc`→`07ee92df`, posthog-android
  `8659a7b4`→`129a83a1`.
- **Rule 4 (staleness backstop).** These were the four oldest audits in the matrix (2026-08-06 and
  2026-08-10) together with posthog-java; all were ~11 weeks past the ~4-week re-verification window.
  posthog-java is the one left behind and leads the queue below.

All three were audited as **targeted** re-audits rather than full 64-row re-derivations, the same
approach used for posthog-js last cycle: the rows the delta lands on, every prior ❌/❓ row, and the
five contracts that had no row at all. Each per-SDK file states its own scope in the header.

### posthog-android — 39 ✅ · 15 🟡 · 4 ❌ · 6 ➖ · 0 ❓ (was 31/16/9/3/0 on 59 rows)

**The most improved SDK this matrix has recorded.** Six rows moved ❌→✅ or 🟡→✅ on real code
changes, and all six were things the previous audit called out specifically: `alias()` now carries
`distinct_id`; `screen()` applies the title *after* merging caller properties, the exact inversion
n11 flagged; `close()` calls `flush()`; `startSessionReplay()` is opt-out aware and takes the start
under `setupLock`; `isRetryableFlagsError` gained `UnknownHostException` and `SSLException`
(PostHog/posthog-android#828, which the last audit recorded as approved-but-unmerged) while correctly
*keeping* `ConnectException` fail-fast — which spec change #110 has since made the required
behaviour. The largest single change is **Autocapture ❌→✅**: a full `$autocapture` pipeline now
exists (`PostHogElementInteractionIntegration`, `InteractionTarget` building `$elements_chain`, with
`posthog_autocapture_no_capture` / `ph-no-capture` subtree exclusion and Compose support), where the
previous audit found nothing but the session-touch integration.

**Capture Exception ❌→✅ is a spec change, not a code change** — #103 withdrew the top-level
`$exception_type`/`$exception_message` requirement the ❌ rested on. Separately, the new
`ignoredExceptionTypes` requirement is already implemented on both paths, including the
qualified-class-name rejoin for events handed over by the Flutter and RN bridges.

**Capture was reconfirmed against the new precedence requirement and passes exactly**, including the
five-step client ordering and the carve-out for a caller-supplied `$session_id` — `buildProperties`
even carries comments explaining why `$is_identified` and the replay debug bundle are applied after
the caller's map. **Session Replay Debug Properties ✅ on first audit**: the four mobile required
keys, the exactly-four-key mobile optional bundle, a single-outstanding-claim 30-second throttle that
a capture nested inside `beforeSend` cannot steal, `$snapshot` exclusion via
`appendSharedProps = !isSnapshotEvent`, and a minimal `$feature_flag_called` allowlist.

**Exception Event Metadata ❌ on first audit** is the one bad result, and it is bad in five
independent ways at once: `synthetic` is the literal `false` on every entry (a forbidden placeholder),
`handled` is resolved once and copied onto every cause and suppressed entry, `mechanism.source` is
never emitted at all (the parent edge is smuggled into `type` as `"suppressed"`), `exception_id` is
omitted entirely on single-entry lists, and `$exception_source` is never set — including from the
uncaught handler the spec's canonical table maps to `android.uncaught_exception_handler`.

Two new gaps were added to existing 🟡 rows: no question-type gate in `getActiveMatchingSurveys`
(#93), and no size cap on a held replay epoch (#83). Still ❌: Get Feature Flags and Get Feature Flags
And Payloads (no public flat/bulk getters) and Traces (no `/i/v1/traces` pipeline).

### posthog-react-native — 32 ✅ · 24 🟡 · 2 ❌ · 5 ➖ · 1 ❓ (was 31/23/2/2/1 on 59 rows)

Three consecutive runs had RN at the top of the queue and three times it was displaced. The audit
when it finally ran found **no row changed status on code movement** — the drift was large (+2.5
months of monorepo commits) but landed on shared `@posthog/core` internals rather than on contracted
RN behavior.

The useful results are the two new client rows. **Session Replay Debug Properties ✅** — RN's
implementation is the reference-quality one for the rewritten #96 contract: a single outstanding
bundle claim so a capture nested in `before_send` cannot also take it, a throttle window that starts
when the carrying event is *accepted* rather than when it is built, `$snapshot` stripped of all debug
keys, and a backdated-event check so a previous-process crash reported on this launch does not
describe this session's state. **Exception Event Metadata 🟡** — the shared `@posthog/core`
`ErrorPropertiesBuilder` gives RN full depth-first `exception_id`/`parent_id` linkage, `chained` +
`cause`/`member` sources, no inherited `handled`, and the spec's 50-entry and 1,000-member budgets
implemented literally. Its one real gap is the same one posthog-js has: `$exception_source` is never
set anywhere in the monorepo, so RN's three distinct capture boundaries are indistinguishable
downstream. One fix in `@posthog/core` plus the per-integration call sites closes it on both SDKs.

**Traces stays ❌, but the remediation changed shape.** At the last audit there was no OTLP span
implementation anywhere in the monorepo; `packages/core/src/traces/` is now a complete one — span
model, context manager, traceparent, OTLP encoding, live spans — wired into the shared stateless core
and consumed by posthog-node. React-native simply does not consume it. That is wiring, not building.

Is Opt Out remains the other ❌ (`optedOut` is still a getter property with no callable `isOptOut()`,
unlike every other audited client SDK), Capture stays 🟡 on the missing non-empty event-name guard,
and HTTP Client stays 🟡 on the fixed-delay backoff — both shared-core defects that fix browser, node
and react-native together. Session Replay Privacy is the only ❓ cell and stays ❓ deliberately: it
depends on native code in a legacy package not cloned for this audit.

### posthog-flutter — 19 ✅ · 25 🟡 · 6 ❌ · 8 ➖ · 6 ❓ (was 20/22/6/5/6 on 59 rows)

**The repo is not the same shape it was.** At `05b53dc` posthog-flutter was a thin Dart wrapper, which
is why eleven of its rows were ❓ or ➖ — the contracted behavior lived in native code this repo does
not contain. It now ships a **first-party Dart implementation** under `posthog_flutter/lib/src/core/`
(capture, batching, feature flags, session management, persistence, file storage) for a new
Windows/Linux desktop target, plus Dart-side surveys, error tracking, replay and logs.

That produced this run's only *downgrade anywhere in the matrix*: **Capture ✅→🟡**. The desktop Dart
core's `_enrichProperties` spreads the SDK context and common properties **after** the caller's
properties, and the code comment states the intent plainly — "It wins over registered and event
properties of the same name". That was a defensible reading until #114 merged; the requirement now
says the opposite for client SDKs. It is the only Needs-deprecation-path verdict added this run,
because the SDK's own documentation currently promises the behavior that is now non-conformant.

**Setup's 🟡 survived but its reason shrank to one item.** The `projectToken` rename (#108) is fully
and correctly implemented — primary positional parameter, trimmed, with a `@Deprecated` `apiKey`
getter returning the same value and both names carried on the platform-channel map so older native
shims keep working — and a blank-token guard was added. Only the double-init guard is still missing,
and even that is less harmful now that `_installFlutterIntegrations` uninstalls first.

**Shutdown ❌→🟡**: the underlying posthog-android `close()` now flushes, closing the original failure
on the largest platform; the desktop path's bounded two-second send attempt keeps it short of ✅.
**Exception Event Metadata ❌** on first audit — no linkage fields at all, causes inheriting the
outermost `handled` and `type`, no `mechanism.source`, non-canonical mechanism categories
(`FlutterError`, `PlatformDispatcher`, `isolateError`) where the spec wants an `$exception_source`
that is never set, a hardcoded `$exception_level: 'error'`, and a chain cap of 10 against the spec's
50. **Session Replay Debug Properties 🟡** — the native platforms inherit posthog-android's
conforming split, but the desktop core sends optional-bundle keys on every event with no eligibility
gate and no throttle.

**The six ❓ rows stay ❓, and the reason has changed.** Event Batcher, Feature Flag Called Tracker,
HTTP Client, Persistent Storage, Remote Config and Retry Queue were Unknown because the behavior was
unverifiable from this repo. The desktop Dart core now implements all six, so they are no longer
unverifiable — merely unaudited. Resolving them needs a dedicated pass over the new core rather than
a verdict inferred from a skim, and guessing would be worse than the ❓. That pass is queued.

## Roll-up

| SDK | Overall | ✅ | 🟡 | ❌ | ➖ | ❓ | Last audited | Open gaps | File |
|---|---|---|---|---|---|---|---|---|---|
| posthog-js | 26/64 fully compliant (41%) | 26 | 21 | 12 | 5 | 0 | 2026-10-05 · `6538babc` (targeted re-audit; most of the 59 pre-existing rows carried from 2026-08-10, see file header) | 33 | [posthog-js.md](posthog-js.md) |
| posthog-python | 14/62 fully compliant (23%; 29 contracts N/A on a server SDK; **needs +2: Session Replay Debug Properties, MCP Analytics**) | 14 | 12 | 7 | 29 | 0 | 2026-08-17 · `95c7f6e0` | 19 | [posthog-python.md](posthog-python.md) |
| posthog-android | 39/64 fully compliant (61%) | 39 | 15 | 4 | 6 | 0 | 2026-10-26 · `129a83a1` | 19 | [posthog-android.md](posthog-android.md) |
| posthog-ios | 38/64 fully compliant (59%) | 38 | 16 | 4 | 6 | 0 | 2026-10-08 · `f5cbe87c` + PostHog/posthog-ios#924–#934 (out-of-cycle refresh, see below) | 20 | [posthog-ios.md](posthog-ios.md) |
| posthog-node | 10/62 fully compliant (16%; 28 contracts N/A on a server SDK; **needs +2: Session Replay Debug Properties, MCP Analytics**) | 10 | 16 | 8 | 28 | 0 | 2026-08-17 · `fbdb6c7b` (posthog-js monorepo) | 24 | [posthog-node.md](posthog-node.md) |
| posthog-flutter | 19/64 fully compliant (30%) | 19 | 25 | 6 | 8 | 6 | 2026-10-26 · `07ee92df` | 31 | [posthog-flutter.md](posthog-flutter.md) |
| posthog-react-native | 32/64 fully compliant (50%) | 32 | 24 | 2 | 5 | 1 | 2026-10-26 · `2e98ca8d` (posthog-js monorepo) | 26 | [posthog-react-native.md](posthog-react-native.md) |
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

**Row-count note:** 11 of the 12 in-scope SDKs are now at the full 64 rows. posthog-java is the only
file still at 59 and is first in the queue below; it is audited out of `PostHog/posthog-android`'s
`posthog-server/` subdirectory, so the next run can backfill it against a repo this run already read.

**Three movements worth noting in the raw numbers.** posthog-android's ✅ count jumped 31→39 on real
code changes plus one spec withdrawal, the largest single-run improvement this matrix has recorded,
and it is now the most compliant client SDK by both count and percentage. posthog-flutter's ✅ count
*fell* by one (20→19) while its row count grew by five, and the single downgrade — Capture ✅→🟡 —
came entirely from new spec text (#114) landing on a desktop Dart core whose own documentation
promises the opposite precedence; its percentage fall (34%→30%) is mostly the larger denominator.
posthog-react-native gained one ✅ net (31→32) despite no row changing on code movement: the two new
client-applicable rows scored ✅ and 🟡, and three of its five new rows are ➖. Percentages that move
because the denominator grew are not regressions, and the per-SDK files mark which direction each row
moved and why.

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
audited at a `posthog-js` SHA — `2e98ca8d` as of this run, which finally closes the +676-commit drift
the previous run flagged. Unlike posthog-node it extends the full client-side `PostHogCore` base, so
it is scored like a client SDK (raw Pass/64), not given the server-SDK applicable-only treatment. **posthog-java note:**
the standalone `PostHog/posthog-java` repo is also archived; its README redirects to a new home at
`PostHog/posthog-android`'s `posthog-server/` subdirectory (package `com.posthog.server`,
Kotlin/JVM), which is what that audit evaluated — its audited commit (`8659a7b4`) is a
`posthog-android` SHA. It is no longer the same commit posthog-android uses: this run moved
posthog-android to `129a83a1` while posthog-java stayed at `8659a7b4`, so the two have diverged and
posthog-java now leads the queue.

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
| posthog-android | Get Feature Flags | Backward-compatible | No public flat bulk getter; internal cache-only version exists but isn't exposed — [posthog-android.md](posthog-android.md) |
| posthog-android | Get Feature Flags And Payloads | Backward-compatible | No combined getter; returns `null` (not empty maps) on cold cache — [posthog-android.md](posthog-android.md) |
| posthog-android | Traces | Backward-compatible | No OTLP traces/spans implementation — [posthog-android.md](posthog-android.md) |
| posthog-ios | Get Feature Flags | Backward-compatible | No public flat key→value bulk flag getter — [posthog-ios.md#n9](posthog-ios.md) |
| posthog-ios | Get Feature Flags And Payloads | Backward-compatible | No combined flags+payloads getter under any name — [posthog-ios.md#n10](posthog-ios.md) |
| posthog-ios | Session Replay Privacy | Needs deprecation path | Default wireframe mode still records the children of a plain `ph-no-capture` container unmasked — [posthog-ios.md#n24](posthog-ios.md) |
| posthog-ios | Traces | Backward-compatible | No OTLP span/traces implementation anywhere — [posthog-ios.md#n2](posthog-ios.md) |
| posthog-node | Traces | Backward-compatible | No OTLP `/i/v1/traces` pipeline anywhere in the monorepo (industry-wide gap, matches posthog-python/-js) — [posthog-node.md#n2](posthog-node.md) |
| posthog-node | Capture Exception | Needs deprecation path | Deeper Exception Event Metadata verification surfaced overlapping hard failures (hardcoded `handled`/severity, missing flat properties, inverted precedence) — [posthog-node.md#n7](posthog-node.md) |
| posthog-node | Is Feature Enabled | Backward-compatible | Neither `isFeatureEnabled()` nor its successor accepts a caller `defaultValue` (hard SHALL, no server carve-out) — [posthog-node.md#n13](posthog-node.md) |
| posthog-node | Set/Reset Person/Group Properties For Flags (×4) | Backward-compatible | Zero implementation; methods exist only on the client-only base class node doesn't extend — [posthog-node.md#n15](posthog-node.md) |
| posthog-node | Exception Event Metadata | Mixed (see note) | No `exception_id`/`parent_id` tree linkage, hardcoded `handled`/`$exception_level`, no `$exception_source`, caller properties override SDK-canonical fields — [posthog-node.md#n20](posthog-node.md) |
| posthog-flutter | Get Anonymous ID | Backward-compatible | Method doesn't exist in the Dart API at all (standing `// TODO`) — [posthog-flutter.md](posthog-flutter.md) |
| posthog-flutter | Get Feature Flags | Backward-compatible | No bulk flag getter anywhere in Dart — [posthog-flutter.md](posthog-flutter.md) |
| posthog-flutter | Get Feature Flags And Payloads | Backward-compatible | No combined flags+payloads getter anywhere in Dart — [posthog-flutter.md](posthog-flutter.md) |
| posthog-flutter | Traces | Backward-compatible | No implementation; net-new, pre-GA — [posthog-flutter.md](posthog-flutter.md) |
| posthog-flutter | Tracing Headers | Backward-compatible | No implementation; Flutter has no Dart-side HTTP client of its own to intercept app traffic with — [posthog-flutter.md](posthog-flutter.md) |
| posthog-react-native | Traces | Backward-compatible | No OTLP span/traces implementation anywhere in the monorepo — [posthog-react-native.md](posthog-react-native.md) |
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
| posthog-android | Exception Event Metadata | Backward-compatible | **New this run** — `synthetic` is the literal `false` on every entry, `handled` is copied onto every cause and suppressed entry, `mechanism.source` is never emitted (the parent edge is smuggled into `type` as `"suppressed"`), `exception_id` is omitted on single-entry lists, and `$exception_source` is never set from the uncaught handler — [posthog-android.md](posthog-android.md) |
| posthog-flutter | Exception Event Metadata | Backward-compatible | **New this run** — no `exception_id`/`parent_id` linkage at all, causes inherit the outermost `handled` and `type`, no `mechanism.source`, non-canonical mechanism categories (`FlutterError`, `PlatformDispatcher`, `isolateError`) with no `$exception_source`, hardcoded `$exception_level: 'error'`, chain capped at 10 instead of 50 — [posthog-flutter.md](posthog-flutter.md) |

### 🟡 Partial (highlights — see per-SDK files for the full list)

| SDK | Contract | Backwards-compat verdict | Note |
|---|---|---|---|
| posthog-flutter | Capture | **Needs deprecation path** | **Downgraded from ✅ this run on new spec text** — the desktop Dart core's `_enrichProperties` spreads SDK context and common properties *after* the caller's properties, and its doc comment documents that inverted precedence as intentional; spec change #114 now requires the opposite on client SDKs — [posthog-flutter.md](posthog-flutter.md) |
| posthog-react-native | Exception Event Metadata | Backward-compatible | **New this run** — linkage, chaining, sources and the 50/1,000 budgets are all correct in `@posthog/core`; `$exception_source` is never set anywhere in the monorepo, so RN's three capture boundaries are indistinguishable downstream (same gap as posthog-js) — [posthog-react-native.md](posthog-react-native.md) |
| posthog-flutter | Session Replay Debug Properties | Backward-compatible | **New this run** — the desktop Dart core sends optional-bundle keys (`$sdk_debug_session_start`, `$sdk_debug_current_session_duration`) on every event with no eligibility gate and no 30-second throttle, and no `$snapshot` exclusion — [posthog-flutter.md](posthog-flutter.md) |
| posthog-android | Surveys | Backward-compatible | **New gap this run** — no question-type gate in `getActiveMatchingSurveys`, so a survey carrying a newer question type is partially rendered instead of skipped (spec change #93); inherited by posthog-flutter and the RN bridge — [posthog-android.md](posthog-android.md) |
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
[posthog-node.md#n20](posthog-node.md), and [posthog-ios.md#n19](posthog-ios.md). Since this is a
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

None — all 12 in-scope SDKs have at least one full audit on file. The row-count backfill that has run
alongside the rotation since Capture AI, Evaluate Flags, Exception Event Metadata, Session Replay
Debug Properties and MCP Analytics landed is now down to **one SDK**: posthog-java, at 59 rows.

## Queued for next run

This run used all 3 slots (**posthog-react-native**, **posthog-flutter**, **posthog-android**) — the
top three of the previous queue, in order. That leaves **9 SDKs queued**. Eight of them are already
at 64 rows, so the rotation is now almost pure re-verification rather than backfill.

| SDK | Last-audited SHA | Last audited | Rows | Weeks since |
|---|---|---|---|---|
| posthog-java | `8659a7b4` (posthog-android monorepo) | 2026-08-10 | 59 → needs the 5 new rows | 11 |
| posthog-python | `95c7f6e0` | 2026-08-17 | 62 → needs +2 | 10 |
| posthog-node | `fbdb6c7b` (posthog-js monorepo) | 2026-08-17 | 62 → needs +2 | 10 |
| posthog-php | `5451f4e0` | 2026-09-28 | 63 → needs +1 | 4 |
| posthog-ruby | `185060ab` | 2026-09-28 | 63 → needs +1 | 4 |
| posthog-go | `08549f42` | 2026-10-05 | 64 | 3 |
| posthog-dotnet | `ae4d019c` | 2026-10-05 | 64 | 3 |
| posthog-js | `6538babc` | 2026-10-05 | 64 | 3 |
| posthog-ios | `f5cbe87c` | 2026-10-08 | 64 | 2.5 |

(The three SDKs audited this run now carry 64 rows each; the "needs +N" column above is what is left
of the row backfill, confined to five SDKs and dominated by posthog-java's five.)

Prioritized for upcoming runs:

1. **posthog-java** — now the single stalest audit in the matrix (2026-08-10, 11 weeks) and the last
   SDK still at 59 rows. It is also the one server SDK with a local evaluator that has never been
   checked against the holdout or negative-knowledge patterns, and it carries the server-only spec
   deltas this cycle: the `flag-definition-loader` snake_case shared-cache field names
   ([#78](https://github.com/PostHog/sdk-specs/pull/78)), group-key rendering for bucketing
   ([#89](https://github.com/PostHog/sdk-specs/pull/89)), and the `$release_id` environment variable
   ([#80](https://github.com/PostHog/sdk-specs/pull/80)). Its `posthog-server/` module lives in the
   posthog-android monorepo this run just cloned and read, which makes it cheap to pick up next.
2. **posthog-python, posthog-node** — 10 weeks stale, both still at 62 rows, and both named by the
   `capture-ai` spec as its two reference implementations, which is the only way to settle whether
   posthog-dotnet's Capture AI 🟡 is a real adoption gap or a spec-applicability gap. posthog-node
   additionally has two shared-`@posthog/core` defects confirmed again this run from the react-native
   side — the missing non-empty event-name guard and the fixed-delay `/flags` backoff — so a node
   audit can close three SDKs' notes at once. Both also carry the server `$release_id` requirement.
3. **posthog-flutter's desktop Dart core (out-of-cycle, half a slot).** The six ❓ cells in this
   matrix are all posthog-flutter's, and this run established that they are no longer *unverifiable*
   — the new `posthog_flutter/lib/src/core/` implements Event Batcher, Feature Flag Called Tracker,
   HTTP Client, Persistent Storage, Remote Config and Retry Queue in Dart for the Windows/Linux
   target. Draining all six needs one focused pass over that core, not a full 64-row re-audit, and it
   would take the matrix to zero Unknown cells for the first time.
4. **posthog-php, posthog-ruby** — 4 weeks, and both need only the MCP Analytics row (➖ N/A for both
   on the spec's own applicability table). A one-row addition does not justify a slot; fold it into
   whichever run has spare capacity.
5. **posthog-go, posthog-dotnet, posthog-js, posthog-ios** — all audited within the last three weeks
   and all at 64 rows; they come back round on the ~4-week staleness backstop. posthog-js is the
   exception worth watching: the `$exception_source` gap confirmed on react-native this run is the
   same cell, and spec change #114 (caller property precedence) is browser-applicable and was not
   merged when posthog-js was last scored.

At three SDKs per run the full rotation takes four weeks, which meets the ~4-week target. This run
used the cap in full for the second consecutive time while also clearing the five-contract row
backfill on three SDKs at once, so the rotation is back on schedule.
