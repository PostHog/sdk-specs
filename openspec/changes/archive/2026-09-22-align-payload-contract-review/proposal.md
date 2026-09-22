## Why

PR #71 review found that the cache and snapshot contracts still permit malformed raw strings, while new payload scenarios reject them. Acceptance coverage also needs explicit source selection, default handling, stronger double-decoding controls, and consistent step text.

## What Changes

- Align cache reads and snapshot payload access with malformed-payload safety, preserving existing valid snapshot representations.
- Specify the known-flag/no-payload sentinel, including `null` for JavaScript and TypeScript payload getters.
- Split platform-specific outlines, cover local and remote structured results, and add defaults and already-decoded numeric/boolean string cases.
- Mirror acceptance scenario text and tables in canonical specs.
- Correct the original archived migration description: decoded-value getter contracts also affect APIs returning valid serialized strings.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `feature-flag-cache`: Prohibit exposing malformed serialized payloads as raw values.
- `evaluate-flags`: Require validation even for raw-string snapshot payload accessors.
- `get-feature-flag-payload`: Clarify the absent sentinel and strengthen default and double-decoding scenarios.
- `get-feature-flag-result`: Cover client cache and server local/remote paths explicitly.
- `get-feature-flags-and-payloads`: Use scenario-level platform tags and consistent steps.

## Impact

Specs and acceptance documentation only. No SDK source changes. Existing valid raw-string snapshot APIs remain supported, but must validate JSON before exposing it. The older decoded-value getter contract may require a Go return-type migration. The historical compliance audit is not a certification against these updated requirements.
