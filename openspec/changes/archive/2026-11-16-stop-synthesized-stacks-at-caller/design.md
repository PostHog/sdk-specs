## Context

Two existing requirements sit next to this one and neither covers it:

- `capture-exception` → "Stack trace preservation over synthesis": use an existing stack rather
  than synthesizing one. Silent on the synthesized case itself.
- `exception-event-metadata` → "Explicit synthetic state": an SDK-generated current stack that
  replaces a missing or unusable original is `mechanism.synthetic: true`. Silent on its contents.

A synthesized stack is produced by walking the current call stack inside the SDK. Unless the SDK
removes its own frames, the leading frames are the SDK's capture path, and the server reads the
issue location — and both fingerprint versions hash these frames — from SDK source instead of
application source.

## Evidence

| SDK | Synthesizes a current stack? | Behavior | Source |
|---|---|---|---|
| posthog-ios | yes, for a never-raised error or `NSException` | conforms on `main` since 2026-11-15. Each public `captureException` overload reads `Thread.callStackReturnAddresses` in its own body and drops its own frame; the convenience overloads no longer call each other | PostHog/posthog-ios#1079, fixing #1077. 4.0 port merged as #1080 |
| posthog-js (browser, `@posthog/node`, react-native) | yes, for non-`Error` input | known gap. The synthetic `Error` is constructed inside the SDK's own capture method and the parser skips only its message line (`skipFirstLines` defaults to 1), so that method's frame stays on top; react-native builds it in `captureExceptionInternal`, adding a second SDK frame | `packages/node/src/client.ts:3450`, `packages/browser/src/posthog-core.ts:4587`, `packages/react-native/src/posthog-rn.ts:2578`, `packages/core/src/error-tracking/error-properties-builder.ts:165` (read 2026-11-18, not run) |
| posthog-python | no | stacks come from `__traceback__` / `sys.exc_info()`, which start at the raise site. `should_hide_frame` filters inherited `sentry_sdk.` frames only | `posthog/exception_utils.py` (read 2026-11-16) |
| every other SDK | unknown | not audited for this change | — |

## Decision

State the requirement at the level the behavior is observable on the wire — the leading frames of
a synthesized stack — rather than prescribing a mechanism (symbol matching, fixed frame counts,
binary-name matching). posthog-ios#1079 rejected both symbol-prefix matching (stripped release
builds make `dladdr` return unrelated symbols) and skipping a fixed number of frames (inlining
changes the depth), which is why the requirement does not name one.

The known client-side gap on iOS — an Objective-C caller in a stripped, statically linked build
still has the `@objc` thunk on top, which the server demotes to not-in-app — is why the
requirement allows an unidentifiable bridge thunk to remain.

## Open question for review

Whether this should also constrain `in_app` for any SDK frame that does remain. No spec mentions
`in_app` today, so this change does not introduce it.
