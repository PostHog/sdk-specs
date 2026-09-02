## 1. Establish the Contract

- [x] 1.1 Read the logs `beforeSend` implementation in every SDK that has one, and record whether a throwing hook drops the record or continues with the pre-hook value.
- [x] 1.2 Check whether any SDK implements the spec's fail-open text. None does.
- [x] 1.3 Read the `traces` rationale for diverging, and decide whether the stated reason — that the logs hook "does not carry a scrubbing designation" — holds against how the SDKs and their docs actually present it.
- [x] 1.4 Check the sibling analytics `before_send` hook in the same SDKs, to tell a logs-specific decision apart from a house style.
- [x] 1.5 Confirm `posthog-ios` cannot observe a throwing hook, so the requirement is satisfiable there without a code change.

## 2. Write the Delta

- [x] 2.1 Add the scrubbing designation to `beforeSend hook` and rewrite the failure sentence to require a drop, saying what containment still guarantees.
- [x] 2.2 Require the drop to be diagnosable, allowing an error-type-only report because a hook's exception message can embed the record body.
- [x] 2.3 Replace the `throwing hook is contained` scenario and add one for containment.
- [x] 2.4 Update `Gating and beforeSpanSend` in `traces` to drop the divergence sentence.

## 3. Validate and Review

- [x] 3.1 Run `openspec validate --specs --strict --no-interactive` and `openspec validate require-fail-closed-logs-before-send --strict`.
- [x] 3.2 Run `git diff --check`.
- [ ] 3.3 Decide whether the analytics `before_send` split gets its own proposal, and whether it resolves toward drop or continue.
- [ ] 3.4 Decide whether the two hooks should converge further than failure handling — the logs hook drops on a blanked body, the traces hook has no equivalent.
