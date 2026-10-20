## Context

The interaction hold withholds a recording epoch's buffered data until a genuine interaction, an
independent trigger, an explicit override, or (for fresh-start holds) a clean unload releases it.
Held data therefore accumulates without an upper bound in time, and the per-emission size cap is
the only thing that bounds it. The requirement never said what happens at that cap, so the
implementation chose the cheapest answer — discard — and that silently contradicted the
requirement's own clean-unload clause.

## Goals / Non-Goals

**Goals:**
- Bound the memory a held epoch can occupy, as before.
- Keep what was already captured, so a released recording starts at the epoch start.
- Keep the clean-unload release conditioned only on the hold being fresh-start and the document
  having been visible, not on whether the buffer happened to overflow.

**Non-Goals:**
- Changing the size cap, or how it is measured.
- Shipping anything for a hold that is never released.
- Porting the interaction hold to SDKs that are exempt from it.

## Decisions

### Stop collecting at the cap, keep what is buffered

**Decision.** At the cap the held epoch stops accepting further replay data and retains what it
has. Memory stays bounded by the cap either way; the discard bought nothing beyond the retained
buffer's own size, which the cap already limits.

**Alternatives considered.**
- *Keep discarding (previous behavior).* Bounds memory identically but loses the epoch start,
  which is the part of the recording a held epoch exists to preserve.
- *Ship early at the cap.* Breaks the hold: an untouched tab would become billable, which the
  requirement forbids.
- *Rotate the buffer and keep the most recent data.* Keeps the interaction-adjacent tail that the
  post-release full snapshot already re-establishes, and drops the start, which nothing else can
  recover.

### A fresh full snapshot bridges the cap-to-release gap

Data captured between the cap and the release is genuinely absent, so the recording would jump.
Taking a full snapshot at release makes playback continuous from that point. This is the same
recovery step the previous implementation already took; it is now additive to the retained data
rather than a replacement for it.

### Overflow does not gate the clean-unload release

The clean-unload release existed to preserve pre-hold behavior for passive visits. An overflowed
hold is the case where a passive visit captured the most, so excluding it inverted the intent.

## Risks / Trade-offs

- [A visible fresh-start epoch that overflowed and saw no interaction now ships one recording
  where it shipped none] → This is the recovery the clean-unload clause already required; it is
  bounded by the size cap and by the fresh-start and document-visible conditions.
- [Retained data can be older than the release] → Playback is made continuous by the full
  snapshot at release, and timestamps are unchanged.

## Migration Plan

`posthog-js` already implements this (PostHog/posthog-js#5063, `posthog-js` patch). No public API
or configuration change. Rollback is restoring the discard.

## Open Questions

None.
