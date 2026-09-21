## 1. Review the contract

- [ ] 1.1 Review the proposed transport, response, browser-delivery, and server-scope requirements against the implementation evidence in design.md.
- [ ] 1.2 Confirm the proposal is approved before applying and archiving it.

## 2. Acceptance coverage

- [ ] 2.1 Add client-only Gherkin scenarios to acceptance/private/remote-config.feature for bodyless GET, public project token, US/EU asset routing, and custom base-path preservation.
- [ ] 2.2 Add response scenarios using real JSON wire fields, including unknown and omitted optional fields, and preserve existing behavioral scenarios.
- [ ] 2.3 Cover the browser preloaded-config exception without requiring script execution in native SDKs.

## 3. Validate and synchronize

- [ ] 3.1 Run openspec validate document-remote-config-http-contract --strict and inspect the complete diff.
- [ ] 3.2 After approval and acceptance updates, archive on this branch to sync the delta into the canonical remote-config spec.
- [ ] 3.3 Run openspec validate --specs --strict and git diff --check after archival.
