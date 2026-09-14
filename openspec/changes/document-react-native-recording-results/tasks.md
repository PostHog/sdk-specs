## 1. Review the API variant

- [ ] 1.1 Get maintainer agreement to keep void canonical and specify React Native's boolean variant.
- [ ] 1.2 Confirm the proposed scenarios against the final posthog-js#4884 implementation and its regression tests, including cancellation and unavailable state confirmation.

## 2. Apply and archive after approval

- [ ] 2.1 Reconcile the React Native public-signature sections with the approved variant during archival, preserving all other SDK signatures and existing scenarios.
- [ ] 2.2 Apply and archive this change on the same PR, then run `openspec validate --specs --strict` and inspect both resulting specs for contradictory prose.

## 3. Coordinate the release

- [ ] 3.1 Confirm that posthog-js#4884 ships as a React Native minor release and record its exact version.
- [ ] 3.2 Replace the website follow-up's unreleased notice with that minimum version and publish it after the SDK release.
