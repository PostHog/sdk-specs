## 1. Spec delta

- [x] 1.1 Confirm the delta in `specs/identify/spec.md` modifies the single `Canonical identify
      behavior` requirement as a full copied-and-edited block
- [x] 1.2 Add the new `@client` scenario for matching-id-while-anonymous transition
- [x] 1.3 Verify the three existing scenarios are copied unchanged

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Split the "Same distinct id" bullet in Behavior step 3 into anonymous-transition vs.
      already-identified cases
- [x] 2.2 Update the "Duplicate-call suppression" table row to note the anonymous-transition
      exception

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 3.2 Run `/opsx:apply` then `/opsx:archive` to sync the delta into `specs/identify/spec.md`

## 4. Downstream follow-up (separate changes, not this one)

- [ ] 4.1 Audit Flutter and React Native for the same fix; port + re-check against this scenario
      if they still exhibit the old behavior
