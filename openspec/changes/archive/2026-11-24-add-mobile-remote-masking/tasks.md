## 1. Spec delta

- [x] 1.1 Add "Mobile SDKs read dedicated mobile masking keys" with the key names, the flag mapping and the ignored web keys
- [x] 1.2 Add "The stricter side wins, per flag" with the resolution rule and the non-boolean cases
- [x] 1.3 Add "Resolved masking follows the cached and live remote config" with the buffered-frame rule
- [x] 1.4 Add "Log once when the server turns on a mask the local value had off"
- [x] 1.5 Add "Wrapper SDKs get the resolved flags from native"
- [x] 1.6 Add "Always-mask rules are unchanged by remote masking"
- [x] 1.7 Add "Browser masking precedence is unchanged" as the baseline
- [x] 1.8 Confirm each requirement cites posthog-js `origin/main` `f05a993f9` with `file:line` and a covering test, or says it is new mobile behavior with no reference implementation

## 2. Validation

- [x] 2.1 Run `openspec validate add-mobile-remote-masking --strict`
- [x] 2.2 At archive, sync the delta into `specs/session-replay-privacy/spec.md` and hand edit three places the delta cannot reach: Behavior item 5 (mobile applies the resolved `masking.mobile` flags, with a pointer to the new requirements), the "Remote-config update" lifecycle line (mobile applies `masking.mobile` on each remote config update), and the "State read" bullet about remote replay config
- [x] 2.3 Run `openspec validate --specs --strict`
- [x] 2.4 Archive the change under `openspec/changes/archive/YYYY-MM-DD-add-mobile-remote-masking/`
