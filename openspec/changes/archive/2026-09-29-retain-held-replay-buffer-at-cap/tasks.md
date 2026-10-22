## 1. Establish the Contract

- [x] 1.1 Read how `posthog-js` bounded a held epoch's buffer at the emission size cap before and after PostHog/posthog-js#5063.
- [x] 1.2 Confirm the previous discard also skipped the clean-unload release the requirement already mandates for fresh-start holds.
- [x] 1.3 Confirm the emission invariant is preserved: a held epoch at the cap that is never released still ships nothing.
- [x] 1.4 Confirm no other SDK implements the interaction hold, so no port is affected.

## 2. Write the Delta

- [x] 2.1 Extend `Interaction hold for unconfirmed-activity recording epochs` with the size-cap behavior: stop collecting, retain buffered data, bridge with a fresh full snapshot on release.
- [x] 2.2 State that reaching the cap does not disqualify a fresh-start hold from the clean-unload release.
- [x] 2.3 Add the release-at-cap and clean-unload-at-cap scenarios; the existing scenarios still hold as written.

## 3. Validate and Review

- [x] 3.1 Run `git diff --check`.
- [x] 3.2 Decide whether acceptance scenarios belong in `acceptance/`. Spec scenarios suffice: `acceptance/` carries no interaction-hold feature file.
- [x] 3.3 Archive into the canonical `session-replay-ingestion-controls` spec.
