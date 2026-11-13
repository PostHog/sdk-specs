## Context
Verified PostHog/posthog#132949 at `a12a5b7991e7d1562cd571ea89a13b73e5638a5c` and Python main at `c60e7a62d78689a38ad87bd31241b9678ef7d061`. The backend PR is not yet merged.

Sources: [scorer API](https://github.com/PostHog/posthog/blob/a12a5b7991e7d1562cd571ea89a13b73e5638a5c/products/ai_observability/backend/api/score_definitions.py), [upload serializer](https://github.com/PostHog/posthog/blob/a12a5b7991e7d1562cd571ea89a13b73e5638a5c/products/ai_observability/backend/api/offline_experiment_serializers.py), and [ingestion service](https://github.com/PostHog/posthog/blob/a12a5b7991e7d1562cd571ea89a13b73e5638a5c/products/ai_observability/backend/offline_evaluation_service.py).

## Goals / Non-Goals
Support composites through the existing scorer and upload clients, including ingestion-only credentials. Local formula engines, nested composites, experiment-level formulas, and result inspection APIs are outside this change.

## Decisions
- Calculation is independent of output kind. Composition pins exact reported versions; immutable version creation always supplies it explicitly.
- Use server validation with optional output config. SDKs validate declaration shapes and preserve structured server errors rather than duplicating the formula interpreter.
- Keep ordinary wire requests unchanged. Missing old scorer metadata defaults to reported; legacy reported receipt status is unknown (None in Python). Composite receipts must contain a stored outcome.
- Keep every supplied result for a composite-bearing item together. Merge overlapping spans to preserve order and error indices without hidden read requests. This deliberately uses conservative groups because an ingestion-only caller may know only the composite version UUID. Reject oversized groups before any network writes; callers can prepare smaller adjacent item batches or explicitly use stored inputs with read-scoped credentials.
- Preserve original calculation bytes for replay, including after closure. Current access checks remain backend-owned.

## Risks / Trade-offs
Conservative grouping can reject a batch whose dependencies could fit after caller reordering. Document adjacency and retain ordinary-only chunking. A successful HTTP response can contain an error outcome; callers must inspect receipts. Backend rollout must precede composite usage; omit new fields for ordinary operations.

## Migration Plan
Sync and archive both capability deltas in this PR, then release SDK support after backend deployment. Existing acceptance files remain tagged @server, not @sdk:server, until harness bindings are verified with a real adapter.
