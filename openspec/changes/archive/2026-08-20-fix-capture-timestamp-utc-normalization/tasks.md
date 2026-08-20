## 1. Prose alignment (no requirement delta needed)

- [x] 1.1 Update the "Attach envelope fields" bullet of `specs/capture/spec.md` to state that
      `timestamp` is normalized to its equivalent UTC instant before serialization, and that
      fractional-second precision on the input is preserved rather than truncated
- [x] 1.2 Confirm no existing scenario asserts a specific timezone/offset behavior (none do)

## 2. Validation

- [ ] 2.1 Run `openspec validate --specs --strict` and resolve any errors (CLI unavailable in the
      authoring sandbox; CI on the PR should run this)

## 3. Downstream follow-up (separate work, not this change)

- [ ] 3.1 Check whether posthog-java (posthog-server, in the posthog-android monorepo) needs the
      same UTC-normalization fix — no java-specific PR was found in this run's lookback window
