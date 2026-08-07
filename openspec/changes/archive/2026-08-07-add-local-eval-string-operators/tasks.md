## 1. Spec delta

- [x] 1.1 Confirm the delta in `specs/local-feature-flag-evaluator/spec.md` adds one new
      requirement (`String prefix/suffix property filter operators`) with two scenarios
- [x] 1.2 Verify the existing requirements and scenarios are copied unchanged

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Add a one-line pointer from Behavior item 6 ("Match flag conditions locally") to the
      new requirement, without re-enumerating every operator there

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 3.2 Run `/opsx:apply` then `/opsx:archive` to sync the delta into
      `specs/local-feature-flag-evaluator/spec.md`

## 4. Downstream follow-up (separate changes, not this one)

- [ ] 4.1 Audit posthog-android, posthog-ios, posthog-java (posthog-server), and posthog-flutter
      for the same `starts_with`/`ends_with` local-evaluation support; port this requirement's
      scope to them if/when they ship it
- [ ] 4.2 Consider a separate requirement for "unrecognized operator degrades to inconclusive
      for that flag rather than disabling local evaluation project-wide" once more than one SDK
      is confirmed to implement it (posthog-dotnet#268 is the only confirmed instance so far)
