## 1. Spec delta

- [x] 1.1 Add the truthiness rule to **Snapshot payload access** in `evaluate-flags`
- [x] 1.2 Add the falsy-payload scenario outline, covering local and remote sources

## 2. Validation

- [x] 2.1 Check the behavior against posthog-js#5817
      (`packages/node/src/extensions/feature-flags/feature-flags.ts`) and its local-evaluation test
- [x] 2.2 Confirm no existing requirement already pinned falsy payloads for local evaluation
- [x] 2.3 Archive the change and sync the delta into `openspec/specs/evaluate-flags/spec.md`
