# Tasks

## 1. Confirm the reference implementation

- [ ] 1.1 Inspect the merged `posthog-js` network-request metrics change and record its metric name, unit, configuration, bounded attributes, exclusion rules, release version, and tests in the support record; verify a test request produces the expected Metrics series.
- [ ] 1.2 Check the reference implementation for opt-out, disabled-state, shutdown, observer-error, and PostHog-ingestion exclusion behaviour; verify each result against the scenarios in `network-request-metrics`.

## 2. Extend the Metrics specification

- [ ] 2.1 Archive this OpenSpec change so its Network Request Timing requirement is synced into `openspec/specs/metrics/spec.md`; verify `openspec validate --specs --strict` passes.
- [ ] 2.2 Keep the requirement scenarios in the Metrics spec as the contract test cases, matching the Metrics product-pipeline precedent; verify each scenario is testable against an SDK implementation.
- [ ] 2.3 Update the Metrics capability description only if its scope needs to name automatic network-request timing; verify the root capability list remains a single Metrics entry.

## 3. Publish the support map

- [ ] 3.1 Add `compliance/network-request-metrics.md` with the four-state support map and evidence fields; verify it marks browser `posthog-js` as shipped and verified and does not treat Session Replay network recording as Metrics evidence.
- [ ] 3.2 Add initial candidate entries for iOS, Android, React Native, Flutter, Unity, Node, Python, Go, Java, .NET, PHP, and Ruby; verify each names a host HTTP API to assess or an explicit out-of-scope reason, without changing a compliance total.
- [ ] 3.3 Link the support map from `compliance/README.md`, explain that candidate states are outside the normal conformance score, and add a `network-request-metrics` compliance row only after a SDK is fully audited; verify existing roll-up counts do not change for candidates.

## 4. Plan safe SDK rollouts

- [ ] 4.1 For each candidate that has a safe host API, create a separate SDK-port OpenSpec change with implementation evidence and focused tests; verify it can satisfy the canonical contract before changing its compliance status.
- [ ] 4.2 Enable each new adapter only through its documented Metrics/network-timing configuration and monitor series volume, capture failures, and client errors after release; verify the adapter can be disabled without an application behaviour change.
