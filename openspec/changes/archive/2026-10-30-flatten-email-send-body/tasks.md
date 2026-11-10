## 1. Spec delta

- [x] 1.1 Modify **Send request** in `emails` so the body holds `template_id`, `to`, `message_data` and, only when the caller passed one, `distinct_id`, and update its scenario body
- [x] 1.2 Modify **Send request headers** so the scenario without a distinct ID says the body has no `distinct_id`

## 2. Prose alignment (applied at archive, outside the requirement delta)

- [x] 2.1 Update the `send` row of the HTTP mapping table in `specs/emails/spec.md` to the flat body

## 3. Acceptance feature

- [x] 3.1 Update the expected request body in `acceptance/public/emails.feature` to the flat body

## 4. Validation

- [x] 4.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 4.2 Run `openspec archive` to sync the delta into `specs/emails/spec.md` and archive the change
