## Context

Capture property values reach the wire through each SDK's JSON encoder. For container types the
encoders disagree. Evidence, each repo read at `origin/main` on 2026-11-12:

| SDK | SHA | Set-like value becomes | Where |
|---|---|---|---|
| posthog-js (core) | e609837f | `{}` | `packages/core/src/utils/string-utils.ts:27` `safeJsonStringify` handles bigint, function, symbol, Error and cycles only. Used for `/batch/` at `packages/core/src/posthog-core-stateless.ts:1615`. |
| posthog-js (browser) | e609837f | `{}` | Lost at capture time, before serialization: `packages/browser/src/posthog-core.ts:2031` calls `_copyAndTruncateStrings`, whose `deepCircularCopy` (`packages/browser-common/src/utils/general-utils.ts:123`) copies non-array objects through `each()`, which iterates own keys only (`general-utils.ts:35`). The serializer, `packages/browser-common/src/utils/request-utils.ts:9` `jsonStringify`, handles Error and bigint only. |
| posthog-ruby | 669aabfa | the string `"#<Set: {1}>"` | `lib/posthog/transport.rb:157` `JSON.generate`. `lib/posthog/utils.rb:58` `isoify_dates` changes dates only. Output checked with Ruby 3.3.5. |
| posthog-python | 5378ece8 | `set`, `frozenset`, `list`, `tuple`, `deque`: array | `posthog/utils.py:92` sends them to `_clean_list`. Other unknown values reach `_coerce_unicode` (`posthog/utils.py:144`), which returns `None`. `frozenset` and `deque` were added in PostHog/posthog-python#1230 (merged 2026-11-12, not yet in a release). `posthog/test/test_utils.py:311` covers `tuple` and `:321` covers `frozenset` and `deque`. No test covers `set`. |
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
string that loses the elements as structured data, so callers are unlikely to depend on the old
output. The posthog-js behavior is a side effect of generic object copying and `JSON.stringify`,
not a choice. posthog-python already sends arrays on main. The fixes are small: posthog-ruby needs
one conversion before `JSON.generate`, posthog-js core one branch in `safeJsonStringify`, and the
posthog-js browser a change in `deepCircularCopy` as well as in `jsonStringify`. The null-property precedent
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
- Unordered set output makes test fixtures order-sensitive → scenarios use one-element sets or
  compare without order.
