## Context and sources

Canonical behavior comes from the flags service and the Python fix, not the currently divergent SDK implementations:

- [Backend holdout precedence and hashing](https://github.com/PostHog/posthog/blob/5caf339ee80/rust/feature-flags/src/flags/flag_matching.rs): holdout selection precedes release conditions; `get_holdout_hash` uses flag-level aggregation and the prefix `holdout-`.
- [Backend rollout comparison](https://github.com/PostHog/posthog/blob/5caf339ee80/rust/feature-flags/src/flags/v1_bucketing.rs): 100 bypasses hashing; otherwise compare inclusively.
- [Python implementation](https://github.com/PostHog/posthog-python/blob/9c84daafa5194fe3340b0169452e02adb8801da5/posthog/feature_flags.py) and [PR #978](https://github.com/PostHog/posthog-python/pull/978): SHA-1 first 15 hex digits, normalization by `0xFFFFFFFFFFFFFFF`, percentage clamping, and holdout resolution before conditions.
- The existing definition-loader contract requires complete definition snapshots; holdout fields must therefore survive typed models and cache round-trips.

## Decisions

1. Return `holdout-<id>` as a synthetic string variant, not false, and do not require it in the ordinary variant list. Keep the inactive-flag short circuit and unrelated fallback rules.
2. Use `holdout-<bucketing_value>`, without the dot used by ordinary flag hashes. Exclude both flag key and holdout id so the same identity and percentage select the same population across flags.
3. Preserve fractional percentages and clamp to 0–100. Preserve the backend's inclusive comparison even at the theoretical exact-zero hash boundary; do not inaccurately claim that zero percent can never match any hash.
4. Use flag-level identity, not a later condition's aggregation override. Full membership bypasses hashing; existing context-resolution and unsupported-feature rules are otherwise unchanged.
5. Preserve metadata in existing definition stores and drop stale holdouts when a new snapshot removes them. Do not add a new cache mechanism.
6. Skip holdout objects whose `id` or `exclusion_percentage` is missing or null, matching Python's `_get_holdout_variant`. Continue ordinary evaluation without constructing a holdout variant.

## Validation

Acceptance scenarios cover precedence, inactive/absent holdouts, four missing/null field cases, bulk/dependencies, membership vectors, boundaries, group/device identity, cache round-trips, and removal on refresh. The exact-zero inclusive rule remains in the requirement text without a standalone acceptance scenario requiring an injected hash. This does not assert that a zero hash is mathematically impossible. These feature files are contracts, not a claim that SDK conformance tests have run.

Independent SHA-1 calculations pin two 20% membership cases: `user-1` hashes to 0.17805599206573022 and is held out; `user-5` hashes to 0.6563813925994418 and is not. The incorrect `holdout.` prefix yields 0.455744838790653 and 0.02397893259616086 respectively, reversing both outcomes.

Run strict OpenSpec validation before and after archiving. SDK implementations and executable conformance remain follow-up work in their respective repositories.

## Risks

Correcting local evaluation changes assignments for populations that previously bypassed holdouts. Missing serialization fields can preserve the bug despite a fixed evaluator; the loader requirement makes that boundary explicit. Recovery for malformed/non-finite inputs other than the explicit missing/null field exception is intentionally not standardized here.
