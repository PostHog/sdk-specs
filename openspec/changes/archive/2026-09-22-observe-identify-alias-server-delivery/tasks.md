## 1. Specify and implement acceptance coverage

- [x] 1.1 Update server identify and alias OpenSpec scenarios to assert externally delivered event names, identities and properties after public flush.
- [x] 1.2 Replace queue-based server acceptance scenarios with two identify examples and two alias examples in the existing feature files.
- [x] 1.3 Keep the client and invalid-input scenarios' original steps and preconditions, without imposing them on the server examples.

## 2. Validate and archive

- [x] 2.1 Synchronize the modified requirements into `openspec/specs/identify/spec.md` and `openspec/specs/alias/spec.md` and archive the change under `openspec/changes/archive/` in this PR.
- [x] 2.2 Run `openspec validate --specs --strict`, parse the Gherkin cases and validate the four server cases with the opt-in harness and real Node adapter.
