## 1. Spec delta

- [x] 1.1 Add "Attach only the disabled shape while replay is intentionally off" to `session-replay-debug-properties`, with the local-off and remote-off definitions, the off-state shape, the per-event evaluation, and the consumer rule
- [x] 1.2 Modify the required-keys requirement to withhold the required keys while replay is intentionally off
- [x] 1.3 Modify "Attach the disabled shape when replay is not configured" to a single-key mobile fallback
- [x] 1.4 Modify "Stop and uninstall reset the reported state and clear any stale hold reason" so no `$sdk_debug_replay_*` key remains
- [x] 1.5 Modify the keys requirement (capture mode and session start) and the two crash-context requirements
- [x] 1.6 Confirm each requirement cites posthog-js at `16e3f63b9` with `file:line` and a covering test, and that unmet behavior says so

## 2. Validation

- [x] 2.1 Run `openspec validate drop-replay-debug-keys-when-replay-off --strict`
- [x] 2.2 Sync the delta into `specs/session-replay-debug-properties/spec.md` and edit the Purpose sentence about the crash-context snapshot
- [x] 2.3 Run `openspec validate --specs --strict`
- [x] 2.4 Archive the change under `openspec/changes/archive/YYYY-MM-DD-drop-replay-debug-keys-when-replay-off/`

## 3. Compliance notes

- [x] 3.1 `compliance/posthog-js.md` n36: extend the gap from the stop case to the remote-off case and the persisted-key reload case, and point the remediation at the gate
- [x] 3.2 `compliance/posthog-react-native.md` n24: add the gaps for remote-off, `capture_mode`, and `session_start`
- [x] 3.3 `compliance/posthog-flutter.md` n28: note that the Windows and Linux `$sdk_debug_session_start` gap also violates the off-state shape
- [x] 3.4 `compliance/posthog-ios.md` n26 and `compliance/posthog-android.md` n17: add the off-state gap (capture mode in the fallback, required keys after stop and remote-off)
