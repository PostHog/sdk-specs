## 1. Contract and acceptance

- [x] 1.1 Define recursive null/undefined object-member omission during event serialization while preserving array positions and existing public APIs.
- [x] 1.2 Apply the shared contract to AI and exception capture.
- [x] 1.3 Add ten acceptance scenarios for wire delivery, nullable input compatibility, and disk persistence/restore.

## 2. Validation and archive

- [x] 2.1 Validate OpenSpec and Gherkin syntax, scenario coverage, and JSON input/output examples.
- [x] 2.2 Sync canonical specs and consolidate the final contract into one archive relative to the PR base.

Validation covers specification consistency and serialized JSON fixtures, not SDK/backend conformance. API compatibility was inspected statically; no SDK compilation, runtime, or persistence tests were run.
