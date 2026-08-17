## 1. Prose alignment (applied directly, no requirement-delta mechanism)

- [x] 1.1 Update `specs/flush/spec.md`'s Ruby "Surface variants" row to
      `flush(timeout: nil): Boolean`, with a one-line note on the return semantics
- [x] 1.2 Add a Ruby "Surface variants" row to `specs/shutdown/spec.md`:
      `shutdown(timeout: nil): Boolean`, with a one-line note on the return semantics

## 2. Validation

- [x] 2.1 Confirm no existing requirement or scenario text was changed
- [x] 2.2 Run `openspec validate --specs --strict` and resolve any errors
