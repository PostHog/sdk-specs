## Why

PR #76 review identified an ambiguity: Python skips holdouts whose id or exclusion percentage is missing or null, while the new contract could be read as forbidding that. The exact-zero hash acceptance scenario also requires injection rather than an ordinary identifier fixture.

## What Changes

- Explicitly skip incomplete holdout objects, matching Python.
- Add missing/null field acceptance cases.
- Remove the exact-zero acceptance scenario while retaining the inclusive rule in the requirement text.

## Capabilities

### Modified Capabilities

- `local-feature-flag-evaluator`: clarify incomplete holdout handling.

## Impact

Documentation and acceptance contracts only. Apply and archive this clarification on the existing PR branch. SDK code remains unchanged.
