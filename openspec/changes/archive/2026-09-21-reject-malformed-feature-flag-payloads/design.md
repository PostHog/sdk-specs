## Context

The existing payload error-handling prose allows “missing/unparsed” payloads. Result and bulk specs require resilience but do not forbid returning malformed serialized strings. Python PR #947's review selects `None`, noting that the API already rejects malformed payloads and that raw strings are ambiguous.

## Goals / Non-Goals

**Goals:** Define one observable decoding contract for cached, local, and remote payloads; preserve valid flag results; cover empty serialized input separately from a valid JSON empty string.

**Non-goals:** SDK code changes, new fallback requests, changes to event tracking, or replacing existing missing-payload map conventions.

## Decisions

- Add normative requirements to the three existing public API specs through OpenSpec deltas. The payload requirement explicitly supersedes the ambiguous legacy wording without manually editing canonical spec files.
- Reject raw-string fallback for malformed serialized payloads. Use the existing no-payload sentinel instead, as requested in the linked review.
- Preserve the existing missing-payload shape in bulk maps and optional structured-result fields: omitted or null-like. Forcing a new map shape would broaden this change unnecessarily.
- Decode only serialized representations, never already-decoded strings. A valid JSON string payload must remain a string, including the valid empty string; truthiness checks cannot substitute for parse success.
- Treat decode failure independently from evaluation success. Do not erase flag values or healthy sibling payloads.
- During apply, add corresponding acceptance scenarios with explicit serialized-input fixtures so the harness does not reject or pre-decode malformed data before it reaches the SDK path being tested.

## Risks / Trade-offs

- [SDKs currently return raw strings] → Document this as a compatibility change and track SDK implementation separately.
- [Empty input confused with JSON `""`] → Include distinct acceptance examples and valid falsey-value controls.
- [Single and bulk implementations diverge] → Exercise both APIs against the same inputs, including server local and remote evaluation.

## Migration Plan

After approval, add acceptance coverage, validate the change, and archive on this branch to synchronize canonical requirements. No SDK release is part of this change. Any rollback should use a new spec change rather than rewriting history.

## Open Questions

None; existing SDK-specific absent-value representations remain supported, but malformed raw strings are explicitly forbidden.
