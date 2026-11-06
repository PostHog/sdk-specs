## 1. Spec delta

- [x] 1.1 Add one requirement to `capture`, **Client-side capture rate limiting never loses tokens to a clock change**
- [x] 1.2 State the monotonic refill rules: zero refill while the clock is behind the stored instant, store the later instant, cap at the burst limit, never go below zero
- [x] 1.3 Add the rollback and catch-up scenarios

## 2. Validation

- [x] 2.1 Run `openspec validate --specs --strict` and resolve any errors
- [x] 2.2 Run `openspec archive` to sync the delta into `specs/capture/spec.md` and archive the change
