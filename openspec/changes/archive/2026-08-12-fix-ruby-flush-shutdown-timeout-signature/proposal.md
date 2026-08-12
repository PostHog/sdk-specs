## Why

[posthog-ruby#230](https://github.com/PostHog/posthog-ruby/pull/230) ("Add optional timeout to
flush and shutdown") added an optional `timeout:` keyword argument to both `flush` and
`shutdown`, and changed their return type from `void` to `Boolean` (`true` on a completed drain,
`false` if the timeout elapsed first; sync-mode clients always return `true` and ignore the
timeout; omitting `timeout` preserves the prior blocking-until-complete behavior).

`openspec/specs/flush/spec.md` documents Ruby's surface variant as `flush(): void`, and
`openspec/specs/shutdown/spec.md` does not list a Ruby surface variant at all — both are now
stale/incomplete documentation of a shipped public API signature. This is confirmed spec drift
(a documented method signature no longer matches the shipped SDK), not an ambiguous behavior
change: the PR's tests and changeset converge on one clear, already-merged signature.

This is a narrow documentation fix. Ruby's own optional-timeout pattern already matches the
shape `shutdown`'s canonical signature anticipated (`shutdown(timeoutMs?: number)`); `flush`'s
canonical signature did not previously include a timeout parameter at all.

## What Changes

- **Prose alignment only** (no requirement/scenario changes): update the "Surface variants"
  section of `specs/flush/spec.md` to reflect Ruby's new `flush(timeout: nil): Boolean`
  signature, and add a Ruby entry to `specs/shutdown/spec.md`'s "Surface variants" section for
  `shutdown(timeout: nil): Boolean`.
- No behavioral requirement is added: the existing `flush` and `shutdown` requirements already
  describe "best-effort delivery within a bound" generically enough to cover an optional
  caller-supplied timeout; only the per-SDK signature documentation was stale.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `flush`: no requirement/scenario changes — only the Ruby row in "Surface variants" is
  corrected.
- `shutdown`: no requirement/scenario changes — only a missing Ruby row in "Surface variants" is
  added.

## Impact

- `openspec/specs/flush/spec.md` and `openspec/specs/shutdown/spec.md` — corrected directly
  (no ADDED/MODIFIED Requirement delta needed since only descriptive "Public signatures" prose
  changed, following this repo's precedent of applying non-requirement prose fixes directly at
  archive time).
- Implementation: posthog-ruby already ships this as of PR #230, merged 2026-08-05.
- Low risk: this is a factual correction to documented method signatures, not a new behavioral
  contract.
