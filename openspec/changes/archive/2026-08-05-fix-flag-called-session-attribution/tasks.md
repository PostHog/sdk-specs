## 1. Spec delta

- [x] 1.1 Confirm the delta modifies the existing `Minimal event mode for non-experiment flags`
      requirement, adding one allowlist category and one scenario, with all other scenarios
      copied unchanged
- [x] 1.2 Verify the new category names the concrete properties (`$referring_domain`,
      canonical UTM/click-id params) rather than a vague phrase, consistent with how this repo
      names concrete rules elsewhere (see sdk-specs#20's precedent)

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Run `/opsx:apply` then `/opsx:archive` to sync the delta into
      `specs/feature-flag-called-tracker/spec.md`

## 3. Downstream follow-up (separate changes, not this one)

- [ ] 3.1 If another SDK ships a minimal-event mode in the future, confirm its allowlist
      includes the session-attribution category before treating it as conformant
