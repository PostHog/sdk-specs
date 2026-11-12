## Context

Capture property values reach the wire through each SDK's JSON encoder. For container types the
encoders disagree. Evidence, each repo read at `origin/main` on 2026-11-12:

| SDK | SHA | Set-like value becomes | Where |
|---|---|---|---|
| posthog-js (core) | 3e624214 | `{}` | `packages/core/src/utils/string-utils.ts:27` `safeJsonStringify` handles bigint, function, symbol, Error and cycles only. Used for `/batch/` at `packages/core/src/posthog-core-stateless.ts:1615`. |
| posthog-js (browser) | 3e624214 | `{}` | `packages/browser-common/src/utils/request-utils.ts:9` `jsonStringify` handles Error and bigint only. |
| posthog-ruby | 669aabfa | the string `"#<Set: {1}>"` | `lib/posthog/transport.rb:157` `JSON.generate`. `lib/posthog/utils.rb:58` `isoify_dates` changes dates only. Output checked with Ruby 3.3.5. |
| posthog-python | c60e7a62 | `set`, `list`, `tuple`: array. `frozenset`, `deque`: `None`. | `posthog/utils.py:92` sends `set`, `list`, `tuple` to `_clean_list`. Other unknown values reach `_coerce_unicode` (`posthog/utils.py:144`), which returns `None`. `posthog/test/test_utils.py:310` covers `tuple`. No test covers `set`. |
| posthog-python, PR #1230 (open, not merged) | 140f7660 | `frozenset`, `deque`: array | `posthog/utils.py:92` |
| posthog-go | cbf49d41 | no set type in Go. Slices and arrays are arrays. | `event_properties_json.go:35` `json.Marshal` |
| posthog-rs | efe85292 | whatever the caller's `Serialize` produces (serde serializes `HashSet` and `BTreeSet` as arrays) | `src/event.rs:152` `serde_json::to_value` |

Not verified: posthog-php, posthog-elixir, posthog-dotnet, posthog-ios, posthog-android,
posthog-flutter, posthog-unity, posthog-kmp, posthog-godot, posthog-unreal. A search found no
container step before the encoder in php (`json_encode`), elixir (`Jason.encode!`) or dotnet
(`System.Text.Json`). Their behavior for sets was not run.

The only adjacent spec text is `openspec/specs/register/spec.md:42`: SDKs "may reject ...
non-serializable objects after sanitization".

## Goals / Non-Goals

**Goals:** One wire shape for built-in set-like and ordered sequence values in custom capture
properties.

**Non-Goals:** keyed containers other than plain objects/maps (JavaScript `Map`, for example: entries
array and object are both plausible); lazy or one-shot iterables (generators, iterators, `range`),
which the posthog-python #1230 author left out on purpose; `bytes`; the fallback for other
non-JSON values; `capture_ai`, `capture_exception` and super properties (the requirement can be
referenced from them later); SDK implementation.

## Decisions (pending: one option needs a call)

posthog-js is the behavioral reference, and it turns a `Set` into `{}`. A rule that set-like values
become arrays diverges from it. The options:

- **A. Informative note only.** Add prose to the capture spec that lists current behavior per SDK.
  No requirement, no scenario. No SDK becomes non-conformant. The table rots as SDKs change, and the
  spec names no winner, which `openspec/project.md` asks for when SDKs diverge.
- **B. SHOULD-level guidance.** SDKs SHOULD serialize set-like and ordered sequence values as
  arrays. posthog-js and posthog-ruby are listed as known gaps. Two SDKs can stay different and
  both conform.
- **C. SHALL requirement plus scenarios** (drafted in `specs/capture/spec.md`), with follow-up
  changes for posthog-js and posthog-ruby. This makes posthog-js non-conformant until the follow-up
  lands.

**Recommendation: C.** Every non-array outcome today loses the data (`{}`, `null`) or sends a debug
string nobody can query, so no caller can depend on the old output. The posthog-js behavior is a
side effect of `JSON.stringify`, not a choice. The fix in each SDK is one branch in an existing
replacer or clean step. The null-property precedent
(`openspec/changes/archive/2026-09-08-preserve-nullable-capture-api/`) also used SHALL with
per-SDK rollout. B leaves two conforming SDKs with different output for the same input.

Drafted details, valid for B and C:

- "Set-like" means the runtime's built-in unordered collection types (for example Python `set` and
  `frozenset`, JavaScript `Set`, Ruby `Set`, Swift `Set`, Kotlin/Java `Set`). "Ordered sequence"
  means built-in array-like types other than the native array (for example Python `tuple` and
  `deque`).
- Set element order is not specified. Sequence order is kept.
- Elements go through the same cleanup as other values, so nested null-property omission and
  array-position rules still apply.

## Risks / Trade-offs

- posthog-js and posthog-ruby output changes → follow-up changes, release notes.
- Ruby 3.5+ may print `Set` differently, which does not matter for the rule but changes today's
  debug string.
- Unordered set output makes test fixtures order-sensitive → scenarios use one-element sets or
  compare without order.
