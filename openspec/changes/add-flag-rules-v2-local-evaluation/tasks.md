## 1. Evidence and proposal

- [x] 1.1 Read the public rules v2 contract in posthog-sdk-test-harness 1.34.0 (contract 10.0.0): the config schema, the literal registry and its version rule, the boolean, value and experiment corpora, the hash vectors and the definitions schemas.
- [x] 1.2 Read posthog-sdk-test-harness#111 (contract 10.1.0, draft): `rules/local_outcomes.json`, `corpus/v2_local_evaluation.json` and `fixtures/wire/definitions_feed.json`.
- [x] 1.3 Read the existing specs: `local-feature-flag-evaluator`, `flag-definition-loader`, `evaluate-flags`, `get-feature-flag-result`, `feature-flag-called-tracker` and `experiment-exposure`.
- [x] 1.4 Write the proposal, the design and the delta specs, and run `openspec validate add-flag-rules-v2-local-evaluation --strict`.

## 2. Settle the decisions

- [ ] 2.1 Settle the decisions in `design.md`, above all the cache field name (decision 9) and the harness capability name (decision 10), and update the delta specs and features for any change.
- [ ] 2.2 Release contract 10.1.0 (posthog-sdk-test-harness#111) and point this change at the release.
- [ ] 2.3 Pin in the contract the two outcomes this change proposes beyond it: an inactive entry whose document is unsupported is `flag_disabled` (decision 6), and an unknown entry field outside `filters` is ignored (decision 11).

## 3. Acceptance and discoverability

- [x] 3.1 Add `acceptance/private/flag-rules-v2-local-evaluation.feature`, built on the contract's feed fixture and local cases: the `v=2` request, the legacy body, every return type, unsupported entries in auto and local-only modes, missing context, inactive flags, both events, a bulk fallback, dates in UTC and a dependency on a config version 2 flag.
- [x] 3.2 Rewrite the two local scenarios of `acceptance/private/experiment-exposure.feature` with concrete definitions, and replace their `@v2_local_evaluation_capable` tag with `@requires:feature_flags_local_evaluation_v2`.
- [x] 3.3 Add the shared cache scenarios to `acceptance/private/flag-definition-loader.feature`.
- [ ] 3.4 Bind the three new steps in posthog-sdk-test-harness (a definitions document for `v=2` requests, the definitions query check, the absent event property), run the features against a reference SDK, and then replace `@server` with `@sdk:server` on the scenarios that pass.
- [ ] 3.5 When syncing, write the Purpose and Applicability sections of `openspec/specs/flag-rules-v2-local-evaluation/spec.md`, and add "Flag Rules V2 Local Evaluation" to the capability index in `README.md`.

## 4. Validation and archive

- [x] 4.1 Run `openspec validate add-flag-rules-v2-local-evaluation --strict` and resolve all issues.
- [ ] 4.2 Archive the change so the canonical specs are synced in the same PR, then run `openspec validate --specs --strict`.
