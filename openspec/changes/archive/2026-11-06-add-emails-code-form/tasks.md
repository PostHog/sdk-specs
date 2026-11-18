## 1. Spec delta

- [x] 1.1 Modify **Public surface** in `emails` so `send` covers both the template form and the code form
- [x] 1.2 Add **Send code form** with the code-form fields, their defaults, and the one-form-per-call rule
- [x] 1.3 Modify **Send request** so the body shape follows the form the caller chose
- [x] 1.4 Modify **Argument checks** to cover the code-form fields
- [x] 1.5 Add **Migration header** for the client-level migrated-from option

## 2. Prose alignment (applied at archive, outside the requirement delta)

- [x] 2.1 Update the Purpose, the "Not covered" line, the public surface table, the client option table and the HTTP mapping table in `specs/emails/spec.md`

## 3. Acceptance feature

- [x] 3.1 Add a code-form send scenario to `acceptance/public/emails.feature`

## 4. Validation

- [x] 4.1 Check the delta against posthog-node and posthog-python as merged
- [x] 4.2 Archive the change into `specs/emails/spec.md`
