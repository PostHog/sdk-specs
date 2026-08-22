## Why

The evaluate-flags contract does not distinguish an omitted flag-key scope from an explicitly empty list. SDKs therefore either broaden an empty list into an unscoped evaluation or return an empty snapshot after doing unnecessary work, which can surprise callers that build the list dynamically.

## What Changes

- Define an omitted or null flag-key list as unscoped evaluation of all available flags.
- Define an explicitly empty flag-key list as a no-op that returns an empty snapshot and sends no `/flags` request.
- Keep a non-empty flag-key list scoped to exactly the requested keys for local evaluation, remote evaluation, and the returned snapshot.
- Add public acceptance coverage that distinguishes all three inputs.
- **BREAKING**: Android, Python, Go, and .NET currently treat an explicitly empty list as unscoped. They will need to return an empty snapshot instead.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `evaluate-flags`: Define omitted, empty, and non-empty request-time flag-key scopes.

## Impact

The server SDK implementations audited while preparing this change currently differ:

| SDK | Current explicit-empty behavior | Required implementation change |
|---|---|---|
| Android | Normalizes an empty list to an unscoped local evaluation and can return all flags. | Preserve the distinction from null and return an empty snapshot before fallback. |
| Python | Normalizes an empty list to `None` and evaluates all flags. | Preserve the distinction from `None` and return an empty snapshot. |
| Node.js | Returns an empty snapshot, but can still load definitions or call `/flags` before discarding the result. | Short-circuit before evaluation so `/flags` is never called. |
| Go | Uses list length for scoping, so both `nil` and an empty slice evaluate all flags. | Distinguish `nil` from an explicitly empty slice and return an empty snapshot for the latter. |
| .NET | Defaults `FlagKeysToEvaluate` to an empty collection and treats it as unscoped, so omission and explicit emptiness are indistinguishable. | Represent whether the option was supplied, then return an empty snapshot when it was explicitly empty. |

This changes the canonical public evaluate-flags contract and its acceptance suite. It does not change the behavior of snapshot-only in-memory filtering.
