## 1. Acceptance contract

- [x] 1.1 Replace the shared missing-id identify scenario with a client-scoped scenario and an observable server generated-id delivery scenario; use only `@client` / `@server` scope tags in the changed acceptance feature.
- [x] 1.2 Preserve the existing explicit-id server case IDs, unrelated client scenarios, and alias feature; check the new server case has a stable ID for opt-in selection.

## 2. Verification and archive readiness

- [x] 2.1 Validate the OpenSpec change strictly with `openspec validate server-identify-id-fallback --strict` and verify all unchanged client and explicit-id requirement scenarios remain in the delta.
- [x] 2.2 Check the proposed canonical prose updates against the delta and existing tracing-header contract, so the synced identify spec will not retain contradictory required-id / throw wording.
