> Superseded on this PR by `drop-null-capture-properties`: omit null-valued object properties, but preserve null array elements. This archive records the earlier decision only.

## Why

JSON `null` is valid event data, and an explicitly present null-valued property is not the same as an absent key. Python PR [#926](https://github.com/PostHog/posthog-python/pull/926) proposes dropping those properties, exposing a gap in the capture contract despite existing SDKs preserving them.

## What Changes

- Require capture methods to accept explicit null-valued custom properties and preserve them as JSON `null`, including nested objects and array positions, for queued and immediate delivery.
- Distinguish null values from absent properties and JavaScript object properties containing `undefined`.
- Apply the same contract to caller-supplied properties on exception and AI capture.
- Keep caller-configured filtering, reserved-field validation, and OTLP logs/traces rules unchanged.
- Add wire-level acceptance scenarios. **BREAKING** for implementations that currently strip explicit nulls: conformance changes their emitted payloads; SDK rollout needs compatibility review.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture`: Define explicit null acceptance and preservation through serialization.
- `capture-ai`: Inherit the capture null-property contract on the AI route.
- `capture-exception`: Inherit the capture null-property contract for additional event properties.

## Impact

Specs and acceptance scenarios only; no SDK implementation changes. Python, Node/React Native, Go, Ruby, and iOS explicit `NSNull()` provide preservation precedent. Android currently filters nulls; non-nullable property APIs may require a platform-idiomatic null representation. This change does not claim every SDK already conforms.
