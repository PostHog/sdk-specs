## 1. Spec delta

- [x] 1.1 Modify **Client-level GeoIP control with per-call override** in `capture` so its client sentence defers to the new requirement
- [x] 1.2 Add **Client SDK GeoIP opt-out** to `capture` with five scenarios

## 2. Validation

- [x] 2.1 Check the delta against the shipped source of posthog-ios, posthog-android, posthog-flutter and posthog-js
- [x] 2.2 Sync the delta into `openspec/specs/capture/spec.md` and archive the change

## 3. Downstream follow-ups (separate changes, not this one)

- [ ] 3.1 posthog-sdk-test-harness: step bindings for the `@client` GeoIP scenarios, then add them to `acceptance/public/capture.feature`
- [ ] 3.2 posthog-flutter: decide whether the stamp can move before the Dart `beforeSend`, or keep the divergence recorded
- [ ] 3.3 posthog-unity, posthog-kmp, posthog-godot: decide whether to add the option
