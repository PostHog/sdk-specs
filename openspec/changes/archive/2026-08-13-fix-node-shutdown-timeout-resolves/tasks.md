## 1. Prose alignment (no requirement delta needed)

- [x] 1.1 Update the "Error handling" section of `specs/shutdown/spec.md` to say promise-based SDKs
      SHOULD resolve (not reject) on shutdown timeout, logging a critical diagnostic instead
- [x] 1.2 Confirm no existing scenario asserts reject-on-timeout behavior (none do)

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors

## 3. Downstream follow-up (separate work, not this change)

- [ ] 3.1 Check whether other promise-based SDKs (posthog-python async paths, if any) still reject
      on shutdown timeout, and whether the spec's guidance should be a hard SHALL rather than SHOULD
