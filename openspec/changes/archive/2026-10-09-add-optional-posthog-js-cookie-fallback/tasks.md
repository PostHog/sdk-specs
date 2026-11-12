## 1. Contract update

- [x] 1.1 Confirm the cookie format and consent handling in posthog-js (`storage.ts`, `sessionid.ts`, `consent.ts`, `@posthog/core` `cookie.ts`).
- [x] 1.2 Draft the cookie fallback requirement and its scenarios.
- [x] 1.3 Sync the requirement and the narrative notes into the canonical `tracing-headers` spec.

## 2. Validation and archive

- [x] 2.1 Validate the change and canonical specs strictly; check the diff.
- [x] 2.2 Archive the completed change on this branch.

Validation: `openspec validate tracing-headers --type spec --strict` passes. `openspec validate --specs --strict` (CLI 1.14.1) reports the same failures in other specs with and without this change. These are specification checks, not executed SDK conformance tests.
