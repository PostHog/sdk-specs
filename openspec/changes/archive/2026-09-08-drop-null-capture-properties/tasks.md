## 1. Revised contract

- [x] 1.1 Replace the preservation requirements with null object-property omission and explicit array-position preservation.
- [x] 1.2 Revise capture, AI, and exception Gherkin scenarios and mark the previous decision superseded.

## 2. Validation

- [x] 2.1 Validate the delta strictly and check Gherkin scenario coverage and JSON input/output examples.
- [x] 2.2 Review scope and compatibility before syncing and archiving on the existing PR branch.

Strict delta validation passed. All seven new/revised scenarios match their Gherkin counterparts; JSON input/output fixtures were checked against a reference object-key cleanup that preserves array positions. These are specification checks, not SDK conformance tests. The owner approved the replacement policy and requested the existing PR be updated.
