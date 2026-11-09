# Tasks

## 1. Request-context contract

- [x] 1.1 Compare existing tracing-headers requirements and native trace context keys; record the integration gap in proposal.md and design.md.
- [x] 1.2 Define active request spans, child snapshots, precedence, scope lifetime, and optional setup through delta requirements with observable scenarios.
- [x] 1.3 Add matching descriptive scenarios to the existing tracing-headers acceptance feature and validate their Gherkin syntax with the official parser.
- [x] 1.4 Validate the change with OpenSpec strict checks.

## Workflow follow-up

- Sync and archive the completed spec change on this branch before opening the PR.
- Validate the synchronized canonical specs with OpenSpec strict checks and inspect the resulting diff.
- Keep SDK implementation, framework validation, and release progress in issue #128; archive does not mean those implementations are complete.
