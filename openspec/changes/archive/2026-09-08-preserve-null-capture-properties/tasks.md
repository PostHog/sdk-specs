## 1. Contract and acceptance coverage

- [x] 1.1 Define null preservation in capture and reference it from AI and exception capture, with scoped exclusions and SDK compatibility evidence.
- [x] 1.2 Add matching wire-level acceptance scenarios for queued/immediate capture, undefined versus null, AI capture, and exception capture.

## 2. Validation

- [x] 2.1 Validate the OpenSpec change strictly and check acceptance syntax and scenario coverage.
- [x] 2.2 Review the delta against canonical specs for scope and compatibility before archive sync.

Validation: strict change validation passed; all 62 existing canonical specs passed strict validation; all three edited Gherkin files parsed; five new scenarios matched their delta specs and JSON examples parsed successfully; `git diff --check` passed. These are specification checks, not SDK conformance tests. Canonical specs were synced through `openspec archive` on 2026-09-08 after owner approval, and all 62 canonical specs passed strict validation again.
