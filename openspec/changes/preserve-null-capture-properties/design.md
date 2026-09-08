## Context

The capture spec does not define null-property serialization. Python's `clean()` explicitly preserves `None`; `json.dumps(..., cls=DatetimeSerializer)` emits JSON `null`, recursively. Node/React Native, Go, Ruby, and iOS explicit `NSNull()` also preserve it. Android's `GsonSafeMapSerializer` instead skips null map values and list elements. This contract selects preservation, not the lowest common denominator.

Evidence from the inspected SDK revisions:
- [Python PR #926](https://github.com/PostHog/posthog-python/pull/926) proposes changing existing top-level preservation.
- [Node/core payload construction](https://github.com/PostHog/posthog-js/blob/f902b705ed07efb4c78695646da6d6708ae082b9/packages/core/src/posthog-core-stateless.ts#L477-L501) retains caller values before JSON serialization.
- [iOS sanitizer](https://github.com/PostHog/posthog-ios/blob/611db7567af31263da4b80317bfe7d2340b8df40/PostHog/Utils/DictUtils.swift#L44-L89) accepts JSON-compatible values, including `NSNull()`.
- [Android serializer](https://github.com/PostHog/posthog-android/blob/0d7f567006bf24b6913d7fd00e025597dcbd605e/posthog/src/main/java/com/posthog/internal/GsonSafeMapSerializer.kt) drops nulls recursively.

## Goals / Non-Goals

**Goals:** Preserve caller-supplied JSON nulls on the wire for ordinary, immediate, AI, and exception capture. Make absent keys and null array positions unambiguous in acceptance scenarios.

**Non-Goals:** SDK implementation changes, backend query/person-update semantics, accepting null for required or typed reserved fields, changing privacy hooks, or changing OTLP attribute encoding.

## Decisions

- Define one shared requirement in `capture`; reference it from AI and exception capture rather than duplicating policy. Explicit null is valid JSON data, not a serialization error or implicit deletion instruction.
- Preserve nulls recursively. Top-level-only preservation leaves nested custom payloads lossy; removing null array elements also changes positional meaning.
- Allow platform-idiomatic null representations (such as Swift `NSNull()`). A nullable properties argument is not the same as nullable entries; languages with non-nullable entry types need a way to represent explicit JSON null to conform.
- Keep absence distinct: an omitted key stays absent. JavaScript object `undefined` is not JSON null and can continue to be omitted by normal JSON serialization. This does not redefine JavaScript array serialization.
- Existing property precedence, reserved-field validation, consent, and explicitly configured filters still apply. Null preservation must not bypass privacy controls or populate missing exception metadata.
- Assert decoded wire JSON, not only queued dictionaries, for both queued and immediate delivery where supported. Spec-only Gherkin scenarios describe the contract; SDK adapters implement them separately.

## Risks / Trade-offs

- Existing null-dropping SDKs change emitted data when converging → require per-SDK compatibility review and release notes; do not bundle SDK changes here.
- Slightly larger payloads than stripping nulls → preserve caller intent; applications can deliberately filter unwanted values.
- Confusion with OTLP null omission → explicitly exclude logs and traces from this analytics contract.

## Migration Plan

Add delta requirements and matching acceptance scenarios, validate the change, then use OpenSpec archive to sync canonical specs. No SDK release or conformance claim is made by this spec change.
