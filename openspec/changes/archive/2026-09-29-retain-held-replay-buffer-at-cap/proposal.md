## Why

`Interaction hold for unconfirmed-activity recording epochs` says a held epoch's buffered data
is withheld until a release, and that a clean unload releases and ships a held **fresh-start**
epoch. It says nothing about what happens when a held epoch's buffer reaches the emission size
cap before any release arrives, and that gap let the implementation drop data the requirement
promises to ship.

`posthog-js` used to bound memory at the cap by discarding the held epoch's buffered data
outright. Two consequences followed, both reported by a customer as recordings missing the first
~10-15 minutes:

- A page that mutated heavily before its first interaction (video, animation, polling) lost the
  entire held start of its recording. On release only a fresh full snapshot resumed capture, so
  the recording began at the interaction rather than at the epoch start.
- A clean unload skipped the fresh-start release entirely, because an overflowed hold "had
  nothing playable left to ship" — true only as a consequence of the discard. The spec's
  clean-unload clause was therefore unmet for exactly the epochs that had captured the most.

PostHog/posthog-js#5063 changed this: a held buffer at the cap stops collecting but keeps its
data, the retained data ships on release with a fresh full snapshot bridging the gap between cap
and release, and an overflowed fresh-start hold ships on clean unload like any other.

## What Changes

- State that reaching the size cap while held stops further collection but does not discard
  already-buffered data.
- Require the retained data to be emitted on release, with a fresh full snapshot bridging the
  gap between the cap and the release point.
- State that reaching the cap does not by itself disqualify a fresh-start hold from the
  clean-unload release.
- Keep the emission invariant explicit: a held epoch at the cap that is never released still
  emits nothing, so an untouched tab remains non-billable.
- Add two scenarios covering the release and the clean unload at the cap.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `session-replay-ingestion-controls`: `Interaction hold for unconfirmed-activity recording
  epochs` retains a held epoch's buffered data at the size cap.

## Impact

- `posthog-js`: already implements this as of PostHog/posthog-js#5063.
- The requirement is scoped to SDKs whose sessions start or rotate without a confirmed-interaction
  signal (currently posthog-js / web); no other SDK is affected.
- Emission volume is unchanged except in one recovered case the requirement already covers: a
  visible fresh-start epoch that overflowed its cap and never saw interaction now ships its
  buffered data on clean unload, instead of nothing. Holds that are never released still ship
  nothing, and rotation-born holds still die on unload.
