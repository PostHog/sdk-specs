## Why

[posthog-js#4506](https://github.com/PostHog/posthog-js/pull/4506) (merged 2026-08-12, superseding
#4439) changed `shutdown()`'s timeout behavior in `@posthog/core` (backs posthog-node): instead of
rejecting the returned promise with a bare string when the shutdown timeout elapses, the SDK now
**resolves** the promise and logs a critical diagnostic (`Timeout while shutting down PostHog. Some
events may not have been sent.`, with `shutdownTimeoutMs` context). The PR's own rationale: an
unhandled promise rejection at shutdown time can crash the host Node process, which is worse than
losing a queued analytics event.

`openspec/specs/shutdown/spec.md`'s "Error handling" section said the opposite: "Promise-based SDKs
may reject on timeout or unrecoverable flush failure." That line is now stale for the canonical
posthog-js/node implementation and would mislead any other SDK using this spec as a reference for
promise-based shutdown behavior.

## What Changes

Prose-only fix to the "Error handling" section of `shutdown/spec.md` — no requirement or scenario
text changes. The existing scenarios ("Shutdown honors delivery failures without crashing") already
describe non-throwing behavior generically enough to cover this; only the more specific "Promise-based
SDKs may reject on timeout" sentence was factually wrong.

- Replace the reject-on-timeout guidance with: promise-based SDKs SHOULD resolve (not reject) when
  the shutdown timeout elapses, logging a critical diagnostic instead, precisely because an unhandled
  rejection can crash the host process. Reject is still permitted for other unrecoverable flush
  failures (unchanged).

Archived directly per this repo's convention for non-requirement prose fixes (see the sibling
`2026-08-12-fix-ruby-flush-shutdown-timeout-signature` change for precedent).

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `shutdown`: "Error handling" prose corrected to match posthog-js/node's shipped timeout behavior.
  No requirement or scenario changes.

## Impact

- `openspec/specs/shutdown/spec.md` — source of truth, corrected directly (prose-only, no delta
  spec needed since no requirement/scenario text changed).
- Source: [posthog-js#4506](https://github.com/PostHog/posthog-js/pull/4506).
- Not investigated: whether other promise-based SDKs (posthog-python's async paths, if any) still
  reject on shutdown timeout. This proposal only corrects the spec to match the one SDK with a
  confirmed, merged change; it does not assert what other SDKs currently do.
