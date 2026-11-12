## 0. Decision

- [ ] 0.1 Choose option A, B or C in design.md, then align the delta (C is drafted)

## 1. Spec delta

- [ ] 1.1 Add **Capture serializes set-like and sequence property values as arrays** to `capture` with four scenarios

## 2. Validation

- [ ] 2.1 Run `openspec validate --specs --strict`
- [ ] 2.2 Run `openspec archive` to sync the delta and archive the change

## 3. Downstream follow-ups (separate changes, not this one)

- [ ] 3.1 posthog-js: serialize `Set` as an array in core `safeJsonStringify`, and in the browser both `deepCircularCopy` (used by `_copyAndTruncateStrings`) and `jsonStringify`
- [ ] 3.2 posthog-ruby: serialize `Set` as an array before `JSON.generate`
- [ ] 3.3 posthog-python: add a `set` test to `clean()` (`frozenset` and `deque` landed in PostHog/posthog-python#1230)
- [ ] 3.4 Check posthog-php, posthog-elixir, posthog-dotnet and the mobile SDKs
- [ ] 3.5 posthog-sdk-test-harness: step bindings for the new scenarios, then add them to `acceptance/public/capture.feature`
