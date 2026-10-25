## 1. Source confirmation

- [x] 1.1 Confirm the capture v1 server contract on PostHog/posthog `master` (`rust/capture/src/v1/constants.rs` `REQUIRED_HEADERS`, `v1/context.rs` header and token checks, `v1/analytics/types.rs` `Event` and option parsing, `v1/analytics/response.rs` `results` and `duplicates_dropped`, `v1/error.rs` status codes and `Retry-After`).
- [x] 1.2 Confirm the shipped SDK behavior on posthog-python `v1` (`capture_send.py`, `capture_event.py`, `consumer.py`, `client.py`), posthog-go `v1` (`capture_send.go`, `capture_event.go`, `backoff.go`, `posthog.go` `enqueueTo`), posthog-rs `v1` (`capture_event.rs`, `client/capture.rs`, `retry.rs`, `transport.rs`) and the posthog-node capture v1 series (`capture-v1/sender.ts`, `transform.ts`, `capture-lane/lane.ts`, `event-defaults.ts`), including the open pre-release PRs that change redirects and the minimal flag-event trim.
- [x] 1.3 Record the accepted variations (non-finite numbers, compression default, missing distinct id, timestamp digits) in `design.md`.

## 2. Spec deltas

- [x] 2.1 Draft the `capture` delta: wire contract, request headers, per-event results, per-event options, server layer order, library identity, session and window ids, identity fallbacks, timestamps, per-event serialization, fail-open; modify the client precedence requirement's server note.
- [x] 2.2 Draft the `retry-queue` delta: status classification, attempt budget, waits, `Retry-After`, no HTTP-library retries; narrative notes for `429` and `413`.
- [x] 2.3 Draft the `http-client` delta: bearer token, header set, encodings, same-origin 307/308 redirects.
- [x] 2.4 Draft the `event-batcher` delta: byte-aware check-before-append, no analytics per-event cap below capture's, `413` terminal.

## 3. Validation and archive

- [x] 3.1 Run `openspec validate add-capture-v1 --type change --strict`.
- [x] 3.2 Archive the change on this branch (`openspec archive add-capture-v1 --yes`), then apply each delta's "Narrative alignment" notes to the canonical specs by hand.
- [x] 3.3 Run `openspec validate --specs --strict --no-interactive` and compare the totals with `main` (67 passed, 0 failed on 2026-10-25).
- [ ] 3.4 Reconcile with sdk-specs #145 (flag properties), #140 (non-finite numbers) and #81 (compression default) before merge.

Validation note: these are specification checks. The scenarios are not opted in with `@sdk:server`; opting them in needs an end-to-end run of the harness against a real SDK adapter, which is a separate change.
