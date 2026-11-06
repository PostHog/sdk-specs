## 1. Specify the warning scope

- [x] 1.1 Prepare the complete modified warning requirement, including runtime metadata, retained definitions, and warning deduplication.
- [x] 1.2 Add matching acceptance scenarios for API/cache loads, server/shared/null/absent runtimes, retained local evaluation, and runtime changes.

## 2. Validate and record follow-ups

- [x] 2.1 Audit every requested SDK and the test harness at recorded revisions, and prepare the PR comment identifying SDK fixes beyond Node.
- [x] 2.2 Validate the OpenSpec change, parse the acceptance scenarios, run harness discovery, and record binding or execution gaps without claiming conformance.

OpenSpec change validation passed. Harness discovery at `75fb00092c6045daef60c30acc10ac83afefbfe9` parsed all 11 added examples but reported missing bindings for each. The complete feature changed from 100 cases (46 harness-ready, 54 missing bindings) to 111 cases (46 harness-ready, 65 missing bindings). Both discovery runs exited 1. No SDK execution or new integration selection tags are claimed.

## 3. Address PR review

- [x] 3.1 Reuse existing definition, runtime, and refresh wording; add a positive server `unsupported_definition` warning example and assert the suppressed definition remains unresolved.
- [x] 3.2 Clarify the snapshot runtime-filter reference and warning reset rule, sync the delta into the canonical spec, and validate matching acceptance scenarios.

Review validation: the change and all 68 canonical specs pass strict OpenSpec validation. Static checks confirm the canonical warning requirement exactly matches the delta and all six warning scenarios have matching steps and Examples in Gherkin and OpenSpec. Harness discovery at the same revision now parses 112 cases (46 harness-ready, 66 missing bindings), including 12 examples added by this PR; it still exits 1. The explicit null runtime remains distinct from an absent field via `reports evaluation runtime null`; no runtime setup or warning-observation binding is available at this harness revision. SDK execution remains unverified.
