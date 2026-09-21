## 1. Review the contract

- [x] 1.1 Review the proposed transport, response, browser-delivery, and capability-based scope requirements against the implementation evidence in design.md.
- [x] 1.2 Confirm the proposal is approved before applying and archiving it.

## 2. Acceptance coverage

- [x] 2.1 Add Gherkin scenarios for client and server SDKs that implement project remote configuration to acceptance/private/remote-config.feature for bodyless GET, public project token, US/EU asset routing, and custom base-path preservation.
- [x] 2.2 Add response scenarios using real JSON wire fields, including unknown and omitted optional fields, and preserve existing behavioral scenarios.
- [x] 2.3 Cover the browser preloaded-config exception without requiring script execution in native SDKs.

## 3. Validate and synchronize

- [x] 3.1 Run openspec validate document-remote-config-http-contract --strict and inspect the complete diff.
- [x] 3.2 After approval and acceptance updates, archive on this branch to sync the delta into the canonical remote-config spec.
- [x] 3.3 Run openspec validate --specs --strict and git diff --check after archival.
