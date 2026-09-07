## Context

The service change in PostHog PR #90694 is the authority: `products/feature_flags/backend/local_evaluation.py` adds the top-level response selector; `rust/feature-flags/src/properties/property_matching.rs` gates the legacy boolean-like branch and retains the empty-array truthiness exception. The parent-approved implementation contract selects released service v1 for missing/1, even where an SDK historically differs.

This repository contains contracts, not an executable local matcher or Gherkin step implementations. Validation here can establish contract coverage, parse acceptance fixtures, and validate OpenSpec; it cannot certify any SDK's runtime behavior.

## Goals / Non-Goals

**Goals:** Update the two existing capabilities via deltas and CLI archive/sync; make matching and definition-lifecycle acceptance cases unambiguous before SDK writers start.

**Non-Goals:** No implementation code, new public SDK API, new cache backend, dependency changes, compliance updates, or unrelated operator normalization changes.

## Decisions

- **Exact-2 selection, not a threshold:** missing/1 uses service legacy; only 2 enables explicit equality. Unknown versions fall back to legacy unless an existing safe-inconclusive policy applies. This follows the service instead of guessing future semantics.
- **One snapshot, not a mutable global toggle:** define version as part of the rule snapshot and require propagation through all supported caches/evaluation surfaces. Keep failure/304 state paired, reset on fresh omission, and isolate/invalidate evaluation caches on version-only changes. Do not prescribe storage primitives to SDKs.
- **Preserve existing normalization and safe fallbacks:** v2 removes only the aggregate boolean gate for nonempty filters, not canonical stringification, Unicode lowercase, numeric ambiguity protection, missing-property fallback, or existing unsupported null-filter policy. Known null property is not missing.
- **Acceptance fixtures before canonical sync:** qualify the existing legacy table, add missing/1/2 six-row and complementary negative coverage, then add normalization, propagation, reload, cache, and concurrency scenarios. Use JSON literals in value columns and the word `omitted` only for absence of the top-level selector.
- **No runtime pass claim:** use available cached Gherkin tooling to parse and compile fixtures; OpenSpec strict validation and baseline/updated contract-coverage checks demonstrate the spec change only. SDK runtime red/green belongs to each implementation lane.

## Risks / Trade-offs

- [Historical Ruby/Elixir behavior differs from service legacy] → Name service v1 as the target explicitly; implementation lanes document compatibility corrections.
- [Host runtimes lose numeric JSON kinds] → Retain existing safe-inconclusive policy rather than expanding this change into numeric normalization.
- [Not all SDKs have every cache or API surface] → Apply snapshot round-trip and wrapper checks only to supported surfaces; do not invent infrastructure.
- [Syntactically valid Gherkin is not executed acceptance] → Report parsing/compilation separately from SDK execution; leave compliance untouched.

## Migration Plan

Create and validate the proposal/deltas/tasks, receive apply authorization under the approved contract, update acceptance fixtures, and archive using the OpenSpec CLI to sync canonical requirements. No commits, staging, publication, or SDK changes occur here. Rollback, if needed, is reverting this single change's contract/fixture edits; runtime deployment is owned by SDK repositories.

## Open Questions

None beyond independent review of the completed contract lane.
