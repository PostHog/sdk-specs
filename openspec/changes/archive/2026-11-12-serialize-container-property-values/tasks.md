## 0. Decision

- [x] 0.1 Choose option A, B or C in design.md (C chosen)

## 1. Spec delta

- [x] 1.1 Add **Capture serializes set-like and listed sequence property values as arrays** to `capture` with the per-runtime table and four scenarios

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict`
- [x] 2.2 Run `openspec archive` to sync the delta and archive the change

## 3. Downstream follow-ups (separate changes, not this one)

- [ ] 3.1 posthog-js: serialize `Set` as an array in core `safeJsonStringify`, and in the browser both `deepCircularCopy` (used by `_copyAndTruncateStrings`) and `jsonStringify`
- [ ] 3.2 posthog-ruby: convert `Set` to an array recursively before `JSON.generate`
- [ ] 3.3 posthog-python: add a `set` test to `clean()`
- [ ] 3.4 posthog-ios: convert `Set` and `NSSet` to an array in `sanitizeInvalidValue`
- [ ] 3.5 posthog-unity: add an `IEnumerable` case after `IList` in `JsonSerializer`
- [ ] 3.6 posthog-elixir: convert `MapSet` to a list recursively before `RedactorEncoder.encode`
- [ ] 3.7 posthog-flutter: handle `Set` in the desktop `toJsonValue`, and `Queue` in both `toJsonValue` and `PropertyNormalizer`
- [ ] 3.8 posthog-kmp: convert `Set` to a list in the apple, js and wasmJs property converters
- [ ] 3.9 posthog-godot: accept the listed Packed arrays in `is_json` and convert them to `Array`
- [ ] 3.10 posthog-php: convert `SplDoublyLinkedList` (including `SplQueue`, excluding `SplStack`) and `SplFixedArray` to arrays recursively before `JsonEncoder::encode`
- [ ] 3.11 Check posthog-pi, posthog-openclaw and posthog-opencode
- [ ] 3.12 posthog-sdk-test-harness: step bindings for the new scenarios, then add them to `acceptance/public/capture.feature`
