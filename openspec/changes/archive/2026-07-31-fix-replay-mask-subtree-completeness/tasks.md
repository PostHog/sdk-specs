## 1. Spec delta

- [x] 1.1 Confirm the delta in `specs/session-replay-privacy/spec.md` modifies the single
      `Canonical session-replay-privacy behavior` requirement as a full copied-and-edited block
- [x] 1.2 Add the new scenario for mask-discovery completeness across siblings/nested matches
- [x] 1.3 Verify the four existing scenarios are copied unchanged

## 2. Prose alignment (applied at archive, outside the requirement-delta mechanism)

- [x] 2.1 Add a completeness clause to Behavior item 4 (apply masks before
      serialization/upload) covering screenshot/wireframe mask discovery

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 3.2 Run `/opsx:apply` then `/opsx:archive` to sync the delta into
      `specs/session-replay-privacy/spec.md`

## 4. Downstream follow-up (separate changes, not this one)

- [ ] 4.1 Audit native iOS/Android/web mask-discovery tree walks for the same traversal-drops-
      matched-nodes defect class, independent of Flutter's own implementation
- [ ] 4.2 Evaluate the two adjacent bugs noted in the Flutter PR (stale parsers after re-setup;
      `maskAllImages` masking text) for their own follow-up changes if confirmed cross-platform
