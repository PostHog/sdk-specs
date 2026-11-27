## 1. Spec delta

- [x] 1.1 Add **Capture serializes date and time property values as ISO 8601 strings in UTC** to `capture` with three scenarios

## 2. Validation

- [x] 2.1 Review the delta against the per-SDK survey in design.md
- [x] 2.2 Sync the delta into `openspec/specs/capture/spec.md` and archive the change

## 3. Downstream follow-ups (separate changes, not this one)

- [ ] 3.1 posthog-python: normalize to UTC in `DatetimeSerializer.default` instead of bare `isoformat()`
- [ ] 3.2 posthog-go: convert `time.Time` property values to UTC before encoding
- [ ] 3.3 posthog-dotnet: register a UTC-normalizing `DateTime`/`DateTimeOffset` converter in `JsonSerializerHelper.Options`
- [ ] 3.4 posthog-ruby: apply `datetime_in_iso8601` recursively, not only to top-level values
- [ ] 3.5 Survey posthog-php, posthog-elixir, posthog-rs, posthog-unity, posthog-kmp, posthog-godot, posthog-java and posthog-unreal
- [ ] 3.6 posthog-sdk-test-harness: step bindings for the new scenarios, then add them to `acceptance/public/capture.feature`
