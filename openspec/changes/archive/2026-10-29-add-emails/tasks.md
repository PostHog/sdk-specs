## 1. Verification

- [x] 1.1 Inventory posthog-node and posthog-python email behavior from source: surface, options, request, idempotency, retries, errors, status read, shutdown
- [x] 1.2 Check the request and response shapes against the backend send and status views
- [x] 1.3 List the differences between the two SDKs and pick the canonical behavior for each

## 2. Spec delta

- [x] 2.1 Write the `emails` delta
- [x] 2.2 Review the delta: every requirement has at least one scenario, and scenarios use WHEN/THEN

## 3. Acceptance feature

- [x] 3.1 Add `acceptance/public/emails.feature` with server scenarios for the request, idempotency, retries, host refusal, errors and the status read

## 4. Archive

- [x] 4.1 Archive the change, add the Purpose, Applicability and Public surface sections to `openspec/specs/emails/spec.md`, and add the capability to the README table
