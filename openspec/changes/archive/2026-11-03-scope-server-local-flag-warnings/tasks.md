## 1. Specify the warning scope

- [x] 1.1 Prepare the complete modified warning requirement, including runtime metadata, retained definitions, and warning deduplication.
- [x] 1.2 Add matching acceptance scenarios for API/cache loads, server/shared/null/absent runtimes, retained local evaluation, and runtime changes.

## 2. Validate and record follow-ups

- [x] 2.1 Audit every requested SDK and the test harness at recorded revisions, and prepare the PR comment identifying SDK fixes beyond Node.
- [x] 2.2 Validate the OpenSpec change, parse the acceptance scenarios, run harness discovery, and record binding or execution gaps without claiming conformance.

OpenSpec change validation passed. Harness discovery at `75fb00092c6045daef60c30acc10ac83afefbfe9` parsed all 11 added examples but reported missing bindings for each. The complete feature changed from 100 cases (46 harness-ready, 54 missing bindings) to 111 cases (46 harness-ready, 65 missing bindings). Both discovery runs exited 1. No SDK execution or new integration selection tags are claimed.
