## 1. Source confirmation

- [x] 1.1 Confirm the AI lane on PostHog/posthog `master` (`rust/capture/src/v1/analytics/router.rs` `ai_routes`, `v1/analytics/constants.rs` `DETAIL_MISROUTED_EVENT` and `DETAIL_AI_EVENT_TOO_BIG`, `v1/analytics/process.rs` `apply_ai_event_size_limit`) and the production ceiling of 8 MiB on `properties`.
- [x] 1.2 Confirm the AI method, lane isolation, configuration and size handling on posthog-python `v1` (`client.py` `capture_ai`, `consumer.py` `AI_MAX_MSG_SIZE`, `BATCH_SIZE_LIMIT`), posthog-go `v1` (`posthog.go` `EnqueueAI`, `capture_lane.go` `aiLaneConfig`, `aiMaxEventBytes`), posthog-rs `v1` (`async_client.rs` `capture_ai*`, `transport.rs` `AI_MAX_EVENT_BYTES`, `AI_BATCH_BYTES_TARGET`) and the posthog-node series (`client.ts` `captureAi`, `capture-lane/limits.ts`, `capture-lane/settings.ts`).
- [x] 1.3 Confirm the wrapper rule in posthog-python `posthog/ai/*` (always the AI method, disabled wrapper when the client lacks it) and the posthog-node `@posthog/ai` capability check.

## 2. Spec delta and harness

- [x] 2.1 Draft the `capture-ai` delta: the capture v1 AI lane, wrapper routing, lane configuration, size and batching; modify the full-capture flag requirement.
- [x] 2.2 Add `migration/yaml-parity-v1/capture-ai-v1.feature` under `@requires:capture_ai_v1`, mirroring the v0 cases on `/i/v1/ai/events` with the registered step phrases.
- [x] 2.3 Document `capture_ai_v1` in `migration/yaml-parity-v1/README.md`.

## 3. Validation and archive

- [x] 3.1 Run `openspec validate add-capture-ai-v1 --type change --strict`.
- [x] 3.2 Archive the change on this branch (`openspec archive add-capture-ai-v1 --yes`), then apply the "Narrative alignment" notes to the canonical spec by hand.
- [x] 3.3 Run `openspec validate --specs --strict --no-interactive` and compare the totals with `main` (67 passed, 0 failed on 2026-10-25).
- [ ] 3.4 Close or rebase draft #118, which this change supersedes.

Validation note: the harness feature reuses phrases registered for `capture-ai.feature`, except the property-absence step, which the harness capture v1 suite update binds; no adapter declares `capture_ai_v1` yet, so the cases are discoverable but unselected until an SDK adapter adds the capability.
