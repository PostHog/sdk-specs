## Context

Capture property values reach the wire through each SDK's JSON encoder or a normalization step
before it. For container types the SDKs disagree, and most outcomes lose the data. The only
adjacent spec text is `openspec/specs/register/spec.md:42`: SDKs "may reject ... non-serializable
objects after sanitization".

Each repo was read at `origin/main` on 2026-11-12. "Ran" means the encoder or normalizer was
executed standalone; the SDK was not run end to end anywhere.

| SDK | SHA | Set-like value today | Listed sequence today | Status under this change | Where |
|---|---|---|---|---|---|
| posthog-python | 5378ece8 | array | array (`tuple`, `deque`) | conforms (merged in #1230 on 2026-11-12, not yet released) | `posthog/utils.py:92`. Tests: `posthog/test/test_utils.py:311` (`tuple`), `:321` (`frozenset`, `deque`). No `set` test. |
| posthog-android | d753954d | array | array | conforms | `internal/GsonSafeMapSerializer.kt:58-60` falls through to `gson.toJsonTree`, whose collection adapter writes arrays. Code reading. |
| posthog-dotnet | 6f08ed0a | array | array | conforms | `src/PostHog/Json/JsonSerializerHelper.cs:8`, System.Text.Json by runtime type. Ran. `Stack<T>` (pop order) is out of scope. |
| posthog-rs | 9517fbde | array | array | conforms | `src/event.rs:152` `serde_json::to_value`. Serde writes sets and `VecDeque` as sequences. |
| posthog-go | cbf49d41 | n/a | n/a | conforms (nothing to do) | `properties.go:16`, `event_properties_json.go:35`. |
| posthog-unreal | 97d187e2 | not admitted | n/a | conforms (nothing to do) | `Public/PostHogProperties.h:12-31`: `FPostHogValue` takes no `TSet`. |
| posthog-js core (node, react-native) | e609837f | `{}` | n/a | small fix | `packages/core/src/utils/string-utils.ts:27` `safeJsonStringify`, used at `posthog-core-stateless.ts:1615`. Ran `JSON.stringify`. |
| posthog-js browser | e609837f | `{}` | n/a | small fix (2 places) | `packages/browser/src/posthog-core.ts:2031` `_copyAndTruncateStrings` → `deepCircularCopy` (`browser-common/src/utils/general-utils.ts:123`), whose `each()` iterates own keys only (`:35`). Then `request-utils.ts:9` `jsonStringify`. |
| posthog-ruby | 669aabfa | `"#<Set: {1}>"` | n/a | small fix | `lib/posthog/transport.rb:157` `JSON.generate`. `lib/posthog/utils.rb:58` `isoify_dates` is top-level only. Ran on Ruby 3.3.5. |
| posthog-ios | 986df1a0 | key dropped | n/a | small fix | `PostHogSDK.swift:965` → `Utils/DictUtils.swift:70` `sanitizeInvalidValue` returns `nil`, `:61` removes the key. Ran the two Swift checks it relies on. |
| posthog-unity | 854e0c4e | type-name string | type-name string | small fix | `Runtime/Utilities/JsonSerializer.cs:111-122`: only `IDictionary` and `IList`, else `ToString()`. Code reading. |
| posthog-elixir | 401a4a02 | `{"map":{"1":[],...}}` | n/a | small fix | `lib/posthog.ex:81` `RedactorEncoder.encode` exposes the `MapSet` struct. Ran with the locked versions. |
| posthog-flutter | f11de779 | mobile and web: array. Desktop: string. | string (`Queue`) | small fix | `lib/src/utils/property_normalizer.dart:26` handles `Set`, `:37` stringifies the rest. Desktop: `lib/src/core/utils/utils.dart:50-54` `toJsonValue` stringifies. Normalizer ran; desktop from code reading. |
| posthog-kmp | e92e1656 | Android/JVM: array. iOS/macOS: dropped. wasm: string. JS: not verified. | n/a | small fix (3 converters) | `appleMain/.../NativeProperties.apple.kt:79`, `jsMain/.../PostHog.js.kt:385-392`, `wasmJsMain/.../PostHog.wasmJs.kt:296-308`. Code reading. |
| posthog-godot | b1db27ef | n/a | whole event dropped | small fix | `addons/posthog/internal/utils.gd:38-55` `is_json` rejects Packed arrays, so `posthog.gd:150` drops the event. Code reading. |
| posthog-php | ff58bda9 | n/a (no built-in set) | `SplQueue` → `{}`. `SplFixedArray` → array. | medium fix | `lib/Internal/JsonEncoder.php:32` plain `json_encode`, no pre-walk. Ran. |

Not checked: posthog-pi, posthog-openclaw, posthog-opencode.

## Goals / Non-Goals

**Goals:** One wire shape for set-like values and for a closed, per-runtime list of ordered
sequence types, so every SDK can conform and no two conforming SDKs differ.

**Non-Goals:**

- Keyed containers other than plain objects/maps. JavaScript `Map` becomes `{}` today. An object
  with stringified keys loses data when keys are not strings, and an entries array is a different
  shape. That needs its own decision.
- Byte containers. Python decodes `bytes` to a UTF-8 string today (`posthog/utils.py:144`).
  UTF-8 string, base64 and an array of numbers are all plausible.
- Lazy or one-shot iterables. Serializing one consumes it, so a retry or a disk round-trip sees
  it empty, and an infinite one would block the host. The posthog-python #1230 author left these
  out for the same reason.
- Order-defined collections not in the table, such as .NET `Stack<T>`.
- Containers the runtime represents as plain tuples, such as Erlang `:queue` and `:gb_sets`. No
  SDK can recognize them.
- `capture_ai`, `capture_exception` and super properties. They can reference this requirement
  later.
- SDK implementation.

## Decisions

- **Three categories.** Set-like values become arrays. Listed finite ordered sequences become
  arrays in order. Everything else above is explicitly out of scope. A general "all containers"
  rule would include types no SDK can serialize safely or recognize, and types with no agreed
  shape.
- **The sequence category is a closed table per runtime.** "Ordered sequence" has no shared
  meaning across languages. PHP has no built-in set, and Godot has no set type at all. An
  unlisted runtime applies the set category and treats the sequence category as empty.
- Set element order is not specified. Sequence order is kept.
- Elements go through the same cleanup as other values, so nested null-property omission and
  array-position rules still apply.

### Strictness: option C (chosen 2026-11-12)

posthog-js is the behavioral reference, and it turns a `Set` into `{}`. A rule that set-like
values become arrays diverges from it. The options:

- **A. Informative note only.** Add prose to the capture spec that lists current behavior per SDK.
  No requirement, no scenario. No SDK becomes non-conformant. The table goes out of date, and the
  spec names no winner, which `openspec/project.md` asks for when SDKs diverge.
- **B. SHOULD-level guidance.** SDKs SHOULD follow the rule, and the non-conforming SDKs are
  listed as known gaps. Two SDKs can stay different and both conform.
- **C. SHALL requirement plus scenarios** (drafted in `specs/capture/spec.md`), with follow-up
  changes for the SDKs that need a fix. They are non-conformant until each follow-up lands.

**Chosen: C.** With the three-category scope, every SDK can conform: six already do, and
the rest need a small fix (posthog-php a medium one). Every non-array outcome today loses the
elements as structured data (`{}`, `null`, a dropped key or event, or a debug string), so callers
are unlikely to depend on it. The posthog-js behavior is a side effect of generic object copying
and `JSON.stringify`, not a choice. The null-property precedent
(`openspec/changes/archive/2026-09-08-preserve-nullable-capture-api/`) also used SHALL with
per-SDK rollout. B leaves two conforming SDKs with different output for the same input.

## Risks / Trade-offs

- Serialized output changes in posthog-js, posthog-ruby, posthog-ios, posthog-unity,
  posthog-elixir, posthog-flutter, posthog-kmp, posthog-godot and posthog-php → follow-up
  changes and release notes.
- A posthog-ruby caller who loads `json/add/set` gets `{"json_class":"Set","a":[...]}` today.
  That output also changes.
- The per-runtime table needs an update when a new SDK runtime is added.
- Unordered set output makes test fixtures order-sensitive → scenarios use one-element sets or
  compare without order.
