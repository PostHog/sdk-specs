## 1. Spec delta

- [x] 1.1 Add **Send message category** with the optional `category` of the code form, its wire shape, the left-out rule, its meaning on the server, and its refusal codes
- [x] 1.2 Modify **Send code form** so the message category is a code-form input that a template send refuses
- [x] 1.3 Modify **Send request** so the code form holds `category` only when the caller passed one
- [x] 1.4 Modify **Argument checks** so the SDK checks the category's shape and leaves the key's format and the lengths to PostHog
- [x] 1.5 Modify **Error names** so the error name is not called a category

## 2. Prose alignment (applied at archive, outside the requirement delta)

- [x] 2.1 Update the Purpose, the "Not covered" line, and the code-form rows of the public surface and HTTP mapping tables in `specs/emails/spec.md`

## 3. Acceptance feature

- [x] 3.1 Add message-category scenarios to `acceptance/public/emails.feature`, and for a refused category send keeping PostHog's code without a retry

## 4. Validation

- [x] 4.1 Check the delta against the contract in PostHog/posthog#132118 and the eight SDK changes
- [x] 4.2 Run `openspec validate --specs --strict` and archive the change into `specs/emails/spec.md`
