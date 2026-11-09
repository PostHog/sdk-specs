## 1. Spec delta

- [x] 1.1 Remove wireframe replay and the `screenshotMode` / `screenshot` options from `session-replay-privacy`, including the wireframe secure-window scenario
- [x] 1.2 Make `$sdk_debug_replay_capture_mode` always `screenshot` in `session-replay-debug-properties`
- [x] 1.3 Drop "wireframes" from the `start-session-recording` narrative

## 2. Validation

- [x] 2.1 Run `openspec validate --strict`
- [x] 2.2 Sync the delta into `specs/` and archive the change
