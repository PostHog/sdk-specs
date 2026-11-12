## Context

The accepted review feedback on SDK-specs #211 concerns documentation and fixture consistency, not a new SDK implementation. The original archived change supplies backend and SDK source evidence. Static inspection of PR head `3c602641bea824d656ea59c4f27d801f588864e9` confirmed:

- The combined-error scenario does not name the response-wide error string.
- Default handling and local-inconclusive/remote-failed telemetry have no explicit scenarios.
- Failure interpretation is independent of the response-wide error bit, but the text does not distinguish that from the existing client refresh rules in `bootstrap`.
- The paired bulk API has no failed-record requirement.
- The acceptance outline for no-rule-identity outcomes includes a failed row and unconditionally asserts scalar false, excluding SDKs with documented nullish no-result mappings.

## Goals / Non-Goals

**Goals:** Make the accepted cases concrete, retain existing client refresh and missing-response conventions, and reconcile the acceptance fixture without losing its metadata and exposure checks.

**Non-Goals:** Decide release compatibility; change SDK code, snapshot missing/unresolved behavior, bootstrap retention policy, harness bindings, integration tags or dependency pins.

## Decisions

- Keep interpretation and retention separate. Failed records never supply a new value. Existing bootstrap rules decide whether a previously served value remains: intentionally partial or response-wide errored refreshes merge; complete refreshes without that bit replace. Successful in-call server local values remain protected separately.
- Use the documented missing response sentinel for failed direct-read telemetry, not a caller default. Preserve config-version and reason attribution for failed config version 2 records.
- Add a paired-bulk requirement rather than rely only on a value-only API cross-reference. Failed remote payloads cannot replace a successful local pair.
- Split the failed fixture row into its own scenario. Retain config-version/reason, no-rule-identity and no-exposure assertions without forcing a platform-independent scalar false.
- Keep the existing descriptive acceptance scope. No `@sdk:` opt-in or claim of real-adapter execution is introduced.

## Validation

The baseline canonical specs pass strict validation. A Gherkin-AST consistency check fails on the existing failed row because it requires scalar false; repeat it after the split while checking that all metadata and no-exposure assertions remain.

Use the official Gherkin parser/compiler version 39.0.0, matching harness revision `f7afba4378941ae40bf84d8f10d30f2cfa4df212`. Check harness discovery against that revision and report missing legacy bindings rather than claiming runtime conformance. Validate the delta, sync/archive it with the CLI, validate all canonical specs, and check the final diff.

The fixture check passes after the split: 31 cases parse, all 30 unaffected cases are unchanged, and the failed case retains all six metadata/no-exposure assertions. Discovery reports 4 harness-ready cases and 27 cases with existing missing bindings; no new unbound step phrases were introduced. No SDK runtime execution is claimed.

## Risks / Trade-offs

- Failure interpretation could be mistaken for a new stale-cache policy. Mitigation: explicit complete/partial/errored refresh cases.
- A fixture-only change could be mistaken for executable coverage. Mitigation: retain descriptive tags and report discovery gaps separately from parsing and SDK execution.
- SDK release compatibility is still undecided. Mitigation: leave that review thread open and add no normative release-policy wording.

## Open Questions

The reviewer's release-policy question is deliberately deferred at the user's request.
