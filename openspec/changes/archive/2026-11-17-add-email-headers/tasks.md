## 1. Spec delta

- [x] 1.1 Modify **Send code form** in `emails` so the code form takes an optional headers mapping, sent as given, and a template send refuses it
- [x] 1.2 Modify **Send request** so the code-form body holds `headers` only when the caller passed it

## 2. Prose alignment (applied at archive, outside the requirement delta)

- [x] 2.1 Update the "Not covered" line, the public surface table and the HTTP mapping table in `specs/emails/spec.md`

## 3. Acceptance feature

- [x] 3.1 Add a code-form send with headers to `acceptance/public/emails.feature`

## 4. Validation

- [x] 4.1 Run `openspec validate --specs --strict` and archive the change into `specs/emails/spec.md`
