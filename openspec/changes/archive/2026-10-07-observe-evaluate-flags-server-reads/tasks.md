## 1. Acceptance executions

- [x] 1.1 Add the expanded remote-read, request-local filter, supported caller-default, and safe-empty matrix to the existing evaluate-flags feature; scope legacy Background setup and server applicability to existing scenarios while preserving all legacy examples and capability tags.
- [x] 1.2 Express requested reads as ordered JSON arguments, public semantic outcomes, identity/context/key-scope traffic expectations, and explicit public flush/exposure presence, dedupe, silence, and missing-key metadata assertions.
- [x] 1.3 Update specs documentation and strictly validate the prepared delta; leave integration tags pending real SDK verification.

## 2. Shared harness bindings

- [x] 2.1 Bind the compound read step to /evaluate_flags/read, forwarding JSON arguments unchanged and retaining only arguments/native getter outcomes for assertions.
- [x] 2.2 Add strict ordered semantic checks for declared scalar/rich public results, native missing values, declared decoded/serialized payload representations, unordered public key sets, and nested filter outcomes, accessed-key selection, and parent preservation; compare exposure count, identity/groups, flag key, canonical response, and missing-key error metadata.
- [x] 2.3 Add healthy/defective controlled-host tests in both capture protocols and public representation modes, covering reordered/coerced results, undeclared/wrong result shapes, double-decoded strings, false/zero/null payloads, incorrect context/key scope, filter membership, false/unknown/payload-only access selection, child-to-parent access leakage, stale results, extra requests, wrong exposures, exposure during silent reads/filters, incorrect defaults, fabricated empty results, missing-identity/disabled traffic, failure not exercised, and accessor retries.
- [x] 2.4 Cover missing routes, native throws, client selection, whole-suite/bundle expectations, and add harness documentation plus a minor changeset.

## 3. Node adapter

- [x] 3.1 Implement request-scoped /evaluate_flags/read: translate evaluation arguments, await one public evaluateFlags call, invoke requested getters/public key enumeration and native only/onlyAccessed filters with nested reads in order, and return their outcomes; declare Node's scalar-value and decoded-JSON representations through existing capability negotiation.
- [x] 3.2 Add argument/method spies for option JSON and omission fidelity, one evaluation per compound request, every requested getter/filter call with correct native parent/child receiver, evaluation-only requests, caller-default argument omission/false/true, native missing-identity overloads, public disabled/flag-specific retry settings, empty/unknown/duplicate filter keys, SDK-owned accessed-key filtering and clone isolation, and independent evaluations on later requests.
- [x] 3.3 Declare the supported flag_snapshot_enablement_default capability for Node; add unsupported method/argument, native thrown-result, missing-value, and non-JSON-result regressions; retain existing adapter lifecycle/error behavior.
- [x] 3.4 Add real installed-package HTTP tests in CJS/ESM × capture v0/v1, public warning observations for unknown filter keys in SDK-native integration tests, and update adapter documentation.

## 4. Real SDK validation and review

- [x] 4.1 Build fresh Node packages/consumer from pinned source and verify package provenance; execute every expanded matrix case explicitly in all four configurations before integration opt-in.
- [x] 4.2 Add @sdk:server after actual installed-SDK execution, retaining non-compliant cases and their failing statuses; verify full profile-selected acceptance discovery and execute the entire tagged suite in all four configurations.
- [x] 4.3 Run focused harness/adapter suites, changed-file format/lint, strict OpenSpec validation, and git diff checks; record exact results, heads, scopes, and residual risks.
- [x] 4.4 Obtain one fresh read-only review across the three scoped diffs, adjudicate findings, fix validated in-scope issues, and rerun affected checks.

## Post-implementation handoff

After implementation/review completes, synchronize and archive this change on the same specs branch, preserving every existing canonical requirement. Commit scoped changes only; build and validate a clean committed bundled harness distribution against the committed specs and Node adapter in all four configurations.

Submit/link the three follow-ups using the existing repository stacks above #105, #75, and #5232. Preserve parent PR state and branches. Keep publication, merges, CI defaults, and release-pin advancement separate from this acceptance-test submission.
