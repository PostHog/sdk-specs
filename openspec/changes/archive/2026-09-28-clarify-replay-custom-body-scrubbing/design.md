## Context

The browser SDK's `buildNetworkRequestOptions` in `packages/browser/src/extensions/replay/external/config.ts` separates `enforcedCleaningFn` (headers, ingestion paths, payload limits) from `scrubPayloads` (body-content heuristics). Since posthog-js #1085, custom callbacks replace only the latter. The spec and compliance report conflated these layers.

## Goals / Non-Goals

**Goals:** Preserve that intentional override contract, keep mandatory protections, and make both paths testable in the specification.

**Non-goals:** New options, different deny lists or size limits, altered host/capture eligibility, mobile replay changes, or new executable harness bindings.

## Decisions

- Select exactly one body-scrubbing strategy after mandatory cleaning: custom callback when supplied, otherwise default scrubber. Never apply the default body scrubber before or after a custom callback.
- Keep callbacks responsible for body privacy. They receive bodies that have not undergone default content heuristics, but must handle absent or size-limited bodies.
- Retain header redaction, ingestion-path filtering, and payload-size limits regardless of callback presence. Requests dropped by mandatory filtering never reach the callback. Existing host exclusions and capture opt-ins are unchanged. Header names may remain with redacted values. Cleaning protects callback inputs, is not reapplied to outputs, and cannot prevent callbacks from restoring sensitive data.
- Specify modern callback outcomes separately: nullish ordinary records are dropped with derived server timings; nullish initial entries retain only pre-callback timing metadata with an empty URL. Thrown callbacks fail closed per record, including initial entries, without losing unrelated records or allowing exceptions to escape. This exception isolation is the intended contract and requires a separate posthog-js fix.
- Correct Behavior items 9–10 and the ordering/error-handling narrative alongside the new normative requirement so no contradictory guidance remains.
- Correct only the browser compliance finding and its roll-up. This is not a fresh audit of the rest of replay or other SDKs.

## Risks / Trade-offs

- Custom callbacks can retain sensitive body contents → explicitly document caller responsibility; defaults remain conservative when neither modern nor deprecated callback is supplied.
- The deprecated URL-only hook is adapted into the modern callback and also bypasses default body scrubbing, despite having no access to bodies → document the compatibility behavior and recommend migrating to the modern hook or disabling body capture. Changing that behavior is a separate SDK change. The modern hook takes precedence when both are supplied.
- Unconditional pre-hook scrubbing can replace JSON with non-JSON markers and discard harmless content → reject it as a backward-compatible fix. A version bump alone does not isolate users loading the unversioned lazy recorder.
- Size limiting can still replace a body before the callback → document that mandatory preprocessing remains in force, not a guarantee of raw JSON.

## Migration Plan

Sync and archive the spec correction on this branch; update the compliance assessment. Body-scrubber replacement preserves existing browser behavior. Consistent per-record exception isolation requires a separate posthog-js implementation change; the existing SDK can lose whole batches or let live-observer exceptions escape. Acceptance scenarios here are specification coverage, not a claim that the released SDK already conforms to exception isolation.
