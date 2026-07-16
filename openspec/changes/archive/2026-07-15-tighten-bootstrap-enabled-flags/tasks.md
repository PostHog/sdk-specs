# Tasks

## 1. Tighten the spec
- [x] 1.1 Modify the flag-serving requirement to specify enabled-only serving (posthog-js `!!value`) and payloads-for-enabled.
- [x] 1.2 Add a scenario for a disabled bootstrap flag and its payload not being served.

## 2. Acceptance
- [x] 2.1 Add the disabled-flag scenario to `acceptance/public/bootstrap.feature`.

## 3. Validate and archive
- [x] 3.1 `openspec validate tighten-bootstrap-enabled-flags --strict` passes.
- [ ] 3.2 Cross-SDK review sign-off (folded into the bootstrap spec review).
