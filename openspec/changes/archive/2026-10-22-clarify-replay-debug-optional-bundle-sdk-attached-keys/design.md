## Context

posthog-js `calculateEventProperties` copies the caller's properties and then writes replay debug
keys into that copy only when the event is eligible and the window is open, or the key is required
(`packages/browser/src/posthog-core.ts:2172`, `:2218-2222` at `0fd32143b`). It never deletes a
debug-named key that the caller, `register`, or `before_send` placed on the event. posthog-android
`sdkDebugProperties` (`PostHog.kt:816-832` at `2e364df96`) builds the same way. The spec's
"SHALL NOT carry" wording can be read as requiring a strip step neither SDK has.

## Goals / Non-Goals

**Goals:** make the sentence unambiguous, keep it aligned with posthog-js, and give the mobile SDKs
one scenario that fails if they strip caller keys.

**Non-goals:** changing which events are eligible, the 30-second window, the acceptance rules for
starting the window, or the precedence of SDK-written values.

## Decisions

- State the rule as "the SDK SHALL NOT attach", scoped to the SDK's own writes, and say explicitly
  that it does not require removal of keys from other routes. The permissive form matches what the
  reference does without adding a new SHALL about registered keys.
- Keep the existing precedence sentence as the only statement about collisions when the SDK does
  write a key; the new text cross-references it rather than restating it.
- Note that posthog-js's `hidden` persistence exposure for its own session-persisted replay state is
  a storage rule, already cited in the key catalogue, so a reader does not mistake it for the gate.
- The new scenario uses `$sdk_debug_session_start` because it is in the optional bundle on every
  platform.

## Risks / Trade-offs

- A caller can put a stale or wrong value under a debug key on a custom event → accepted; the key is
  the caller's and the existing precedence rule still overwrites it whenever the SDK writes it.
- No SDK has a test for the new scenario yet → recorded as planned on every SDK, not as conformance.

## Migration Plan

Spec-only. Archive on this branch; no SDK work follows.
