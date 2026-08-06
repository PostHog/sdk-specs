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

## Roll-up

| SDK | Overall | ✅ | 🟡 | ❌ | ➖ | ❓ | Last audited | Open gaps | File |
|---|---|---|---|---|---|---|---|---|---|
| posthog-js | 34/59 fully compliant (58%) | 34 | 15 | 7 | 3 | 0 | 2026-08-06 · `e1efa57` | 22 | [posthog-js.md](posthog-js.md) |
| posthog-python | 10/59 fully compliant (17%; 29 contracts N/A on a server SDK) | 10 | 13 | 7 | 29 | 0 | 2026-08-06 · `55370ee` | 20 | [posthog-python.md](posthog-python.md) |
| posthog-android | 33/59 fully compliant (56%) | 33 | 19 | 4 | 3 | 0 | 2026-08-06 · `0d2b16b` | 23 | [posthog-android.md](posthog-android.md) |
| posthog-ios | Pending initial audit | – | – | – | – | – | never | – | – |
| posthog-node | Pending initial audit | – | – | – | – | – | never | – | – |
| posthog-flutter | Pending initial audit | – | – | – | – | – | never | – | – |
| posthog-react-native | Pending initial audit | – | – | – | – | – | never | – | – |
| posthog-php | Pending initial audit | – | – | – | – | – | never | – | – |
| posthog-ruby | Pending initial audit | – | – | – | – | – | never | – | – |
| posthog-go | Pending initial audit | – | – | – | – | – | never | – | – |
| posthog-java | Pending initial audit | – | – | – | – | – | never | – | – |
| posthog-dotnet | Pending initial audit | – | – | – | – | – | never | – | – |

"Overall" for posthog-python is computed against the 30 contracts actually applicable to a
server SDK (10 Pass / 30 applicable = 33% of applicable contracts pass; shown above as raw
Pass/59 for comparability with client SDKs, which see N/A far less often).

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

Full contract-by-contract detail (all 47 posthog-js, 38 posthog-python, and 47 posthog-android
non-Pass cells) is in the respective per-SDK files.

## Cross-cutting pattern worth flagging

The **Feature Flag Called Tracker** minimal-event allowlist gap (missing session-attribution
properties from the most recently merged spec change) shows up as Partial in both
posthog-python and posthog-android this run, and was already noted as fixed in posthog-js/-node
by the posthog-js auditor. Worth a human check on posthog-ios/-flutter/-react-native/-php/-ruby/-go/-java/-dotnet
when they're audited, since this looks like a fix that was rolled out to some SDKs but not
others.

## Unknown (❓) cells needing human review

None this run — all three audited SDKs (posthog-js, posthog-python, posthog-android) resolved
every one of their 59 contracts to a concrete ✅/🟡/❌/➖ status with direct code evidence.

## Pending initial audit

posthog-ios, posthog-node, posthog-flutter, posthog-react-native, posthog-php, posthog-ruby,
posthog-go, posthog-java, posthog-dotnet — no compliance file exists yet for any of these.

## Queued for next run

This run's bootstrap cap (3 SDKs/run) was spent on posthog-js, posthog-python, and
posthog-android — the three SDKs most touched by spec changes merged in the last few weeks
(traces, retry-queue durability, capture-exception ordering, session-replay idle-rotation,
feature-flag-called session attribution). All 9 remaining pending-initial-audit SDKs are queued;
next run should continue draining that backlog, prioritizing posthog-ios and posthog-node (also
referenced heavily in the same recent spec changes) before rotating to posthog-flutter,
posthog-react-native, posthog-php, posthog-ruby, posthog-go, posthog-java, and posthog-dotnet.
