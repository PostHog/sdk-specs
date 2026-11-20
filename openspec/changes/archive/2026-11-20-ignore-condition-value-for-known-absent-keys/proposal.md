## Why

PostHog/sdk-specs#233 says a known-absent key resolves its criterion "regardless of the condition value", but the operator inventory requirement also says a named negative operator "MUST NOT convert an invalid pattern" into a match. The two rules disagree for a listed key with a malformed condition value, such as `not_regex "["` or `gt "not-a-number"`. SDK implementations split three ways on it: some match, some return no match, and one stays inconclusive.

The flags service settles it. It removes a listed key from the property map before matching, so every operator takes its missing-value branch before it reads the condition value. `not_regex "["` returns true and `gt "not-a-number"` returns false.

## What Changes

- A known-absent key resolves its criterion from the known-absent table without parsing, compiling, or validating a present condition value.
- The negated-operator rule in the operator inventory requirement makes an exception for the known-absent table, as it already does for `not_between`.
- The regex requirement says its pattern rules apply only to a present key. For a known-absent key, `regex` doesn't match and `not_regex` matches without compiling the pattern.
- An omitted condition value stays inconclusive for a value-requiring operator, even for a known-absent key.
- Acceptance scenarios cover an invalid regex, a non-numeric number, an invalid version, an invalid date, and an omitted condition value on a listed key.

## Capabilities

### Modified Capabilities

- `local-feature-flag-evaluator`: the canonical operator inventory requirement and the regular-expression requirement.

## Impact

SDKs resolve a listed key locally with the same result as the flags service, including for a misconfigured condition value, and make no `/flags` request for it. Each SDK that validated the condition value first for a listed key needs a small change.

## Non-goals

No change for a present key, for an omitted key that isn't listed, or for operators an SDK doesn't implement locally. Those still follow the existing rules and fall back to `/flags`.
