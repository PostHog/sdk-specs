# Tasks

## 1. Tighten the spec
- [x] 1.1 Add a requirement that applying bootstrap feature flags fires the flags-loaded callback at setup, before the first `/flags` response.

## 2. Acceptance
- [x] 2.1 Add the setup-time callback-firing scenario to `acceptance/public/bootstrap.feature`.

## 3. Validate and archive
- [x] 3.1 `openspec validate bootstrap-flags-loaded-callback --strict` passes.
- [ ] 3.2 Cross-SDK review sign-off (folded into the bootstrap spec review).
