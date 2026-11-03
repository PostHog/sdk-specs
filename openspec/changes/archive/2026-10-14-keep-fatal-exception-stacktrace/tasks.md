## 1. Spec delta

- [x] 1.1 Add the **Fatal exception payloads keep their exception data** requirement to
      `capture-exception`, with scenarios for the unset optional frame field, for parity with the
      handled path, and for the size budget

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any new errors
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/capture-exception/spec.md` and
      archive the change
