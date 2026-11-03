## 1. Spec delta

- [x] 1.1 Modify exactly one requirement in `http-client`, **Feature flag evaluation retry policy**, as a full copied-and-edited block
- [x] 1.2 State that a connection refused by the destination SHALL NOT be retried and is surfaced as the flag error immediately, while DNS, TLS, timeout, and connection reset/lost failures still retry
- [x] 1.3 Add the **Flags request does not retry a refused connection** scenario
- [x] 1.4 Add the scenario to `acceptance/private/http-client.feature`
- [x] 1.5 Correct the posthog-android n22 compliance remediation so it no longer asks for `ConnectException` retry

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/http-client/spec.md` and archive the change
