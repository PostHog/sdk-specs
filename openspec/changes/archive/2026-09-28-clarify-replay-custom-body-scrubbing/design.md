## Context

The browser SDK's `buildNetworkRequestOptions` in `packages/browser/src/extensions/replay/external/config.ts` separates `enforcedCleaningFn` (headers, ingestion paths, payload limits) from `scrubPayloads` (body-content heuristics). Since posthog-js #1085, custom callbacks replace only the latter. The spec and compliance report conflated these layers.

## Goals / Non-Goals

**Goals:** Preserve that intentional override contract, keep mandatory protections, and make both paths testable in the specification.

**Non-goals:** New options, different deny lists or size limits, altered host/capture eligibility, mobile replay changes, or new executable harness bindings.

## Decisions

- Select exactly one body-scrubbing strategy after mandatory cleaning: custom callback when supplied, otherwise default scrubber. Never apply the default body scrubber before or after a custom callback.
- Keep callbacks responsible for body privacy. They receive bodies that have not undergone default content heuristics, but must handle absent or size-limited bodies.
- Retain header redaction, ingestion-path filtering, and payload-size limits regardless of callback presence. Requests dropped by mandatory filtering never reach the callback. Existing host exclusions and capture opt-ins are unchanged.
- Correct Behavior items 9–10 and the ordering/error-handling narrative alongside the new normative requirement so no contradictory guidance remains.
- Correct only the browser compliance finding and its roll-up. This is not a fresh audit of the rest of replay or other SDKs.

## Risks / Trade-offs

- Custom callbacks can retain sensitive body contents → explicitly document caller responsibility; defaults remain conservative when no callback is supplied.
- Unconditional pre-hook scrubbing can replace JSON with non-JSON markers and discard harmless content → reject it as a backward-compatible fix. A version bump alone does not isolate users loading the unversioned lazy recorder.
- Size limiting can still replace a body before the callback → document that mandatory preprocessing remains in force, not a guarantee of raw JSON.

## Migration Plan

Sync and archive the spec correction on this branch; update the compliance assessment. No SDK migration is needed for existing browser behavior. Acceptance scenarios are specification coverage only; no SDK conformance execution is claimed.
