## 1. Contract and acceptance

- [x] 1.1 Clarify existing public API compatibility and event serialization for wire and disk in the shared capture requirement.
- [x] 1.2 Add acceptance scenarios for existing nullable inputs and persisted null/undefined values without changing earlier array-position coverage.

## 2. Validation

- [x] 2.1 Validate the delta, Gherkin syntax, scenario coverage, and serialized JSON examples.
- [x] 2.2 Review the clarification against the existing AI/exception references and disk-storage scope before sync/archive.

Strict delta validation passed. Ten current null-policy scenarios across capture, AI, and exception capture match the Gherkin files. JSON input/output examples, including disk and restored-event payloads, match reference normalization without array compaction. API compatibility wording was inspected statically; no SDK compilation, runtime, or persistence conformance tests were run.
