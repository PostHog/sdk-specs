## 1. Acceptance contract

- [x] 1.1 Correct canonical applicability to include existing server manual exception APIs and document Node's current signature, using the prepared delta for normative changes.
- [x] 1.2 Retain sdk-specs #103's structured type/message correction in the existing canonical requirement, behavior description, and handled-exception acceptance scenario.
- [x] 1.3 Add the two native-exception delivery cases to the existing feature with explicit distinct IDs, public flush, and received-envelope assertions. Initially retain descriptive server tags.
- [x] 1.4 Move Background setup into each existing legacy scenario and preserve its coverage and applicability.

## 2. Shared harness bindings and tests

- [x] 2.1 Add the JSON-argument operation step for `/capture_exception`, forwarding the descriptor and operation arguments unchanged.
- [x] 2.2 Add received-primary-exception assertions for type/message, boolean handled state, and nonempty stack frames; reuse existing request, event, and JSON property assertions.
- [x] 2.3 Add controlled healthy/defective hosts covering exact delivery, identity, scalar/nested JSON types, missing or malformed exception data, unexpected SDK throws, and both capture wire formats.
- [x] 2.4 Verify missing-route reporting and server/client profile selection; update whole-acceptance-suite controlled-host coverage to account for newly selected exception cases.
- [x] 2.5 Document the route and fixture semantics and add a harness changeset according to repository policy.

## 3. Node public adapter and tests

- [x] 3.1 Negotiate `/capture_exception`, construct the native TypeError fixture, and call public `captureException()` with supplied positional arguments while preserving omission, native outcomes, and SDK exceptions.
- [x] 3.2 Add argument-spy tests for the native Error object and stack, caller properties, omitted properties, supported descriptor validation, unknown parameters, and completion classification.
- [x] 3.3 Add installed-package HTTP tests proving explicit flush delivers the native exception and caller arguments without synthetic payload construction or implicit flush.
- [x] 3.4 Document the public signature, native fixture representation, and supported argument subset without changing SDK production code or CI pins.

## 4. Integration verification

- [x] 4.1 Run focused harness and adapter suites, retaining their exact commands and completed results.
- [x] 4.2 Build Node and its dependency closure freshly from the follow-up source; run the new cases with checkout-based specs and harness in CJS/ESM and capture v0/v1, preserving reports and exit codes.
- [x] 4.3 After all four executions pass, replace the new cases' descriptive server tags with `@sdk:server` and confirm whole-suite selection, missing-route visibility, and unselected legacy cases.
- [x] 4.4 Validate a self-contained branch-built harness distribution against the same real Node consumer, without publication.
- [x] 4.5 Run changed-file formatting/lint checks, strict OpenSpec validation, and `git diff --check`; obtain one fresh read-only post-implementation review and resolve in-scope findings.

## Post-implementation archive and handoff

After the implementation tasks pass, archive this change on the same specs branch and verify the applied specs strictly. Record exact heads, dependency links, validation results, and residual rollout gates. Confirm group-identify branches and PR scopes remain intact.

Use scoped commits and `gh stack` to track and submit each follow-up above its repository's group-identify PR under the established submission authority. Merge, publication, reviewer requests, and rollout pins require separate authority.
