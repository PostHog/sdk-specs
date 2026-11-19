## Why

`capture-exception` says what happens when the captured input already carries a stack
("Stack trace preservation over synthesis"), and `exception-event-metadata` says that a
SDK-generated replacement stack is marked `mechanism.synthetic`. Neither says where that
synthesized stack has to start.

posthog-ios shipped error tracking in 3.45.0 with a synthesized stack whose top 4–7 frames were
the SDK's own capture path, whenever the SDK was statically linked into the app (the Swift Package
Manager default). The reported issue location was PostHog's own source file rather than the
application call site. PostHog/posthog-ios#1079 (merged 2026-11-15, fixing
PostHog/posthog-ios#1077) changed each public `captureException` overload to read the caller's
stack in its own body and drop its own frame, so the trace starts at the call site in every build
mode.

posthog-js does not conform yet: browser, `@posthog/node` and react-native build their
`syntheticException` with `new Error(...)` inside the SDK's own capture method and skip only the
message line, so that method's frame stays at the top of the stack. The spec records this as a
known gap.

The behavior is contractual — it decides the frames that reach `$exception_list[].stacktrace`, and
therefore the server-side issue location and the fingerprint — but no spec states it.

## What Changes

- **Capture Exception**: a new requirement, "Synthesized stacks stop at the application call
  site". When the SDK synthesizes a current stack for an exception (the `mechanism.synthetic`
  `true` case), that stack SHALL end at the application frame that called the public capture API.
  In the canonical bottom-up frame order the last frame is the call site, and the SDK's own
  capture-path frames do not follow it. Where a language-bridge thunk between the caller and the
  SDK cannot be identified on the client, the SDK MAY leave it in place.
- Two scenarios.
- Scope: synthesized stacks only. Stacks that come from a runtime exception or traceback (the
  common server-SDK case) are unchanged, as is frame order, which "Frame order" already fixes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture-exception`: define where a synthesized current stack starts.

## Impact

Specifications only. No SDK changes in this PR.

Conformance was **not** audited across every SDK for this change. Verified: posthog-ios conforms
on `main` after PostHog/posthog-ios#1079 (its 4.0 port, PostHog/posthog-ios#1080, is merged);
posthog-js keeps its own capture-method frame (known gap); posthog-python
builds stacks from the exception traceback and so does not synthesize one here. Every other SDK is
unchecked — see design.md.
