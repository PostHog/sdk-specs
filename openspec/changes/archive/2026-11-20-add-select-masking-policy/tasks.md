## 1. Spec delta

- [x] 1.1 Add **Explicit per-select masking policy** to `session-replay-privacy`, with the
      decision values, the masked/unmasked shapes, fail-closed handling, the capture points, and
      the recorder-support gate
- [x] 1.2 Cite posthog-js at `7bf3339b7` with `file:line` for each rule

## 2. Validation

- [x] 2.1 Add `selectMaskingFn` to the browser option block in "Public signature(s)"
- [x] 2.2 Sync the delta into `specs/session-replay-privacy/spec.md` and archive the change under
      `openspec/changes/archive/2026-11-20-add-select-masking-policy/`
