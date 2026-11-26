## 1. Spec delta

- [x] 1.1 Modify **Public surface** in `emails` to name `send`, `batch` and `get`
- [x] 1.2 Add the scheduled send requirements: **Scheduled send request**, **Scheduling only on PostHog Cloud**, **Scheduled send confirmation**, **Grace window for a passed time**, **Unconfirmed schedule** and **Scheduled delivery status**
- [x] 1.3 Add the batch requirements: **Batch request**, **Batch argument checks**, **Batch retries**, **Batch recipient results**, **Batch refusals**, **Batch 404 without a field**, **Batch content too large**, **Batch refusal after a lost answer** and **Unconfirmed recipient wording**

## 2. Prose alignment (applied at archive, outside the requirement delta)

- [x] 2.1 Update Purpose, Applicability and Not covered in `specs/emails/spec.md` for scheduled and batch sends
- [x] 2.2 Add the scheduled time and `batch` to the Public surface table, the batch route to the HTTP mapping table, and `scheduled` to the statuses
- [x] 2.3 Add the `409` `batch_unavailable` row to the Error names table, and a Batch errors table

## 3. Validation

- [x] 3.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 3.2 Run `openspec archive` to sync the delta into `specs/emails/spec.md` and archive the change
