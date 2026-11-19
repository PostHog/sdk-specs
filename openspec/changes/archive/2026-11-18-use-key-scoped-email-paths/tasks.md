## 1. Spec delta

- [x] 1.1 Modify **App host** in `emails` so its scenario expects `https://eu.posthog.com/api/messaging/send/email/`
- [x] 1.2 Modify **Send request** so `send` posts to `{app host}/api/messaging/send/email/`
- [x] 1.3 Modify **Status read request** so `get` reads `{app host}/api/messaging/emails/{message ID in lowercase}/`

## 2. Prose alignment (applied at archive, outside the requirement delta)

- [x] 2.1 Update the `send` and `get` rows of the HTTP mapping table in `specs/emails/spec.md` to the new paths, and note that the routes accept project secret API keys only

## 3. Acceptance feature

- [x] 3.1 Update the expected send and status read URLs in `acceptance/public/emails.feature`

## 4. Validation

- [x] 4.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 4.2 Run `openspec archive` to sync the delta into `specs/emails/spec.md` and archive the change
